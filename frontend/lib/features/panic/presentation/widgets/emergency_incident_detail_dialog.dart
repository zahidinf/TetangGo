import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../security/data/security_repository.dart';
import '../../../security/domain/models/security_models.dart';
import 'admin_incident_correction_dialog.dart';

class EmergencyIncidentDetailDialog extends StatefulWidget {
  final SecurityIncidentModel incident;
  final UserModel? user;
  final VoidCallback? onIncidentUpdated;

  const EmergencyIncidentDetailDialog({
    super.key,
    required this.incident,
    required this.user,
    this.onIncidentUpdated,
  });

  @override
  State<EmergencyIncidentDetailDialog> createState() =>
      _EmergencyIncidentDetailDialogState();
}

class _EmergencyIncidentDetailDialogState
    extends State<EmergencyIncidentDetailDialog> {
  late SecurityIncidentModel _incident;
  bool _isLoadingLogs = true;
  List<IncidentLogModel> _logs = [];
  String? _logsError;

  @override
  void initState() {
    super.initState();
    _incident = widget.incident;
    _fetchAuditLogs();
  }

  Future<void> _fetchAuditLogs() async {
    try {
      final repo = context.read<SecurityRepository>();
      final logs = await repo.getIncidentLogs(_incident.id);
      if (mounted) {
        setState(() {
          _logs = logs;
          _isLoadingLogs = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _logsError = 'Gagal memuat riwayat audit';
          _isLoadingLogs = false;
        });
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
      case 'REPORTED':
        return AppTheme.danger;
      case 'RESPONDING':
      case 'ACKNOWLEDGED':
        return Colors.orange;
      case 'RESOLVED':
        return AppTheme.success;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
      case 'REPORTED':
        return 'Dilaporkan';
      case 'RESPONDING':
      case 'ACKNOWLEDGED':
        return 'Sedang Ditangani';
      case 'RESOLVED':
        return 'Terkendali';
      default:
        return status;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toUpperCase()) {
      case 'KEJAHATAN':
        return AppTheme.danger;
      case 'KEBAKARAN':
        return Colors.deepOrange;
      case 'MEDIS':
        return Colors.blue;
      default:
        return AppTheme.primaryDark;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(_incident.category).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.emergency_rounded,
                      color: _getCategoryColor(_incident.category),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Laporan Darurat #${_incident.id}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _getStatusColor(_incident.status)
                                    .withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _getStatusColor(_incident.status)
                                      .withOpacity(0.4),
                                ),
                              ),
                              child: Text(
                                _getStatusLabel(_incident.status),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _getStatusColor(_incident.status),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Dilaporkan pada ${dateFormat.format(_incident.reportedAt)} WIB',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 32),

              // Detail Section
              _buildDetailItem(
                icon: Icons.category_outlined,
                label: 'Jenis Kejadian',
                value: _incident.categoryDisplay,
              ),
              const SizedBox(height: 12),
              _buildDetailItem(
                icon: Icons.title_rounded,
                label: 'Judul Laporan',
                value: _incident.title,
              ),
              const SizedBox(height: 12),
              _buildDetailItem(
                icon: Icons.notes_rounded,
                label: 'Deskripsi',
                value: _incident.description.isNotEmpty
                    ? _incident.description
                    : 'Tidak ada deskripsi tambahan',
              ),
              const SizedBox(height: 12),
              _buildDetailItem(
                icon: Icons.person_pin_circle_outlined,
                label: 'Pelapor',
                value:
                    '${_incident.reporterName}${_incident.reporterPhone != null ? ' (${_incident.reporterPhone})' : ''}',
              ),
              const SizedBox(height: 12),
              _buildDetailItem(
                icon: Icons.home_outlined,
                label: 'Lokasi / Hunian',
                value: _incident.houseDisplay,
              ),

              if (_incident.latitude != null && _incident.longitude != null) ...[
                const SizedBox(height: 12),
                _buildDetailItem(
                  icon: Icons.location_on_outlined,
                  label: 'Koordinat GPS',
                  value:
                      'Lat: ${_incident.latitude?.toStringAsFixed(6)}, Lon: ${_incident.longitude?.toStringAsFixed(6)} (${_incident.locationSource ?? 'GPS'})',
                ),
              ],

              // Penanganan & Penyelesaian Info
              if (_incident.assignedSecurityName != null ||
                  _incident.handlingStartedAt != null ||
                  _incident.resolutionNotes != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Informasi Penanganan Petugas',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_incident.assignedSecurityName != null)
                        Text(
                          'Petugas Satpam: ${_incident.assignedSecurityName}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      if (_incident.handlingStartedAt != null)
                        Text(
                          'Mulai Ditangani: ${dateFormat.format(_incident.handlingStartedAt!)} WIB',
                          style: const TextStyle(fontSize: 12),
                        ),
                      if (_incident.resolvedAt != null)
                        Text(
                          'Waktu Selesai: ${dateFormat.format(_incident.resolvedAt!)} WIB',
                          style: const TextStyle(fontSize: 12),
                        ),
                      if (_incident.resolutionNotes != null &&
                          _incident.resolutionNotes!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Catatan Akhir: ${_incident.resolutionNotes}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              // Audit Trail Log Section
              const SizedBox(height: 20),
              const Row(
                children: [
                  Icon(Icons.history_rounded, size: 18, color: AppTheme.primaryDark),
                  SizedBox(width: 8),
                  Text(
                    'Riwayat Perubahan & Audit Trail',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_isLoadingLogs)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (_logsError != null)
                Text(
                  _logsError!,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                )
              else if (_logs.isEmpty)
                const Text(
                  'Belum ada catatan audit lanjutan',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _logs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${log.action} • ${log.userName.isNotEmpty ? log.userName : 'Sistem'} (${log.userRole})',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                dateFormat.format(log.createdAt),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          if (log.previousStatus != null &&
                              log.newStatus != null &&
                              log.previousStatus != log.newStatus) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Status: ${_getStatusLabel(log.previousStatus!)} ➔ ${_getStatusLabel(log.newStatus!)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryDark,
                              ),
                            ),
                          ],
                          if (log.notes.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Catatan: ${log.notes}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Tutup'),
                  ),
                  if (widget.user?.isAdmin == true) ...[
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final updated = await showDialog<SecurityIncidentModel>(
                          context: context,
                          builder: (ctx) => AdminIncidentCorrectionDialog(
                            incident: _incident,
                            onSuccess: (newInc) {
                              setState(() {
                                _incident = newInc;
                              });
                              _fetchAuditLogs();
                              widget.onIncidentUpdated?.call();
                            },
                          ),
                        );
                        if (updated != null && mounted) {
                          setState(() {
                            _incident = updated;
                          });
                          _fetchAuditLogs();
                          widget.onIncidentUpdated?.call();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.edit_note_rounded, size: 18),
                      label: const Text('Koreksi Laporan (Admin)'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.textSecondary),
        const SizedBox(width: 10),
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
