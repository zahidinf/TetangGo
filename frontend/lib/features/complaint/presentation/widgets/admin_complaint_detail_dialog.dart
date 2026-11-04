import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/repositories/complaint_repository.dart';
import '../../domain/models/complaint_model.dart';
import 'complaint_detail_dialog.dart';

class AdminComplaintDetailDialog extends StatelessWidget {
  final ComplaintModel complaint;
  final List<ComplaintAssignmentModel> assignments;
  final DioClient dioClient;
  final bool canAssign;
  final VoidCallback? onAssignTapped;
  final ValueChanged<ComplaintStatus>? onStatusChanged;

  const AdminComplaintDetailDialog({
    super.key,
    required this.complaint,
    required this.assignments,
    required this.dioClient,
    this.canAssign = false,
    this.onAssignTapped,
    this.onStatusChanged,
  });

  static void show(
    BuildContext context, {
    required ComplaintModel complaint,
    required List<ComplaintAssignmentModel> assignments,
    required DioClient dioClient,
    bool canAssign = false,
    VoidCallback? onAssignTapped,
    ValueChanged<ComplaintStatus>? onStatusChanged,
  }) {
    showDialog(
      context: context,
      builder: (_) => AdminComplaintDetailDialog(
        complaint: complaint,
        assignments: assignments,
        dioClient: dioClient,
        canAssign: canAssign,
        onAssignTapped: onAssignTapped,
        onStatusChanged: onStatusChanged,
      ),
    );
  }

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
        constraints: const BoxConstraints(maxWidth: 680),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _getStatusColor(complaint.status).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.assignment_outlined,
                      color: _getStatusColor(complaint.status),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          complaint.ticketNumber,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          complaint.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),

              // Badges row
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildBadge(
                    label: complaint.category.label,
                    icon: Icons.label_outline,
                    color: Colors.blueGrey,
                  ),
                  _buildBadge(
                    label: complaint.status.label,
                    icon: Icons.info_outline,
                    color: _getStatusColor(complaint.status),
                  ),
                  _buildBadge(
                    label: dateStr,
                    icon: Icons.calendar_today_outlined,
                    color: Colors.grey.shade700,
                  ),
                  if (complaint.reporterName != null)
                    _buildBadge(
                      label: 'Pelapor: ${complaint.reporterName}',
                      icon: Icons.person_outline,
                      color: AppTheme.primary,
                    ),
                  if (complaint.houseDisplay.isNotEmpty)
                    _buildBadge(
                      label: complaint.houseDisplay,
                      icon: Icons.home_outlined,
                      color: Colors.indigo,
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Description
              const Text(
                'Deskripsi Laporan',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  complaint.description,
                  style: const TextStyle(fontSize: 14, height: 1.4, color: AppTheme.textDark),
                ),
              ),
              const SizedBox(height: 18),

              // Officer Status Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: complaint.assignedOfficer != null
                      ? AppTheme.primary.withOpacity(0.06)
                      : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: complaint.assignedOfficer != null
                        ? AppTheme.primary.withOpacity(0.2)
                        : Colors.amber.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      complaint.assignedOfficer != null
                          ? Icons.engineering_rounded
                          : Icons.person_off_outlined,
                      color: complaint.assignedOfficer != null
                          ? AppTheme.primary
                          : Colors.amber.shade800,
                      size: 28,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            complaint.assignedOfficer != null
                                ? 'Petugas Ditugaskan: ${complaint.assignedOfficer}'
                                : 'Belum Ada Petugas Ditugaskan',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: complaint.assignedOfficer != null
                                  ? AppTheme.primary
                                  : Colors.amber.shade900,
                            ),
                          ),
                          if (complaint.assignedAt != null)
                            Text(
                              'Ditugaskan pada: ${DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(complaint.assignedAt!)}',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                            ),
                        ],
                      ),
                    ),
                    if (canAssign)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.person_add_rounded, size: 16),
                        label: Text(
                          complaint.assignedOfficer != null ? 'Ganti Petugas' : 'Tugaskan',
                          style: const TextStyle(fontSize: 13),
                        ),
                        onPressed: onAssignTapped,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Photo Section
              if (complaint.photoUrl != null && complaint.photoUrl!.isNotEmpty) ...[
                const Text(
                  'Foto Bukti Lapangan',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                ),
                const SizedBox(height: 8),
                ComplaintPhotoViewer(
                  photoUrl: complaint.photoUrl!,
                  repository: ComplaintRepository(dioClient),
                ),
                const SizedBox(height: 18),
              ],

              // Assignment Audit Trail
              const Text(
                'Riwayat Penugasan & Audit',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark),
              ),
              const SizedBox(height: 8),

              if (assignments.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Center(
                    child: Text(
                      'Belum ada riwayat penugasan untuk tiket ini.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: assignments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = assignments[index];
                    final timeStr = DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(item.assignedAt);
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: AppTheme.primary.withOpacity(0.12),
                            child: const Icon(Icons.history_rounded, size: 16, color: AppTheme.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      item.officerName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    Text(
                                      timeStr,
                                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Ditugaskan oleh: ${item.assignedByName ?? 'Pengelola Lingkungan'}',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                ),
                                if (item.notes != null && item.notes!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Catatan: "${item.notes}"',
                                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

              const SizedBox(height: 24),

              // Bottom status changer & close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (canAssign)
                    PopupMenuButton<ComplaintStatus>(
                      tooltip: 'Ubah Status',
                      onSelected: onStatusChanged,
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: ComplaintStatus.menunggu,
                          child: Text('Ubah: Menunggu'),
                        ),
                        const PopupMenuItem(
                          value: ComplaintStatus.diproses,
                          child: Text('Ubah: Diproses (Dalam Pengerjaan)'),
                        ),
                        const PopupMenuItem(
                          value: ComplaintStatus.selesai,
                          child: Text('Ubah: Selesai'),
                        ),
                        const PopupMenuItem(
                          value: ComplaintStatus.ditolak,
                          child: Text('Ubah: Ditolak'),
                        ),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.published_with_changes_rounded, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Ubah Status (${complaint.status.label})',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Tutup'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
