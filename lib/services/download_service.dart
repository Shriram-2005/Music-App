import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'api_service.dart';
import 'db_helper.dart';

class DownloadService {
  static final Dio _dio = Dio();

  static Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      if (await Permission.storage.request().isGranted) return true;
      if (await Permission.manageExternalStorage.request().isGranted) return true;
      // Android 13+ audio permission
      if (await Permission.audio.request().isGranted) return true;
      return false;
    }
    return true; // iOS usually handles this gracefully for app documents
  }

  static Future<void> downloadSong(DbHelper dbHelper, dynamic song, Function(double) onProgress, Function(bool, String) onComplete) async {
    final hasPermission = await requestPermissions();
    if (!hasPermission) {
      onComplete(false, 'Storage permission denied');
      return;
    }

    try {
      final songId = song['id'].toString();
      
      // Check if already downloaded
      final existingPath = await dbHelper.getDownloadPath(songId);
      if (existingPath != null && File(existingPath).existsSync()) {
        onComplete(true, 'Already downloaded');
        return;
      }

      // Get streaming URL
      final audioUrl = await ApiService.getAudioUrl(songId);
      if (audioUrl.isEmpty) {
        onComplete(false, 'Failed to fetch audio stream');
        return;
      }

      // Determine local path
      final dir = await getApplicationDocumentsDirectory();
      final sanitizedName = (song['name']?.toString() ?? 'unknown').replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final savePath = '${dir.path}/$songId-$sanitizedName.mp4';

      await _dio.download(
        audioUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgress(received / total);
          }
        },
      );

      // Save to database
      await dbHelper.saveDownload(song, savePath);
      onComplete(true, 'Download complete');

    } catch (e) {
      onComplete(false, e.toString());
    }
  }
}
