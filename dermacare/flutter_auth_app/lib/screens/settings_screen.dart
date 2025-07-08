import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../providers/auth_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _darkModeEnabled = false;
  bool _autoSaveEnabled = true;
  String _selectedLanguage = 'English';
  String _selectedTheme = 'System Default';
  String? _profileImagePath;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    String? savedImagePath = prefs.getString('profile_image_path');
    
    // Verify if the saved image still exists
    if (savedImagePath != null && !File(savedImagePath).existsSync()) {
      // If the file doesn't exist, remove the invalid path
      await prefs.remove('profile_image_path');
      savedImagePath = null;
    }
    
    setState(() {
      _autoSaveEnabled = prefs.getBool('auto_save_enabled') ?? true;
      _selectedLanguage = prefs.getString('selected_language') ?? 'English';
      _profileImagePath = savedImagePath;
      
      // Get theme from AuthProvider
      switch (auth.themeMode) {
        case ThemeMode.light:
          _selectedTheme = 'Light';
          _darkModeEnabled = false;
          break;
        case ThemeMode.dark:
          _selectedTheme = 'Dark';
          _darkModeEnabled = true;
          break;
        case ThemeMode.system:
          _selectedTheme = 'System Default';
          final brightness = MediaQuery.of(context).platformBrightness;
          _darkModeEnabled = brightness == Brightness.dark;
          break;
      }
    });
  }

  Future<void> _savePreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    await prefs.setBool('auto_save_enabled', _autoSaveEnabled);
    await prefs.setString('selected_language', _selectedLanguage);
    if (_profileImagePath != null) {
      await prefs.setString('profile_image_path', _profileImagePath!);
    }
    
    // Update theme through AuthProvider
    ThemeMode themeMode;
    switch (_selectedTheme) {
      case 'Light':
        themeMode = ThemeMode.light;
        break;
      case 'Dark':
        themeMode = ThemeMode.dark;
        break;
      case 'System Default':
      default:
        themeMode = ThemeMode.system;
        break;
    }
    
    await auth.setTheme(themeMode);
  }

  Future<void> _removeProfileImage() async {
    try {
      if (_profileImagePath != null) {
        // Delete the actual file
        final file = File(_profileImagePath!);
        if (file.existsSync()) {
          await file.delete();
        }
      }
      
      // Clear from preferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('profile_image_path');
      
      setState(() {
        _profileImagePath = null;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing profile picture: $e')),
        );
      }
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromSource(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromSource(ImageSource.gallery);
                },
              ),
              if (_profileImagePath != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _removeProfileImage();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);

      if (image != null) {
        // Get app's document directory
        final Directory appDir = await getApplicationDocumentsDirectory();
        final String fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final String localPath = '${appDir.path}/$fileName';
        
        // Copy the image to app's document directory
        final File localImage = await File(image.path).copy(localPath);
        
        setState(() {
          _profileImagePath = localImage.path;
        });
        _savePreferences();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile picture updated successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile picture: $e')),
        );
      }
    }
  }

  Future<void> _logout() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.logout();
    
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isTablet = screenWidth > 600;
        final isDesktop = screenWidth > 1200;
        
        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(80),
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              automaticallyImplyLeading: false,
              toolbarHeight: 80,
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF4285F4),
                      Color(0xFF34A853),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 40 : (isTablet ? 30 : 20),
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.arrow_back_ios,
                              color: Colors.white,
                              size: isDesktop ? 24 : (isTablet ? 22 : 20),
                            ),
                            onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
                          ),
                        ),
                        SizedBox(width: isDesktop ? 20 : (isTablet ? 18 : 16)),
                        Text(
                          'Settings',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isDesktop ? 30 : (isTablet ? 28 : 26),
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isDesktop ? 800 : (isTablet ? 600 : double.infinity),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isDesktop ? 40.0 : (isTablet ? 30.0 : 20.0)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Section
                    _buildSectionHeader('Profile'),
                    _buildProfileCard(),

                    SizedBox(height: isDesktop ? 32 : (isTablet ? 28 : 24)),
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

                    SizedBox(height: isDesktop ? 32 : (isTablet ? 28 : 24)),
                    _buildSectionHeader('App Preferences'),
                    _buildSwitchCard(
                      icon: Icons.dark_mode,
                      title: 'Dark Mode',
                      subtitle: 'Switch to dark theme',
                      value: _darkModeEnabled,
                      onChanged: _selectedTheme != 'System Default' ? (value) async {
                        final auth = Provider.of<AuthProvider>(context, listen: false);
                        setState(() {
                          _darkModeEnabled = value;
                          _selectedTheme = value ? 'Dark' : 'Light';
                        });
                        await auth.setTheme(value ? ThemeMode.dark : ThemeMode.light);
                        await _savePreferences();
                      } : null,
                      enabled: _selectedTheme != 'System Default',
                    ),
                    _buildSwitchCard(
                      icon: Icons.save,
                      title: 'Auto Save',
                      subtitle: 'Automatically save app data',
                      value: _autoSaveEnabled,
                      onChanged: (value) {
                        setState(() {
                          _autoSaveEnabled = value;
                        });
                        _savePreferences();
                      },
                    ),

                    SizedBox(height: isDesktop ? 32 : (isTablet ? 28 : 24)),
                    _buildSectionHeader('Data & Privacy'),
                    _buildSettingCard(
                      icon: Icons.history,
                      title: 'Clear App Data',
                      subtitle: 'Remove all locally stored data',
                      onTap: () => _showClearDataDialog(),
                    ),
                    _buildSettingCard(
                      icon: Icons.security,
                      title: 'Privacy Policy',
                      subtitle: 'Read our privacy policy',
                      onTap: () {
                        _showInfoDialog(
                          'Privacy Policy',
                          'Your privacy is important to us. This app processes data securely and does not share personal information without consent.',
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
                          'By using this app, you agree to our terms and conditions. Please read carefully and contact us if you have any questions.',
                        );
                      },
                    ),

                    SizedBox(height: isDesktop ? 32 : (isTablet ? 28 : 24)),
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
                          'DermaCare v1.0.0\n\nA healthcare mobile application built with Flutter.\n\nDeveloped with care for your health and privacy.',
                        );
                      },
                    ),

                    SizedBox(height: isDesktop ? 32 : (isTablet ? 28 : 24)),
                    _buildSectionHeader('Account'),
                    _buildSettingCard(
                      icon: Icons.logout,
                      title: 'Logout',
                      subtitle: 'Sign out of your account',
                      onTap: () => _showLogoutDialog(),
                      textColor: Colors.red,
                    ),

                    SizedBox(height: isDesktop ? 60 : (isTablet ? 50 : 40)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileCard() {
    final auth = Provider.of<AuthProvider>(context);
    
    return Card(
      elevation: 0,
      color: Colors.grey[50],
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            GestureDetector(
              onTap: _showImageOptions,
              child: Stack(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue[100],
                    ),
                    child: ClipOval(
                      child: _profileImagePath != null && File(_profileImagePath!).existsSync()
                          ? Image.file(
                              File(_profileImagePath!),
                              fit: BoxFit.cover,
                              width: 80,
                              height: 80,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(Icons.person, size: 40, color: Colors.blue[700]);
                              },
                            )
                          : Icon(Icons.person, size: 40, color: Colors.blue[700]),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.blue[700],
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    auth.username ?? 'User',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    auth.email ?? 'user@example.com',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (auth.phone != null && auth.phone!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      auth.phone!,
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
              onPressed: _showImageOptions,
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
            size: 20,
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
    required ValueChanged<bool>? onChanged,
    bool enabled = true,
  }) {
    return Card(
      elevation: 0,
      color: enabled ? Colors.grey[50] : Colors.grey[100],
      margin: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: enabled ? Colors.blue[100] : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon, 
            color: enabled ? Colors.blue[700] : Colors.grey[500], 
            size: 20
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16, 
            fontWeight: FontWeight.w600,
            color: enabled ? Colors.black87 : Colors.grey[500],
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 14, 
            color: enabled ? Colors.grey[600] : Colors.grey[400],
          ),
        ),
        value: value,
        onChanged: enabled ? onChanged : null,
        activeColor: Colors.blue,
      ),
    );
  }

  void _showEditProfileDialog() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final nameController = TextEditingController(text: auth.username ?? '');
    final phoneController = TextEditingController(text: auth.phone ?? '');

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
                if (nameController.text.isNotEmpty) {
                  // Update username and phone in AuthProvider
                  await auth.updateUsername(nameController.text);
                  await auth.updatePhone(phoneController.text);

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
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Select Theme',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // System Default Option
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  title: const Text(
                    'System Default',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  subtitle: const Text(
                    'Follow device settings',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  leading: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.white, Colors.grey],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedTheme == 'System Default' ? const Color(0xFF4285F4) : Colors.grey[300]!,
                        width: 2,
                      ),
                    ),
                    child: _selectedTheme == 'System Default'
                        ? const Icon(
                            Icons.check,
                            size: 16,
                            color: Color(0xFF4285F4),
                          )
                        : const Icon(
                            Icons.settings,
                            size: 12,
                            color: Colors.grey,
                          ),
                  ),
                  onTap: () async {
                    final auth = Provider.of<AuthProvider>(context, listen: false);
                    setState(() {
                      _selectedTheme = 'System Default';
                      final brightness = MediaQuery.of(context).platformBrightness;
                      _darkModeEnabled = brightness == Brightness.dark;
                    });
                    await auth.setTheme(ThemeMode.system);
                    await _savePreferences();
                    if (mounted) {
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),
              // Light Theme Option
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  title: const Text(
                    'Light Theme',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  leading: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedTheme == 'Light' ? const Color(0xFF4285F4) : Colors.grey[300]!,
                        width: 2,
                      ),
                    ),
                    child: _selectedTheme == 'Light'
                        ? const Icon(
                            Icons.check,
                            size: 16,
                            color: Color(0xFF4285F4),
                          )
                        : const Icon(
                            Icons.light_mode,
                            size: 12,
                            color: Colors.orange,
                          ),
                  ),
                  onTap: () async {
                    final auth = Provider.of<AuthProvider>(context, listen: false);
                    setState(() {
                      _selectedTheme = 'Light';
                      _darkModeEnabled = false;
                    });
                    await auth.setTheme(ThemeMode.light);
                    await _savePreferences();
                    if (mounted) {
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),
              // Dark Theme Option
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  title: const Text(
                    'Dark Theme',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  leading: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedTheme == 'Dark' ? const Color(0xFF4285F4) : Colors.grey[300]!,
                        width: 2,
                      ),
                    ),
                    child: _selectedTheme == 'Dark'
                        ? const Icon(
                            Icons.check,
                            size: 16,
                            color: Color(0xFF4285F4),
                          )
                        : const Icon(
                            Icons.dark_mode,
                            size: 12,
                            color: Colors.white,
                          ),
                  ),
                  onTap: () async {
                    final auth = Provider.of<AuthProvider>(context, listen: false);
                    setState(() {
                      _selectedTheme = 'Dark';
                      _darkModeEnabled = true;
                    });
                    await auth.setTheme(ThemeMode.dark);
                    await _savePreferences();
                    if (mounted) {
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF4285F4),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear App Data'),
          content: const Text(
            'Are you sure you want to clear all app data? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                SharedPreferences prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('App data cleared successfully')),
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
