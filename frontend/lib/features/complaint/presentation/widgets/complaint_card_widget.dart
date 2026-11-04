import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/complaint_model.dart';

class ComplaintCardWidget extends StatelessWidget {
  final ComplaintModel complaint;
  final VoidCallback onTap;
  final VoidCallback? onAssignTapped;
  final ValueChanged<ComplaintStatus>? onStatusChanged;
  final bool canManage;
  final bool isKanban;

  const ComplaintCardWidget({
    super.key,
    required this.complaint,
    required this.onTap,
    this.onAssignTapped,
    this.onStatusChanged,
    this.canManage = false,
    this.isKanban = false,
  });

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
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      elevation: isKanban ? 1.5 : 1.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ticket and Status Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        complaint.ticketNumber,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(complaint.status).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      complaint.status.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(complaint.status),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Title
              Text(
                complaint.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),

              // Category & Date
              Row(
                children: [
                  Icon(Icons.label_outline, size: 13, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      complaint.category.label,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.access_time, size: 13, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('dd/MM, HH:mm', 'id_ID').format(complaint.createdAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Officer info
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: complaint.assignedOfficer != null
                      ? AppTheme.primary.withOpacity(0.06)
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: complaint.assignedOfficer != null
                        ? AppTheme.primary.withOpacity(0.15)
                        : Colors.orange.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      complaint.assignedOfficer != null
                          ? Icons.person_pin_rounded
                          : Icons.person_off_outlined,
                      size: 14,
                      color: complaint.assignedOfficer != null
                          ? AppTheme.primary
                          : Colors.orange.shade800,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        complaint.assignedOfficer != null
                            ? 'Petugas: ${complaint.assignedOfficer}'
                            : 'Belum ada petugas',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: complaint.assignedOfficer != null
                              ? AppTheme.primary
                              : Colors.orange.shade900,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // Optional Reporter Info (if available)
              if (complaint.reporterName != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 12, color: AppTheme.textMuted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Warga: ${complaint.reporterName} ${complaint.houseDisplay.isNotEmpty ? "(${complaint.houseDisplay})" : ""}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              // Management actions row
              if (canManage) ...[
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onAssignTapped != null)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.person_add_alt_1_rounded, size: 14),
                        label: Text(
                          complaint.assignedOfficer != null ? 'Ganti' : 'Tugaskan',
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: onAssignTapped,
                      ),
                    if (onStatusChanged != null)
                      PopupMenuButton<ComplaintStatus>(
                        tooltip: 'Pindah Status',
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.more_vert_rounded, size: 18),
                        onSelected: onStatusChanged,
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: ComplaintStatus.menunggu,
                            child: Text('Menunggu'),
                          ),
                          const PopupMenuItem(
                            value: ComplaintStatus.diproses,
                            child: Text('Diproses (Dalam Pengerjaan)'),
                          ),
                          const PopupMenuItem(
                            value: ComplaintStatus.selesai,
                            child: Text('Selesai'),
                          ),
                          const PopupMenuItem(
                            value: ComplaintStatus.ditolak,
                            child: Text('Ditolak'),
                          ),
                        ],
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
}
