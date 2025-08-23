from flask import Flask, request, jsonify
from flask_cors import CORS
from flask_pymongo import PyMongo
from werkzeug.security import generate_password_hash, check_password_hash
from werkzeug.utils import secure_filename
import jwt
import datetime
from datetime import timezone
from functools import wraps
import os
import uuid
import base64
from PIL import Image
from bson.objectid import ObjectId
import io
import numpy as np
from google.oauth2 import id_token
from google.auth.transport import requests as google_requests
import requests
from Model.standalone_predictor import predict_image, load_model_and_encoder

app = Flask(__name__)
# Allow all origins for testing (use specific origins in production)
CORS(app, resources={r"/*": {"origins": "*"}})  # Changed to allow all origins

# Configurations
app.config['MONGO_URI'] = 'mongodb+srv://vaghelanikhil:NikhilVaghela121607@cluster0.qo1wq3w.mongodb.net/Cluster0?retryWrites=true&w=majority&appName=Cluster0'
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'agbvaljvhavmnbavhalfhuaefhbvchjvbvbavd')

# Google OAuth Configuration
GOOGLE_CLIENT_ID = os.environ.get('GOOGLE_CLIENT_ID', '742123302553-88e0099nok872g2re7e5l9m0v0h2ldh0.apps.googleusercontent.com')

mongo = PyMongo(app)
users = mongo.db.users
analyses = mongo.db.analyses
chat_history = mongo.db.chat_history
# New collection for prediction history items (image + prediction stored together)
predictions = mongo.db.predictions

# Configure upload folder
UPLOAD_FOLDER = 'uploads'
if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)

ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg'}

# Load the model and encoder at startup
model_path = 'Model/skin_disease_efficientnet_model1.pth'
encoder_path = 'Model/label_encoder_mode1.pkl'
model, label_encoder = load_model_and_encoder(model_path, encoder_path)

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def token_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        token = None
        if 'Authorization' in request.headers:
            token = request.headers['Authorization'].split(' ')[1]
        if not token:
            return jsonify({'message': 'Token is missing!'}), 401
        try:
            data = jwt.decode(token, app.config['SECRET_KEY'], algorithms=["HS256"])
            current_user = users.find_one({'email': data['email']})
        except Exception as e:
            return jsonify({'message': 'Token is invalid!'}), 401
        return f(current_user, *args, **kwargs)
    return decorated

# Make sure you have these imports at the top of your app.py file
import datetime
from datetime import timezone
from bson.objectid import ObjectId

@app.route('/chat/history', defaults={'chat_id': None}, methods=['POST', 'GET'])
@app.route('/chat/history/<chat_id>', methods=['GET'])
@token_required
def handle_chat_history(current_user, chat_id):
    if request.method == 'POST':
        data = request.get_json()
        if not data or 'messages' not in data or not data['messages']:
            return jsonify({'message': 'Missing or empty messages data'}), 400

        chat_id = data.get('chat_id')
        messages = data['messages']
        title = messages[0].get('text', 'Untitled Chat')
        
        if chat_id:
            # Update existing chat
            try:
                obj_id = ObjectId(chat_id)
            except Exception:
                return jsonify({'message': 'Invalid chat ID format'}), 400
            
            result = chat_history.update_one(
                {'_id': obj_id, 'user_email': current_user['email']},
                {
                    '$set': {
                        'messages': messages,
                        'title': title,
                        'timestamp': datetime.datetime.now(timezone.utc).isoformat()
                    }
                }
            )
            if result.matched_count == 0:
                return jsonify({'message': 'Chat not found or access denied'}), 404
            return jsonify({'message': 'Chat history updated successfully'}), 200
        else:
            # Create new chat
            chat_session = {
                'user_email': current_user['email'],
                'title': title,
                'messages': messages,
                'timestamp': datetime.datetime.now(timezone.utc).isoformat()
            }
            result = chat_history.insert_one(chat_session)
            return jsonify({
                'message': 'Chat history saved successfully',
                'chat_id': str(result.inserted_id)
            }), 201
    
    if request.method == 'GET':
        if chat_id:
            try:
                obj_id = ObjectId(chat_id)
            except Exception:
                return jsonify({'message': 'Invalid chat ID format'}), 400

            chat_session = chat_history.find_one({
                '_id': obj_id,
                'user_email': current_user['email']
            })

            if not chat_session:
                return jsonify({'message': 'Chat session not found or access denied'}), 404
            
            # --- START: ADDED FIX FOR SINGLE CHAT ---
            # Ensure timestamp is a string for backward compatibility
            if 'timestamp' in chat_session and isinstance(chat_session['timestamp'], datetime.datetime):
                chat_session['timestamp'] = chat_session['timestamp'].isoformat()
            # --- END: ADDED FIX FOR SINGLE CHAT ---

            chat_session['_id'] = str(chat_session['_id'])
            return jsonify(chat_session), 200
        else:
            user_chats = chat_history.find({'user_email': current_user['email']}).sort('timestamp', -1)
            history = []
            for chat in user_chats:
                # --- START: ADDED FIX FOR CHAT LIST ---
                # Ensure timestamp is a string for backward compatibility
                timestamp = chat.get('timestamp')
                if isinstance(timestamp, datetime.datetime):
                    timestamp = timestamp.isoformat()
                # --- END: ADDED FIX FOR CHAT LIST ---
                
                history.append({
                    'id': str(chat['_id']),
                    'title': chat['title'],
                    'timestamp': timestamp # Use the corrected timestamp
                })
            return jsonify(history), 200

@app.route('/chat/history/delete', methods=['POST'])
@token_required
def delete_chat_history(current_user):
    data = request.get_json()
    if not data or 'ids' not in data:
        return jsonify({'message': 'Missing chat IDs'}), 400

    chat_ids_str = data['ids']
    if not isinstance(chat_ids_str, list):
        return jsonify({'message': 'IDs should be a list'}), 400

    try:
        object_ids = [ObjectId(cid) for cid in chat_ids_str]
    except Exception:
        return jsonify({'message': 'Invalid chat ID format'}), 400

    result = chat_history.delete_many({
        '_id': {'$in': object_ids},
        'user_email': current_user['email']
    })

    if result.deleted_count > 0:
        return jsonify({'message': f'{result.deleted_count} conversations deleted successfully'}), 200
    else:
        return jsonify({'message': 'No conversations found to delete'}), 404


@app.route('/auth/google', methods=['POST'])
def google_auth():
    try:
        data = request.get_json()
        id_token_str = data.get('idToken')
        
        if not id_token_str:
            return jsonify({'message': 'ID token is required'}), 400
        
        # Verify the Google ID token
        try:
            idinfo = id_token.verify_oauth2_token(
                id_token_str, 
                google_requests.Request(), 
                GOOGLE_CLIENT_ID
            )
            
            # Get user info from Google
            google_user_id = idinfo['sub']
            email = idinfo['email']
            name = idinfo.get('name', '')
            picture = idinfo.get('picture', '')
            
        except ValueError as e:
            return jsonify({'message': 'Invalid Google token'}), 401
        
        # Check if user exists
        user = users.find_one({'email': email})
        
        if not user:
            # Create new user
            user = {
                'username': name,
                'email': email,
                'google_id': google_user_id,
                'profile_picture': picture,
                'auth_provider': 'google',
                'created_at': datetime.datetime.utcnow()
            }
            users.insert_one(user)
        else:
            # Update user info if needed
            users.update_one(
                {'email': email},
                {'$set': {
                    'username': name,
                    'profile_picture': picture,
                    'last_login': datetime.datetime.utcnow()
                }}
            )
            
        # Generate JWT token
        token = jwt.encode({
            'email': email,
            'exp': datetime.datetime.utcnow() + datetime.timedelta(hours=24)
        }, app.config['SECRET_KEY'], algorithm="HS256")
        
        return jsonify({'token': token, 'user': {
            'username': user.get('username'),
            'email': user.get('email'),
            'profile_picture': user.get('profile_picture')
        }}), 200
        
    except Exception as e:
        return jsonify({'message': str(e)}), 500

@app.route('/predict', methods=['POST'])
def predict():
    if 'image' not in request.files:
        return jsonify({'error': 'No image file provided'}), 400

    file = request.files['image']

    if file.filename == '':
        return jsonify({'error': 'No selected file'}), 400

    if file and allowed_file(file.filename):
        filename = secure_filename(file.filename)
        # Ensure the uploads directory exists
        if not os.path.exists(UPLOAD_FOLDER):
            os.makedirs(UPLOAD_FOLDER)
        image_path = os.path.join(UPLOAD_FOLDER, filename)
        file.save(image_path)

        try:
            # Use the pre-loaded model and encoder
            prediction_result = predict_image(image_path, model, label_encoder)
            return jsonify(prediction_result)
        except Exception as e:
            return jsonify({'error': str(e)}), 500
    else:
        return jsonify({'error': 'File type not allowed'}), 400


@app.route('/register', methods=['POST'])
def register():
    data = request.get_json()
    print(f"Received register request: {data}")  # Debug log
    if not data or not data.get('email') or not data.get('password') or not data.get('username'):
        return jsonify({'message': 'Missing fields!'}), 400
    if users.find_one({'email': data['email']}):
        return jsonify({'message': 'User already exists!'}), 409
    hashed_pw = generate_password_hash(data['password'])
    user = {
        'username': data['username'],
        'email': data['email'],
        'password': hashed_pw,
        'created_at': datetime.datetime.utcnow()
    }
    users.insert_one(user)
    return jsonify({'message': 'User registered successfully!'}), 201

@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    print(f"Received login request: {data}")  # Debug log
    if not data or not data.get('email') or not data.get('password'):
        return jsonify({'message': 'Missing fields!'}), 400
    user = users.find_one({'email': data['email']})
    if not user or not check_password_hash(user['password'], data['password']):
        return jsonify({'message': 'Invalid credentials!'}), 401
    token = jwt.encode({
        'email': user['email'],
        'exp': datetime.datetime.utcnow() + datetime.timedelta(hours=24)
    }, app.config['SECRET_KEY'], algorithm="HS256")
    return jsonify({'token': token, 'username': user['username'], 'email': user['email']}), 200

@app.route('/profile', methods=['GET'])
@token_required
def profile(current_user):
    user_data = {
        'username': current_user['username'],
        'email': current_user['email'],
        'created_at': str(current_user['created_at'])  # Convert datetime to string
    }
    return jsonify({'user': user_data}), 200

def mock_ml_analysis(image_path):
    """
    Mock ML analysis function. In a real implementation, this would call
    your trained skin analysis model.
    """
    import random
    
    conditions = [
        {
            'condition': 'Healthy Skin',
            'severity': 'Normal',
            'confidence': random.uniform(90, 98),
            'description': 'Your skin appears healthy with no visible signs of concerning conditions.',
            'features': [
                'Even skin tone',
                'No visible lesions',
                'Good texture',
                'Appropriate pigmentation'
            ],
            'recommendations': [
                'Continue your current skincare routine',
                'Use sunscreen daily (SPF 30+)',
                'Stay hydrated',
                'Regular skin check-ups'
            ]
        },
        {
            'condition': 'Acne',
            'severity': 'Mild',
            'confidence': random.uniform(80, 95),
            'description': 'Mild acne detected. This is a common skin condition that can be managed with proper care.',
            'features': [
                'Small inflammatory lesions',
                'Some comedones present',
                'Localized inflammation',
                'No scarring detected'
            ],
            'recommendations': [
                'Use gentle, non-comedogenic cleanser',
                'Apply topical retinoids or salicylic acid',
                'Avoid touching affected areas',
                'Consider consulting a dermatologist'
            ]
        },
        {
            'condition': 'Sun Damage',
            'severity': 'Moderate',
            'confidence': random.uniform(75, 90),
            'description': 'Signs of sun damage are visible. Early intervention can help prevent further damage.',
            'features': [
                'Hyperpigmentation spots',
                'Uneven skin tone',
                'Fine lines present',
                'Texture changes'
            ],
            'recommendations': [
                'Use broad-spectrum sunscreen daily',
                'Apply vitamin C serum',
                'Consider professional treatments',
                'Regular dermatologist check-ups'
            ]
        }
    ]
    
    # Randomly select a condition for demo purposes
    selected = random.choice(conditions)
    
    return {
        'condition': selected['condition'],
        'severity': selected['severity'],
        'confidence': selected['confidence'],
        'description': selected['description'],
        'features': selected['features'],
        'recommendations': selected['recommendations'],
        'timestamp': datetime.datetime.utcnow().isoformat(),
        'model_version': 'DermaCare-AI-v1.0'
    }

# =========================
# Prediction History Routes
# =========================

@app.route('/history', methods=['POST'])
@token_required
def save_prediction_history(current_user):
    """
    Save a prediction record with the uploaded image (stored as base64) and prediction data.
    Expects multipart/form-data with fields:
      - image: file
      - prediction: str
      - confidence: float or str
    """
    try:
        if 'image' not in request.files:
            return jsonify({'message': 'No image file provided'}), 400

        file = request.files['image']
        if file.filename == '':
            return jsonify({'message': 'No file selected'}), 400

        if not allowed_file(file.filename):
            return jsonify({'message': 'Invalid file type. Please upload a PNG, JPG, or JPEG image.'}), 400

        # Read file bytes and encode as base64 string for storage
        image_bytes = file.read()
        image_b64 = base64.b64encode(image_bytes).decode('utf-8')
        mime_type = file.mimetype or 'application/octet-stream'

        prediction = request.form.get('prediction')
        confidence = request.form.get('confidence')

        if prediction is None or confidence is None:
            return jsonify({'message': 'Missing prediction or confidence'}), 400

        try:
            confidence_val = float(confidence)
        except Exception:
            return jsonify({'message': 'Invalid confidence value'}), 400

        record = {
            'user_id': str(current_user['_id']),
            'user_email': current_user['email'],
            'image_base64': image_b64,
            'image_mime': mime_type,
            'prediction': prediction,
            'confidence': confidence_val,
            'created_at': datetime.datetime.utcnow()
        }

        result = predictions.insert_one(record)
        return jsonify({'message': 'Saved', 'id': str(result.inserted_id)}), 201

    except Exception as e:
        return jsonify({'message': f'Error saving prediction: {str(e)}'}), 500


@app.route('/history', methods=['GET'])
@token_required
def fetch_prediction_history(current_user):
    """
    Return latest prediction history for authenticated user including base64 images.
    """
    try:
        items = predictions.find({'user_email': current_user['email']}).sort('created_at', -1).limit(100)
        history = []
        for it in items:
            created_at = it.get('created_at')
            if isinstance(created_at, datetime.datetime):
                created_at = created_at.isoformat()
            history.append({
                'id': str(it.get('_id')),
                'prediction': it.get('prediction'),
                'confidence': it.get('confidence'),
                'image_base64': it.get('image_base64'),
                'image_mime': it.get('image_mime', 'image/jpeg'),
                'created_at': created_at,
            })
        return jsonify(history), 200
    except Exception as e:
        return jsonify({'message': f'Error fetching history: {str(e)}'}), 500

@app.route('/analyze-skin', methods=['POST'])
@token_required
def analyze_skin(current_user):
    try:
        if 'image' not in request.files:
            return jsonify({'message': 'No image file provided'}), 400
        
        file = request.files['image']
        if file.filename == '':
            return jsonify({'message': 'No file selected'}), 400
        
        if file and allowed_file(file.filename):
            # Generate unique filename
            filename = secure_filename(f"{uuid.uuid4()}_{file.filename}")
            filepath = os.path.join(UPLOAD_FOLDER, filename)
            file.save(filepath)
            
            # Perform ML analysis (mock for now)
            analysis_result = mock_ml_analysis(filepath)
            
            # Store analysis in database
            analysis_record = {
                'user_id': str(current_user['_id']),
                'user_email': current_user['email'],
                'image_path': filepath,
                'analysis_result': analysis_result,
                'created_at': datetime.datetime.utcnow()
            }
            
            analyses.insert_one(analysis_record)
            
            return jsonify(analysis_result), 200
        else:
            return jsonify({'message': 'Invalid file type. Please upload a PNG, JPG, or JPEG image.'}), 400
            
    except Exception as e:
        return jsonify({'message': f'Error analyzing image: {str(e)}'}), 500

@app.route('/analysis-history', methods=['GET'])
@token_required
def get_analysis_history(current_user):
    try:
        # Get analysis history for the current user
        user_analyses = analyses.find(
            {'user_email': current_user['email']}
        ).sort('created_at', -1).limit(50)  # Get last 50 analyses
        
        history = []
        for analysis in user_analyses:
            result = analysis['analysis_result']
            history.append(result)
        
        return jsonify(history), 200
        
    except Exception as e:
        return jsonify({'message': f'Error fetching analysis history: {str(e)}'}), 500

@app.route('/save-analysis', methods=['POST'])
@token_required
def save_analysis(current_user):
    try:
        if 'analysis' not in request.form:
            return jsonify({'message': 'No analysis data provided'}), 400
        
        if 'image' not in request.files:
            return jsonify({'message': 'No image file provided'}), 400
        
        # Parse analysis data
        import json
        analysis_data = json.loads(request.form['analysis'])
        
        # Save image file
        file = request.files['image']
        if file and allowed_file(file.filename):
            filename = secure_filename(f"saved_{uuid.uuid4()}_{file.filename}")
            filepath = os.path.join(UPLOAD_FOLDER, filename)
            file.save(filepath)
            
            # Store in database
            analysis_record = {
                'user_id': str(current_user['_id']),
                'user_email': current_user['email'],
                'image_path': filepath,
                'analysis_result': analysis_data,
                'saved_manually': True,
                'created_at': datetime.datetime.utcnow()
            }
            
            analyses.insert_one(analysis_record)
            
            return jsonify({'message': 'Analysis saved successfully'}), 200
        else:
            return jsonify({'message': 'Invalid file type'}), 400
            
    except Exception as e:
        return jsonify({'message': f'Error saving analysis: {str(e)}'}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
