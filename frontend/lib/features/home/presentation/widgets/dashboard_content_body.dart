import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/domain/models/user_model.dart';
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

  @override
  void initState() {
    super.initState();
    _fetchDashboardStats();
  }

  Future<void> _fetchDashboardStats() async {
    // Hanya Admin RT yang memiliki akses ke endpoint /api/v1/admin/dashboard/stats
    final isAdmin = widget.user?.role == 'admin_rt';
    if (!isAdmin) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repository = context.read<DashboardRepository>();
      final data = await repository.getAdminDashboardStats();
      if (mounted) {
        setState(() {
          _statsData = data;
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
      // Kartu 3: Iuran Terkumpul Bulan Ini
      StatCardData(
        title: 'Iuran Terkumpul (${data.currentPeriod})',
        value: _formatCurrency(data.collectedAmount),
        subtitle: 'Target: ${_formatCurrency(data.targetAmount)}',
        icon: Icons.payments_outlined,
        color: AppTheme.primary,
        trend: '$pctCollected%',
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
    final userName = widget.user?.name ?? 'Pengurus RT';
    final userRole = widget.user?.roleDisplay ?? 'Admin RT';

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
              if (_isLoading && _statsData == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_statsData != null)
                _buildStatCardsGrid(_statsData!),

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
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Papan Pengumuman Warga',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.campaign_rounded, color: AppTheme.primary, size: 20),
            ],
          ),
          const SizedBox(height: 14),
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
                  'Belum ada pengumuman resmi yang dipublikasikan (Modul Pengumuman Aktif di Sprint 3).',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
