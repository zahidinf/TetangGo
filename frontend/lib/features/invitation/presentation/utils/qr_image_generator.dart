import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../domain/models/invitation_model.dart';

class QrImageGenerator {
  /// Menghasilkan kartu undangan lengkap berupa gambar PNG berkualitas tinggi (600 x 920)
  /// Memuat logo/identitas TetangGo, info undangan lengkap, dan QR Code asli yang dapat dipindai.
  static Future<Uint8List?> generateQrPng({
    required GuestInvitationModel invitation,
    double width = 600,
    double height = 920,
  }) async {
    try {
      final payload = invitation.qrPayload.isNotEmpty
          ? invitation.qrPayload
          : invitation.invitationCode;

      final painter = QrPainter(
        data: payload,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        gapless: true,
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Color(0xFF0F172A),
        ),
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Color(0xFF0F172A),
        ),
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));

      // 1. Background Kartu Putih Bersih
      final bgPaint = Paint()..color = Colors.white;
      canvas.drawRect(Rect.fromLTWH(0, 0, width, height), bgPaint);

      // 2. Header Brand Strip / Banner Atas (Emerald Green & Subtle Accent)
      final headerPaint = Paint()..color = const Color(0xFF10B981); // Emerald
      canvas.drawRect(Rect.fromLTWH(0, 0, width, 10), headerPaint);

      // 3. Logo & Nama TetangGo di Bagian Atas
      // Gambar badge icon rumah (Holiday Village / House shape representation)
      final badgePaint = Paint()..color = const Color(0xFF10B981).withValues(alpha: 0.12);
      final badgeRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(40, 36, 44, 44),
        const Radius.circular(12),
      );
      canvas.drawRRect(badgeRect, badgePaint);

      // Ikon visual sederhana: Rumah / Lingkungan
      final iconPaint = Paint()
        ..color = const Color(0xFF10B981)
        ..style = PaintingStyle.fill;
      final housePath = Path()
        ..moveTo(62, 46)
        ..lineTo(74, 56)
        ..lineTo(70, 56)
        ..lineTo(70, 68)
        ..lineTo(54, 68)
        ..lineTo(54, 56)
        ..lineTo(50, 56)
        ..close();
      canvas.drawPath(housePath, iconPaint);

      // Teks Brand "TetangGo"
      final brandPainter = TextPainter(
        text: const TextSpan(
          text: 'TetangGo',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      brandPainter.paint(canvas, const Offset(96, 40));

      final brandSubPainter = TextPainter(
        text: const TextSpan(
          text: 'Sistem Akses & Keamanan Warga',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      brandSubPainter.paint(canvas, const Offset(96, 64));

      // Garis Pembatas Header
      final divPaint = Paint()
        ..color = const Color(0xFFE2E8F0)
        ..strokeWidth = 1.0;
      canvas.drawLine(const Offset(40, 96), Offset(width - 40, 96), divPaint);

      // 4. Judul Kartu "UNDANGAN TETANGGO"
      final titlePainter = TextPainter(
        text: const TextSpan(
          text: 'UNDANGAN MASUK RESMI',
          style: TextStyle(
            color: Color(0xFF10B981),
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: width - 80);
      titlePainter.paint(canvas, Offset((width - titlePainter.width) / 2, 114));

      // 5. Sapaan Tamu
      final greetingPainter = TextPainter(
        text: TextSpan(
          text: 'Halo, ${invitation.guestName}',
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: width - 80);
      greetingPainter.paint(canvas, Offset((width - greetingPainter.width) / 2, 140));

      // Sub-sapaan
      final subGreetingPainter = TextPainter(
        text: const TextSpan(
          text: 'Anda telah diundang untuk berkunjung dengan rincian berikut:',
          style: TextStyle(
            color: Color(0xFF475569),
            fontSize: 13,
            fontWeight: FontWeight.normal,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: width - 80);
      subGreetingPainter.paint(canvas, Offset((width - subGreetingPainter.width) / 2, 172));

      // 6. Kotak Informasi Undangan
      const infoBoxTop = 202.0;
      const infoBoxHeight = 176.0;
      final infoBoxRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(40, infoBoxTop, width - 80, infoBoxHeight),
        const Radius.circular(14),
      );
      final infoBoxBg = Paint()..color = const Color(0xFFF8FAFC);
      canvas.drawRRect(infoBoxRect, infoBoxBg);

      final infoBoxBorder = Paint()
        ..color = const Color(0xFFE2E8F0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawRRect(infoBoxRect, infoBoxBorder);

      final df = DateFormat('dd MMM yyyy, HH:mm');
      final validUntilStr = df.format(invitation.validUntil);
      final visitLabel = invitation.visitType == VisitType.tamu ? 'Tamu Warga' : 'Kurir / Paket / Delivery';

      // Baris-baris informasi
      double rowY = infoBoxTop + 14;
      void drawInfoRow(String label, String value, {Color valColor = const Color(0xFF0F172A), bool bold = true}) {
        final lblP = TextPainter(
          text: TextSpan(
            text: label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout(maxWidth: 160);
        lblP.paint(canvas, Offset(56, rowY));

        final valP = TextPainter(
          text: TextSpan(
            text: value,
            style: TextStyle(
              color: valColor,
              fontSize: 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
          textAlign: TextAlign.right,
          textDirection: ui.TextDirection.ltr,
        )..layout(maxWidth: width - 80 - 180);
        valP.paint(canvas, Offset(width - 56 - valP.width, rowY));

        rowY += 32;
      }

      drawInfoRow('Tujuan Hunian', invitation.houseDisplay.isNotEmpty ? invitation.houseDisplay : 'Warga TetangGo');
      drawInfoRow('Tuan Rumah', invitation.hostName ?? 'Warga TetangGo');
      drawInfoRow('Jenis Kunjungan', visitLabel, valColor: const Color(0xFF0F766E));
      drawInfoRow('Berlaku Hingga', '$validUntilStr WIB', valColor: const Color(0xFF10B981));
      drawInfoRow('Kode Undangan', invitation.invitationCode, valColor: const Color(0xFF1E293B));

      // 7. Area QR Code Container dengan Quiet Zone
      const qrBoxTop = 398.0;
      const qrBoxSize = 270.0;
      final qrBoxLeft = (width - qrBoxSize) / 2;

      final qrContainerRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(qrBoxLeft, qrBoxTop, qrBoxSize, qrBoxSize),
        const Radius.circular(16),
      );
      final qrContainerPaint = Paint()..color = Colors.white;
      canvas.drawRRect(qrContainerRect, qrContainerPaint);

      final qrBorderPaint = Paint()
        ..color = const Color(0xFFCBD5E1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawRRect(qrContainerRect, qrBorderPaint);

      // Render QR Code di tengah container (quiet zone 25px)
      const qrInnerSize = 220.0;
      const qrMargin = (qrBoxSize - qrInnerSize) / 2;
      canvas.save();
      canvas.translate(qrBoxLeft + qrMargin, qrBoxTop + qrMargin);
      painter.paint(canvas, const Size(qrInnerSize, qrInnerSize));
      canvas.restore();

      // 8. Kode Undangan Teks di Bawah QR
      final codePainter = TextPainter(
        text: TextSpan(
          text: invitation.invitationCode,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: width - 80);
      codePainter.paint(canvas, Offset((width - codePainter.width) / 2, qrBoxTop + qrBoxSize + 14));

      // 9. Instruksi Petugas Satpam di Bagian Bawah
      const instrTop = 724.0;
      final instrBoxRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(40, instrTop, width - 80, 84),
        const Radius.circular(12),
      );
      final instrBoxBg = Paint()..color = const Color(0xFF10B981).withValues(alpha: 0.08);
      canvas.drawRRect(instrBoxRect, instrBoxBg);

      final instrBorder = Paint()
        ..color = const Color(0xFF10B981).withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawRRect(instrBoxRect, instrBorder);

      final instrTitlePainter = TextPainter(
        text: const TextSpan(
          text: 'PETUNJUK AKSES MASUK',
          style: TextStyle(
            color: Color(0xFF047857),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: width - 110);
      instrTitlePainter.paint(canvas, Offset((width - instrTitlePainter.width) / 2, instrTop + 14));

      final instrBodyPainter = TextPainter(
        text: const TextSpan(
          text: 'Tunjukkan kode QR ini kepada petugas satpam di pos keamanan cluster untuk verifikasi izin masuk Anda.',
          style: TextStyle(
            color: Color(0xFF334155),
            fontSize: 12,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: width - 110);
      instrBodyPainter.paint(canvas, Offset((width - instrBodyPainter.width) / 2, instrTop + 34));

      // 10. Footer Tipis
      final footerPainter = TextPainter(
        text: const TextSpan(
          text: 'Diterbitkan secara digital oleh TetangGo Smart Neighborhood',
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: width - 80);
      footerPainter.paint(canvas, Offset((width - footerPainter.width) / 2, height - 36));

      // Finish Recording & Export PNG Bytes
      final picture = recorder.endRecording();
      final img = await picture.toImage(width.toInt(), height.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error generating invitation card PNG: $e');
      return null;
    }
  }

  /// Menghasilkan nama file kartu undangan yang rapi dan konsisten
  static String getFilename(GuestInvitationModel invitation) {
    final cleanCode = invitation.invitationCode.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return 'undangan_tetanggo_$cleanCode.png';
  }
}
