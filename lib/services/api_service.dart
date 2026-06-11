import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dart_des/dart_des.dart';

class ApiService {
  static Future<List<dynamic>> searchSongs(String query, {int page = 1}) async {
    try {
      final url = 'https://www.jiosaavn.com/api.php?__call=search.getResults&q=${Uri.encodeComponent(query)}&n=50&p=$page&_format=json&_marker=0';
      final res = await http.get(Uri.parse(url));
      final json = jsonDecode(res.body);

      final songs = json['results'] as List?;
      if (songs == null) return [];
      
      final Map<String, dynamic> uniqueSongs = {};
      
      for (var s in songs) {
        final name = (s['song'] ?? s['title'] ?? 'Unknown').toString().replaceAll('&quot;', '"');
        final cleanName = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        final artists = s['primary_artists'] ?? s['more_info']?['primary_artists'] ?? 'Unknown';
        final uniqueKey = cleanName + artists.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        
        if (!uniqueSongs.containsKey(uniqueKey) && cleanName.isNotEmpty) {
          final album = s['album'] ?? s['more_info']?['album'] ?? '';
          final img = s['image']?.toString().replaceAll('50x50', '500x500').replaceAll('150x150', '500x500') ?? '';
          
          uniqueSongs[uniqueKey] = {
            'id': s['id'].toString(),
            'name': name,
            'primaryArtists': artists,
            'image': [{'url': img}],
            'album': {'name': album},
          };
        }
      }
      
      return uniqueSongs.values.toList();
    } catch (e) {
      print('Error searching songs: $e');
      return [];
    }
  }

  static Future<String> getAudioUrl(String songId) async {
    try {
      final url = 'https://www.jiosaavn.com/api.php?__call=song.getDetails&pids=$songId&_format=json&_marker=0';
      final res = await http.get(Uri.parse(url));
      final json = jsonDecode(res.body);

      // JioSaavn returns the object under the ID key
      final songDetails = json[songId];
      if (songDetails == null) return '';

      final encryptedUrl = songDetails['encrypted_media_url'];
      if (encryptedUrl != null && encryptedUrl.isNotEmpty) {
        // Standard JioSaavn DES ECB decryption
        final key = '38346591';
        DES desECB = DES(key: key.codeUnits, mode: DESMode.ECB);
        
        // Decode base64 to bytes
        List<int> encryptedBytes = base64.decode(encryptedUrl);
        // Decrypt
        List<int> decryptedBytes = desECB.decrypt(encryptedBytes);
        // Convert to string and completely obliterate PKCS7 padding bytes which crash the HTTP request!
        final decryptedString = utf8.decode(decryptedBytes);
        final cleanString = decryptedString.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
        
        // Upgrade to 320kbps MP4 (do NOT change .mp4 to .mp3, it causes CDN 404!)
        return cleanString.replaceAll('_96', '_320');
      }

      // Fallback
      final previewUrl = songDetails['media_preview_url'];
      if (previewUrl != null && previewUrl.isNotEmpty) {
         return previewUrl.toString().replaceAll('preview', 'h').replaceAll('_96_p', '_320');
      }

      return '';
    } catch (e) {
      print('Error getting audio stream: $e');
      return '';
    }
  }

  static Future<String?> getSyncedLyrics(String trackName, String artistName, [int? durationInSeconds]) async {
    try {
      final cleanTrack = trackName.split('(')[0].trim();
      final cleanArtist = artistName.split(',')[0].trim();

      final url = Uri.parse('https://lrclib.net/api/search?track_name=${Uri.encodeComponent(cleanTrack)}&artist_name=${Uri.encodeComponent(cleanArtist)}');
      final res = await http.get(url);
      if (res.statusCode == 200) {
        List<dynamic> jsonList = jsonDecode(res.body);
        if (jsonList.isNotEmpty) {
          if (durationInSeconds != null) {
            jsonList.sort((a, b) {
              final durA = (a['duration'] as num?)?.toInt() ?? 0;
              final durB = (b['duration'] as num?)?.toInt() ?? 0;
              final diffA = (durA - durationInSeconds).abs();
              final diffB = (durB - durationInSeconds).abs();
              return diffA.compareTo(diffB);
            });
          } else {
            jsonList.sort((a, b) {
              final lenA = (a['syncedLyrics']?.toString() ?? '').length;
              final lenB = (b['syncedLyrics']?.toString() ?? '').length;
              return lenB.compareTo(lenA);
            });
          }

          // Prefer synced lyrics
          for (var item in jsonList) {
            if (item['syncedLyrics'] != null && item['syncedLyrics'].toString().isNotEmpty) {
              return item['syncedLyrics'];
            }
          }
          // Fallback to plain lyrics
          for (var item in jsonList) {
            if (item['plainLyrics'] != null && item['plainLyrics'].toString().isNotEmpty) {
              return item['plainLyrics'];
            }
          }
        }
      }
      return null;
    } catch (e) {
      print('Error fetching lyrics from LRCLIB: $e');
      return null;
    }
  }
}
