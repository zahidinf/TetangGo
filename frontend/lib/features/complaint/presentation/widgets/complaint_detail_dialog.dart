import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/repositories/complaint_repository.dart';
import '../../domain/models/complaint_model.dart';

class ComplaintDetailDialog extends StatelessWidget {
  final ComplaintModel complaint;
  final DioClient dioClient;
  final ComplaintRepository? complaintRepository;

  const ComplaintDetailDialog({
    super.key,
    required this.complaint,
    required this.dioClient,
    this.complaintRepository,
  });

  static void show(
    BuildContext context, {
    required ComplaintModel complaint,
    required DioClient dioClient,
    ComplaintRepository? complaintRepository,
  }) {
    showDialog(
      context: context,
      builder: (_) => ComplaintDetailDialog(
        complaint: complaint,
        dioClient: dioClient,
        complaintRepository: complaintRepository,
      ),
    );
  }

  ComplaintRepository get _repository =>
      complaintRepository ?? ComplaintRepository(dioClient);

  Color _getStatusColor(ComplaintStatus status) {
    switch (status) {
      case ComplaintStatus.menunggu:
        return AppTheme.accent;
      case ComplaintStatus.diproses:
        return AppTheme.primary;
      case ComplaintStatus.selesai:
        return AppTheme.success;
      case ComplaintStatus.ditolak:
        return AppTheme.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(complaint.createdAt);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(complaint.status).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      complaint.status.label,
                      style: TextStyle(
                        color: _getStatusColor(complaint.status),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Nomor Tiket
              Row(
                children: [
                  const Icon(Icons.confirmation_number_outlined, size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    complaint.ticketNumber,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Judul
              Text(
                complaint.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              // Kategori & Tanggal
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.category_outlined, size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        complaint.category.label,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.access_time_rounded, size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        dateStr,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),

              // Deskripsi
              const Text(
                'Deskripsi Masalah',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  complaint.description,
                  style: const TextStyle(fontSize: 14, height: 1.4, color: AppTheme.textPrimary),
                ),
              ),
              const SizedBox(height: 16),

              // Foto Bukti Kerusakan jika ada
              if (complaint.photoUrl != null && complaint.photoUrl!.isNotEmpty) ...[
                const Text(
                  'Foto Bukti Fasilitas Lingkungan',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                ComplaintPhotoViewer(
                  photoUrl: complaint.photoUrl!,
                  repository: _repository,
                ),
                const SizedBox(height: 16),
              ],

              // Pelapor Info
              if (complaint.houseDisplay.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.home_outlined, size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      'Lokasi Pelapor: ${complaint.houseDisplay}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Tutup'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ComplaintPhotoViewer extends StatefulWidget {
  final String photoUrl;
  final ComplaintRepository repository;

  const ComplaintPhotoViewer({
    super.key,
    required this.photoUrl,
    required this.repository,
  });

  @override
  State<ComplaintPhotoViewer> createState() => _ComplaintPhotoViewerState();
}

class _ComplaintPhotoViewerState extends State<ComplaintPhotoViewer> {
  Uint8List? _photoBytes;
  bool _isLoading = true;
  String? _errorMessage;
  IconData _errorIcon = Icons.broken_image_outlined;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
  }

  @override
  void didUpdateWidget(covariant ComplaintPhotoViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoUrl != widget.photoUrl) {
      _loadPhoto();
    }
  }

  Future<void> _loadPhoto() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final bytes = await widget.repository.getComplaintPhotoBytes(widget.photoUrl);
      if (!mounted) return;
      setState(() {
        _photoBytes = bytes;
        _isLoading = false;
        _errorMessage = null;
      });
    } on ComplaintPhotoException catch (e) {
      if (!mounted) return;
      IconData icon = Icons.broken_image_outlined;
      final msg = e.message.toLowerCase();
      if (msg.contains('akses dilindungi') ||
          msg.contains('autentikasi') ||
          msg.contains('izin')) {
        icon = Icons.lock_outline;
      } else if (msg.contains('tidak ditemukan')) {
        icon = Icons.image_not_supported_outlined;
      } else if (msg.contains('koneksi') || msg.contains('jaringan')) {
        icon = Icons.wifi_off_outlined;
      }

      setState(() {
        _photoBytes = null;
        _isLoading = false;
        _errorMessage = e.message;
        _errorIcon = icon;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _photoBytes = null;
        _isLoading = false;
        _errorMessage = 'Gagal memuat foto pengaduan';
        _errorIcon = Icons.broken_image_outlined;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        alignment: Alignment.center,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(height: 10),
            Text(
              'Memuat foto pengaduan...',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        height: 180,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_errorIcon, size: 36, color: Colors.grey.shade600),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _loadPhoto,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Coba Lagi', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }

    if (_photoBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          _photoBytes!,
          height: 220,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, stack) => Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            alignment: Alignment.center,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image_outlined, size: 36, color: Colors.grey),
                SizedBox(height: 8),
                Text(
                  'Format foto tidak didukung atau file rusak',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
