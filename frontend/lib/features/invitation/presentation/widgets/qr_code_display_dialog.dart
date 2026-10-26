import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/file_saver.dart';
import '../../domain/models/invitation_model.dart';
import '../utils/qr_image_generator.dart';

class QRCodeDisplayDialog extends StatefulWidget {
  final GuestInvitationModel invitation;

  const QRCodeDisplayDialog({
    super.key,
    required this.invitation,
  });

  static Future<void> show(
    BuildContext context, {
    required GuestInvitationModel invitation,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => QRCodeDisplayDialog(invitation: invitation),
    );
  }

  @override
  State<QRCodeDisplayDialog> createState() => _QRCodeDisplayDialogState();
}

class _QRCodeDisplayDialogState extends State<QRCodeDisplayDialog> {
  bool _isDownloading = false;
  bool _isSharingWhatsApp = false;

  GuestInvitationModel get invitation => widget.invitation;

  /// Tombol Kirim ke WhatsApp:
  /// Mengirimkan file gambar PNG kartu undangan utuh yang berisi rincian undangan dan QR Code asli.
  /// Pada Android/iOS menggunakan native share sheet file image/png menuju WhatsApp.
  /// Pada Web, jika browser mendukung file sharing via Web Share API, file diteruskan langsung.
  /// Jika browser Web desktop tidak mengizinkan pengiriman file lokal otomatis,
  /// gambar kartu undangan otomatis diunduh dan dialog fallback memfasilitasi buka WhatsApp.
  Future<void> _shareCardToWhatsApp() async {
    if (invitation.status == InvitationStatus.cancelled) return;
    if (_isSharingWhatsApp) return;
    setState(() => _isSharingWhatsApp = true);

    try {
      final pngBytes = await QrImageGenerator.generateQrPng(invitation: invitation);
      if (pngBytes == null || pngBytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal membuat kartu undangan. Silakan coba lagi.'),
              backgroundColor: AppTheme.danger,
            ),
          );
        }
        return;
      }

      final filename = QrImageGenerator.getFilename(invitation);

      // Gunakan mekanisme berbagi file gambar lintas platform
      final result = await FileSaver.shareImage(
        bytes: pngBytes,
        filename: filename,
        title: 'Undangan Masuk TetangGo: ${invitation.guestName}',
        text: 'Undangan Masuk TetangGo — ${invitation.guestName} (${invitation.invitationCode})',
      );

      if (!mounted) return;

      switch (result.status) {
        case ShareImageStatus.success:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gambar kartu undangan siap dikirim.'),
              backgroundColor: AppTheme.success,
            ),
          );
          break;

        case ShareImageStatus.dismissed:
          // User menutup share sheet secara sengaja, tangani secara graceful tanpa crash
          break;

        case ShareImageStatus.fallbackDownloaded:
          // Browser tidak mendukung pengiriman file gambar otomatis.
          // Gambar kartu sudah otomatis tersimpan, tampilkan panduan untuk WhatsApp.
          await _showFallbackWhatsAppDialog(filename);
          break;

        case ShareImageStatus.unsupported:
        case ShareImageStatus.failed:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message ?? 'Gagal membagikan kartu undangan.'),
              backgroundColor: AppTheme.danger,
            ),
          );
          break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharingWhatsApp = false);
      }
    }
  }

  /// Dialog Fallback jika browser Web desktop tidak mendukung attachment file otomatis
  Future<void> _showFallbackWhatsAppDialog(String filename) async {
    if (!mounted) return;

    final phone = invitation.phone?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    String targetPhone = phone;
    if (targetPhone.startsWith('0')) {
      targetPhone = '62${targetPhone.substring(1)}';
    }

    final briefText = Uri.encodeComponent(
        'Halo ${invitation.guestName}, terlampir gambar kartu undangan resmi TetangGo untuk izin masuk di pos satpam (Kode: ${invitation.invitationCode}).');
    final waUrl = targetPhone.isNotEmpty
        ? 'https://wa.me/$targetPhone?text=$briefText'
        : 'https://wa.me/?text=$briefText';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.download_done_rounded, color: Color(0xFF25D366), size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Gambar Kartu Tersimpan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'File gambar "$filename" telah otomatis diunduh ke komputer Anda.',
              style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            const Text(
              'Browser desktop tidak mengizinkan pengiriman file gambar otomatis ke WhatsApp Web. Buka WhatsApp dan lampirkan file gambar kartu undangan tersebut ke ruang obrolan tamu.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final uri = Uri.parse(waUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Buka WhatsApp Sekarang'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  /// Unduh Gambar Kartu Undangan (format PNG lengkap dengan informasi & QR Code)
  Future<void> _downloadQrImage() async {
    if (invitation.status == InvitationStatus.cancelled) return;
    if (_isDownloading) return;
    setState(() => _isDownloading = true);

    try {
      final pngBytes = await QrImageGenerator.generateQrPng(invitation: invitation);
      if (pngBytes == null || pngBytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal membuat kartu undangan. Silakan coba lagi.'),
              backgroundColor: AppTheme.danger,
            ),
          );
        }
        return;
      }

      final filename = QrImageGenerator.getFilename(invitation);
      final success = await FileSaver.saveImage(bytes: pngBytes, filename: filename);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(kIsWeb
                  ? 'Kartu undangan berhasil diunduh ($filename)'
                  : 'Kartu undangan siap disimpan / dibagikan'),
              backgroundColor: AppTheme.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal menyimpan file gambar kartu undangan.'),
              backgroundColor: AppTheme.danger,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan saat mengunduh gambar: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy, HH:mm');
    final validUntilStr = df.format(invitation.validUntil);
    final isCancelled = invitation.status == InvitationStatus.cancelled;
    final isCompleted = invitation.status == InvitationStatus.completed;
    final isTerminated = isCancelled || isCompleted;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.qr_code_2_rounded,
                            color: AppTheme.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'QR Undangan Masuk',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                invitation.invitationCode,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                    splashRadius: 20,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // QR Canvas Container / Revoked Status Banner (US-2)
              Center(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isTerminated
                          ? (isCancelled ? AppTheme.danger.withValues(alpha: 0.3) : Colors.teal.withValues(alpha: 0.3))
                          : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      if (isTerminated) ...[
                        // US-2 / US-5.2: QR tidak boleh ditampilkan sebagai QR aktif jika dibatalkan atau diakhiri
                        Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            color: isCancelled
                                ? AppTheme.danger.withValues(alpha: 0.08)
                                : Colors.teal.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isCancelled
                                  ? AppTheme.danger.withValues(alpha: 0.4)
                                  : Colors.teal.withValues(alpha: 0.4),
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isCancelled
                                      ? AppTheme.danger.withValues(alpha: 0.15)
                                      : Colors.teal.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isCancelled ? Icons.cancel_outlined : Icons.check_circle_outline,
                                  color: isCancelled ? AppTheme.danger : Colors.teal,
                                  size: 48,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                isCancelled ? 'QR DIBATALKAN' : 'UNDANGAN DIAKHIRI',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                  color: isCancelled ? AppTheme.danger : Colors.teal,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Tidak Berlaku Lagi',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isCancelled
                                ? AppTheme.danger.withValues(alpha: 0.1)
                                : Colors.teal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isCancelled
                                ? 'Undangan Dibatalkan — QR Tidak Berlaku'
                                : 'Undangan Diakhiri Pengundang — QR Tidak Berlaku',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isCancelled ? AppTheme.danger : Colors.teal,
                            ),
                          ),
                        ),
                      ] else ...[
                        QrImageView(
                          data: invitation.qrPayload.isNotEmpty
                              ? invitation.qrPayload
                              : invitation.invitationCode,
                          version: QrVersions.auto,
                          size: 200,
                          backgroundColor: Colors.white,
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        invitation.guestName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: invitation.visitType == VisitType.tamu
                              ? AppTheme.primary.withValues(alpha: 0.1)
                              : Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          invitation.visitType.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: invitation.visitType == VisitType.tamu
                                ? AppTheme.primary
                                : Colors.orange.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Info card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(
                      icon: Icons.timer_outlined,
                      label: isTerminated ? 'Status Undangan' : 'Berlaku Hingga',
                      value: isCancelled
                          ? 'DIBATALKAN'
                          : (isCompleted ? 'TELAH DIAKHIRI' : '$validUntilStr WIB'),
                      valueColor: isTerminated
                          ? (isCancelled ? AppTheme.danger : Colors.teal)
                          : (invitation.isActive ? AppTheme.success : AppTheme.danger),
                    ),
                    if (isCancelled &&
                        invitation.cancellationReason != null &&
                        invitation.cancellationReason!.isNotEmpty) ...[
                      const Divider(height: 16, color: Color(0xFFE2E8F0)),
                      _buildInfoRow(
                        icon: Icons.info_outline,
                        label: 'Alasan Batal',
                        value: invitation.cancellationReason!,
                        valueColor: AppTheme.danger,
                      ),
                    ],
                    if (invitation.houseDisplay.isNotEmpty) ...[
                      const Divider(height: 16, color: Color(0xFFE2E8F0)),
                      _buildInfoRow(
                        icon: Icons.home_outlined,
                        label: 'Tujuan Hunian',
                        value: invitation.houseDisplay,
                      ),
                    ],
                    if (invitation.phone != null && invitation.phone!.isNotEmpty) ...[
                      const Divider(height: 16, color: Color(0xFFE2E8F0)),
                      _buildInfoRow(
                        icon: Icons.phone_outlined,
                        label: 'No. Handphone',
                        value: invitation.phone!,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Action Buttons: Unduh Gambar Undangan & Kirim ke WhatsApp (Tombol Bagikan teks telah dihapus)
              if (isTerminated) ...[
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Tutup'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    // Tombol Unduh Gambar Kartu Undangan
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isDownloading ? null : _downloadQrImage,
                        icon: _isDownloading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.primary,
                                ),
                              )
                            : const Icon(Icons.download_rounded, size: 18),
                        label: Text(_isDownloading ? 'Menyimpan...' : 'Unduh Gambar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: const BorderSide(color: AppTheme.primary),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Tombol Kirim Kartu ke WhatsApp
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isSharingWhatsApp ? null : _shareCardToWhatsApp,
                        icon: _isSharingWhatsApp
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 18),
                        label: Text(_isSharingWhatsApp ? 'Memproses...' : 'Kirim ke WhatsApp'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: valueColor ?? AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
