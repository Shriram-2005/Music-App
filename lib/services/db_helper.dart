import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
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

    final newPath = join(dbPath, 'ausram_music_$userId.db');
    final oldPath = join(dbPath, 'aura_music_$userId.db');
    final oldPathV2 = join(dbPath, 'aura_music_v2_$userId.db'); // Wait, let's also check this just in case!

    // Migrate old db if it exists and new DB doesn't exist yet
    final oldFile = File(oldPath);
    final oldFileV2 = File(oldPathV2);
    final newFile = File(newPath);
    
    if (!await newFile.exists() || (await newFile.length()) == 0) {
      if (await oldFile.exists()) {
        await oldFile.copy(newPath);
      } else if (await oldFileV2.exists()) {
        await oldFileV2.copy(newPath);
      }
    }

    // Safely mark old files as migrated so they never interfere again
    if (await oldFile.exists()) {
      try {
        await oldFile.rename('$oldPath.migrated');
      } catch (_) {}
    }
    if (await oldFileV2.exists()) {
      try {
        await oldFileV2.rename('$oldPathV2.migrated');
      } catch (_) {}
    }

    return await openDatabase(
      newPath,
      version: 5,
      onOpen: (db) async {
        try {
          await db.execute('ALTER TABLE playlists ADD COLUMN orderIndex INTEGER DEFAULT 0');
        } catch (_) {}
        await db.execute('''
          CREATE TABLE IF NOT EXISTS recent_searches (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            query TEXT UNIQUE,
            timestamp INTEGER
          )
        ''');
      },
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
    await db.delete('recent_searches');
  }

  Future<void> exportDatabase(String targetPath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'ausram_music_$userId.db');
    final sourceFile = File(path);
    if (await sourceFile.exists()) {
      await sourceFile.copy(targetPath);
    } else {
      throw Exception('Database file not found');
    }
  }

  Future<Uint8List> getDatabaseBytes() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'ausram_music_$userId.db');
    final sourceFile = File(path);
    if (await sourceFile.exists()) {
      return await sourceFile.readAsBytes();
    } else {
      throw Exception('Database file not found');
    }
  }

  Future<void> importDatabase(String sourcePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'ausram_music_$userId.db');
    final sourceFile = File(sourcePath);
    if (await sourceFile.exists()) {
      if (_db != null) {
        await _db!.close();
        _db = null;
      }
      await sourceFile.copy(path);
      _db = await _initDb();
    } else {
      throw Exception('Backup file not found');
    }
  }

  Future<void> mergeDatabase(String sourcePath) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw Exception('Backup file not found');
    }

    final backupDb = await openDatabase(sourcePath, readOnly: true);
    final targetDb = await database;

    try {
      // 1. Merge liked songs
      final bakLiked = await backupDb.query('liked_songs');
      for (var row in bakLiked) {
        await targetDb.insert('liked_songs', row, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      // 2. Fetch target playlists and map by lowercase name
      final currentPlaylists = await targetDb.query('playlists');
      final Map<String, String> plByName = {};
      for (var p in currentPlaylists) {
        final name = (p['name']?.toString() ?? '').trim().toLowerCase();
        if (name.isNotEmpty) {
          plByName[name] = p['id'].toString();
        }
      }

      // 3. Fetch backup playlists
      final bakPlaylists = await backupDb.query('playlists');
      for (var bp in bakPlaylists) {
        final bName = bp['name']?.toString() ?? 'Playlist';
        final normName = bName.trim().toLowerCase();
        String targetPlId;

        if (plByName.containsKey(normName)) {
          targetPlId = plByName[normName]!;
        } else {
          // Insert playlist
          targetPlId = bp['id'].toString();
          await targetDb.insert('playlists', {
            'id': targetPlId,
            'name': bName,
            'image': bp['image'] ?? '',
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          plByName[normName] = targetPlId;
        }

        // Get existing songs in target playlist
        final existingRows = await targetDb.query('playlist_songs', columns: ['songId'], where: 'playlistId = ?', whereArgs: [targetPlId]);
        final existingSongIds = existingRows.map((r) => r['songId'].toString()).toSet();

        // Get backup songs for this playlist
        final bakSongs = await backupDb.query('playlist_songs', where: 'playlistId = ?', whereArgs: [bp['id'].toString()]);
        for (var sRow in bakSongs) {
          final sId = sRow['songId']?.toString();
          if (sId != null && !existingSongIds.contains(sId)) {
            await targetDb.insert('playlist_songs', {
              'playlistId': targetPlId,
              'songId': sId,
              'songData': sRow['songData'],
            });
            existingSongIds.add(sId);
          }
        }
      }
    } finally {
      await backupDb.close();
    }
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
    List<dynamic> songs = [];
    for (var row in results) {
      try {
        final rawData = row['songData'];
        if (rawData != null && rawData is String && rawData.isNotEmpty) {
          final decoded = jsonDecode(rawData);
          if (decoded != null) {
            songs.add(decoded);
          }
        }
      } catch (e) {
        print('Error decoding liked song row: $e');
      }
    }
    return songs;
  }

  // --- Playlists --- //
  
  Future<String> createPlaylist(String name) async {
    final db = await database;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM playlists')) ?? 0;
    await db.insert('playlists', {
      'id': id,
      'name': name,
      'image': '',
      'orderIndex': count,
    });
    return id;
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

  Future<void> reorderPlaylists(List<String> orderedIds) async {
    final db = await database;
    await db.transaction((txn) async {
      for (int i = 0; i < orderedIds.length; i++) {
        await txn.update(
          'playlists',
          {'orderIndex': i},
          where: 'id = ?',
          whereArgs: [orderedIds[i]],
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> getPlaylists() async {
    final db = await database;
    List<Map<String, dynamic>> playlists;
    try {
      playlists = await db.query('playlists', orderBy: 'orderIndex ASC, rowid ASC');
    } catch (_) {
      playlists = await db.query('playlists', orderBy: 'rowid ASC');
    }
    
    List<Map<String, dynamic>> enrichedPlaylists = [];
    for (var p in playlists) {
      final pId = p['id'].toString();
      try {
        final pSongs = await getPlaylistSongs(pId);
        final enriched = Map<String, dynamic>.from(p);
        enriched['id'] = pId;
        enriched['songs'] = pSongs;
        enrichedPlaylists.add(enriched);
      } catch (e) {
        print('Error loading playlist $pId: $e');
        final enriched = Map<String, dynamic>.from(p);
        enriched['id'] = pId;
        enriched['songs'] = [];
        enrichedPlaylists.add(enriched);
      }
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
    final pIdStr = playlistId.toString();
    final pIdInt = int.tryParse(pIdStr);

    final results = await db.query(
      'playlist_songs', 
      where: pIdInt != null ? 'playlistId = ? OR playlistId = ?' : 'playlistId = ?', 
      whereArgs: pIdInt != null ? [pIdStr, pIdInt] : [pIdStr],
      orderBy: 'rowid ASC',
    );

    List<dynamic> songs = [];
    for (var row in results) {
      try {
        final rawData = row['songData'];
        if (rawData != null && rawData is String && rawData.isNotEmpty) {
          final decoded = jsonDecode(rawData);
          if (decoded != null) {
            songs.add(decoded);
          }
        }
      } catch (e) {
        print('Error decoding song row in playlist $playlistId: $e');
      }
    }
    return songs;
  }

  // --- Recent Searches --- //

  Future<void> saveSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;
    final db = await database;
    // Upsert query
    await db.insert(
      'recent_searches', 
      {
        'query': clean,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Enforce max 15
    final countSq = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM recent_searches'));
    if (countSq != null && countSq > 15) {
      await db.execute('''
        DELETE FROM recent_searches 
        WHERE id NOT IN (
          SELECT id FROM recent_searches 
          ORDER BY timestamp DESC 
          LIMIT 15
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
