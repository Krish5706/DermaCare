import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'dart:convert';
import 'package:http/http.dart' as http;

class GoogleAuthService {
  static GoogleSignIn? _googleSignIn;

  static GoogleSignIn get googleSignIn {
    if (_googleSignIn == null) {
      if (kIsWeb) {
        _googleSignIn = GoogleSignIn(
          clientId: 'YOUR_WEB_CLIENT_ID.googleusercontent.com', // Replace with your actual web client ID
        );
      } else {
        // For Android and iOS, client ID is configured in google-services.json and GoogleService-Info.plist
        _googleSignIn = GoogleSignIn(
          scopes: [
            'email',
            'profile',
          ],
        );
      }
    }
    return _googleSignIn!;
  }

  // Backend URL configuration
  static String get _baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:5000';
    } else if (Platform.isIOS) {
      return 'http://localhost:5000';
    } else {
      return 'http://localhost:5000';
    }
  }

  static Future<Map<String, dynamic>?> signInWithGoogle() async {
    try {
      print('=== GOOGLE SIGN-IN SERVICE DEBUG ===');
      
      // Check if already signed in
      await googleSignIn.signOut(); // Sign out first to ensure fresh sign-in
      
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        print('Google sign-in was cancelled by user');
        return null;
      }

      print('Google user signed in: ${googleUser.email}');
      print('Display name: ${googleUser.displayName}');
      print('Photo URL: ${googleUser.photoUrl}');

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      print('Got Google auth tokens');
      print('Access token available: ${googleAuth.accessToken != null}');
      print('ID token available: ${googleAuth.idToken != null}');

      // For now, let's create a mock response since backend might not be ready
      // You can uncomment the backend call when your server is configured
      
      /*
      // Send the ID token to your backend for verification
      final response = await _sendTokenToBackend(googleAuth.idToken);
      
      if (response != null) {
        print('Backend authentication successful');
        return response;
      } else {
        print('Backend authentication failed');
        return null;
      }
      */
      
      // Mock response for testing (remove this when backend is ready)
      return {
        'token': 'mock_jwt_token_${DateTime.now().millisecondsSinceEpoch}',
        'username': googleUser.displayName ?? 'Google User',
        'email': googleUser.email,
        'profile_picture': googleUser.photoUrl,
      };
      
    } catch (error) {
      print('Google sign-in error: $error');
      
      // Provide more specific error messages
      if (error.toString().contains('sign_in_failed')) {
        throw Exception('Google Sign-In configuration error. Please check your setup.');
      } else if (error.toString().contains('network_error')) {
        throw Exception('Network error. Please check your internet connection.');
      } else {
        throw Exception('Google sign-in failed: $error');
      }
    }
  }

  static Future<Map<String, dynamic>?> _sendTokenToBackend(String? idToken) async {
    if (idToken == null) {
      print('ID token is null');
      return null;
    }

    try {
      print('Sending ID token to backend...');
      
      final uri = Uri.parse('$_baseUrl/auth/google');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'idToken': idToken,
        }),
      ).timeout(const Duration(seconds: 15));

      print('Backend response status: ${response.statusCode}');
      print('Backend response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'token': data['token'],
          'username': data['username'],
          'email': data['email'],
          'profile_picture': data['profile_picture'],
        };
      } else {
        print('Backend returned error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error sending token to backend: $e');
      return null;
    }
  }

  static Future<void> signOut() async {
    try {
      await googleSignIn.signOut();
      print('Google sign-out successful');
    } catch (error) {
      print('Google sign-out error: $error');
    }
  }

  static Future<bool> isSignedIn() async {
    return await googleSignIn.isSignedIn();
  }

  static GoogleSignInAccount? getCurrentUser() {
    return googleSignIn.currentUser;
  }
}
