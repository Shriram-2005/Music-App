
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../providers/library_provider.dart';
import '../providers/settings_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.watch<LibraryProvider>();
    final authService = context.watch<AuthService>();
    final user = authService.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                'Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            _buildSectionHeader('Profile'),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.primary,
                backgroundImage: user?.photoURL != null && user!.photoURL!.isNotEmpty ? NetworkImage(user.photoURL!) : null,
                child: user?.photoURL == null || user!.photoURL!.isEmpty ? const Icon(Icons.person, color: Colors.black) : null,
              ),
              title: Text(user?.displayName?.isNotEmpty == true ? user!.displayName! : (user?.email ?? 'Not signed in'), style: const TextStyle(color: Colors.white)),
              subtitle: Text(user?.displayName?.isNotEmpty == true ? user!.email! : 'Free Plan', style: const TextStyle(color: Colors.white54)),
              trailing: IconButton(
                icon: const Icon(Icons.edit, color: Colors.white70),
                onPressed: () {
                  _showEditProfileDialog(context, authService);
                },
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Sign Out', style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: Colors.grey[900],
                    title: const Text('Sign Out?', style: TextStyle(color: Colors.white)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL', style: TextStyle(color: Colors.white54))),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('SIGN OUT', style: TextStyle(color: Colors.redAccent))),
                    ],
                  ),
                );
                if (confirm == true) {
                  await authService.signOut();
                }
              },
            ),

            _buildSectionHeader('Storage & Data'),
            FutureBuilder<double>(
              future: libraryProvider.getDownloadedSizeMB(),
              builder: (context, snapshot) {
                final downloadedMB = snapshot.data ?? 0.0;
                final cacheMB = context.read<SettingsProvider>().maxCacheSizeMB.toDouble();
                final totalMB = downloadedMB + cacheMB; // Approximation
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Device Storage Used', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Row(
                          children: [
                            if (cacheMB > 0)
                              Expanded(
                                flex: cacheMB.toInt(),
                                child: Container(height: 16, color: Colors.blueAccent, child: const Tooltip(message: 'Cache', child: SizedBox())),
                              ),
                            if (downloadedMB > 0)
                              Expanded(
                                flex: downloadedMB.toInt(),
                                child: Container(height: 16, color: AppTheme.primary, child: const Tooltip(message: 'Downloads', child: SizedBox())),
                              ),
                            Expanded(
                              flex: totalMB < 1000 ? (1000 - totalMB).toInt() : 100, // Show relative free space scale
                              child: Container(height: 16, color: Colors.white12, child: const Tooltip(message: 'Free', child: SizedBox())),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(width: 12, height: 12, color: Colors.blueAccent),
                              const SizedBox(width: 4),
                              Text('Cache (~${cacheMB.toInt()}MB)', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                          Row(
                            children: [
                              Container(width: 12, height: 12, color: AppTheme.primary),
                              const SizedBox(width: 4),
                              Text('Downloads (${downloadedMB.toStringAsFixed(1)}MB)', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.storage, color: Colors.white70),
              title: const Text('Clear App Cache', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Remove recently played and cached files', style: TextStyle(color: Colors.white54)),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: Colors.grey[900],
                    title: const Text('Clear Cache?', style: TextStyle(color: Colors.white)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL', style: TextStyle(color: Colors.white54))),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('CLEAR', style: TextStyle(color: AppTheme.primary))),
                    ],
                  ),
                );
                
                if (confirm == true && context.mounted) {
                  libraryProvider.clearCache();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cache cleared')));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.history, color: Colors.white70),
              title: const Text('Clear Recently Played', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Remove your recently played songs history', style: TextStyle(color: Colors.white54)),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: Colors.grey[900],
                    title: const Text('Clear History?', style: TextStyle(color: Colors.white)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL', style: TextStyle(color: Colors.white54))),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('CLEAR', style: TextStyle(color: AppTheme.primary))),
                    ],
                  ),
                );
                
                if (confirm == true && context.mounted) {
                  libraryProvider.clearRecentlyPlayed();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recently played history cleared')));
                }
              },
            ),
            _buildSectionHeader('Home Screen Customization'),
            Consumer<SettingsProvider>(
              builder: (context, settings, child) {
                return Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Offline Mode', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Only show downloaded and cached songs. Disables all network activity.', style: TextStyle(color: Colors.white54)),
                      activeColor: AppTheme.primary,
                      value: settings.isOfflineMode,
                      onChanged: (val) => settings.toggleOfflineMode(val),
                    ),
                    const Divider(color: Colors.white24),
                    ListTile(
                      title: const Text('Maximum Cache Size', style: TextStyle(color: Colors.white)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${settings.maxCacheSizeMB} MB', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                          Slider(
                            value: settings.maxCacheSizeMB.toDouble(),
                            min: 100,
                            max: 2048,
                            divisions: 20,
                            activeColor: AppTheme.primary,
                            inactiveColor: Colors.white24,
                            onChanged: (val) => settings.setMaxCacheSize(val.toInt()),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white24),
                    SwitchListTile(
                      title: const Text('Recent Searches', style: TextStyle(color: Colors.white)),
                      subtitle: const Text('Show your recent searches', style: TextStyle(color: Colors.white54)),
                      activeColor: AppTheme.primary,
                      value: settings.showRecentSearches,
                      onChanged: (val) => settings.toggleRecentSearches(val),
                    ),
                    SwitchListTile(
                      title: const Text('Recently Played', style: TextStyle(color: Colors.white)),
                      subtitle: const Text('Show your listening history', style: TextStyle(color: Colors.white54)),
                      activeColor: AppTheme.primary,
                      value: settings.showRecentlyPlayed,
                      onChanged: (val) => settings.toggleRecentlyPlayed(val),
                    ),
                    SwitchListTile(
                      title: const Text('Trending Now', style: TextStyle(color: Colors.white)),
                      subtitle: const Text('Show global trending hits', style: TextStyle(color: Colors.white54)),
                      activeColor: AppTheme.primary,
                      value: settings.showTrending,
                      onChanged: (val) => settings.toggleTrending(val),
                    ),
                    const ListTile(
                      title: Text('Recommended & Daily Mix', style: TextStyle(color: Colors.white)),
                      subtitle: Text('Always on for personalized experience', style: TextStyle(color: Colors.white54)),
                      trailing: Icon(Icons.lock_outline, color: Colors.white54),
                    ),
                  ],
                );
              },
            ),

            _buildSectionHeader('Appearance & Language'),
            Consumer<SettingsProvider>(
              builder: (context, settings, child) {
                return Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.translate, color: Colors.white70),
                      title: const Text('Lyrics Translation Language', style: TextStyle(color: Colors.white)),
                      subtitle: const Text('Language to show translated lyrics', style: TextStyle(color: Colors.white54)),
                      trailing: DropdownButton<String>(
                        dropdownColor: Colors.grey[900],
                        value: settings.translationLanguage,
                        items: const [
                          DropdownMenuItem(value: 'en', child: Text('English', style: TextStyle(color: Colors.white))),
                          DropdownMenuItem(value: 'ta', child: Text('Tamil', style: TextStyle(color: Colors.white))),
                          DropdownMenuItem(value: 'te', child: Text('Telugu', style: TextStyle(color: Colors.white))),
                          DropdownMenuItem(value: 'hi', child: Text('Hindi', style: TextStyle(color: Colors.white))),
                          DropdownMenuItem(value: 'es', child: Text('Spanish', style: TextStyle(color: Colors.white))),
                        ],
                        onChanged: (val) {
                          if (val != null) settings.setTranslationLanguage(val);
                        },
                      ),
                    ),
                    const Divider(color: Colors.white24),
                    SwitchListTile(
                      title: const Text('Gapless Crossfade', style: TextStyle(color: Colors.white)),
                      subtitle: const Text('Smoothly overlap songs', style: TextStyle(color: Colors.white54)),
                      activeColor: AppTheme.primary,
                      value: settings.crossfadeEnabled,
                      onChanged: (val) => settings.setCrossfadeEnabled(val),
                    ),
                    if (settings.crossfadeEnabled)
                      ListTile(
                        title: const Text('Crossfade Duration', style: TextStyle(color: Colors.white54)),
                        subtitle: Row(
                          children: [
                            Text('${settings.crossfadeDuration}s', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                            Expanded(
                              child: Slider(
                                value: settings.crossfadeDuration.toDouble(),
                                min: 1,
                                max: 12,
                                divisions: 11,
                                activeColor: AppTheme.primary,
                                inactiveColor: Colors.white24,
                                onChanged: (val) => settings.setCrossfadeDuration(val.toInt()),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.color_lens, color: Colors.white70),
              title: const Text('Theme Color', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Dynamic based on album art (Default)', style: TextStyle(color: Colors.white54)),
            ),

            _buildSectionHeader('Data Backup & Restore'),
            ListTile(
              leading: const Icon(Icons.download, color: Colors.white70),
              title: const Text('Export Database', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Backup your playlists, liked songs, and history', style: TextStyle(color: Colors.white54)),
              onTap: () async {
                final dbHelper = libraryProvider.dbHelper;
                if (dbHelper == null) return;
                try {
                  final bytes = await dbHelper.getDatabaseBytes();
                  String? outputFile = await FilePicker.saveFile(
                    dialogTitle: 'Save Database Backup',
                    fileName: 'ausram_music_backup.db',
                    bytes: bytes,
                  );
                  if (outputFile != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Database exported to: $outputFile')));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to export: $e')));
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.upload, color: Colors.white70),
              title: const Text('Import Database', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Restore from a previous backup file', style: TextStyle(color: Colors.white54)),
              onTap: () async {
                try {
                  FilePickerResult? result = await FilePicker.pickFiles(
                    type: FileType.any,
                  );
                  if (result != null && result.files.single.path != null) {
                    final sourcePath = result.files.single.path!;
                    final lowerPath = sourcePath.toLowerCase();
                    if (!lowerPath.contains('.db')) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a valid .db backup file')));
                      }
                      return;
                    }

                    if (!context.mounted) return;
                    showDialog(
                      context: context,
                      builder: (dialogCtx) => AlertDialog(
                        backgroundColor: Colors.grey[900],
                        title: const Text('Restore Database', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        content: const Text(
                          'How would you like to restore this backup?\n\n'
                          '• Merge: Keeps your current playlists and adds any missing playlists and songs from the backup.\n\n'
                          '• Replace: Completely replaces your library with the backup.',
                          style: TextStyle(color: Colors.white70),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogCtx),
                            child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(dialogCtx);
                              await libraryProvider.mergeDatabase(sourcePath);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Database merged successfully!')));
                              }
                            },
                            child: const Text('MERGE (RECOMMENDED)', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(dialogCtx);
                              await libraryProvider.importDatabase(sourcePath);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Database replaced successfully!')));
                              }
                            },
                            child: const Text('REPLACE', style: TextStyle(color: Colors.redAccent)),
                          ),
                        ],
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to import: $e')));
                  }
                }
              },
            ),

            _buildSectionHeader('About'),
            const ListTile(
              leading: Icon(Icons.info_outline, color: Colors.white70),
              title: Text('AUSRAM Music Version', style: TextStyle(color: Colors.white)),
              subtitle: Text('1.0.0-final', style: TextStyle(color: Colors.white54)),
            ),
            
            const SizedBox(height: 100), // Player padding
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, AuthService authService) {
    final user = authService.currentUser;
    TextEditingController nameController = TextEditingController(text: user?.displayName);
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Edit Profile', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: AppTheme.primary,
                backgroundImage: user?.photoURL != null && user!.photoURL!.isNotEmpty ? NetworkImage(user.photoURL!) : null,
                child: user?.photoURL == null || user!.photoURL!.isEmpty
                    ? const Icon(Icons.person, color: Colors.black, size: 40)
                    : null,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      setState(() => isLoading = true);
                      try {

                        await authService.updateProfile(
                          displayName: nameController.text.trim(),
                        );
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
                        setState(() => isLoading = false);
                      }
                    },
              child: isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
                  : const Text('SAVE', style: TextStyle(color: AppTheme.primary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
