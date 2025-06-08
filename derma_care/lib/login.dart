import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'database_helper.dart';
import 'main.dart';

class MyLogin extends StatefulWidget {
  const MyLogin({super.key});

  @override
  State<MyLogin> createState() => _MyLoginState();
}

class _MyLoginState extends State<MyLogin> {
  bool isLogin = true;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();

  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  bool isLoading = false;

  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _handleLogin() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      _showSnackBar('Please fill all fields');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      String hashedPassword = _hashPassword(passwordController.text);
      var user = await DatabaseHelper.instance.loginUser(
        emailController.text,
        hashedPassword,
      );

      if (!mounted) return;

      if (user != null) {
        SharedPreferences prefs = await SharedPreferences.getInstance();

        if (!mounted) return;

        await prefs.setBool('isLoggedIn', true);
        await prefs.setInt('userId', user['id']);
        await prefs.setString('userEmail', user['email']);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      } else {
        _showSnackBar('Invalid email or password');
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Login failed: ${e.toString()}');
    }

    if (!mounted) return;
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _handleSignup() async {
    if (emailController.text.isEmpty ||
        passwordController.text.isEmpty ||
        confirmPasswordController.text.isEmpty ||
        nameController.text.isEmpty) {
      _showSnackBar('Please fill all fields');
      return;
    }

    if (passwordController.text != confirmPasswordController.text) {
      _showSnackBar('Passwords do not match');
      return;
    }

    if (passwordController.text.length < 6) {
      _showSnackBar('Password must be at least 6 characters');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      String hashedPassword = _hashPassword(passwordController.text);
      int userId = await DatabaseHelper.instance.insertUser({
        'name': nameController.text,
        'email': emailController.text,
        'password': hashedPassword,
        'phone': phoneController.text,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;

      SharedPreferences prefs = await SharedPreferences.getInstance();

      if (!mounted) return;

      await prefs.setBool('isLoggedIn', true);
      await prefs.setInt('userId', userId);
      await prefs.setString('userEmail', emailController.text);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } catch (e) {
      if (!mounted) return;

      if (e.toString().contains('UNIQUE constraint failed')) {
        _showSnackBar('Email already exists. Please use a different email.');
      } else {
        _showSnackBar('Signup failed: ${e.toString()}');
      }
    }

    if (!mounted) return;
    setState(() {
      isLoading = false;
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[600],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWideScreen = constraints.maxWidth >= 800;

          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: isWideScreen
                    ? Row(
                        children: [
                          _buildLeftPanel(),
                          _buildRightPanel(width: 400),
                        ],
                      )
                    : Column(
                        children: [
                          _buildLeftPanel(height: 220),
                          _buildRightPanel(width: double.infinity),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLeftPanel({double? height}) {
    return Container(
      height: height,
      width: height == null ? null : double.infinity,
      color: const Color(0xFFEFB1D9),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_hospital, size: 100, color: Colors.white),
            SizedBox(height: 20),
            Text(
              "DERMACARE",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
            SizedBox(height: 10),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 30.0),
              child: Text(
                "Your personal skin disease detection assistant",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightPanel({required double width}) {
    return Expanded(
      child: Center(
        child: Container(
          width: width > 400 ? 400 : width,
          margin: const EdgeInsets.symmetric(vertical: 30),
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isLogin ? "Welcome Back" : "Create Account",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                isLogin ? "Sign in to continue" : "Fill the form to sign up",
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 30),
              if (!isLogin) ...[
                TextField(
                  controller: nameController,
                  decoration: _inputDecoration("Full Name"),
                ),
                const SizedBox(height: 20),
              ],
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration("Email"),
              ),
              const SizedBox(height: 20),
              if (!isLogin) ...[
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: _inputDecoration("Phone Number (Optional)"),
                ),
                const SizedBox(height: 20),
              ],
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: _inputDecoration("Password").copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                  ),
                ),
              ),
              if (!isLogin) ...[
                const SizedBox(height: 20),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: obscureConfirmPassword,
                  decoration: _inputDecoration("Confirm Password").copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          obscureConfirmPassword = !obscureConfirmPassword;
                        });
                      },
                    ),
                  ),
                ),
              ],
              if (isLogin)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      _showForgotPasswordDialog();
                    },
                    child: const Text(
                      "Forgot Password?",
                      style: TextStyle(color: Colors.blueAccent),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 45,
                child: ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          if (isLogin) {
                            _handleLogin();
                          } else {
                            _handleSignup();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        )
                      : Text(
                          isLogin ? "SIGN IN" : "SIGN UP",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 15),
              TextButton(
                onPressed: () {
                  setState(() {
                    isLogin = !isLogin;
                    // Clear form fields when switching
                    emailController.clear();
                    passwordController.clear();
                    confirmPasswordController.clear();
                    nameController.clear();
                    phoneController.clear();
                  });
                },
                child: Text(
                  isLogin
                      ? "Don't have an account? Sign up"
                      : "Already have an account? Login",
                  style: const TextStyle(color: Colors.black87),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      filled: true,
      fillColor: Colors.grey.shade100,
    );
  }

  void _showForgotPasswordDialog() {
    final TextEditingController forgotEmailController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Reset Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter your email address to reset your password:'),
              const SizedBox(height: 16),
              TextField(
                controller: forgotEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showSnackBar('Password reset link sent to your email!');
              },
              child: const Text('Send Reset Link'),
            ),
          ],
        );
      },
    );
  }
}
