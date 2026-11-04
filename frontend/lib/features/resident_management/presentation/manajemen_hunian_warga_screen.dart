import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/standard_submenu_tab_bar.dart';
import '../../auth/domain/models/user_model.dart';
import '../../profile/presentation/resident_profile_screen.dart';
import 'houses_management_view.dart';
import 'resident_verification_view.dart';

enum ManagementTabType {
  verification,
  houses,
  profile,
}

class ManajemenHunianWargaScreen extends StatefulWidget {
  final UserModel? currentUser;
  final VoidCallback? onQueueUpdated;
  final int pendingCount;
  final int initialTab;
  final String? initialTabKey;

  const ManajemenHunianWargaScreen({
    super.key,
    this.currentUser,
    this.onQueueUpdated,
    this.pendingCount = 0,
    this.initialTab = 0,
    this.initialTabKey,
  });

  @override
  State<ManajemenHunianWargaScreen> createState() =>
      ManajemenHunianWargaScreenState();
}

class ManajemenHunianWargaScreenState extends State<ManajemenHunianWargaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<ManagementTabType> _availableTabs;

  List<ManagementTabType> _computeAvailableTabs() {
    final tabs = <ManagementTabType>[];
    // Strict priority order:
    // 1. Verifikasi Warga (if permitted)
    if (widget.currentUser?.canAccessVerificationAdmin ?? false) {
      tabs.add(ManagementTabType.verification);
    }
    // 2. Data Hunian & Warga (if permitted)
    if (widget.currentUser?.canAccessHousesAdmin ?? false) {
      tabs.add(ManagementTabType.houses);
    }
    // 3. Profil Hunian & Keluarga (baseline profile access)
    tabs.add(ManagementTabType.profile);
    return tabs;
  }

  @override
  void initState() {
    super.initState();
    _availableTabs = _computeAvailableTabs();

    int initialIndex = 0;
    if (widget.initialTabKey != null) {
      final found = _availableTabs.indexWhere((t) {
        switch (t) {
          case ManagementTabType.verification:
            return widget.initialTabKey == 'verification';
          case ManagementTabType.houses:
            return widget.initialTabKey == 'houses';
          case ManagementTabType.profile:
            return widget.initialTabKey == 'profile';
        }
      });
      if (found != -1) initialIndex = found;
    } else if (widget.initialTab >= 0 &&
        widget.initialTab < _availableTabs.length) {
      initialIndex = widget.initialTab;
    }

    _tabController = TabController(
      length: _availableTabs.length,
      initialIndex: initialIndex,
      vsync: this,
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant ManajemenHunianWargaScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newTabs = _computeAvailableTabs();
    if (newTabs.length != _availableTabs.length) {
      _tabController.dispose();
      _availableTabs = newTabs;
      _tabController = TabController(
        length: _availableTabs.length,
        vsync: this,
      );
      _tabController.addListener(() {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void switchToTabKey(String key) {
    final idx = _availableTabs.indexWhere((t) {
      switch (t) {
        case ManagementTabType.verification:
          return key == 'verification';
        case ManagementTabType.houses:
          return key == 'houses';
        case ManagementTabType.profile:
          return key == 'profile';
      }
    });
    if (idx != -1 && idx < _availableTabs.length) {
      _tabController.animateTo(idx);
    }
  }

  String get activeTabKey {
    if (_tabController.index < _availableTabs.length) {
      switch (_availableTabs[_tabController.index]) {
        case ManagementTabType.verification:
          return 'verification';
        case ManagementTabType.houses:
          return 'houses';
        case ManagementTabType.profile:
          return 'profile';
      }
    }
    return 'resident_management';
  }

  String get _headerSubtitle {
    if (_tabController.index < _availableTabs.length) {
      switch (_availableTabs[_tabController.index]) {
        case ManagementTabType.verification:
          return 'Proses pendaftaran dan verifikasi berkas warga baru';
        case ManagementTabType.houses:
          return 'Kelola nomor blok rumah, data penghuni, dan direktori warga';
        case ManagementTabType.profile:
          return 'Informasi hunian, data anggota keluarga, dan kendaraan terdaftar';
      }
    }
    return 'Kelola data hunian, verifikasi warga, dan profil keluarga';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTabBar(isDesktop),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _buildTabViews(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(bool isDesktop) {
    final submenuItems = _availableTabs.map((type) {
      switch (type) {
        case ManagementTabType.verification:
          return StandardSubmenuItem(
            icon: Icons.how_to_reg_rounded,
            label: 'Verifikasi Warga',
            badgeCount: widget.pendingCount,
          );
        case ManagementTabType.houses:
          return const StandardSubmenuItem(
            icon: Icons.home_work_rounded,
            label: 'Data Hunian & Warga',
          );
        case ManagementTabType.profile:
          return const StandardSubmenuItem(
            icon: Icons.family_restroom_rounded,
            label: 'Profil Hunian & Keluarga',
          );
      }
    }).toList();

    return StandardSubmenuTabBar(
      controller: _tabController,
      items: submenuItems,
      isScrollable: isDesktop ? false : true,
    );
  }

  List<Widget> _buildTabViews() {
    return _availableTabs.map((type) {
      switch (type) {
        case ManagementTabType.verification:
          return _KeepAliveTabWrapper(
            child: ResidentVerificationView(
              onQueueUpdated: widget.onQueueUpdated,
            ),
          );
        case ManagementTabType.houses:
          return const _KeepAliveTabWrapper(
            child: HousesManagementView(),
          );
        case ManagementTabType.profile:
          return const _KeepAliveTabWrapper(
            child: ResidentProfileScreen(),
          );
      }
    }).toList();
  }
}

class _KeepAliveTabWrapper extends StatefulWidget {
  final Widget child;
  const _KeepAliveTabWrapper({required this.child});

  @override
  State<_KeepAliveTabWrapper> createState() => _KeepAliveTabWrapperState();
}

class _KeepAliveTabWrapperState extends State<_KeepAliveTabWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
