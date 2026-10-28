import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../services/db_helper.dart';
import '../services/api_service.dart';

class LibraryProvider extends ChangeNotifier {
  DbHelper? _dbHelper;
  String? _userId;
  
  List<dynamic> _likedSongs = [];
  List<Map<String, dynamic>> _playlists = [];
  List<dynamic> _downloadedSongs = [];
  
  List<dynamic> get likedSongs => _likedSongs;
  List<Map<String, dynamic>> get playlists => _playlists;
  List<dynamic> get downloadedSongs => _downloadedSongs;
  DbHelper? get dbHelper => _dbHelper;

  LibraryProvider(this._userId) {
    if (_userId != null) {
      _dbHelper = DbHelper(userId: _userId!);
      loadLibrary();
    }
  }

  void updateUser(String? newUserId) {
    if (_userId != newUserId) {
      _userId = newUserId;
      if (_userId != null) {
        _dbHelper = DbHelper(userId: _userId!);
        loadLibrary();
      } else {
        _likedSongs = [];
        _playlists = [];
        _downloadedSongs = [];
        _dbHelper = null;
        notifyListeners();
      }
    }
  }

  Future<void> loadLibrary() async {
    if (_dbHelper == null) return;

    _likedSongs = await _dbHelper!.getLikedSongs();
    _playlists = await _dbHelper!.getPlaylists();
    _downloadedSongs = await _dbHelper!.getDownloadedSongs();
    notifyListeners();
  }

  bool isLiked(String songId) {
    return _likedSongs.any((song) => song['id'].toString() == songId);
  }

  Future<void> toggleLike(dynamic song) async {
    if (_dbHelper == null) return;
    await _dbHelper!.toggleLikedSong(song);
    _likedSongs = await _dbHelper!.getLikedSongs();
    notifyListeners();
  }

  Future<String?> createPlaylist(String name) async {
    if (_dbHelper == null) return null;
    final id = await _dbHelper!.createPlaylist(name);
    _playlists = await _dbHelper!.getPlaylists();
    notifyListeners();
    return id;
  }

  Future<void> renamePlaylist(String id, String newName) async {
    if (_dbHelper == null) return;
    await _dbHelper!.renamePlaylist(id, newName);
    _playlists = await _dbHelper!.getPlaylists();
    notifyListeners();
  }

  Future<void> deletePlaylist(String id) async {
    if (_dbHelper == null) return;
    await _dbHelper!.deletePlaylist(id);
    _playlists = await _dbHelper!.getPlaylists();
    notifyListeners();
  }

  Future<void> reorderPlaylists(int oldIndex, int newIndex) async {
    if (_dbHelper == null) return;
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = _playlists.removeAt(oldIndex);
    _playlists.insert(newIndex, item);
    notifyListeners();

    final orderedIds = _playlists.map((p) => p['id'].toString()).toList();
    await _dbHelper!.reorderPlaylists(orderedIds);
  }

  Future<void> addSongToPlaylist(String playlistId, dynamic song) async {
    if (_dbHelper == null) return;
    await _dbHelper!.addSongToPlaylist(playlistId, song);
    _playlists = await _dbHelper!.getPlaylists();
    notifyListeners();
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    if (_dbHelper == null) return;
    await _dbHelper!.removeSongFromPlaylist(playlistId, songId);
    _playlists = await _dbHelper!.getPlaylists();
    notifyListeners();
  }

  Future<void> replacePlaylistSongs(String playlistId, List<dynamic> songs) async {
    if (_dbHelper == null) return;
    await _dbHelper!.replacePlaylistSongs(playlistId, songs);
    _playlists = await _dbHelper!.getPlaylists();
    notifyListeners();
  }

  Future<List<dynamic>> getPlaylistSongs(String playlistId) async {
    if (_dbHelper == null) return [];
    return await _dbHelper!.getPlaylistSongs(playlistId);
  }

  Future<void> addRecentlyPlayed(dynamic song) async {
    if (_dbHelper == null) return;
    await _dbHelper!.addRecentlyPlayed(song);
  }

  Future<List<dynamic>> getRecentlyPlayed() async {
    if (_dbHelper == null) return [];
    return await _dbHelper!.getRecentlyPlayed();
  }

  Future<void> clearRecentlyPlayed() async {
    if (_dbHelper == null) return;
    await _dbHelper!.clearRecentlyPlayed();
    notifyListeners();
  }

  // --- Download Functionality ---

  bool isDownloaded(String songId) {
    return _downloadedSongs.any((song) => song['id'].toString() == songId);
  }

  Future<bool> downloadSong(dynamic song) async {
    if (_dbHelper == null) return false;
    try {
      final downloadUrl = await ApiService.getAudioUrl(song['id'].toString());
      if (downloadUrl == null) return false;

      final dir = await getApplicationDocumentsDirectory();
      final localPath = '${dir.path}/${song['id']}.mp3';

      final dio = Dio();
      await dio.download(downloadUrl, localPath);

      await _dbHelper!.saveDownload(song, localPath);
      _downloadedSongs = await _dbHelper!.getDownloadedSongs();
      notifyListeners();
      return true;
    } catch (e) {
      print('Download error: $e');
      return false;
    }
  }

  Future<void> removeDownload(String songId) async {
    if (_dbHelper == null) return;
    
    final song = _downloadedSongs.cast<Map<String,dynamic>?>().firstWhere((s) => s != null && s['id'].toString() == songId, orElse: () => null);
    if (song != null && song['localPath'] != null) {
      try {
        final file = File(song['localPath']);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {}
    }
    
    await _dbHelper!.deleteDownload(songId);
    await loadLibrary();
  }

  Future<double> getDownloadedSizeMB() async {
    if (_userId == null) return 0.0;
    double totalSize = 0.0;
    for (var song in _downloadedSongs) {
      try {
        final path = song['localPath'] as String?;
        if (path != null) {
          final file = File(path);
          if (await file.exists()) {
            final size = await file.length();
            totalSize += size / (1024 * 1024);
          }
        }
      } catch (e) {}
    }
    return totalSize;
  }

  Future<void> importDatabase(String sourcePath) async {
    if (_dbHelper == null) return;
    await _dbHelper!.importDatabase(sourcePath);
    await loadLibrary();
  }

  Future<void> mergeDatabase(String sourcePath) async {
    if (_dbHelper == null) return;
    await _dbHelper!.mergeDatabase(sourcePath);
    await loadLibrary();
  }

  Future<void> clearCache() async {
    if (_dbHelper == null) return;
    await _dbHelper!.clearDatabase();
    notifyListeners();
  }
}
