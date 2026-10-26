import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../auth/domain/models/user_model.dart';
import '../../auth/presentation/bloc/auth_bloc.dart';
import '../../auth/presentation/bloc/auth_event.dart';
import '../../auth/presentation/bloc/auth_state.dart';
import '../../admin_billing/presentation/admin_billing_view.dart';
import '../../announcements/presentation/announcements_screen.dart';
import '../../billing/data/billing_repository.dart';
import '../../billing/domain/models/billing_models.dart';
import '../../billing/presentation/resident_billing_screen.dart';
import '../../cashbook/presentation/cashbook_screen.dart';
import '../../profile/presentation/resident_profile_screen.dart';
import '../../panic/presentation/emergency_monitoring_screen.dart';
import '../../panic/presentation/widgets/panic_button_fab.dart';
import '../../invitation/data/repositories/invitation_repository.dart';
import '../../invitation/presentation/bloc/invitation_bloc.dart';
import '../../invitation/presentation/screens/resident_invitations_screen.dart';
import '../../invitation/presentation/screens/security_guestbook_screen.dart';
import '../../resident_management/data/resident_repository.dart';
import '../../resident_management/presentation/houses_management_view.dart';
import '../../resident_management/presentation/resident_verification_view.dart';
import '../../security/data/security_repository.dart';
import '../../security/presentation/security_management_view.dart';
import 'widgets/about_tetanggo_dialog.dart';
import 'widgets/dashboard_content_body.dart';
import 'widgets/dashboard_sidebar.dart';

class AdaptiveDashboardScreen extends StatefulWidget {
  const AdaptiveDashboardScreen({super.key});

  @override
  State<AdaptiveDashboardScreen> createState() =>
      _AdaptiveDashboardScreenState();
}

class _AdaptiveDashboardScreenState extends State<AdaptiveDashboardScreen> {
  int _selectedMenuIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<AdminBillingViewState> _adminBillingKey =
      GlobalKey<AdminBillingViewState>();
  final Set<String> _visitedTabKeys = {'dashboard'};
  int _pendingCount = 0;
  int _pendingBillsCount = 0;
  int _residentUnpaidBillsCount = 0;
  int? _activeIncidentsCount;
  Timer? _incidentCountTimer;

  @override
  void initState() {
    super.initState();
    _fetchPendingCount(skipResidentBills: true);
    _startIncidentCountPolling();
  }

  void _startIncidentCountPolling() {
    _incidentCountTimer?.cancel();
    _incidentCountTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _fetchActiveIncidentsCount();
    });
  }

  Future<void> _fetchActiveIncidentsCount() async {
    if (!mounted) return;
    final user = context.read<AuthBloc>().state.user;
    if (user == null) return;
    try {
      final securityRepo = context.read<SecurityRepository>();
      final activeCount = await securityRepo.getActiveIncidentCount();
      if (mounted && _activeIncidentsCount != activeCount) {
        setState(() {
          _activeIncidentsCount = activeCount;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _incidentCountTimer?.cancel();
    _incidentCountTimer = null;
    super.dispose();
  }

  Future<void> _fetchPendingCount({bool skipResidentBills = false}) async {
    final user = context.read<AuthBloc>().state.user;
    if (user != null) {
      try {
        final residentRepo = context.read<ResidentRepository>();
        final billingRepo = context.read<BillingRepository>();
        final securityRepo = context.read<SecurityRepository>();

        final futures = <Future<dynamic>>[];
        if (user.hasAdminAccess && user.canAccessVerificationAdmin) {
          futures.add(residentRepo.getPendingUsers());
        } else {
          futures.add(Future.value(<dynamic>[]));
        }

        if (user.hasAdminAccess && user.canAccessBillingAdmin) {
          futures.add(billingRepo.getPendingPayments());
        } else {
          futures.add(Future.value(<dynamic>[]));
        }

        if (user.canAccessResidentIuran && !skipResidentBills) {
          futures.add(billingRepo.getResidentBills());
        } else {
          futures.add(Future.value(<BillModel>[]));
        }

        futures.add(securityRepo.getActiveIncidentCount());

        final results = await Future.wait(futures);

        if (mounted) {
          final users = results[0] as List;
          final bills = results[1] as List;
          final residentBills = results[2] as List;
          final activeCount = results[3] as int?;
          final unpaidCount =
              residentBills.where((b) => b is BillModel && b.isUnpaid).length;

          setState(() {
            _pendingCount = users.length;
            _pendingBillsCount = bills.length;
            if (activeCount != null) {
              _activeIncidentsCount = activeCount;
            }
            if (!skipResidentBills) {
              _residentUnpaidBillsCount = unpaidCount;
            }
          });
        }
      } catch (_) {}
    }
  }

  SidebarItemData _getActiveItem(List<SidebarItemData> items) {
    if (items.isEmpty) {
      return const SidebarItemData(
        keyId: 'dashboard',
        title: 'TetangGo',
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard_rounded,
        index: 0,
      );
    }
    if (_selectedMenuIndex >= 0 && _selectedMenuIndex < items.length) {
      return items[_selectedMenuIndex];
    }
    return items[0];
  }

  void _navigateToKey(String key, List<SidebarItemData> items) {
    if (key == 'resident_billing' &&
        !items.any((it) => it.keyId == 'resident_billing') &&
        items.any((it) => it.keyId == 'billing')) {
      final billingIdx = items.indexWhere((it) => it.keyId == 'billing');
      setState(() {
        _selectedMenuIndex = billingIdx;
        _visitedTabKeys.add('billing');
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _adminBillingKey.currentState?.switchToResidentBillingTab();
      });
      return;
    }

    final idx = items.indexWhere((it) => it.keyId == key);
    if (idx != -1) {
      setState(() {
        _selectedMenuIndex = idx;
        _visitedTabKeys.add(key);
      });
    }
  }

  void _onLogoutPressed() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Konfirmasi Keluar',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content:
            const Text('Apakah Anda yakin ingin keluar dari portal TetangGo?'),
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

  Widget _buildContent(
      UserModel? user, List<SidebarItemData> items, bool isDesktop) {
    final activeItem = _getActiveItem(items);
    _visitedTabKeys.add(activeItem.keyId);

    final currentIndex = items.indexWhere((it) => it.keyId == activeItem.keyId);
    final clampedIndex =
        (currentIndex >= 0 && currentIndex < items.length) ? currentIndex : 0;

    return IndexedStack(
      index: clampedIndex,
      children: [
        for (int i = 0; i < items.length; i++)
          _visitedTabKeys.contains(items[i].keyId)
              ? KeyedSubtree(
                  key: ValueKey(items[i].keyId),
                  child:
                      _buildTabWidget(items[i].keyId, user, items, isDesktop),
                )
              : const SizedBox.shrink(),
      ],
    );
  }

  Widget _buildTabWidget(String key, UserModel? user,
      List<SidebarItemData> items, bool isDesktop) {
    switch (key) {
      case 'dashboard':
        return DashboardContentBody(
          user: user,
          isDesktop: isDesktop,
          onNavigate: (targetKey) => _navigateToKey(targetKey, items),
          onUnpaidCountUpdated: (count) {
            if (mounted && _residentUnpaidBillsCount != count) {
              setState(() => _residentUnpaidBillsCount = count);
            }
          },
        );
      case 'verification':
        return ResidentVerificationView(onQueueUpdated: _fetchPendingCount);
      case 'houses':
        return const HousesManagementView();
      case 'security_management':
        if (!(user?.canAccessSecurityAdmin ?? false)) {
          return _buildFeaturePlaceholder('Akses Terbatas: Hanya Pengurus');
        }
        return const SecurityManagementView();
      case 'profile':
        return const ResidentProfileScreen();
      case 'billing':
        return AdminBillingView(
          key: _adminBillingKey,
          onPendingCountUpdated: _fetchPendingCount,
          hasResidentAccess: user?.canAccessResidentIuran ?? false,
          onNavigateToResidentBilling: (user?.canAccessResidentIuran ?? false)
              ? () => _navigateToKey('resident_billing', items)
              : null,
        );
      case 'resident_billing':
        return ResidentBillingScreen(onBillUpdated: _fetchPendingCount);
      case 'invitations':
        return BlocProvider(
          create: (context) => InvitationBloc(
            repository: context.read<InvitationRepository>(),
          ),
          child: const ResidentInvitationsScreen(),
        );
      case 'cashbook':
        return CashbookScreen(isAdmin: user?.canAccessCashbookAdmin ?? false);
      case 'announcements':
        return AnnouncementsScreen(isAdmin: user?.canAccessLeadership ?? false);
      case 'guestbook':
        return SecurityGuestbookScreen(user: user);
      case 'panic':
        return EmergencyMonitoringScreen(
          user: user,
          onIncidentCountChanged: () {
            _fetchActiveIncidentsCount();
            _fetchPendingCount(skipResidentBills: true);
          },
        );
      default:
        return _buildFeaturePlaceholder(key);
    }
  }

  Widget _buildFeaturePlaceholder(String title) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.construction_rounded,
                size: 48,
                color: AppTheme.primaryDark,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Modul ini sedang aktif dan siap digunakan sesuai wewenang peran Anda.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
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
        final items = NavigationItemBuilder.buildNavigationItems(
          user,
          pendingCount: _pendingCount,
          pendingBillsCount: _pendingBillsCount,
          residentUnpaidBillsCount: _residentUnpaidBillsCount,
          activeIncidentsCount: _activeIncidentsCount,
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= Responsive.desktopBreakpoint) {
              return _buildDesktopScaffold(user, items, isTablet: false);
            } else if (constraints.maxWidth >= Responsive.mobileBreakpoint) {
              return _buildDesktopScaffold(user, items, isTablet: true);
            } else {
              return _buildMobileScaffold(user, items);
            }
          },
        );
      },
    );
  }

  // --- MOBILE LAYOUT (< 768px) ---
  Widget _buildMobileScaffold(UserModel? user, List<SidebarItemData> items) {
    final activeItem = _getActiveItem(items);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.holiday_village_rounded,
                color: AppTheme.primary, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                activeItem.title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    fontSize: 16),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded,
                color: AppTheme.textSecondary),
            tooltip: 'Tentang TetangGo',
            onPressed: () => AboutTetangGoDialog.show(context),
          ),
          if ((user?.canAccessVerificationAdmin ?? false) && _pendingCount > 0)
            IconButton(
              icon: Badge(
                label: Text('$_pendingCount'),
                child: const Icon(Icons.how_to_reg_rounded,
                    color: AppTheme.primary),
              ),
              onPressed: () => _navigateToKey('verification', items),
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
            if (index >= 0 && index < items.length) {
              setState(() {
                _selectedMenuIndex = index;
                _visitedTabKeys.add(items[index].keyId);
              });
            }
            Navigator.pop(context);
          },
          user: user,
          pendingCount: _pendingCount,
          pendingBillsCount: _pendingBillsCount,
          residentUnpaidBillsCount: _residentUnpaidBillsCount,
          activeIncidentsCount: _activeIncidentsCount,
          onLogout: _onLogoutPressed,
        ),
      ),
      body: _buildContent(user, items, false),
      floatingActionButton:
          user != null && (user.isResident || user.hasHousingAssociation)
              ? PanicButtonFab(
                  user: user,
                  onAlarmSent: _fetchActiveIncidentsCount,
                )
              : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _getBottomNavIndex(items),
        selectedItemColor: AppTheme.primaryDark,
        unselectedItemColor: AppTheme.textSecondary,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => _onBottomNavTapped(index, items),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded), label: 'Beranda'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded), label: 'Profil'),
          BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_rounded), label: 'Iuran'),
          BottomNavigationBarItem(
              icon: Icon(Icons.menu_rounded), label: 'Menu Lain'),
        ],
      ),
    );
  }

  int _getBottomNavIndex(List<SidebarItemData> items) {
    final activeKey = _getActiveItem(items).keyId;
    if (activeKey == 'dashboard') return 0;
    if (activeKey == 'profile') return 1;
    if (activeKey == 'resident_billing' || activeKey == 'billing') return 2;
    return 3;
  }

  void _onBottomNavTapped(int index, List<SidebarItemData> items) {
    if (index == 3) {
      _scaffoldKey.currentState?.openDrawer();
      return;
    }
    if (index == 0) {
      _navigateToKey('dashboard', items);
    } else if (index == 1) {
      _navigateToKey('profile', items);
    } else if (index == 2) {
      if (items.any((it) => it.keyId == 'resident_billing')) {
        _navigateToKey('resident_billing', items);
      } else if (items.any((it) => it.keyId == 'billing')) {
        _navigateToKey('billing', items);
      } else {
        _navigateToKey('announcements', items);
      }
    }
  }

  // --- DESKTOP & TABLET LAYOUT (>= 768px & >= 1024px) ---
  Widget _buildDesktopScaffold(UserModel? user, List<SidebarItemData> items,
      {required bool isTablet}) {
    final activeItem = _getActiveItem(items);

    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton:
          user != null && (user.isResident || user.hasHousingAssociation)
              ? PanicButtonFab(
                  user: user,
                  onAlarmSent: _fetchActiveIncidentsCount,
                )
              : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Row(
        children: [
          // Persistent Left Sidebar
          DashboardSidebar(
            selectedIndex: _selectedMenuIndex,
            onItemSelected: (index) {
              if (index >= 0 && index < items.length) {
                setState(() {
                  _selectedMenuIndex = index;
                  _visitedTabKeys.add(items[index].keyId);
                });
              }
            },
            user: user,
            pendingCount: _pendingCount,
            pendingBillsCount: _pendingBillsCount,
            residentUnpaidBillsCount: _residentUnpaidBillsCount,
            activeIncidentsCount: _activeIncidentsCount,
            onLogout: _onLogoutPressed,
          ),
          // Main Body with Top Header Bar
          Expanded(
            child: Column(
              children: [
                // Top Action Bar
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        activeItem.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Row(
                        children: [
                          if (user?.canAccessResidentIuran ?? false)
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                ),
                                icon: const Icon(Icons.payments_rounded,
                                    size: 18),
                                label: const Text('Bayar Iuran Saya',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                                onPressed: () =>
                                    _navigateToKey('resident_billing', items),
                              ),
                            ),
                          if ((user?.canAccessVerificationAdmin ?? false) &&
                              _pendingCount > 0)
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.primaryDark,
                                  side:
                                      const BorderSide(color: AppTheme.primary),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: Badge(
                                  label: Text('$_pendingCount'),
                                  child: const Icon(Icons.how_to_reg_rounded,
                                      size: 18),
                                ),
                                label: const Text('Verifikasi Warga'),
                                onPressed: () =>
                                    _navigateToKey('verification', items),
                              ),
                            ),
                          IconButton(
                            icon: const Icon(Icons.info_outline_rounded,
                                size: 20, color: AppTheme.textSecondary),
                            tooltip: 'Tentang TetangGo',
                            onPressed: () => AboutTetangGoDialog.show(context),
                          ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            radius: 16,
                            backgroundColor:
                                AppTheme.primary.withValues(alpha: 0.12),
                            child: Text(
                              (user?.name.isNotEmpty ?? false)
                                  ? user!.name.substring(0, 1).toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryDark),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            user?.displayName ?? 'Pengguna',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Content View
                Expanded(
                  child: _buildContent(user, items, !isTablet),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
