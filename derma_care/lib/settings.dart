import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).appBarTheme.foregroundColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style: TextStyle(
            color: Theme.of(context).appBarTheme.foregroundColor,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('General'),
            _buildSettingCard(
              icon: Icons.language,
              title: 'Language',
              subtitle: themeProvider.selectedLanguage,
              onTap: () => _showLanguageDialog(themeProvider),
            ),
            _buildSettingCard(
              icon: Icons.palette,
              title: 'Theme',
              subtitle: themeProvider.isDarkMode ? 'Dark' : 'Light',
              onTap: () => _showThemeDialog(themeProvider),
            ),
            
            SizedBox(height: 24),
            _buildSectionHeader('Notifications'),
            _buildSwitchCard(
              icon: Icons.notifications,
              title: 'Push Notifications',
              subtitle: 'Receive scan reminders and updates',
              value: themeProvider.notificationsEnabled,
              onChanged: (value) {
                themeProvider.setNotifications(value);
              },
            ),
            
            SizedBox(height: 24),
            _buildSectionHeader('App Preferences'),
            _buildSwitchCard(
              icon: Icons.dark_mode,
              title: 'Dark Mode',
              subtitle: 'Switch to dark theme',
              value: themeProvider.isDarkMode,
              onChanged: (value) {
                themeProvider.setDarkMode(value);
              },
            ),
            _buildSwitchCard(
              icon: Icons.save,
              title: 'Auto Save Scans',
              subtitle: 'Automatically save scan results',
              value: themeProvider.autoSaveEnabled,
              onChanged: (value) {
                themeProvider.setAutoSave(value);
              },
            ),
            _buildSwitchCard(
              icon: Icons.cloud_off,
              title: 'Offline Mode',
              subtitle: 'Use app without internet connection',
              value: themeProvider.offlineModeEnabled,
              onChanged: (value) {
                themeProvider.setOfflineMode(value);
              },
            ),
            
            SizedBox(height: 24),
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
                // Navigate to privacy policy
                _showInfoDialog('Privacy Policy', 'Your privacy is important to us. This app processes skin images locally and does not share personal data without consent.');
              },
            ),
            _buildSettingCard(
              icon: Icons.description,
              title: 'Terms of Service',
              subtitle: 'View terms and conditions',
              onTap: () {
                // Navigate to terms of service
                _showInfoDialog('Terms of Service', 'By using this app, you agree to our terms and conditions. This app is for educational purposes and should not replace professional medical advice.');
              },
            ),
            
            SizedBox(height: 24),
            _buildSectionHeader('Support'),
            _buildSettingCard(
              icon: Icons.help,
              title: 'Help & FAQ',
              subtitle: 'Get help and find answers',
              onTap: () {
                _showInfoDialog('Help & FAQ', 'For support, please contact us at support@skinscan.com or visit our FAQ section on the website.');
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
                _showInfoDialog('About SkinScan', 'SkinScan v1.0.0\n\nA personal skin disease detection app powered by AI technology.\n\nDeveloped with care for your health and privacy.');
              },
            ),
            
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12, top: 8),
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
  }) {
    return Card(
      elevation: 0,
      color: Theme.of(context).cardTheme.color,
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.blue[700], size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
          ),
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
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
      color: Theme.of(context).cardTheme.color,
      margin: EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        secondary: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.blue[700], size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: Colors.blue,
      ),
    );
  }

  void _showLanguageDialog(ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select Language'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLanguageOption('English', themeProvider),
              _buildLanguageOption('Spanish', themeProvider),
              _buildLanguageOption('French', themeProvider),
              _buildLanguageOption('German', themeProvider),
              _buildLanguageOption('Chinese', themeProvider),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLanguageOption(String language, ThemeProvider themeProvider) {
    return ListTile(
      title: Text(language),
      leading: Radio<String>(
        value: language,
        groupValue: themeProvider.selectedLanguage,
        onChanged: (value) {
          themeProvider.setLanguage(value!);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showThemeDialog(ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select Theme'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('Light'),
                leading: Radio<String>(
                  value: 'Light',
                  groupValue: themeProvider.isDarkMode ? 'Dark' : 'Light',
                  onChanged: (value) {
                    themeProvider.setDarkMode(false);
                    Navigator.pop(context);
                  },
                ),
              ),
              ListTile(
                title: Text('Dark'),
                leading: Radio<String>(
                  value: 'Dark',
                  groupValue: themeProvider.isDarkMode ? 'Dark' : 'Light',
                  onChanged: (value) {
                    themeProvider.setDarkMode(true);
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
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
          title: Text('Clear Scan History'),
          content: Text('Are you sure you want to clear all scan history? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Scan history cleared successfully')),
                );
              },
              child: Text('Clear', style: TextStyle(color: Colors.red)),
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
          content: SingleChildScrollView(
            child: Text(content),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
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
          title: Text('Send Feedback'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('We value your feedback! Please share your thoughts:'),
              SizedBox(height: 16),
              TextField(
                controller: feedbackController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Enter your feedback here...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Thank you for your feedback!')),
                );
              },
              child: Text('Send'),
            ),
          ],
        );
      },
    );
  }
}