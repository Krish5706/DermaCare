import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../providers/auth_provider.dart';

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
      await prefs.remove('profile_image_path');
      savedImagePath = null;
    }

    ThemeMode themeMode = auth.themeMode;
    String selectedTheme;
    bool darkModeEnabled;
    switch (themeMode) {
      case ThemeMode.light:
        selectedTheme = 'Light';
        darkModeEnabled = false;
        break;
      case ThemeMode.dark:
        selectedTheme = 'Dark';
        darkModeEnabled = true;
        break;
      case ThemeMode.system:
        selectedTheme = 'System Default';
        final brightness = MediaQuery.of(context).platformBrightness;
        darkModeEnabled = brightness == Brightness.dark;
        break;
    }

    setState(() {
      _autoSaveEnabled = prefs.getBool('auto_save_enabled') ?? true;
      _selectedLanguage = prefs.getString('selected_language') ?? 'English';
      _profileImagePath = savedImagePath;
      _selectedTheme = selectedTheme;
      _darkModeEnabled = darkModeEnabled;
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

    // Update theme through AuthProvider and sync _selectedTheme
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
    // After setting theme, update _selectedTheme and _darkModeEnabled to match
    setState(() {
      _selectedTheme = _selectedTheme;
      _darkModeEnabled = themeMode == ThemeMode.dark ||
          (themeMode == ThemeMode.system &&
              MediaQuery.of(context).platformBrightness == Brightness.dark);
    });
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
                  title: const Text('Remove Photo',
                      style: TextStyle(color: Colors.red)),
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
        final String fileName =
            'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final String localPath = '${appDir.path}/$fileName';

        // Copy the image to app's document directory
        final File localImage = await File(image.path).copy(localPath);

        setState(() {
          _profileImagePath = localImage.path;
        });
        _savePreferences();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Profile picture updated successfully')),
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

    if (mounted) {
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to AuthProvider so theme changes trigger rebuild
    context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          backgroundColor: colorScheme.surfaceContainerHighest,
          elevation: 0,
          automaticallyImplyLeading: false,
          toolbarHeight: 80,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
            ),
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () =>
                          Navigator.pushReplacementNamed(context, '/home'),
                      child: SizedBox(
                        height: 40,
                        width: 40,
                        child: Center(
                          child: Icon(
                            Icons.arrow_back,
                            color: colorScheme.onSurface,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Settings',
                          style: textTheme.headlineSmall?.copyWith(
                                color: colorScheme.onSurface,
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ) ??
                              const TextStyle(
                                color: Colors.black,
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            _buildSectionHeader('App Preferences'),
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
            const SizedBox(height: 24),
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
                  'DermaCare v1.0.0\n\nA healthcare mobile application built with Flutter.\n\nDeveloped with care for your health and privacy.',
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
    final auth = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    return Card(
      elevation: 0,
      color: theme.cardColor,
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
                      color:
                          colorScheme.primary.withAlpha((0.15 * 255).toInt()),
                    ),
                    child: ClipOval(
                      child: _profileImagePath != null &&
                              File(_profileImagePath!).existsSync()
                          ? Image.file(
                              File(_profileImagePath!),
                              fit: BoxFit.cover,
                              width: 80,
                              height: 80,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(Icons.person,
                                    size: 40, color: colorScheme.primary);
                              },
                            )
                          : Icon(Icons.person,
                              size: 40, color: colorScheme.primary),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: colorScheme.surface, width: 2),
                      ),
                      child: Icon(
                        Icons.camera_alt,
                        size: 12,
                        color: colorScheme.onPrimary,
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
                    style: textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold) ??
                        TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    auth.email ?? 'user@example.com',
                    style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface
                                .withAlpha((0.7 * 255).toInt())) ??
                        TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurface
                                .withAlpha((0.7 * 255).toInt())),
                  ),
                  if (auth.phone != null && auth.phone!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      auth.phone!,
                      style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface
                                  .withAlpha((0.7 * 255).toInt())) ??
                          TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurface
                                  .withAlpha((0.7 * 255).toInt())),
                    ),
                  ],
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _showEditProfileDialog(),
                    child: Text(
                      'Edit Profile',
                      style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ) ??
                          TextStyle(
                              fontSize: 14,
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _showImageOptions,
              icon: Icon(Icons.camera_alt,
                  color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt())),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title,
        style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
              fontSize: 18,
            ) ??
            TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDestructive = textColor == Colors.red;
    return Card(
      elevation: 0,
      color: theme.cardColor,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDestructive
                ? colorScheme.error.withAlpha((0.15 * 255).toInt())
                : colorScheme.primary.withAlpha((0.15 * 255).toInt()),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: isDestructive ? colorScheme.error : colorScheme.primary,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color:
                    isDestructive ? colorScheme.error : colorScheme.onSurface,
                fontSize: 16,
              ) ??
              TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDestructive
                      ? colorScheme.error
                      : colorScheme.onSurface),
        ),
        subtitle: Text(
          subtitle,
          style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt()),
                  fontSize: 14) ??
              TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface.withAlpha((0.7 * 255).toInt())),
        ),
        trailing: Icon(Icons.arrow_forward_ios,
            size: 16,
            color: colorScheme.onSurface.withAlpha((0.5 * 255).toInt())),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    return Card(
      elevation: 0,
      color: theme.cardColor,
      margin: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: enabled
                ? colorScheme.primary.withAlpha((0.15 * 255).toInt())
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: enabled
                ? colorScheme.primary
                : colorScheme.onSurface.withAlpha((0.5 * 255).toInt()),
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: enabled
                    ? colorScheme.onSurface
                    : colorScheme.onSurface.withAlpha((0.5 * 255).toInt()),
                fontSize: 16,
              ) ??
              TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: enabled
                      ? colorScheme.onSurface
                      : colorScheme.onSurface.withAlpha((0.5 * 255).toInt())),
        ),
        subtitle: Text(
          subtitle,
          style: textTheme.bodySmall?.copyWith(
                color: enabled
                    ? colorScheme.onSurface.withAlpha((0.7 * 255).toInt())
                    : colorScheme.onSurface.withAlpha((0.4 * 255).toInt()),
                fontSize: 14,
              ) ??
              TextStyle(
                  fontSize: 14,
                  color: enabled
                      ? colorScheme.onSurface.withAlpha((0.7 * 255).toInt())
                      : colorScheme.onSurface.withAlpha((0.4 * 255).toInt())),
        ),
        value: value,
        onChanged: enabled ? onChanged : null,
        activeColor: colorScheme.primary,
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
                    const SnackBar(
                        content: Text('Profile updated successfully')),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: DialogTheme.of(context).backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Select Theme',
            style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                  fontSize: 20,
                ) ??
                const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // System Default Option
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  title: Text(
                    'System Default',
                    style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface,
                        ) ??
                        const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    'Follow device settings',
                    style: textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          color: colorScheme.onSurface
                              .withAlpha((0.7 * 255).toInt()),
                        ) ??
                        const TextStyle(fontSize: 12),
                  ),
                  leading: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedTheme == 'System Default'
                            ? colorScheme.primary
                            : colorScheme.outlineVariant,
                        width: 2,
                      ),
                    ),
                    child: _selectedTheme == 'System Default'
                        ? Icon(
                            Icons.check,
                            size: 16,
                            color: colorScheme.primary,
                          )
                        : Icon(
                            Icons.settings,
                            size: 12,
                            color: colorScheme.onSurface
                                .withAlpha((0.7 * 255).toInt()),
                          ),
                  ),
                  onTap: () async {
                    final auth =
                        Provider.of<AuthProvider>(context, listen: false);
                    setState(() {
                      _selectedTheme = 'System Default';
                      final brightness =
                          MediaQuery.of(context).platformBrightness;
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
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  title: Text(
                    'Light Theme',
                    style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface,
                        ) ??
                        const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  leading: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedTheme == 'Light'
                            ? colorScheme.primary
                            : colorScheme.outlineVariant,
                        width: 2,
                      ),
                    ),
                    child: _selectedTheme == 'Light'
                        ? Icon(
                            Icons.check,
                            size: 16,
                            color: colorScheme.primary,
                          )
                        : Icon(
                            Icons.light_mode,
                            size: 12,
                            color: colorScheme.primary,
                          ),
                  ),
                  onTap: () async {
                    final auth =
                        Provider.of<AuthProvider>(context, listen: false);
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
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  title: Text(
                    'Dark Theme',
                    style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface,
                        ) ??
                        const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  leading: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedTheme == 'Dark'
                            ? colorScheme.primary
                            : colorScheme.outlineVariant,
                        width: 2,
                      ),
                    ),
                    child: _selectedTheme == 'Dark'
                        ? Icon(
                            Icons.check,
                            size: 16,
                            color: colorScheme.primary,
                          )
                        : Icon(
                            Icons.dark_mode,
                            size: 12,
                            color: colorScheme.onSurface,
                          ),
                  ),
                  onTap: () async {
                    final auth =
                        Provider.of<AuthProvider>(context, listen: false);
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
                foregroundColor: colorScheme.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                'Cancel',
                style: textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600) ??
                    const TextStyle(fontWeight: FontWeight.w600),
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
                  const SnackBar(
                      content: Text('App data cleared successfully')),
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
