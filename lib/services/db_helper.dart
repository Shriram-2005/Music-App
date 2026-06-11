import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DbHelper {
  final String userId;
  DbHelper({required this.userId});

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'aura_music_$userId.db');

    return await openDatabase(
      path,
      version: 4,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE recently_played (
              id TEXT PRIMARY KEY,
              songData TEXT,
              timestamp INTEGER
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE recent_searches (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              query TEXT UNIQUE,
              timestamp INTEGER
            )
          ''');
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE downloaded_songs (
              id TEXT PRIMARY KEY,
              songData TEXT,
              localPath TEXT,
              timestamp INTEGER
            )
          ''');
        }
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE liked_songs (
            id TEXT PRIMARY KEY,
            songData TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE playlists (
            id TEXT PRIMARY KEY,
            name TEXT,
            image TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE playlist_songs (
            playlistId TEXT,
            songId TEXT,
            songData TEXT,
            FOREIGN KEY (playlistId) REFERENCES playlists(id) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE recently_played (
            id TEXT PRIMARY KEY,
            songData TEXT,
            timestamp INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE downloads (
            id TEXT PRIMARY KEY,
            songData TEXT,
            localPath TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE recent_searches (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            query TEXT UNIQUE,
            timestamp INTEGER
          )
        ''');
      },
    );
  }

  // --- Downloads --- //
  
  Future<void> saveDownload(dynamic song, String localPath) async {
    final db = await database;
    await db.insert('downloads', {
      'id': song['id'].toString(),
      'songData': jsonEncode(song),
      'localPath': localPath,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getDownloadPath(String songId) async {
    final db = await database;
    final res = await db.query('downloads', where: 'id = ?', whereArgs: [songId]);
    if (res.isNotEmpty) {
      return res.first['localPath'] as String?;
    }
    return null;
  }

  Future<void> deleteDownload(String songId) async {
    final db = await database;
    await db.delete('downloads', where: 'id = ?', whereArgs: [songId]);
  }

  Future<List<Map<String, dynamic>>> getDownloadedSongs() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('downloads');

    return List.generate(maps.length, (i) {
      final song = jsonDecode(maps[i]['songData'] as String);
      song['localPath'] = maps[i]['localPath'] as String;
      return song;
    });
  }
  
  // --- Recently Played --- //
  
  Future<void> addRecentlyPlayed(dynamic song) async {
    final db = await database;
    final songId = song['id'].toString();
    
    // Upsert equivalent: Delete if exists, then insert to update timestamp
    await db.delete('recently_played', where: 'id = ?', whereArgs: [songId]);
    await db.insert('recently_played', {
      'id': songId,
      'songData': jsonEncode(song),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    // Limit to 20 songs
    final countSq = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM recently_played'));
    if (countSq != null && countSq > 20) {
      await db.execute('''
        DELETE FROM recently_played 
        WHERE id NOT IN (
          SELECT id FROM recently_played 
          ORDER BY timestamp DESC 
          LIMIT 20
        )
      ''');
    }
  }

  Future<List<dynamic>> getRecentlyPlayed() async {
    final db = await database;
    final results = await db.query('recently_played', orderBy: 'timestamp DESC');
    return results.map((row) => jsonDecode(row['songData'] as String)).toList();
  }
  Future<void> clearRecentlyPlayed() async {
    final db = await database;
    await db.delete('recently_played');
  }

  // --- Database Utils --- //
  Future<void> clearDatabase() async {
    final db = await database;
    await db.delete('recently_played');
    await db.delete('playlist_songs');
  }

  // --- Liked Songs --- //
  
  Future<void> toggleLikedSong(dynamic song) async {
    final db = await database;
    final songId = song['id'].toString();
    
    final existing = await db.query('liked_songs', where: 'id = ?', whereArgs: [songId]);
    if (existing.isNotEmpty) {
      // Remove
      await db.delete('liked_songs', where: 'id = ?', whereArgs: [songId]);
    } else {
      // Add
      await db.insert('liked_songs', {
        'id': songId,
        'songData': jsonEncode(song),
      });
    }
  }

  Future<bool> isLiked(String songId) async {
    final db = await database;
    final existing = await db.query('liked_songs', where: 'id = ?', whereArgs: [songId]);
    return existing.isNotEmpty;
  }

  Future<List<dynamic>> getLikedSongs() async {
    final db = await database;
    final results = await db.query('liked_songs');
    return results.map((row) => jsonDecode(row['songData'] as String)).toList();
  }

  // --- Playlists --- //
  
  Future<void> createPlaylist(String name) async {
    final db = await database;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await db.insert('playlists', {
      'id': id,
      'name': name,
      'image': '',
    });
  }

  Future<void> renamePlaylist(String id, String newName) async {
    final db = await database;
    await db.update(
      'playlists',
      {'name': newName},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getPlaylists() async {
    final db = await database;
    final playlists = await db.query('playlists');
    
    List<Map<String, dynamic>> enrichedPlaylists = [];
    for (var p in playlists) {
      final pSongs = await getPlaylistSongs(p['id'] as String);
      final enriched = Map<String, dynamic>.from(p);
      enriched['songs'] = pSongs;
      enrichedPlaylists.add(enriched);
    }
    return enrichedPlaylists;
  }

  Future<void> deletePlaylist(String id) async {
    final db = await database;
    await db.delete('playlists', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> addSongToPlaylist(String playlistId, dynamic song) async {
    final db = await database;
    await db.insert('playlist_songs', {
      'playlistId': playlistId,
      'songId': song['id'].toString(),
      'songData': jsonEncode(song),
    });
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    final db = await database;
    // We only delete the FIRST occurrence if they added duplicates, or just all.
    // By default, deleting by songId string will delete all matching.
    await db.delete(
      'playlist_songs', 
      where: 'playlistId = ? AND songId = ?', 
      whereArgs: [playlistId, songId],
    );
  }

  Future<void> replacePlaylistSongs(String playlistId, List<dynamic> songs) async {
    final db = await database;
    await db.transaction((txn) async {
      // Clear out the existing configuration for this specific playlist
      await txn.delete('playlist_songs', where: 'playlistId = ?', whereArgs: [playlistId]);
      
      // Inject the exact array order as new contiguous rows
      for (var song in songs) {
        await txn.insert('playlist_songs', {
          'playlistId': playlistId,
          'songId': song['id'].toString(),
          'songData': jsonEncode(song),
        });
      }
    });
  }

  Future<List<dynamic>> getPlaylistSongs(String playlistId) async {
    final db = await database;
    // Ordering by the SQLite innate row ID guarantees insertion array order locally
    final results = await db.query(
      'playlist_songs', 
      where: 'playlistId = ?', 
      whereArgs: [playlistId],
      orderBy: 'id ASC',
    );
    return results.map((row) => jsonDecode(row['songData'] as String)).toList();
  }

  // --- Recent Searches --- //

  Future<void> saveSearch(String query) async {
    final db = await database;
    // Upsert query
    await db.insert(
      'recent_searches', 
      {
        'query': query,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Enforce max 5
    final countSq = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM recent_searches'));
    if (countSq != null && countSq > 5) {
      await db.execute('''
        DELETE FROM recent_searches 
        WHERE id NOT IN (
          SELECT id FROM recent_searches 
          ORDER BY timestamp DESC 
          LIMIT 5
        )
      ''');
    }
  }

  Future<List<String>> getRecentSearches() async {
    final db = await database;
    final results = await db.query('recent_searches', orderBy: 'timestamp DESC');
    return results.map((row) => row['query'] as String).toList();
  }

  Future<void> clearRecentSearches() async {
    final db = await database;
    await db.delete('recent_searches');
  }

  Future<void> removeRecentSearch(String query) async {
    final db = await database;
    await db.delete('recent_searches', where: 'query = ?', whereArgs: [query]);
  }
}
