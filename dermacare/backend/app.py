from flask import Flask, request, jsonify
from flask_cors import CORS
from flask_pymongo import PyMongo
from werkzeug.security import generate_password_hash, check_password_hash
from werkzeug.utils import secure_filename
import jwt
import datetime
from functools import wraps
import os
import uuid
import base64
from PIL import Image
import io
import numpy as np
from google.oauth2 import id_token
from google.auth.transport import requests as google_requests
import requests

app = Flask(__name__)
# Allow all origins for testing (use specific origins in production)
CORS(app, resources={r"/*": {"origins": "*"}})  # Changed to allow all origins

# Configurations
app.config['MONGO_URI'] = 'mongodb+srv://vaghelanikhil:NikhilVaghela121607@cluster0.qo1wq3w.mongodb.net/Cluster0?retryWrites=true&w=majority&appName=Cluster0'
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'agbvaljvhavmnbavhalfhuaefhbvchjvbvbavd')

# Google OAuth Configuration
GOOGLE_CLIENT_ID = os.environ.get('GOOGLE_CLIENT_ID', 'your-google-client-id.googleusercontent.com')

mongo = PyMongo(app)
users = mongo.db.users
analyses = mongo.db.analyses

# Configure upload folder
UPLOAD_FOLDER = 'uploads'
if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)

ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg'}

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
            # Update existing user with Google info if not already set
            if not user.get('google_id'):
                users.update_one(
                    {'email': email},
                    {
                        '$set': {
                            'google_id': google_user_id,
                            'profile_picture': picture,
                            'auth_provider': 'google'
                        }
                    }
                )
        
        # Generate JWT token
        token = jwt.encode({
            'email': email,
            'exp': datetime.datetime.utcnow() + datetime.timedelta(hours=24)
        }, app.config['SECRET_KEY'], algorithm="HS256")
        
        return jsonify({
            'token': token,
            'username': name,
            'email': email,
            'profile_picture': picture
        }), 200
        
    except Exception as e:
        print(f"Google auth error: {str(e)}")
        return jsonify({'message': 'Google authentication failed'}), 500

@app.route('/auth/google/web', methods=['POST'])
def google_auth_web():
    """Alternative endpoint for web-based Google Sign-In"""
    try:
        data = request.get_json()
        access_token = data.get('access_token')
        
        if not access_token:
            return jsonify({'message': 'Access token is required'}), 400
        
        # Verify token with Google
        response = requests.get(
            f'https://www.googleapis.com/oauth2/v1/userinfo?access_token={access_token}'
        )
        
        if response.status_code != 200:
            return jsonify({'message': 'Invalid Google token'}), 401
        
        user_info = response.json()
        email = user_info.get('email')
        name = user_info.get('name', '')
        picture = user_info.get('picture', '')
        google_id = user_info.get('id')
        
        # Check if user exists
        user = users.find_one({'email': email})
        
        if not user:
            # Create new user
            user = {
                'username': name,
                'email': email,
                'google_id': google_id,
                'profile_picture': picture,
                'auth_provider': 'google',
                'created_at': datetime.datetime.utcnow()
            }
            users.insert_one(user)
        
        # Generate JWT token
        token = jwt.encode({
            'email': email,
            'exp': datetime.datetime.utcnow() + datetime.timedelta(hours=24)
        }, app.config['SECRET_KEY'], algorithm="HS256")
        
        return jsonify({
            'token': token,
            'username': name,
            'email': email,
            'profile_picture': picture
        }), 200
        
    except Exception as e:
        print(f"Google web auth error: {str(e)}")
        return jsonify({'message': 'Google authentication failed'}), 500

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
