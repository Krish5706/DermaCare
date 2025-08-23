import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config.dart'; // <-- IMPORT ADDED HERE

class GoogleAuthService {
  static GoogleSignIn? _googleSignIn;

  static GoogleSignIn get googleSignIn {
    if (_googleSignIn == null) {
      if (kIsWeb) {
        _googleSignIn = GoogleSignIn(
          clientId: googleWebClientId,
        );
      } else {
        // For Android and iOS, client ID is configured in google-services.json and GoogleService-Info.plist
        _googleSignIn = GoogleSignIn(
          scopes: const ['email', 'profile'],
          // Request an ID token by specifying your OAuth 2.0 Client ID
          serverClientId: googleWebClientId,
        );
      }
    }
    return _googleSignIn!;
  }

  // *** MODIFIED CODE STARTS HERE ***
  // Backend URL configuration
  static String get _baseUrl {
    // Always use the URL from the central config file.
    return backendUrl;
  }
  // *** MODIFIED CODE ENDS HERE ***

  static Future<Map<String, dynamic>?> signInWithGoogle() async {
    try {
      print('=== GOOGLE SIGN-IN SERVICE DEBUG ===');

      // Optional: ensure fresh sign-in
      try {
        await googleSignIn.signOut();
      } catch (_) {}

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
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      print('Got Google auth tokens');
      print('Access token available: ${googleAuth.accessToken != null}');
      print('ID token available: ${googleAuth.idToken != null}');

      // Send the ID token to your backend for verification
      final response = await _sendTokenToBackend(googleAuth.idToken);
      if (response != null) {
        print('Backend authentication successful');
        return response;
      } else {
        print('Backend authentication failed');
        return null;
      }
    } catch (error) {
      print('Google sign-in error: $error');

      // Provide more specific error messages
      if (error.toString().contains('sign_in_failed')) {
        throw Exception(
            'Google Sign-In configuration error. Please check your setup.');
      } else if (error.toString().contains('network_error')) {
        throw Exception(
            'Network error. Please check your internet connection.');
      } else {
        throw Exception('Google sign-in failed: $error');
      }
    }
  }

  static Future<Map<String, dynamic>?> _sendTokenToBackend(
      String? idToken) async {
    if (idToken == null) {
      print('ID token is null');
      return null;
    }

    try {
      print('Sending ID token to backend...');

      final uri = Uri.parse('$_baseUrl/auth/google');
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'idToken': idToken,
            }),
          )
          .timeout(const Duration(seconds: 15));

      print('Backend response status: ${response.statusCode}');
      print('Backend response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Backend returns: { token, user: { username, email, profile_picture } }
        return {
          'token': data['token'],
          'username': (data['user'] ?? {})['username'] ?? '',
          'email': (data['user'] ?? {})['email'] ?? '',
          'profile_picture': (data['user'] ?? {})['profile_picture'],
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
