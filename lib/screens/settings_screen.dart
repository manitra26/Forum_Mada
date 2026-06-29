import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.text('settings')),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsSection(
            title: settings.text('appearance'),
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(settings.text('dark_mode')),
                subtitle: Text(
                  settings.isDarkMode
                      ? settings.text('enabled')
                      : settings.text('disabled'),
                ),
                secondary: const Icon(Icons.dark_mode),
                value: settings.isDarkMode,
                onChanged: settings.setDarkMode,
              ),
              const SizedBox(height: 12),
              Text(
                settings.text('theme_color'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in ThemeProvider.colorLabels.entries)
                    ChoiceChip(
                      avatar: CircleAvatar(
                        radius: 8,
                        backgroundColor: _colorFor(entry.key),
                      ),
                      label: Text(entry.value),
                      selected: settings.themeColor == entry.key,
                      onSelected: (_) => settings.setThemeColor(entry.key),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(settings.text('large_font')),
                subtitle: Text(
                  settings.isLargeFont
                      ? settings.text('large_font_on')
                      : settings.text('large_font_off'),
                ),
                secondary: const Icon(Icons.format_size),
                value: settings.isLargeFont,
                onChanged: settings.setLargeFont,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: settings.text('language'),
            children: [
              for (final entry in ThemeProvider.languageLabels.entries)
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.value),
                  secondary: Icon(_languageIcon(entry.key)),
                  value: entry.key,
                  groupValue: settings.language,
                  onChanged: (value) {
                    if (value != null) settings.setLanguage(value);
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: settings.text('about'),
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.forum),
                title: const Text('ForumMada'),
                subtitle: Text(settings.text('description')),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.info_outline),
                title: Text(settings.text('version')),
                subtitle: const Text('ForumMada v1.0.0'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.code),
                title: Text(settings.text('developer')),
                subtitle: const Text('MANITRA Hadjimanuel'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _colorFor(String value) {
    switch (value) {
      case 'red':
        return Colors.red;
      case 'green':
        return Colors.green;
      case 'purple':
        return Colors.purple;
      case 'orange':
        return Colors.orange;
      case 'blue':
      default:
        return Colors.blue;
    }
  }

  IconData _languageIcon(String value) {
    switch (value) {
      case 'mg':
        return Icons.public;
      case 'en':
        return Icons.translate;
      case 'fr':
      default:
        return Icons.language;
    }
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}
