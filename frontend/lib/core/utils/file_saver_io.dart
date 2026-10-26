import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'file_saver_platform.dart';

class NativeFileSaver implements FileSaverPlatform {
  @override
  Future<bool> saveImageFile({
    required Uint8List bytes,
    required String filename,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$filename');
      await file.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png', name: filename)],
          fileNameOverrides: [filename],
          subject: filename,
        ),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<ShareImageResult> shareImageFile({
    required Uint8List bytes,
    required String filename,
    required String title,
    String? text,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$filename');
      await file.writeAsBytes(bytes);

      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png', name: filename)],
          fileNameOverrides: [filename],
          subject: title,
          text: text,
        ),
      );

      if (result.status == ShareResultStatus.dismissed) {
        return const ShareImageResult(
          status: ShareImageStatus.dismissed,
          message: 'Berbagi dibatalkan.',
        );
      }

      return const ShareImageResult(
        status: ShareImageStatus.success,
        message: 'Kartu undangan berhasil dibagikan.',
      );
    } catch (e) {
      return ShareImageResult(
        status: ShareImageStatus.failed,
        message: 'Gagal membagikan kartu undangan: $e',
      );
    }
  }
}

FileSaverPlatform getFileSaver() => NativeFileSaver();
