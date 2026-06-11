import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

class SettingsProvider extends ChangeNotifier {
  bool _showRecentSearches = true;
  bool _showTrending = true;
  bool _showRecentlyPlayed = true;
  int _maxCacheSizeMB = 500; // default 500MB
  bool _isOfflineMode = false;
  String _translationLanguage = 'en'; // default english
  bool _crossfadeEnabled = false;
  int _crossfadeDuration = 3; // seconds

  bool get showRecentSearches => _showRecentSearches;
  bool get showTrending => _showTrending;
  bool get showRecentlyPlayed => _showRecentlyPlayed;
  int get maxCacheSizeMB => _maxCacheSizeMB;
  bool get isOfflineMode => _isOfflineMode;
  String get translationLanguage => _translationLanguage;
  bool get crossfadeEnabled => _crossfadeEnabled;
  int get crossfadeDuration => _crossfadeDuration;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _showRecentSearches = prefs.getBool('showRecentSearches') ?? true;
    _showTrending = prefs.getBool('showTrending') ?? true;
    _showRecentlyPlayed = prefs.getBool('showRecentlyPlayed') ?? true;
    _maxCacheSizeMB = prefs.getInt('maxCacheSizeMB') ?? 500;
    _isOfflineMode = prefs.getBool('isOfflineMode') ?? false;
    _translationLanguage = prefs.getString('translationLanguage') ?? 'en';
    _crossfadeEnabled = prefs.getBool('crossfadeEnabled') ?? false;
    _crossfadeDuration = prefs.getInt('crossfadeDuration') ?? 3;
    notifyListeners();
    checkAndCleanCache();
  }

  Future<void> checkAndCleanCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/just_audio_cache');
      if (!await cacheDir.exists()) return;

      int totalSize = 0;
      final files = cacheDir.listSync().whereType<File>().toList();
      for (var file in files) {
        totalSize += await file.length();
      }

      int maxSize = _maxCacheSizeMB * 1024 * 1024;
      if (totalSize > maxSize) {
        // Sort files by modified time (oldest first)
        files.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
        
        for (var file in files) {
          if (totalSize <= maxSize) break;
          final size = await file.length();
          await file.delete();
          totalSize -= size;
        }
      }
    } catch (e) {
      print('Cache cleanup error: $e');
    }
  }

  Future<void> toggleRecentSearches(bool value) async {
    _showRecentSearches = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showRecentSearches', value);
    notifyListeners();
  }

  Future<void> toggleTrending(bool value) async {
    _showTrending = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showTrending', value);
    notifyListeners();
  }

  Future<void> toggleRecentlyPlayed(bool value) async {
    _showRecentlyPlayed = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showRecentlyPlayed', value);
    notifyListeners();
  }

  Future<void> setMaxCacheSize(int value) async {
    _maxCacheSizeMB = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('maxCacheSizeMB', value);
    notifyListeners();
    checkAndCleanCache();
  }

  Future<void> toggleOfflineMode(bool value) async {
    _isOfflineMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isOfflineMode', value);
    notifyListeners();
  }

  Future<void> setTranslationLanguage(String langCode) async {
    _translationLanguage = langCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('translationLanguage', langCode);
    notifyListeners();
  }

  Future<void> setCrossfadeEnabled(bool value) async {
    _crossfadeEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('crossfadeEnabled', value);
    notifyListeners();
  }

  Future<void> setCrossfadeDuration(int value) async {
    _crossfadeDuration = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('crossfadeDuration', value);
    notifyListeners();
  }
}
