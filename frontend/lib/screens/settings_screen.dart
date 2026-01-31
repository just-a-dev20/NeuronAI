import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionTitle(context, 'Appearance'),
              _buildSwitchTile(
                context,
                title: 'Dark Mode',
                subtitle: 'Enable dark theme',
                value: settings.isDarkMode,
                onChanged: (value) => settings.setDarkMode(value),
              ),
              _buildSliderTile(
                context,
                title: 'Font Size',
                subtitle: '${settings.fontSize.toInt()}pt',
                value: settings.fontSize,
                min: 12,
                max: 20,
                onChanged: (value) => settings.setFontSize(value),
              ),
              const Divider(),
              _buildSectionTitle(context, 'Connection'),
              _buildTextTile(
                context,
                title: 'API URL',
                subtitle: settings.apiUrl,
                onTap: () => _showEditDialog(
                  context,
                  title: 'API URL',
                  initialValue: settings.apiUrl,
                  onSave: (value) => settings.setApiUrl(value),
                ),
              ),
              _buildTextTile(
                context,
                title: 'WebSocket URL',
                subtitle: settings.wsUrl,
                onTap: () => _showEditDialog(
                  context,
                  title: 'WebSocket URL',
                  initialValue: settings.wsUrl,
                  onSave: (value) => settings.setWsUrl(value),
                ),
              ),
              const Divider(),
              _buildSectionTitle(context, 'Behavior'),
              _buildSwitchTile(
                context,
                title: 'Auto-play Media',
                subtitle: 'Automatically play videos and audio',
                value: settings.autoPlayMedia,
                onChanged: (value) => settings.setAutoPlayMedia(value),
              ),
              _buildSwitchTile(
                context,
                title: 'Typing Indicator',
                subtitle: 'Show when the AI is typing',
                value: settings.showTypingIndicator,
                onChanged: (value) => settings.setShowTypingIndicator(value),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildSliderTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: SizedBox(
        width: 200,
        child: Slider(
          value: value,
          min: min,
          max: max,
          divisions: 8,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTextTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  void _showEditDialog(
    BuildContext context, {
    required String title,
    required String initialValue,
    required ValueChanged<String> onSave,
  }) {
    final controller = TextEditingController(text: initialValue);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              onSave(controller.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
