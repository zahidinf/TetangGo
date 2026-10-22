import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../announcements/data/announcements_repository.dart';
import '../../../announcements/domain/models/announcement_model.dart';
import '../../../announcements/presentation/widgets/announcement_detail_dialog.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../cashbook/data/cashbook_repository.dart';
import '../../../cashbook/domain/models/cashbook_models.dart';
import '../../data/dashboard_repository.dart';
import '../../domain/models/dashboard_stats_model.dart';
import 'stat_card.dart';

class DashboardContentBody extends StatefulWidget {
  final UserModel? user;
  final bool isDesktop;

  const DashboardContentBody({
    super.key,
    required this.user,
    required this.isDesktop,
  });

  @override
  State<DashboardContentBody> createState() => _DashboardContentBodyState();
}

class _DashboardContentBodyState extends State<DashboardContentBody> {
  bool _isLoading = false;
  String? _errorMessage;
  DashboardStatsModel? _statsData;
  CashbookSummaryModel? _cashbookSummary;
  List<AnnouncementModel> _announcements = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboardStats();
  }

  Future<void> _fetchDashboardStats() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final canAccessStats = widget.user?.canAccessLeadership ?? false;
      DashboardStatsModel? data;
      if (canAccessStats) {
        try {
          final repository = context.read<DashboardRepository>();
          data = await repository.getAdminDashboardStats();
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
          _cashbookSummary = cashSummary;
          _announcements = announcementsList;
          _isLoading = false;
        });
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

  List<StatCardData> _buildStatCards(DashboardStatsModel data) {
    final pctCollected = data.targetAmount > 0
        ? ((data.collectedAmount / data.targetAmount) * 100).toInt()
        : 0;

    return [
      // Kartu 1: Total Hunian
      StatCardData(
        title: 'Total Hunian',
        value: '${data.totalHouses} Rumah',
        subtitle: '${data.occupiedHouses} Terisi, ${data.emptyHouses} Kosong',
        icon: Icons.home_work_outlined,
        color: Colors.blue,
        trend: '${data.occupiedHouses}/${data.totalHouses} Terisi',
        isPositive: true,
      ),
      // Kartu 2: Warga Terdaftar
      StatCardData(
        title: 'Warga Terdaftar',
        value: '${data.totalResidents} Warga Aktif',
        subtitle: data.pendingResidents > 0
            ? '${data.pendingResidents} Menunggu Verifikasi'
            : 'Semua Terverifikasi',
        icon: Icons.people_outline,
        color: const Color(0xFF0F766E),
        trend: data.pendingResidents > 0 ? '${data.pendingResidents} Pending' : 'Terverifikasi',
        isPositive: data.pendingResidents == 0,
      ),
      // Kartu 3: Saldo Kas Transparan RT
      StatCardData(
        title: 'Saldo Kas Transparan RT',
        value: _cashbookSummary != null
            ? _formatCurrency(_cashbookSummary!.currentBalance)
            : _formatCurrency(data.collectedAmount),
        subtitle: _cashbookSummary != null
            ? 'Masuk: ${_formatCurrency(_cashbookSummary!.totalIncome)} | Keluar: ${_formatCurrency(_cashbookSummary!.totalExpense)}'
            : 'Target: ${_formatCurrency(data.targetAmount)}',
        icon: Icons.account_balance_wallet_outlined,
        color: AppTheme.primary,
        trend: _cashbookSummary != null ? 'Kas RT' : '$pctCollected%',
        isPositive: true,
      ),
      // Kartu 4: Verifikasi Pembayaran
      StatCardData(
        title: 'Perlu Ditinjau',
        value: '${data.pendingPaymentsCount} Transaksi',
        subtitle: 'Bukti transfer menunggu persetujuan',
        icon: Icons.mark_email_unread_outlined,
        color: const Color(0xFFF59E0B),
        trend: data.pendingPaymentsCount > 0 ? 'Perlu Review' : 'Tuntas',
        isPositive: data.pendingPaymentsCount == 0,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final userName = widget.user?.displayName ?? 'Pengguna';
    final userRole = widget.user?.roleDisplay ?? 'Warga';

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
              const SizedBox(height: 24),

              // Ringkasan Statistik Heading
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Ringkasan Lingkungan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
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
              if (_isLoading && _statsData == null && _cashbookSummary == null && _announcements.isEmpty)
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
        title: 'Saldo Kas Transparan RT',
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
      ),
      StatCardData(
        title: 'Pengumuman RT',
        value: '${_announcements.length} Informasi',
        subtitle: _announcements.isNotEmpty ? _announcements.first.title : 'Belum ada pengumuman baru',
        icon: Icons.campaign_outlined,
        color: const Color(0xFF0F766E),
        trend: 'Terkini',
        isPositive: true,
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
      ),
      const StatCardData(
        title: 'Siaga Keamanan',
        value: 'Pos Satpam & Panic',
        subtitle: 'Siaga 24 jam dalam kondisi darurat',
        icon: Icons.shield_outlined,
        color: Color(0xFFF59E0B),
        trend: 'Siaga 24/7',
        isPositive: true,
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

  Widget _buildRecentActivityTable(DashboardStatsModel? data) {
    final activities = data?.recentActivities ?? [];

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
            Container(
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
            Container(
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
