import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/invitation_model.dart';
import '../bloc/invitation_bloc.dart';
import '../bloc/invitation_state.dart';
import '../widgets/create_invitation_dialog.dart';
import '../widgets/qr_code_display_dialog.dart';

class ResidentInvitationsScreen extends StatefulWidget {
  const ResidentInvitationsScreen({super.key});

  @override
  State<ResidentInvitationsScreen> createState() =>
      _ResidentInvitationsScreenState();
}

class _ResidentInvitationsScreenState extends State<ResidentInvitationsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<InvitationBloc>().add(const LoadInvitations());
  }

  void _openCreateDialog() {
    CreateInvitationDialog.show(
      context,
      onSubmit: ({
        required String guestName,
        required VisitType visitType,
        String? phone,
        String? notes,
        required int validHours,
      }) {
        context.read<InvitationBloc>().add(
              CreateInvitationEvent(
                guestName: guestName,
                visitType: visitType,
                phone: phone,
                notes: notes,
                validHours: validHours,
              ),
            );
      },
    );
  }

  void _confirmCancel(GuestInvitationModel inv) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Batalkan Undangan?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Batalkan izin masuk untuk ${inv.guestName}?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Alasan Pembatalan (Opsional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Kembali'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              context.read<InvitationBloc>().add(
                    CancelInvitationEvent(
                      invitationId: inv.id,
                      reason: reasonController.text,
                    ),
                  );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Batalkan Undangan',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmComplete(GuestInvitationModel inv) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Akhiri Undangan'),
        content: Text(
          'Apakah Anda yakin ingin mengakhiri undangan untuk "${inv.guestName}"?\n\n'
          'Setelah diakhiri, masa berlaku QR akan langsung dinonaktifkan secara permanen dan tidak dapat digunakan kembali untuk masuk, meskipun waktu kedaluwarsa awal belum habis.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              context.read<InvitationBloc>().add(
                    CompleteInvitationEvent(
                      invitationId: inv.id,
                    ),
                  );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            child: const Text('Akhiri Undangan',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<InvitationBloc, InvitationState>(
      listener: (context, state) {
        if (state is InvitationLoaded) {
          if (state.actionMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.actionMessage!)),
            );
          }
          if (state.activeInvitation != null) {
            QRCodeDisplayDialog.show(
              context,
              invitation: state.activeInvitation!,
            );
          }
        } else if (state is InvitationError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppTheme.danger,
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Bar
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Undang Tamu & Kurir',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Terbitkan QR Code akses gerbang masuk cluster untuk tamu atau kurir',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: _openCreateDialog,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Buat Undangan Baru'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Main Content
                Expanded(
                  child: Builder(
                    builder: (context) {
                      if (state is InvitationLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (state is InvitationLoaded) {
                        final list = state.invitations;
                        if (list.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withOpacity(0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.qr_code_2_rounded,
                                    size: 56,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Belum Ada Undangan Tamu',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Buat undangan untuk memberikan izin masuk yang aman bagi tamu atau kurir Anda.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: _openCreateDialog,
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text('Buat Undangan Sekarang'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return RefreshIndicator(
                          onRefresh: () async {
                            context
                                .read<InvitationBloc>()
                                .add(const LoadInvitations());
                          },
                          child: ListView.separated(
                            itemCount: list.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final inv = list[index];
                              return _buildInvitationCard(context, inv);
                            },
                          ),
                        );
                      }

                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInvitationCard(BuildContext context, GuestInvitationModel inv) {
    final df = DateFormat('dd MMM yyyy, HH:mm');
    final validUntilStr = df.format(inv.validUntil);

    Color statusColor;
    String statusText;
    switch (inv.status) {
      case InvitationStatus.active:
        if (inv.isActive) {
          statusColor = AppTheme.success;
          statusText = 'Aktif';
        } else {
          statusColor = AppTheme.danger;
          statusText = 'Kedaluwarsa';
        }
        break;
      case InvitationStatus.used:
        statusColor = Colors.blue;
        statusText = 'Digunakan';
        break;
      case InvitationStatus.completed:
        statusColor = Colors.teal;
        statusText = 'Diakhiri';
        break;
      case InvitationStatus.cancelled:
        statusColor = AppTheme.danger;
        statusText = 'Dibatalkan';
        break;
      case InvitationStatus.expired:
        statusColor = AppTheme.danger;
        statusText = 'Kedaluwarsa';
        break;
    }

    final isGuest = inv.visitType == VisitType.tamu;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isGuest
                  ? AppTheme.primary.withOpacity(0.1)
                  : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isGuest ? Icons.group_rounded : Icons.local_shipping_rounded,
              color: isGuest ? AppTheme.primary : Colors.orange.shade800,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      inv.guestName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        inv.visitType.label,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Kode: ${inv.invitationCode}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.timer_outlined,
                        size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      'Berlaku hingga $validUntilStr WIB',
                      style: TextStyle(
                        fontSize: 12,
                        color: inv.isActive
                            ? AppTheme.textSecondary
                            : AppTheme.danger,
                        fontWeight: inv.isActive
                            ? FontWeight.normal
                            : FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (inv.notes != null && inv.notes!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Catatan: ${inv.notes}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Actions
          Column(
            children: [
              IconButton(
                onPressed: () => QRCodeDisplayDialog.show(
                  context,
                  invitation: inv,
                ),
                tooltip: 'Lihat QR Code',
                icon: const Icon(Icons.qr_code_2_rounded,
                    color: AppTheme.primary, size: 28),
              ),
              if (inv.canBeCompleted)
                IconButton(
                  onPressed: () => _confirmComplete(inv),
                  tooltip: 'Akhiri Undangan',
                  icon: const Icon(Icons.check_circle_outline,
                      color: Colors.teal, size: 22),
                ),
              if (inv.canBeCancelled)
                IconButton(
                  onPressed: () => _confirmCancel(inv),
                  tooltip: 'Batalkan Izin Masuk',
                  icon: const Icon(Icons.cancel_outlined,
                      color: AppTheme.danger, size: 22),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
