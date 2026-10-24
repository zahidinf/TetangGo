import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../announcements/data/announcements_repository.dart';
import '../../../announcements/domain/models/announcement_model.dart';
import '../../../announcements/presentation/widgets/announcement_detail_dialog.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../billing/data/billing_repository.dart';
import '../../../billing/domain/models/billing_models.dart';
import '../../../cashbook/data/cashbook_repository.dart';
import '../../../cashbook/domain/models/cashbook_models.dart';
import '../../data/dashboard_repository.dart';
import '../../domain/models/dashboard_stats_model.dart';
import 'stat_card.dart';

class DashboardContentBody extends StatefulWidget {
  final UserModel? user;
  final bool isDesktop;
  final void Function(String keyId)? onNavigate;
  final ValueChanged<int>? onUnpaidCountUpdated;

  const DashboardContentBody({
    super.key,
    required this.user,
    required this.isDesktop,
    this.onNavigate,
    this.onUnpaidCountUpdated,
  });

  @override
  State<DashboardContentBody> createState() => _DashboardContentBodyState();
}

class _DashboardContentBodyState extends State<DashboardContentBody> {
  bool _isLoading = false;
  String? _errorMessage;
  DashboardStatsModel? _statsData;
  List<DashboardRecentActivityModel> _residentActivities = [];
  CashbookSummaryModel? _cashbookSummary;
  List<AnnouncementModel> _announcements = [];

  List<BillModel> _unpaidBills = [];
  List<BillModel> _pendingBills = [];
  List<BillModel> _rejectedBills = [];
  double _totalUnpaidAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchDashboardStats();
  }

  Future<void> _fetchDashboardStats() async {
    final hasExistingData = _statsData != null ||
        _residentActivities.isNotEmpty ||
        _unpaidBills.isNotEmpty ||
        _pendingBills.isNotEmpty ||
        _rejectedBills.isNotEmpty ||
        _cashbookSummary != null ||
        _announcements.isNotEmpty;

    if (!hasExistingData) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final canAccessAdminStats = widget.user?.hasAdminAccess ?? false;
      DashboardStatsModel? data;
      List<DashboardRecentActivityModel> residentActivities = [];
      List<BillModel> residentBills = [];
      List<BillModel> unpaidBills = [];
      List<BillModel> pendingBills = [];
      List<BillModel> rejectedBills = [];
      double totalUnpaidAmount = 0.0;

      if (canAccessAdminStats) {
        try {
          final repository = context.read<DashboardRepository>();
          data = await repository.getAdminDashboardStats();
        } catch (_) {}
      } else {
        // Warga: Ambil aktivitas iuran hunian warga yang sedang login
        try {
          BillingRepository? billingRepo;
          try {
            billingRepo = context.read<BillingRepository>();
          } catch (_) {}

          if (billingRepo != null) {
            final bills = await billingRepo.getResidentBills();
            residentBills = List<BillModel>.from(bills);
            unpaidBills = residentBills.where((b) => b.isUnpaid).toList();
            pendingBills = residentBills.where((b) => b.isPending).toList();
            rejectedBills = residentBills.where((b) => b.isRejected).toList();
            totalUnpaidAmount = unpaidBills.fold<double>(0.0, (sum, b) => sum + b.amount);

            // Urutkan aktivitas warga berdasarkan:
            // 1. Prioritas status: Belum dibayar -> Menunggu verifikasi -> Ditolak -> Lunas/Disetujui -> Status lain
            // 2. Dalam kelompok status sama: waktu terbaru di atas
            bills.sort((a, b) {
              final prioA = _getResidentDuesPriority(a.status);
              final prioB = _getResidentDuesPriority(b.status);
              if (prioA != prioB) {
                return prioA.compareTo(prioB);
              }

              final timeA = _getRelevantDuesTimestamp(a);
              final timeB = _getRelevantDuesTimestamp(b);
              final timeCompare = timeB.compareTo(timeA);
              if (timeCompare != 0) {
                return timeCompare;
              }

              return b.billingPeriod.compareTo(a.billingPeriod);
            });

            final residentName = widget.user?.displayName ?? 'Warga';
            final defaultBlock = widget.user?.houseBlock ?? '';
            final defaultHouseNumber = widget.user?.houseNumber ?? '';

            residentActivities = bills.take(5).map((bill) {
              final double amount = (bill.payment != null && bill.payment!.amountPaid > 0)
                  ? bill.payment!.amountPaid
                  : bill.amount;
              final DateTime relevantDate = _getRelevantDuesTimestamp(bill);
              final String block = (bill.block != null && bill.block!.trim().isNotEmpty)
                  ? bill.block!
                  : defaultBlock;
              final String houseNumber = (bill.houseNumber != null && bill.houseNumber!.trim().isNotEmpty)
                  ? bill.houseNumber!
                  : defaultHouseNumber;

              return DashboardRecentActivityModel(
                id: bill.id,
                residentName: residentName,
                block: block,
                houseNumber: houseNumber,
                billingPeriod: bill.billingPeriod,
                amountPaid: amount,
                status: bill.status,
                createdAt: relevantDate,
              );
            }).toList();
          }
        } catch (_) {}
      }

      CashbookRepository? cashbookRepo;
      AnnouncementsRepository? announcementsRepo;
      try {
        cashbookRepo = context.read<CashbookRepository>();
      } catch (_) {}
      try {
        announcementsRepo = context.read<AnnouncementsRepository>();
      } catch (_) {}

      CashbookSummaryModel? cashSummary;
      List<AnnouncementModel> announcementsList = [];

      if (cashbookRepo != null) {
        try {
          cashSummary = await cashbookRepo.getCashbookSummary();
        } catch (_) {}
      }
      if (announcementsRepo != null) {
        try {
          announcementsList = await announcementsRepo.getAnnouncements();
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _statsData = data;
          _residentActivities = residentActivities;
          _unpaidBills = unpaidBills;
          _pendingBills = pendingBills;
          _rejectedBills = rejectedBills;
          _totalUnpaidAmount = totalUnpaidAmount;
          _cashbookSummary = cashSummary;
          _announcements = announcementsList;
          _isLoading = false;
        });
        widget.onUnpaidCountUpdated?.call(unpaidBills.length);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(amount);
  }

  String _formatDateTime(DateTime dt) {
    try {
      return DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(dt.toLocal());
    } catch (_) {
      return DateFormat('d/M/yyyy HH:mm').format(dt);
    }
  }

  String _formatBillingPeriod(String? period) {
    if (period == null || period.trim().isEmpty) return '';
    try {
      final parts = period.trim().split('-');
      if (parts.length == 2) {
        final year = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        if (year != null && month != null && month >= 1 && month <= 12) {
          const monthNames = [
            'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
            'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
          ];
          return '${monthNames[month - 1]} $year';
        }
      }
      final dt = DateTime.tryParse('$period-01');
      if (dt != null) {
        return DateFormat('MMMM yyyy', 'id_ID').format(dt);
      }
    } catch (_) {}
    return period.trim();
  }

  int _getResidentDuesPriority(String status) {
    switch (status.toLowerCase().trim()) {
      case 'unpaid':
        return 1;
      case 'pending_verification':
      case 'pending':
      case 'processing':
        return 2;
      case 'rejected':
        return 3;
      case 'paid':
      case 'approved':
        return 4;
      default:
        return 5;
    }
  }

  DateTime _getRelevantDuesTimestamp(BillModel bill) {
    if (bill.payment?.verifiedAtDateTime != null) {
      return bill.payment!.verifiedAtDateTime!;
    }
    if (bill.payment?.createdAt != null) {
      return bill.payment!.createdAt!;
    }
    if (bill.updatedAt.isAfter(bill.createdAt)) {
      return bill.updatedAt;
    }
    return bill.createdAt;
  }

  List<StatCardData> _buildStatCards(DashboardStatsModel data) {
    return _buildStatCardsForRole(widget.user, data);
  }

  List<StatCardData> _buildStatCardsForRole(UserModel? user, DashboardStatsModel data) {
    final pctCollected = data.targetAmount > 0
        ? ((data.collectedAmount / data.targetAmount) * 100).toInt()
        : 0;

    final role = user?.role.toUpperCase() ?? 'ADMIN';

    // 1. Card Perlu Ditindaklanjuti untuk Admin / Ketua / Wakil Ketua
    final totalPendingCombined = data.pendingPaymentsCount + data.pendingResidents;
    final String combinedPendingSub = totalPendingCombined == 0
        ? 'Tidak ada pekerjaan yang perlu ditindaklanjuti'
        : (data.pendingPaymentsCount > 0 && data.pendingResidents > 0)
            ? '${data.pendingPaymentsCount} Iuran, ${data.pendingResidents} Calon Warga'
            : data.pendingPaymentsCount > 0
                ? '${data.pendingPaymentsCount} Bukti transfer iuran menunggu persetujuan'
                : '${data.pendingResidents} Calon warga baru menunggu verifikasi';

    final statCardPerluDitindaklanjutiCombined = StatCardData(
      title: 'Perlu Ditindaklanjuti',
      value: totalPendingCombined > 0 ? '$totalPendingCombined Antrean' : 'Semua Tuntas',
      subtitle: combinedPendingSub,
      icon: Icons.assignment_late_outlined,
      color: totalPendingCombined > 0 ? const Color(0xFFF59E0B) : const Color(0xFF0F766E),
      trend: totalPendingCombined > 0 ? 'Perlu Review' : 'Tuntas',
      isPositive: totalPendingCombined == 0,
      onTap: () {
        if (data.pendingPaymentsCount > 0) {
          widget.onNavigate?.call('billing');
        } else if (data.pendingResidents > 0) {
          widget.onNavigate?.call('verification');
        }
      },
    );

    // 2. Card Perlu Ditindaklanjuti KHUSUS Bendahara (Keuangan saja)
    final statCardPerluDitindaklanjutiBendahara = StatCardData(
      title: 'Perlu Ditindaklanjuti',
      value: data.pendingPaymentsCount > 0
          ? '${data.pendingPaymentsCount} Transaksi'
          : 'Semua Tuntas',
      subtitle: data.pendingPaymentsCount > 0
          ? 'Bukti transfer iuran menunggu verifikasi'
          : 'Tidak ada pembayaran yang perlu ditindaklanjuti',
      icon: Icons.mark_email_unread_outlined,
      color: data.pendingPaymentsCount > 0 ? const Color(0xFFF59E0B) : const Color(0xFF0F766E),
      trend: data.pendingPaymentsCount > 0 ? 'Perlu Review' : 'Tuntas',
      isPositive: data.pendingPaymentsCount == 0,
      onTap: () => widget.onNavigate?.call('billing'),
    );

    // 3. Card Perlu Ditindaklanjuti KHUSUS Sekretaris (Administrasi warga saja)
    final statCardPerluDitindaklanjutiSekretaris = StatCardData(
      title: 'Perlu Ditindaklanjuti',
      value: data.pendingResidents > 0
          ? '${data.pendingResidents} Pendaftaran'
          : 'Semua Tuntas',
      subtitle: data.pendingResidents > 0
          ? 'Pendaftaran calon warga baru menunggu verifikasi'
          : 'Tidak ada pendaftaran yang perlu ditindaklanjuti',
      icon: Icons.how_to_reg_outlined,
      color: data.pendingResidents > 0 ? const Color(0xFFF59E0B) : const Color(0xFF0F766E),
      trend: data.pendingResidents > 0 ? 'Perlu Review' : 'Tuntas',
      isPositive: data.pendingResidents == 0,
      onTap: () => widget.onNavigate?.call('verification'),
    );

    // 4. Card Saldo Kas Transparan (Umum)
    final statCardKas = StatCardData(
      title: 'Saldo Kas Transparan',
      value: _cashbookSummary != null
          ? _formatCurrency(_cashbookSummary!.currentBalance)
          : _formatCurrency(data.collectedAmount),
      subtitle: _cashbookSummary != null
          ? 'Masuk: ${_formatCurrency(_cashbookSummary!.totalIncome)} • Keluar: ${_formatCurrency(_cashbookSummary!.totalExpense)}'
          : 'Target: ${_formatCurrency(data.targetAmount)}',
      icon: Icons.account_balance_wallet_outlined,
      color: AppTheme.primary,
      trend: 'Buku Kas',
      isPositive: true,
      onTap: () => widget.onNavigate?.call('cashbook'),
    );

    // 5. Card Total Hunian
    final statCardHunian = StatCardData(
      title: 'Total Hunian',
      value: '${data.totalHouses} Rumah',
      subtitle: '${data.occupiedHouses} Terisi, ${data.emptyHouses} Kosong',
      icon: Icons.home_work_outlined,
      color: Colors.blue,
      trend: '${data.occupiedHouses}/${data.totalHouses} Terisi',
      isPositive: true,
      onTap: (user?.canAccessHousesAdmin ?? false) ? () => widget.onNavigate?.call('houses') : null,
    );

    // 6. Card Warga Terdaftar
    final statCardWarga = StatCardData(
      title: 'Warga Terdaftar',
      value: '${data.totalResidents} Warga Aktif',
      subtitle: data.pendingResidents > 0
          ? '${data.pendingResidents} Menunggu Verifikasi'
          : 'Semua Terverifikasi',
      icon: Icons.people_outline,
      color: const Color(0xFF0F766E),
      trend: data.pendingResidents > 0 ? '${data.pendingResidents} Pending' : 'Terverifikasi',
      isPositive: data.pendingResidents == 0,
      onTap: (user?.canAccessHousesAdmin ?? false)
          ? () => widget.onNavigate?.call('houses')
          : (user?.canAccessVerificationAdmin ?? false)
              ? () => widget.onNavigate?.call('verification')
              : null,
    );

    // 7. Card Realisasi Iuran Bulan Berjalan (khusus Bendahara)
    final statCardRealisasiIuran = StatCardData(
      title: 'Iuran Periode Berjalan',
      value: _formatCurrency(data.collectedAmount),
      subtitle: 'Target: ${_formatCurrency(data.targetAmount)} (Realisasi: $pctCollected%)',
      icon: Icons.receipt_long_outlined,
      color: const Color(0xFF2563EB),
      trend: '$pctCollected%',
      isPositive: pctCollected >= 75,
      onTap: () => widget.onNavigate?.call('billing'),
    );

    // 8. Card Pengumuman Warga (khusus Bendahara)
    final statCardPengumuman = StatCardData(
      title: 'Pengumuman Warga',
      value: '${_announcements.length} Informasi',
      subtitle: _announcements.isNotEmpty ? _announcements.first.title : 'Belum ada pengumuman baru',
      icon: Icons.campaign_outlined,
      color: const Color(0xFF0F766E),
      trend: 'Terkini',
      isPositive: true,
      onTap: () => widget.onNavigate?.call('announcements'),
    );

    switch (role) {
      case 'CHAIRPERSON':
        return [
          statCardKas,
          statCardPerluDitindaklanjutiCombined,
          statCardHunian,
          statCardWarga,
        ];

      case 'VICE_CHAIRPERSON':
        return [
          statCardHunian,
          statCardWarga,
          statCardPerluDitindaklanjutiCombined,
          statCardKas,
        ];

      case 'TREASURER':
        return [
          statCardKas,
          statCardPerluDitindaklanjutiBendahara,
          statCardRealisasiIuran,
          statCardPengumuman,
        ];

      case 'SECRETARY':
        return [
          statCardPerluDitindaklanjutiSekretaris,
          statCardWarga,
          statCardHunian,
          statCardKas,
        ];

      case 'ADMIN':
      default:
        return [
          statCardPerluDitindaklanjutiCombined,
          statCardKas,
          statCardHunian,
          statCardWarga,
        ];
    }
  }

  Widget _buildResidentAttentionBanner() {
    // 1. Tagihan iuran belum dibayar (Prioritas 1)
    if (_unpaidBills.isNotEmpty) {
      return Container(
        key: const Key('resident_unpaid_banner'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.danger.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ada ${_unpaidBills.length} iuran yang belum dibayar.',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF991B1B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Total kewajiban yang perlu diselesaikan: ${_formatCurrency(_totalUnpaidAmount)}.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7F1D1D),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              key: const Key('resident_banner_action_unpaid'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.danger,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => widget.onNavigate?.call('resident_billing'),
              child: const Text('Lihat Tagihan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    // 2. Pembayaran ditolak (Prioritas 2)
    if (_rejectedBills.isNotEmpty) {
      return Container(
        key: const Key('resident_rejected_banner'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFFCCD3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade700.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cancel_outlined, color: Colors.red.shade700, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pembayaran Anda ditolak. Periksa detail dan tindak lanjuti.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF9F1239),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Terdapat ${_rejectedBills.length} pembayaran memerlukan unggah ulang bukti transfer yang valid.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF881337),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              key: const Key('resident_banner_action_rejected'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBE123C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => widget.onNavigate?.call('resident_billing'),
              child: const Text('Periksa Detail', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    // 3. Pembayaran menunggu verifikasi (Prioritas 3)
    if (_pendingBills.isNotEmpty) {
      return Container(
        key: const Key('resident_pending_banner'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFD97706).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pembayaran Anda sedang menunggu verifikasi.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF92400E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_pendingBills.length} pembayaran iuran sedang dalam proses verifikasi oleh pengurus.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF78350F),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              key: const Key('resident_banner_action_pending'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFD97706)),
                foregroundColor: const Color(0xFF92400E),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => widget.onNavigate?.call('resident_billing'),
              child: const Text('Lihat Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    // 4. Pengumuman penting (Prioritas 4)
    final urgentAnnouncement = _announcements.cast<AnnouncementModel?>().firstWhere(
          (a) => a != null && (a.isUrgent || a.isImportant),
          orElse: () => null,
        );

    if (urgentAnnouncement != null) {
      return Container(
        key: const Key('resident_announcement_banner'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFCD34D)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryDark.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.campaign_rounded, color: AppTheme.primaryDark, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    urgentAnnouncement.isUrgent ? 'Pengumuman Darurat' : 'Pengumuman Penting Lingkungan',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF92400E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    urgentAnnouncement.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF78350F),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              key: const Key('resident_banner_action_announcement'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AnnouncementDetailDialog(announcement: urgentAnnouncement),
                );
              },
              child: const Text('Baca Pengumuman', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    // 5. Kondisi normal ringkas
    return Container(
      key: const Key('resident_normal_banner'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF16A34A), size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Status Iuran Tertib: Seluruh kewajiban iuran lingkungan Anda telah diselesaikan.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF166534)),
            ),
          ),
          if (widget.onNavigate != null)
            TextButton(
              onPressed: () => widget.onNavigate?.call('resident_billing'),
              child: const Text('Riwayat Iuran', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
            ),
        ],
      ),
    );
  }

  Widget _buildResidentDuesSummaryCard() {
    return Container(
      key: const Key('resident_dues_summary_card'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.account_balance_rounded, size: 18, color: AppTheme.primary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ringkasan Iuran Saya',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.onNavigate != null) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => widget.onNavigate?.call('resident_billing'),
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Detail Iuran', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryDark)),
                        SizedBox(width: 2),
                        Icon(Icons.arrow_forward_rounded, size: 14, color: AppTheme.primaryDark),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 600;
              final items = [
                _buildDuesSummaryItem(
                  key: const Key('resident_summary_unpaid'),
                  title: 'Belum Dibayar',
                  count: '${_unpaidBills.length} Tagihan',
                  subtitle: _unpaidBills.isNotEmpty
                      ? 'Total: ${_formatCurrency(_totalUnpaidAmount)}'
                      : 'Rp 0',
                  icon: Icons.pending_actions_rounded,
                  color: _unpaidBills.isNotEmpty ? AppTheme.danger : const Color(0xFF0F766E),
                  badge: _unpaidBills.isNotEmpty ? 'Perlu Bayar' : 'Lunas',
                  isPositive: _unpaidBills.isEmpty,
                  onTap: () => widget.onNavigate?.call('resident_billing'),
                ),
                _buildDuesSummaryItem(
                  key: const Key('resident_summary_pending'),
                  title: 'Menunggu Verifikasi',
                  count: '${_pendingBills.length} Pembayaran',
                  subtitle: _pendingBills.isNotEmpty
                      ? 'Dalam proses verifikasi pengurus'
                      : 'Tidak ada antrean',
                  icon: Icons.hourglass_top_rounded,
                  color: const Color(0xFFF59E0B),
                  badge: _pendingBills.isNotEmpty ? 'Diproses' : 'Nihil',
                  isPositive: true,
                  onTap: () => widget.onNavigate?.call('resident_billing'),
                ),
                _buildDuesSummaryItem(
                  key: const Key('resident_summary_rejected'),
                  title: 'Ditolak',
                  count: '${_rejectedBills.length} Pembayaran',
                  subtitle: _rejectedBills.isNotEmpty
                      ? 'Memerlukan tindak lanjut warga'
                      : 'Tidak ada ditolak',
                  icon: Icons.highlight_off_rounded,
                  color: _rejectedBills.isNotEmpty ? AppTheme.danger : Colors.grey.shade600,
                  badge: _rejectedBills.isNotEmpty ? 'Tindak Lanjut' : 'Nihil',
                  isPositive: _rejectedBills.isEmpty,
                  onTap: () => widget.onNavigate?.call('resident_billing'),
                ),
              ];

              if (isWide) {
                return Row(
                  children: [
                    Expanded(child: items[0]),
                    const SizedBox(width: 12),
                    Expanded(child: items[1]),
                    const SizedBox(width: 12),
                    Expanded(child: items[2]),
                  ],
                );
              }
              return Column(
                children: [
                  items[0],
                  const SizedBox(height: 10),
                  items[1],
                  const SizedBox(height: 10),
                  items[2],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDuesSummaryItem({
    Key? key,
    required String title,
    required String count,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String badge,
    required bool isPositive,
    required VoidCallback onTap,
  }) {
    return Material(
      key: key,
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icon, color: color, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (isPositive ? AppTheme.primary : AppTheme.danger).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isPositive ? AppTheme.primaryDark : AppTheme.danger,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                count,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userName = widget.user?.displayName ?? 'Pengguna';
    final userRole = widget.user?.roleDisplay ?? 'Warga';
    final isResident = !(widget.user?.hasAdminAccess ?? false);

    return SingleChildScrollView(
      padding: EdgeInsets.all(widget.isDesktop ? 24 : 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Banner
              _buildWelcomeBanner(userName, userRole),
              const SizedBox(height: 18),

              // Dynamic Attention Banner untuk Warga (Requirement 2.A)
              if (isResident) ...[
                _buildResidentAttentionBanner(),
                const SizedBox(height: 16),
                _buildResidentDuesSummaryCard(),
                const SizedBox(height: 24),
              ],

              // Ringkasan Statistik Heading
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Ringkasan Lingkungan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _isLoading ? null : _fetchDashboardStats,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(
                      _isLoading ? 'Memperbarui...' : 'Perbarui Data',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Error State Banner jika gagal
              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppTheme.danger),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppTheme.danger, fontSize: 13),
                        ),
                      ),
                      TextButton(
                        onPressed: _fetchDashboardStats,
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                ),

              // Loading State vs Grid Stat Cards
              if (_isLoading && _statsData == null && _residentActivities.isEmpty && _cashbookSummary == null && _announcements.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_statsData != null)
                _buildStatCardsGrid(_statsData!)
              else
                _buildResidentStatCardsGrid(),

              const SizedBox(height: 28),

              // Desktop Multi-Column: Aktivitas Terkini & Papan Pengumuman
              if (widget.isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: _buildRecentActivityTable(_statsData)),
                    const SizedBox(width: 20),
                    Expanded(flex: 4, child: _buildAnnouncementsCard()),
                  ],
                )
              else
                Column(
                  children: [
                    _buildRecentActivityTable(_statsData),
                    const SizedBox(height: 20),
                    _buildAnnouncementsCard(),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCardsGrid(DashboardStatsModel data) {
    final cardList = _buildStatCards(data);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int crossAxisCount = 1;
        double childAspectRatio = 2.4;

        if (width >= 1100) {
          crossAxisCount = 4;
          childAspectRatio = 1.35;
        } else if (width >= 700) {
          crossAxisCount = 2;
          childAspectRatio = 1.8;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cardList.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (context, i) => StatCard(data: cardList[i]),
        );
      },
    );
  }

  List<StatCardData> _buildResidentStatCards() {
    return [
      StatCardData(
        title: 'Saldo Kas Transparan',
        value: _cashbookSummary != null
            ? _formatCurrency(_cashbookSummary!.currentBalance)
            : 'Tersedia',
        subtitle: _cashbookSummary != null
            ? 'Masuk: ${_formatCurrency(_cashbookSummary!.totalIncome)}'
            : 'Transparansi kas terbuka untuk seluruh warga',
        icon: Icons.account_balance_wallet_outlined,
        color: AppTheme.primary,
        trend: 'Kas Warga',
        isPositive: true,
        onTap: () => widget.onNavigate?.call('cashbook'),
      ),
      StatCardData(
        title: 'Pengumuman Warga',
        value: '${_announcements.length} Informasi',
        subtitle: _announcements.isNotEmpty ? _announcements.first.title : 'Belum ada pengumuman baru',
        icon: Icons.campaign_outlined,
        color: const Color(0xFF0F766E),
        trend: 'Terkini',
        isPositive: true,
        onTap: () => widget.onNavigate?.call('announcements'),
      ),
      StatCardData(
        title: 'Unit Hunian Saya',
        value: widget.user?.houseDisplay ?? 'Belum Terdaftar',
        subtitle: widget.user?.canAccessResidentIuran ?? false
            ? 'Terdaftar & Siap Bayar Iuran'
            : 'Belum ditautkan ke unit rumah',
        icon: Icons.home_work_outlined,
        color: Colors.blue,
        trend: widget.user?.canAccessResidentIuran ?? false ? 'Terverifikasi' : 'Belum Terdaftar',
        isPositive: widget.user?.canAccessResidentIuran ?? false,
        onTap: () => widget.onNavigate?.call('profile'),
      ),
      StatCardData(
        title: 'Siaga Keamanan',
        value: 'Pos Satpam & Panic',
        subtitle: 'Siaga 24 jam dalam kondisi darurat',
        icon: Icons.shield_outlined,
        color: const Color(0xFFF59E0B),
        trend: 'Siaga 24/7',
        isPositive: true,
        onTap: () => widget.onNavigate?.call('panic'),
      ),
    ];
  }

  Widget _buildResidentStatCardsGrid() {
    final cardList = _buildResidentStatCards();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int crossAxisCount = 1;
        double childAspectRatio = 2.4;

        if (width >= 1100) {
          crossAxisCount = 4;
          childAspectRatio = 1.35;
        } else if (width >= 700) {
          crossAxisCount = 2;
          childAspectRatio = 1.8;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cardList.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (context, i) => StatCard(data: cardList[i]),
        );
      },
    );
  }

  Widget _buildWelcomeBanner(String userName, String userRole) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF10B981)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.2),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Selamat Datang, $userName 👋',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        userRole,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '"Tetangga Kompak, Lingkungan Terjaga" — Pantau kebersihan, transparansi buku kas, dan siaga keamanan lingkungan cluster dari portal resmi.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityTable([DashboardStatsModel? data]) {
    final activities = (widget.user?.hasAdminAccess ?? false)
        ? (data?.recentActivities ?? _statsData?.recentActivities ?? [])
        : _residentActivities;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Aktivitas Pembayaran Iuran Terkini',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              if (activities.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${activities.length} Transaksi Terkini',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (activities.isEmpty)
            _isLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 36),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 40,
                    color: AppTheme.textSecondary,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Belum ada aktivitas pembayaran iuran baru-baru ini.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activities.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, i) {
                final item = activities[i];
                final isLunas = item.status == 'paid';
                final isPending = item.status == 'pending_verification';

                String statusText;
                Color statusColor;
                if (isLunas) {
                  statusText = 'Lunas';
                  statusColor = AppTheme.primary;
                } else if (isPending) {
                  statusText = 'Menunggu Verifikasi';
                  statusColor = const Color(0xFFF59E0B);
                } else if (item.status == 'rejected') {
                  statusText = 'Ditolak';
                  statusColor = AppTheme.danger;
                } else {
                  statusText = 'Belum Bayar';
                  statusColor = AppTheme.textSecondary;
                }

                final initial = item.residentName.trim().isNotEmpty
                    ? item.residentName.trim()[0].toUpperCase()
                    : 'W';
                final formattedPeriod = _formatBillingPeriod(item.billingPeriod);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: statusColor.withOpacity(0.12),
                        child: Text(
                          initial,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.residentName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            if (formattedPeriod.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Periode: $formattedPeriod',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryDark,
                                ),
                              ),
                            ],
                            const SizedBox(height: 2),
                            Text(
                              'Blok ${item.block} No. ${item.houseNumber} • ${_formatDateTime(item.createdAt)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatCurrency(item.amountPaid),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 3),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementsCard() {
    final topAnnouncements = _announcements.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Papan Pengumuman Warga',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              if (topAnnouncements.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${topAnnouncements.length} Pengumuman',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
                  ),
                )
              else
                const Icon(Icons.campaign_rounded, color: AppTheme.primary, size: 20),
            ],
          ),
          const SizedBox(height: 14),
          if (topAnnouncements.isEmpty)
            _isLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.campaign_outlined,
                    size: 36,
                    color: AppTheme.textSecondary,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Belum ada pengumuman resmi yang dipublikasikan.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topAnnouncements.length,
              separatorBuilder: (_, __) => const Divider(height: 16, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, idx) {
                final a = topAnnouncements[idx];
                Color badgeColor;
                if (a.isUrgent) {
                  badgeColor = AppTheme.danger;
                } else if (a.isImportant) {
                  badgeColor = const Color(0xFFF59E0B);
                } else {
                  badgeColor = AppTheme.primary;
                }

                return InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AnnouncementDetailDialog(announcement: a),
                    );
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: a.isPinned ? AppTheme.danger.withOpacity(0.3) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (a.isPinned) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.danger.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.push_pin_rounded, size: 10, color: AppTheme.danger),
                                    SizedBox(width: 2),
                                    Text('PIN', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.danger)),
                                  ],
                                ),
                              ),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: badgeColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                a.categoryDisplay,
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: badgeColor),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _formatDateTime(a.createdAt),
                              style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          a.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          a.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
