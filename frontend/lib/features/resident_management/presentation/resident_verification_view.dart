import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/resident_repository.dart';
import '../domain/models/pending_user_model.dart';
import 'widgets/unassigned_residents_dialog.dart';

class ResidentVerificationView extends StatefulWidget {
  final VoidCallback? onQueueUpdated;

  const ResidentVerificationView({super.key, this.onQueueUpdated});

  @override
  State<ResidentVerificationView> createState() =>
      _ResidentVerificationViewState();
}

class _ResidentVerificationViewState extends State<ResidentVerificationView> {
  bool _isLoading = true;
  List<PendingUserModel> _pendingUsers = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchPendingUsers();
  }

  Future<void> _fetchPendingUsers() async {
    final hasExistingData = _pendingUsers.isNotEmpty;
    if (!hasExistingData) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final repo = context.read<ResidentRepository>();
      final users = await repo.getPendingUsers();
      if (mounted) {
        setState(() {
          _pendingUsers = users;
          _isLoading = false;
        });
        widget.onQueueUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _showApproveDialog(PendingUserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.check_circle_outline_rounded,
            color: AppTheme.success, size: 48),
        title: const Text('Setujui Pendaftaran Warga',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Apakah Anda yakin ingin menyetujui pendaftaran warga berikut?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nama: ${user.displayName}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                      'Rumah: ${user.houseDisplay} (${user.ownershipDisplay})'),
                  Text('No. HP / WA: ${user.phone}'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _approveUser(user.id);
            },
            child: const Text('Setujui Akun'),
          ),
        ],
      ),
    );
  }

  Future<void> _approveUser(int id) async {
    try {
      final repo = context.read<ResidentRepository>();
      await repo.approveUser(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Warga berhasil diverifikasi dan disetujui!'),
            backgroundColor: AppTheme.success,
          ),
        );
        _fetchPendingUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  void _showRejectDialog(PendingUserModel user) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon:
            const Icon(Icons.cancel_outlined, color: AppTheme.danger, size: 48),
        title: const Text('Tolak Pendaftaran Warga',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tolak pendaftaran akun atas nama ${user.displayName}?'),
            const SizedBox(height: 12),
            const Text('Alasan Penolakan:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'Contoh: Bukan warga Cluster / Rumah salah',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final reason = reasonController.text.trim();
              Navigator.pop(ctx);
              await _rejectUser(user.id, reason);
            },
            child: const Text('Tolak Pendaftaran'),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectUser(int id, String reason) async {
    try {
      final repo = context.read<ResidentRepository>();
      await repo.rejectUser(id, reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pendaftaran warga berhasil ditolak.'),
            backgroundColor: AppTheme.danger,
          ),
        );
        _fetchPendingUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Verifikasi Warga Baru',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_pendingUsers.length} Menunggu',
                              style: const TextStyle(
                                  color: Color(0xFFB45309),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tinjau permohonan bergabung warga baru sebelum dapat mengakses layanan cluster',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => UnassignedResidentsDialog(
                              onMapped: _fetchPendingUsers,
                            ),
                          );
                        },
                        icon: const Icon(Icons.person_search_rounded,
                            size: 18, color: Color(0xFFD97706)),
                        label: const Text('Warga Belum Terpetakan',
                            style: TextStyle(color: Color(0xFFB45309))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFDE68A)),
                          backgroundColor: const Color(0xFFFFFBEB),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: _fetchPendingUsers,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Segarkan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.textPrimary,
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
                  ),
                  child: Text(_errorMessage!,
                      style: const TextStyle(color: AppTheme.danger)),
                ),

              // Table Card
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                elevation: 0,
                color: Colors.white,
                child: (_isLoading && _pendingUsers.isEmpty)
                    ? const Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _pendingUsers.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(48),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.verified_user_outlined,
                                      size: 64, color: Colors.grey.shade400),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Semua pendaftaran telah ditinjau!',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textPrimary),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Tidak ada antrean verifikasi warga baru saat ini.',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(
                                  const Color(0xFFF8FAFC)),
                              columnSpacing: 24,
                              columns: const [
                                DataColumn(
                                    label: Text('Nama Warga',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                                DataColumn(
                                    label: Text('No. WhatsApp / HP',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                                DataColumn(
                                    label: Text('Email',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                                DataColumn(
                                    label: Text('Rumah Diklaim',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                                DataColumn(
                                    label: Text('Status Huni',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                                DataColumn(
                                    label: Text('Waktu Daftar',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                                DataColumn(
                                    label: Text('Aksi',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                              ],
                              rows: _pendingUsers.map((u) {
                                final timeStr =
                                    '${u.createdAt.day.toString().padLeft(2, '0')}/${u.createdAt.month.toString().padLeft(2, '0')}/${u.createdAt.year}';
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor: AppTheme.primary
                                                .withOpacity(0.15),
                                            child: Text(
                                              u.name.isNotEmpty
                                                  ? u.name[0].toUpperCase()
                                                  : 'W',
                                              style: const TextStyle(
                                                color: AppTheme.primary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(u.displayName,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                    DataCell(Text(u.phone)),
                                    DataCell(Text(u.email)),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          u.houseDisplay,
                                          style: const TextStyle(
                                              color: Color(0xFF1D4ED8),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12),
                                        ),
                                      ),
                                    ),
                                    DataCell(Text(u.ownershipDisplay)),
                                    DataCell(Text(timeStr)),
                                    DataCell(
                                      Row(
                                        children: [
                                          ElevatedButton.icon(
                                            onPressed: () =>
                                                _showApproveDialog(u),
                                            icon: const Icon(Icons.check,
                                                size: 16),
                                            label: const Text('Setujui',
                                                style: TextStyle(fontSize: 12)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppTheme.success,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8)),
                                              elevation: 0,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          OutlinedButton.icon(
                                            onPressed: () =>
                                                _showRejectDialog(u),
                                            icon: const Icon(Icons.close,
                                                size: 16),
                                            label: const Text('Tolak',
                                                style: TextStyle(fontSize: 12)),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: AppTheme.danger,
                                              side: const BorderSide(
                                                  color: Color(0xFFFECACA)),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
