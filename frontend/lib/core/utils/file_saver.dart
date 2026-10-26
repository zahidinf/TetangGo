import 'dart:typed_data';
import 'file_saver_platform.dart' show FileSaverPlatform, ShareImageResult, ShareImageStatus;
import 'file_saver_platform.dart'
    if (dart.library.js_interop) 'file_saver_web.dart'
    if (dart.library.io) 'file_saver_io.dart';

export 'file_saver_platform.dart' show ShareImageResult, ShareImageStatus;

class FileSaver {
  static Future<bool> saveImage({
    required Uint8List bytes,
    required String filename,
  }) {
    return getFileSaver().saveImageFile(bytes: bytes, filename: filename);
  }

  static Future<ShareImageResult> shareImage({
    required Uint8List bytes,
    required String filename,
    required String title,
    String? text,
  }) {
    return getFileSaver().shareImageFile(
      bytes: bytes,
      filename: filename,
      title: title,
      text: text,
    );
  }
}
