import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'database_helper.dart';
import 'login.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  bool _autoSaveEnabled = true;
  bool _offlineModeEnabled = false;
  String _selectedLanguage = 'English';
  String _selectedTheme = 'Light';

  // User profile data
  Map<String, dynamic>? _userData;
  String? _profileImagePath;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadPreferences();
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getInt('userId');

    if (_currentUserId != null) {
      var user = await DatabaseHelper.instance.getUser(_currentUserId!);
      if (user != null) {
        setState(() {
          _userData = user;
          _profileImagePath = user['profile_image'];
        });
      }
    }
  }

  Future<void> _loadPreferences() async {
    if (_currentUserId != null) {
      var prefs = await DatabaseHelper.instance.getUserPreferences(_currentUserId!);
      if (prefs != null) {
        setState(() {
          _notificationsEnabled = prefs['notifications_enabled'] == 1;
          _darkModeEnabled = prefs['dark_mode_enabled'] == 1;
          _autoSaveEnabled = prefs['auto_save_enabled'] == 1;
          _offlineModeEnabled = prefs['offline_mode_enabled'] == 1;
          _selectedLanguage = prefs['selected_language'] ?? 'English';
          _selectedTheme = prefs['selected_theme'] ?? 'Light';
        });
      }
    }
  }

  Future<void> _savePreferences() async {
    if (_currentUserId != null) {
      await DatabaseHelper.instance.updateUserPreferences(_currentUserId!, {
        'notifications_enabled': _notificationsEnabled ? 1 : 0,
        'dark_mode_enabled': _darkModeEnabled ? 1 : 0,
        'auto_save_enabled': _autoSaveEnabled ? 1 : 0,
        'offline_mode_enabled': _offlineModeEnabled ? 1 : 0,
        'selected_language': _selectedLanguage,
        'selected_theme': _selectedTheme,
      });
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null && _currentUserId != null) {
      setState(() {
        _profileImagePath = image.path;
      });

      // Update in database
      await DatabaseHelper.instance.updateUser(_currentUserId!, {
        'profile_image': image.path,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated successfully')),
      );
    }
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const MyLogin()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Section
            _buildSectionHeader('Profile'),
            _buildProfileCard(),

            const SizedBox(height: 24),
            _buildSectionHeader('General'),
            _buildSettingCard(
              icon: Icons.language,
              title: 'Language',
              subtitle: _selectedLanguage,
              onTap: () => _showLanguageDialog(),
            ),
            _buildSettingCard(
              icon: Icons.palette,
              title: 'Theme',
              subtitle: _selectedTheme,
              onTap: () => _showThemeDialog(),
            ),

            const SizedBox(height: 24),
            _buildSectionHeader('Notifications'),
            _buildSwitchCard(
              icon: Icons.notifications,
              title: 'Push Notifications',
              subtitle: 'Receive scan reminders and updates',
              value: _notificationsEnabled,
              onChanged: (value) {
                setState(() {
                  _notificationsEnabled = value;
                });
                _savePreferences();
              },
            ),

            const SizedBox(height: 24),
            _buildSectionHeader('App Preferences'),
            _buildSwitchCard(
              icon: Icons.dark_mode,
              title: 'Dark Mode',
              subtitle: 'Switch to dark theme',
              value: _darkModeEnabled,
              onChanged: (value) {
                setState(() {
                  _darkModeEnabled = value;
                  _selectedTheme = value ? 'Dark' : 'Light';
                });
                _savePreferences();
              },
            ),
            _buildSwitchCard(
              icon: Icons.save,
              title: 'Auto Save Scans',
              subtitle: 'Automatically save scan results',
              value: _autoSaveEnabled,
              onChanged: (value) {
                setState(() {
                  _autoSaveEnabled = value;
                });
                _savePreferences();
              },
            ),
            _buildSwitchCard(
              icon: Icons.cloud_off,
              title: 'Offline Mode',
              subtitle: 'Use app without internet connection',
              value: _offlineModeEnabled,
              onChanged: (value) {
                setState(() {
                  _offlineModeEnabled = value;
                });
                _savePreferences();
              },
            ),

            const SizedBox(height: 24),
            _buildSectionHeader('Data & Privacy'),
            _buildSettingCard(
              icon: Icons.history,
              title: 'Clear Scan History',
              subtitle: 'Remove all saved scan results',
              onTap: () => _showClearHistoryDialog(),
            ),
            _buildSettingCard(
              icon: Icons.security,
              title: 'Privacy Policy',
              subtitle: 'Read our privacy policy',
              onTap: () {
                _showInfoDialog(
                  'Privacy Policy',
                  'Your privacy is important to us. This app processes skin images locally and does not share personal data without consent.',
                );
              },
            ),
            _buildSettingCard(
              icon: Icons.description,
              title: 'Terms of Service',
              subtitle: 'View terms and conditions',
              onTap: () {
                _showInfoDialog(
                  'Terms of Service',
                  'By using this app, you agree to our terms and conditions. This app is for educational purposes and should not replace professional medical advice.',
                );
              },
            ),

            const SizedBox(height: 24),
            _buildSectionHeader('Support'),
            _buildSettingCard(
              icon: Icons.help,
              title: 'Help & FAQ',
              subtitle: 'Get help and find answers',
              onTap: () {
                _showInfoDialog(
                  'Help & FAQ',
                  'For support, please contact us at support@dermacare.com or visit our FAQ section on the website.',
                );
              },
            ),
            _buildSettingCard(
              icon: Icons.feedback,
              title: 'Send Feedback',
              subtitle: 'Share your thoughts with us',
              onTap: () {
                _showFeedbackDialog();
              },
            ),
            _buildSettingCard(
              icon: Icons.info,
              title: 'About',
              subtitle: 'App version and information',
              onTap: () {
                _showInfoDialog(
                  'About DermaCare',
                  'DermaCare v1.0.0\n\nA personal skin disease detection app powered by AI technology.\n\nDeveloped with care for your health and privacy.',
                );
              },
            ),

            const SizedBox(height: 24),
            _buildSectionHeader('Account'),
            _buildSettingCard(
              icon: Icons.logout,
              title: 'Logout',
              subtitle: 'Sign out of your account',
              onTap: () => _showLogoutDialog(),
              textColor: Colors.red,
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Card(
      elevation: 0,
      color: Colors.grey[50],
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue[100],
                  image: _profileImagePath != null
                      ? DecorationImage(
                    image: FileImage(File(_profileImagePath!)),
                    fit: BoxFit.cover,
                  )
                      : null,
                ),
                child: _profileImagePath == null
                    ? Icon(Icons.person, size: 40, color: Colors.blue[700])
                    : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _userData?['name'] ?? 'Loading...',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userData?['email'] ?? 'Loading...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (_userData?['phone'] != null && _userData!['phone'].toString().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      _userData!['phone'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _showEditProfileDialog(),
                    child: Text(
                      'Edit Profile',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _pickImage,
              icon: Icon(Icons.camera_alt, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue[700],
        ),
      ),
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return Card(
      elevation: 0,
      color: Colors.grey[50],
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: textColor == Colors.red ? Colors.red[100] : Colors.blue[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
              icon,
              color: textColor == Colors.red ? Colors.red[700] : Colors.blue[700],
              size: 20
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textColor ?? Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSwitchCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      elevation: 0,
      color: Colors.grey[50],
      margin: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.blue[700], size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: Colors.blue,
      ),
    );
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _userData?['name'] ?? '');
    final phoneController = TextEditingController(text: _userData?['phone'] ?? '');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
              onPressed: () async {
                if (nameController.text.isNotEmpty && _currentUserId != null) {
                  await DatabaseHelper.instance.updateUser(_currentUserId!, {
                    'name': nameController.text,
                    'phone': phoneController.text,
                  });

                  setState(() {
                    _userData?['name'] = nameController.text;
                    _userData?['phone'] = phoneController.text;
                  });

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile updated successfully')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Language'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLanguageOption('English'),
              _buildLanguageOption('Spanish'),
              _buildLanguageOption('French'),
              _buildLanguageOption('German'),
              _buildLanguageOption('Chinese'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLanguageOption(String language) {
    return ListTile(
      title: Text(language),
      leading: Radio<String>(
        value: language,
        groupValue: _selectedLanguage,
        onChanged: (value) {
          setState(() {
            _selectedLanguage = value!;
          });
          _savePreferences();
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Theme'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Light'),
                leading: Radio<String>(
                  value: 'Light',
                  groupValue: _selectedTheme,
                  onChanged: (value) {
                    setState(() {
                      _selectedTheme = value!;
                      _darkModeEnabled = false;
                    });
                    _savePreferences();
                    Navigator.pop(context);
                  },
                ),
              ),
              ListTile(
                title: const Text('Dark'),
                leading: Radio<String>(
                  value: 'Dark',
                  groupValue: _selectedTheme,
                  onChanged: (value) {
                    setState(() {
                      _selectedTheme = value!;
                      _darkModeEnabled = true;
                    });
                    _savePreferences();
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showClearHistoryDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear Scan History'),
          content: const Text(
            'Are you sure you want to clear all scan history? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (_currentUserId != null) {
                  await DatabaseHelper.instance.deleteScanHistory(_currentUserId!);
                }
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Scan history cleared successfully')),
                );
              },
              child: const Text('Clear', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _logout();
              },
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _showInfoDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: Text(content)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showFeedbackDialog() {
    final TextEditingController feedbackController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Send Feedback'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('We value your feedback! Please share your thoughts:'),
              const SizedBox(height: 16),
              TextField(
                controller: feedbackController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Enter your feedback here...',
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Thank you for your feedback!')),
                );
              },
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
  }
}