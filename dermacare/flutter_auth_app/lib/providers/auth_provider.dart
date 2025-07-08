import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthProvider extends ChangeNotifier {
  String? _token;
  String? _username;
  String? _email;
  String? _phone;
  bool _isLoading = false;
  String? _error;
  ThemeMode _themeMode = ThemeMode.system;

  String? get token => _token;
  String? get username => _username;
  String? get email => _email;
  String? get phone => _phone;
  bool get isLoading => _isLoading;
  String? get error => _error;
  ThemeMode get themeMode => _themeMode;

  AuthProvider() {
    _loadTheme();
    _loadToken();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final theme = prefs.getString('themeMode');
    if (theme == 'dark') {
      _themeMode = ThemeMode.dark;
    } else if (theme == 'light') {
      _themeMode = ThemeMode.light;
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = mode;
    await prefs.setString('themeMode', mode.name);
    notifyListeners();
  }

  // Method to refresh theme when system theme changes
  void updateSystemTheme() {
    if (_themeMode == ThemeMode.system) {
      notifyListeners();
    }
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('jwt_token');
    _username = prefs.getString('username');
    _email = prefs.getString('email');
    _phone = prefs.getString('user_phone');
    notifyListeners();
  }

  // Dynamically set backend URL for different platforms
  static String get _baseUrl {
    if (kIsWeb) {
      // Use localhost for web
      return 'http://localhost:5000';
    } else if (Platform.isAndroid) {
      // Use 10.0.2.2 for Android emulator (maps to host's localhost)
      return 'http://10.0.2.2:5000';
    } else if (Platform.isIOS) {
      // Use localhost for iOS simulator
      return 'http://localhost:5000';
    } else {
      // Default fallback to localhost
      return 'http://localhost:5000';
    }
  }

  Future<void> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      print('=== LOGIN DEBUG ===');
      print('Email: $email');
      print('Backend URL: $_baseUrl/login');
      
      final uri = Uri.parse('$_baseUrl/login');
      print('Parsed URI: $uri');
      
      final requestBody = jsonEncode({'email': email, 'password': password});
      print('Request body: $requestBody');
      
      final res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: requestBody,
      ).timeout(const Duration(seconds: 10));
      
      print('Response status: ${res.statusCode}');
      print('Response headers: ${res.headers}');
      print('Response body: ${res.body}');
      
      if (res.statusCode == 200) {
        try {
          final data = jsonDecode(res.body);
          print('Parsed response data: $data');
          
          _token = data['token'];
          _username = data['username'];
          _email = data['email'];
          
          if (_token == null || _username == null || _email == null) {
            _error = 'Invalid response format from server';
            print('Error: Missing required fields in response');
            return;
          }
          
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwt_token', _token!);
          await prefs.setString('username', _username!);
          await prefs.setString('email', _email!);
          
          print('Login successful! User: $_username, Token: ${_token!.substring(0, 20)}...');
          _error = null;
          
        } catch (parseError) {
          _error = 'Failed to parse server response';
          print('JSON parse error: $parseError');
        }
      } else {
        try {
          final data = jsonDecode(res.body);
          _error = data['message'] ?? 'Login failed with status ${res.statusCode}';
        } catch (parseError) {
          _error = 'Login failed with status ${res.statusCode}';
        }
        print('Login failed: $_error');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        _error = 'Connection timeout. Please check your network.';
      } else if (e.toString().contains('SocketException')) {
        _error = 'Network error. Please check if the server is running.';
      } else {
        _error = 'Network error: ${e.toString()}';
      }
      print('Login exception: $e');
    }
    
    _isLoading = false;
    notifyListeners();
    print('=== LOGIN DEBUG END ===');
  }

  Future<void> register(String username, String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      print('=== REGISTRATION DEBUG ===');
      print('Username: $username');
      print('Email: $email');
      print('Backend URL: $_baseUrl/register');
      
      final uri = Uri.parse('$_baseUrl/register');
      print('Parsed URI: $uri');
      
      final requestBody = jsonEncode({
        'username': username,
        'email': email,
        'password': password
      });
      print('Request body: $requestBody');
      
      final res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: requestBody,
      ).timeout(const Duration(seconds: 10));
      
      print('Response status: ${res.statusCode}');
      print('Response headers: ${res.headers}');
      print('Response body: ${res.body}');
      
      if (res.statusCode == 201) {
        print('Registration successful! Auto-logging in...');
        _error = null;
        // Auto-login after successful registration
        await login(email, password);
      } else {
        try {
          final data = jsonDecode(res.body);
          _error = data['message'] ?? 'Registration failed with status ${res.statusCode}';
        } catch (parseError) {
          _error = 'Registration failed with status ${res.statusCode}';
        }
        print('Registration failed: $_error');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        _error = 'Connection timeout. Please check your network.';
      } else if (e.toString().contains('SocketException')) {
        _error = 'Network error. Please check if the server is running.';
      } else {
        _error = 'Network error: ${e.toString()}';
      }
      print('Registration exception: $e');
    }
    
    _isLoading = false;
    notifyListeners();
    print('=== REGISTRATION DEBUG END ===');
  }

  Future<void> logout() async {
    _token = null;
    _username = null;
    _email = null;
    _phone = null;
    final prefs = await SharedPreferences.getInstance();
    // Only remove auth-related keys, not all prefs
    await prefs.remove('jwt_token');
    await prefs.remove('username');
    await prefs.remove('email');
    await prefs.remove('user_phone');
    notifyListeners();
  }

  Future<void> updateUsername(String newUsername) async {
    _username = newUsername;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', newUsername);
    notifyListeners();
  }

  Future<void> updatePhone(String newPhone) async {
    _phone = newPhone;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_phone', newPhone);
    notifyListeners();
  }

  // Clear error message
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Google Sign-In (placeholder implementation)
  Future<void> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // TODO: Implement Google Sign-In
      // For now, show a message that it's not implemented
      await Future.delayed(const Duration(seconds: 1));
      _error = 'Google Sign-In not implemented yet';
    } catch (e) {
      _error = 'Google Sign-In failed: ${e.toString()}';
    }
    
    _isLoading = false;
    notifyListeners();
  }
}
