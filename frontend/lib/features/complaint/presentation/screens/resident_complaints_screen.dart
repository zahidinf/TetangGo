import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/standard_page_header.dart';
import '../../data/repositories/complaint_repository.dart';
import '../../domain/models/complaint_model.dart';
import '../bloc/complaint_bloc.dart';
import '../bloc/complaint_event.dart';
import '../bloc/complaint_state.dart';
import '../widgets/complaint_detail_dialog.dart';
import '../widgets/create_complaint_dialog.dart';

class ResidentComplaintsScreen extends StatefulWidget {
  const ResidentComplaintsScreen({super.key});

  @override
  State<ResidentComplaintsScreen> createState() => _ResidentComplaintsScreenState();
}

class _ResidentComplaintsScreenState extends State<ResidentComplaintsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ComplaintBloc>().add(const LoadComplaintsEvent(page: 1));
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

  IconData _getCategoryIcon(ComplaintCategory cat) {
    switch (cat) {
      case ComplaintCategory.lampuJalan:
        return Icons.lightbulb_outline;
      case ComplaintCategory.sampah:
        return Icons.delete_outline;
      case ComplaintCategory.ketertiban:
        return Icons.security_rounded;
      case ComplaintCategory.jalanan:
        return Icons.add_road_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: BlocBuilder<ComplaintBloc, ComplaintState>(
        builder: (context, state) {
          return CustomScrollView(
            slivers: [
              // Action Button (Floating)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Buat Laporan',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => CreateComplaintDialog.show(context),
                    ),
                  ),
                ),
              ),

              // Content based on state
              if (state.listStatus == ComplaintListStatus.loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (state.listStatus == ComplaintListStatus.failure)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
                          const SizedBox(height: 12),
                          Text(
                            state.listErrorMessage ?? 'Gagal memuat pengaduan cluster',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => context.read<ComplaintBloc>().add(
                                  const LoadComplaintsEvent(page: 1, refresh: true),
                                ),
                            child: const Text('Coba Lagi'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (state.complaints.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.assignment_turned_in_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          const Text(
                            'Belum Ada Pengaduan Cluster',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Anda belum pernah membuat laporan fasilitas lingkungan cluster.\nKlik tombol "Buat Laporan" untuk melaporkan kendala fasilitas.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('Buat Laporan Sekarang'),
                            onPressed: () => CreateComplaintDialog.show(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = state.complaints[index];
                        final dateStr = DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(item.createdAt);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          color: Colors.white,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              ComplaintRepository? repo;
                              try {
                                repo = context.read<ComplaintRepository>();
                              } catch (_) {}

                              ComplaintDetailDialog.show(
                                context,
                                complaint: item,
                                dioClient: context.read<DioClient>(),
                                complaintRepository: repo,
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Top row: Category icon, ticket & status badge
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(_getCategoryIcon(item.category),
                                            size: 16, color: AppTheme.primary),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          item.category.label,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                            color: AppTheme.primary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(item.status).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          item.status.label,
                                          style: TextStyle(
                                            color: _getStatusColor(item.status),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Title
                                  Text(
                                    item.title,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),

                                  // Description preview
                                  Text(
                                    item.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                  ),
                                  const SizedBox(height: 12),

                                  // Bottom row: Ticket & Date & Photo indicator
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    alignment: WrapAlignment.spaceBetween,
                                    children: [
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 2,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                            item.ticketNumber,
                                            style: const TextStyle(
                                              fontFamily: 'monospace',
                                              fontWeight: FontWeight.w600,
                                              fontSize: 11,
                                              color: AppTheme.textSecondary,
                                            ),
                                          ),
                                          if (item.photoUrl != null && item.photoUrl!.isNotEmpty) ...[
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: const [
                                                Icon(Icons.photo_outlined, size: 13, color: AppTheme.textSecondary),
                                                SizedBox(width: 2),
                                                Text(
                                                  'Foto',
                                                  style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                      Text(
                                        dateStr,
                                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: state.complaints.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
