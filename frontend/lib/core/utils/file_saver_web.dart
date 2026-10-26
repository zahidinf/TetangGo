import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'file_saver_platform.dart';

class WebFileSaver implements FileSaverPlatform {
  @override
  Future<bool> saveImageFile({
    required Uint8List bytes,
    required String filename,
  }) async {
    try {
      final jsArray = bytes.toJS;
      final blob = web.Blob([jsArray].toJS, web.BlobPropertyBag(type: 'image/png'));
      final url = web.URL.createObjectURL(blob);
      final anchor = web.document.createElement('a') as web.HTMLAnchorElement
        ..href = url
        ..download = filename
        ..style.display = 'none';

      web.document.body!.appendChild(anchor);
      anchor.click();
      anchor.remove();
      web.URL.revokeObjectURL(url);
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
      final jsArray = bytes.toJS;
      final blob = web.Blob([jsArray].toJS, web.BlobPropertyBag(type: 'image/png'));
      final file = web.File([blob].toJS, filename, web.FilePropertyBag(type: 'image/png'));

      final nav = web.window.navigator;

      // Cek apakah Web Share API didukung dan browser mendukung sharing file
      final shareData = web.ShareData(
        files: [file].toJS,
        title: title,
        text: text ?? '',
      );

      // Cek canShare
      bool canShare = false;
      try {
        canShare = nav.canShare(shareData);
      } catch (_) {
        canShare = false;
      }

      if (canShare) {
        await nav.share(shareData).toDart;
        return const ShareImageResult(
          status: ShareImageStatus.success,
          message: 'Berhasil membagikan kartu undangan.',
        );
      }
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('abort') || errStr.contains('cancel') || errStr.contains('dismiss')) {
        return const ShareImageResult(
          status: ShareImageStatus.dismissed,
          message: 'Berbagi dibatalkan.',
        );
      }
    }

    // Fallback: Web Share API tidak mendukung file gambar pada browser ini.
    // Otomatis unduh PNG kartu undangan agar pengguna dapat melampirkan ke WhatsApp.
    final downloaded = await saveImageFile(bytes: bytes, filename: filename);
    if (downloaded) {
      return const ShareImageResult(
        status: ShareImageStatus.fallbackDownloaded,
        message: 'Browser tidak mendukung berbagi gambar langsung. Kartu undangan berhasil diunduh ke perangkat Anda. Silakan lampirkan gambar ke WhatsApp.',
      );
    } else {
      return const ShareImageResult(
        status: ShareImageStatus.failed,
        message: 'Gagal membagikan atau mengunduh kartu undangan.',
      );
    }
  }
}

FileSaverPlatform getFileSaver() => WebFileSaver();
