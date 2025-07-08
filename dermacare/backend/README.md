# Flutter Authentication App Backend

This is the Python Flask backend for the Flutter Authentication App.

## Features
- User registration and login with JWT authentication
- MongoDB database integration
- Secure password hashing
- CORS enabled for frontend communication

## Endpoints
- `POST /register` - Register a new user
- `POST /login` - Login and receive JWT token
- `GET /profile` - Get user profile (JWT required)

## Setup
1. Install dependencies:
   ```sh
   pip install -r requirements.txt
   ```
2. Ensure MongoDB is running locally on port 27017.
3. Run the Flask app:
   ```sh
   python app.py
   ```

## Environment Variables
- `SECRET_KEY`: Secret key for JWT (default: 'your_secret_key')

---

For the Flutter frontend, see the main project directory.
