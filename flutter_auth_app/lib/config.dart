import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

// Automatically select backend URL for each platform
String get backendUrl {
  if (kIsWeb) {
    // Use your PC's IP for web
    return 'http://192.168.0.105:5000';
  } else if (Platform.isAndroid) {
    // Use your PC's IP for physical Android device
    return 'http://192.168.0.105:5000';
  } else {
    // Default for other platforms (iOS, etc.)
    return 'http://127.0.0.1:5000';
  }
}

const String geminiApiKey = 'AIzaSyDvZOzv6663yqJCD5lLzX5iTzL6XHJHjHQ';
// Google OAuth client ID used for Web and as server client ID for mobile
const String googleWebClientId =
    '742123302553-88e0099nok872g2re7e5l9m0v0h2ldh0.apps.googleusercontent.com';
