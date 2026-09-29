import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../auth/domain/models/user_model.dart';
import '../../auth/presentation/bloc/auth_bloc.dart';
import '../../auth/presentation/bloc/auth_event.dart';
import '../../auth/presentation/bloc/auth_state.dart';
import '../../admin_billing/presentation/admin_billing_view.dart';
import '../../billing/data/billing_repository.dart';
import '../../billing/presentation/resident_billing_screen.dart';
import '../../profile/presentation/resident_profile_screen.dart';
import '../../resident_management/data/resident_repository.dart';
import '../../resident_management/presentation/houses_management_view.dart';
import '../../resident_management/presentation/resident_verification_view.dart';
import 'widgets/dashboard_content_body.dart';
import 'widgets/dashboard_sidebar.dart';
import 'widgets/dashboard_top_header.dart';

class AdaptiveDashboardScreen extends StatefulWidget {
  const AdaptiveDashboardScreen({super.key});

  @override
  State<AdaptiveDashboardScreen> createState() => _AdaptiveDashboardScreenState();
}

class _AdaptiveDashboardScreenState extends State<AdaptiveDashboardScreen> {
  int _selectedMenuIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _pendingCount = 0;
  int _pendingBillsCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchPendingCount();
  }

  Future<void> _fetchPendingCount() async {
    final user = context.read<AuthBloc>().state.user;
    if (user != null && user.role == 'admin_rt') {
      try {
        final residentRepo = context.read<ResidentRepository>();
        final billingRepo = context.read<BillingRepository>();

        final results = await Future.wait([
          residentRepo.getPendingUsers(),
          billingRepo.getPendingPayments(),
        ]);

        if (mounted) {
          final users = results[0] as List;
          final bills = results[1] as List;
          setState(() {
            _pendingCount = users.length;
            _pendingBillsCount = bills.length;
          });
        }
      } catch (_) {}
    }
  }

  String _currentMenuTitle(UserModel? user) {
    final isAdmin = user?.role == 'admin_rt';
    if (isAdmin) {
      switch (_selectedMenuIndex) {
        case 0:
          return 'Ringkasan Lingkungan';
        case 1:
          return 'Verifikasi Warga Baru';
        case 2:
          return 'Master Data Hunian & Warga';
        case 3:
          return 'Profil Pengurus RT';
        case 4:
          return 'Iuran & Tagihan';
        case 5:
          return 'Kas Transparan RT';
        case 6:
          return 'Pengumuman Resmi RT';
        case 7:
          return 'Panic Alert Siaga';
        case 8:
          return 'Buku Tamu Pos Satpam';
        default:
          return 'Dashboard Admin';
      }
    } else {
      switch (_selectedMenuIndex) {
        case 0:
          return 'Beranda Warga';
        case 1:
          return 'Profil Hunian & Keluarga';
        case 2:
          return 'Iuran Warga';
        case 3:
          return 'Pengumuman RT';
        case 4:
          return 'Panic Button';
        default:
          return 'Portal Warga';
      }
    }
  }

  void _onLogoutPressed() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Konfirmasi Keluar', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Apakah Anda yakin ingin keluar dari portal TetangGo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              context.read<AuthBloc>().add(AuthLogoutRequested());
            },
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(UserModel? user, bool isDesktop) {
    final isAdmin = user?.role == 'admin_rt';

    if (isAdmin) {
      switch (_selectedMenuIndex) {
        case 0:
          return DashboardContentBody(user: user, isDesktop: isDesktop);
        case 1:
          return ResidentVerificationView(onQueueUpdated: _fetchPendingCount);
        case 2:
          return const HousesManagementView();
        case 3:
          return const ResidentProfileScreen();
        case 4:
          return AdminBillingView(onPendingCountUpdated: _fetchPendingCount);
        default:
          return _buildFeaturePlaceholder(_currentMenuTitle(user));
      }
    } else {
      switch (_selectedMenuIndex) {
        case 0:
          return DashboardContentBody(user: user, isDesktop: isDesktop);
        case 1:
          return const ResidentProfileScreen();
        case 2:
          return const ResidentBillingScreen();
        default:
          return _buildFeaturePlaceholder(_currentMenuTitle(user));
      }
    }
  }

  Widget _buildFeaturePlaceholder(String title) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction_rounded, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Modul $title',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Fitur ini sedang dalam jadwal pengerjaan Sprint berikutnya.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final user = state.user;

        return Responsive(
          mobile: _buildMobileScaffold(user),
          tablet: _buildDesktopScaffold(user, isTablet: true),
          desktop: _buildDesktopScaffold(user, isTablet: false),
        );
      },
    );
  }

  // --- MOBILE LAYOUT (< 768px) ---
  Widget _buildMobileScaffold(UserModel? user) {
    final isAdmin = user?.role == 'admin_rt';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.holiday_village_rounded, color: AppTheme.primary, size: 24),
            const SizedBox(width: 8),
            Text(
              _currentMenuTitle(user),
              style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textPrimary, fontSize: 16),
            ),
          ],
        ),
        actions: [
          if (isAdmin && _pendingCount > 0)
            IconButton(
              icon: Badge(
                label: Text('$_pendingCount'),
                child: const Icon(Icons.how_to_reg_rounded, color: AppTheme.primary),
              ),
              onPressed: () => setState(() => _selectedMenuIndex = 1),
            ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppTheme.danger),
            onPressed: _onLogoutPressed,
          ),
        ],
      ),
      drawer: Drawer(
        child: DashboardSidebar(
          selectedIndex: _selectedMenuIndex,
          onItemSelected: (index) {
            setState(() => _selectedMenuIndex = index);
            Navigator.pop(context);
          },
          user: user,
          pendingCount: _pendingCount,
          pendingBillsCount: _pendingBillsCount,
          onLogout: _onLogoutPressed,
        ),
      ),
      body: _buildContent(user, false),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedMenuIndex > 3 ? 0 : _selectedMenuIndex,
        selectedItemColor: AppTheme.primaryDark,
        unselectedItemColor: AppTheme.textSecondary,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == 3) {
            _scaffoldKey.currentState?.openDrawer();
          } else {
            setState(() => _selectedMenuIndex = index);
          }
        },
        items: isAdmin
            ? const [
                BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Beranda'),
                BottomNavigationBarItem(icon: Icon(Icons.how_to_reg_rounded), label: 'Verifikasi'),
                BottomNavigationBarItem(icon: Icon(Icons.home_work_rounded), label: 'Hunian'),
                BottomNavigationBarItem(icon: Icon(Icons.menu_rounded), label: 'Menu Lain'),
              ]
            : const [
                BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Beranda'),
                BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profil Saya'),
                BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'Iuran'),
                BottomNavigationBarItem(icon: Icon(Icons.menu_rounded), label: 'Menu Lain'),
              ],
      ),
    );
  }

  // --- DESKTOP & TABLET LAYOUT (>= 768px & >= 1024px) ---
  Widget _buildDesktopScaffold(UserModel? user, {required bool isTablet}) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Row(
        children: [
          // Persistent Left Sidebar
          DashboardSidebar(
            selectedIndex: _selectedMenuIndex,
            onItemSelected: (index) => setState(() => _selectedMenuIndex = index),
            user: user,
            pendingCount: _pendingCount,
            pendingBillsCount: _pendingBillsCount,
            onLogout: _onLogoutPressed,
          ),
          // Main Body with Top Header Bar
          Expanded(
            child: Column(
              children: [
                DashboardTopHeader(
                  user: user,
                  activeMenuTitle: _currentMenuTitle(user),
                ),
                Expanded(
                  child: _buildContent(user, true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
