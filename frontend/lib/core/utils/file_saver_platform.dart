import 'dart:typed_data';
import 'package:equatable/equatable.dart';

enum ShareImageStatus {
  success,
  dismissed,
  fallbackDownloaded,
  unsupported,
  failed,
}

class ShareImageResult extends Equatable {
  final ShareImageStatus status;
  final String? message;

  const ShareImageResult({
    required this.status,
    this.message,
  });

  @override
  List<Object?> get props => [status, message];
}

abstract class FileSaverPlatform {
  Future<bool> saveImageFile({
    required Uint8List bytes,
    required String filename,
  });

  Future<ShareImageResult> shareImageFile({
    required Uint8List bytes,
    required String filename,
    required String title,
    String? text,
  });
}

FileSaverPlatform getFileSaver() => throw UnsupportedError('Cannot create file saver');
