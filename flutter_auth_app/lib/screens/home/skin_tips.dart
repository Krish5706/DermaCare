import 'package:flutter/material.dart';

class SkinTipsPage extends StatelessWidget {
  const SkinTipsPage({Key? key}) : super(key: key);

  final List<Map<String, String>> tips = const [
    {
      'title': 'Stay Hydrated',
      'description':
          'Drink at least 8 glasses of water daily to keep your skin hydrated and glowing.'
    },
    {
      'title': 'Use Sunscreen',
      'description':
          'Apply SPF 30 or higher sunscreen every day, even on cloudy days.'
    },
    {
      'title': 'Moisturize Daily',
      'description':
          'Use a suitable moisturizer based on your skin type after cleansing.'
    },
    {
      'title': 'Avoid Harsh Products',
      'description':
          'Stay away from alcohol-based and overly perfumed products.'
    },
    {
      'title': 'Eat a Balanced Diet',
      'description':
          'Include fruits, vegetables, and foods rich in antioxidants.'
    },
    {
      'title': 'Sleep Well',
      'description':
          'Ensure 7-9 hours of sleep each night to help your skin repair and refresh.'
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Skin Tips',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: tips.length,
        itemBuilder: (context, index) {
          final tip = tips[index];
          return Card(
            elevation: 3,
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Icon(
                Icons.spa_rounded,
                color: theme.colorScheme.primary,
              ),
              title: Text(
                tip['title']!,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              subtitle: Text(
                tip['description']!,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
