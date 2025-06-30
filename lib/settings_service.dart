import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _downloadKey = 'download_path';

  Future<String?> loadDownloadPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_downloadKey);
  }

  Future<void> saveDownloadPath(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path == null) {
      await prefs.remove(_downloadKey);
    } else {
      await prefs.setString(_downloadKey, path);
    }
  }
}
