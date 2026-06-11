import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'db_helper.dart';

class FirebaseSyncService {
  final String userId;
  final DbHelper dbHelper;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  FirebaseSyncService({required this.userId, required this.dbHelper});

  /// Pulls data from Firestore and merges with local SQLite
  Future<void> syncDown() async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return;

      final data = doc.data()!;
      
      // Sync Liked Songs
      if (data.containsKey('likedSongs')) {
        final List<dynamic> likedSongsData = data['likedSongs'];
        for (var songJson in likedSongsData) {
          final song = json.decode(songJson);
          final isLiked = await dbHelper.isLiked(song['id'].toString());
          if (!isLiked) {
            await dbHelper.toggleLikedSong(song);
          }
        }
      }

      // Sync Custom Playlists
      if (data.containsKey('playlists')) {
        final List<dynamic> playlistsData = data['playlists'];
        final localPlaylists = await dbHelper.getPlaylists();
        final localIds = localPlaylists.map((p) => p['id'].toString()).toSet();

        for (var pData in playlistsData) {
          final pMap = pData as Map<String, dynamic>;
          final pId = pMap['id'].toString();
          final pName = pMap['name'].toString();
          
          if (!localIds.contains(pId)) {
            await dbHelper.createPlaylist(pName);
            // We should ideally sync the exact UUID, but local create generates a new one.
            // For MVP, we just merge if missing.
          }
        }
      }
    } catch (e) {
      print('Error syncing down from Firestore: $e');
    }
  }

  /// Pushes local SQLite data to Firestore
  Future<void> syncUp() async {
    try {
      final likedSongs = await dbHelper.getLikedSongs();
      final playlists = await dbHelper.getPlaylists();

      final likedSongsJson = likedSongs.map((s) => json.encode(s)).toList();

      await _firestore.collection('users').doc(userId).set({
        'likedSongs': likedSongsJson,
        'playlists': playlists,
        'lastSynced': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error syncing up to Firestore: $e');
    }
  }
}
