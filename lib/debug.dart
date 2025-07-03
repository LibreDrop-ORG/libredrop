library opendrop_debug;

bool debugEnabled = false;

void debugLog(String message) {
  if (debugEnabled) {
    // ignore: avoid_print
    print('[DEBUG] $message');
  }
}
