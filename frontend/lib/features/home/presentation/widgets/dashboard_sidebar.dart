import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/domain/models/user_model.dart';

class SidebarItemData {
  final String keyId;
  final String title;
  final IconData icon;
  final IconData selectedIcon;
  final int index;
  final String? badge;

  const SidebarItemData({
    required this.keyId,
    required this.title,
    required this.icon,
    required this.selectedIcon,
    required this.index,
    this.badge,
  });
}

class NavigationItemBuilder {
  static List<SidebarItemData> buildNavigationItems(
    UserModel? user, {
    int pendingCount = 0,
    int pendingBillsCount = 0,
  }) {
    final List<SidebarItemData> items = [];
    int index = 0;

    // 1. Common Baseline: Beranda Lingkungan / Dashboard
    items.add(
      SidebarItemData(
        keyId: 'dashboard',
        title: user?.canAccessLeadership ?? false ? 'Dashboard' : 'Beranda Lingkungan',
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard_rounded,
        index: index++,
      ),
    );

    // 2. Administrative: Verifikasi Warga (Admin, Chairperson, Vice Chairperson, Secretary)
    if (user?.canAccessVerificationAdmin ?? false) {
      items.add(
        SidebarItemData(
          keyId: 'verification',
          title: 'Verifikasi Warga',
          icon: Icons.how_to_reg_outlined,
          selectedIcon: Icons.how_to_reg_rounded,
          index: index++,
          badge: pendingCount > 0 ? '$pendingCount Baru' : null,
        ),
      );
    }

    // 3. Administrative: Data Hunian & Warga (Admin, Chairperson, Vice Chairperson, Secretary)
    if (user?.canAccessHousesAdmin ?? false) {
      items.add(
        SidebarItemData(
          keyId: 'houses',
          title: 'Data Hunian & Warga',
          icon: Icons.home_work_outlined,
          selectedIcon: Icons.home_work_rounded,
          index: index++,
        ),
      );
    }

    // 4. Common Baseline: Profil Hunian & Keluarga (or Profil Pengurus RT)
    items.add(
      SidebarItemData(
        keyId: 'profile',
        title: user?.canAccessLeadership ?? false ? 'Profil Pengurus RT' : 'Profil Hunian & Keluarga',
        icon: user?.canAccessLeadership ?? false ? Icons.manage_accounts_outlined : Icons.family_restroom_rounded,
        selectedIcon: user?.canAccessLeadership ?? false ? Icons.manage_accounts_rounded : Icons.family_restroom_rounded,
        index: index++,
      ),
    );

    // 5. Administrative: Kelola Iuran & Tagihan (Admin, Chairperson, Vice Chairperson, Treasurer)
    if (user?.canAccessBillingAdmin ?? false) {
      items.add(
        SidebarItemData(
          keyId: 'billing',
          title: 'Iuran & Tagihan (Admin)',
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long_rounded,
          index: index++,
          badge: pendingBillsCount > 0 ? '$pendingBillsCount Baru' : null,
        ),
      );
    }

    // 6. Resident Baseline: Iuran Warga (Accessible to ANY user with valid housing association)
    if (user?.canAccessResidentIuran ?? false) {
      items.add(
        SidebarItemData(
          keyId: 'resident_billing',
          title: user?.canAccessBillingAdmin ?? false ? 'Iuran Pribadi Warga' : 'Iuran Warga',
          icon: Icons.payments_outlined,
          selectedIcon: Icons.payments_rounded,
          index: index++,
        ),
      );
    }

    // 7. Common Baseline: Kas Transparan (Accessible to EVERY resident and admin; editable by admin/treasurer)
    items.add(
      SidebarItemData(
        keyId: 'cashbook',
        title: 'Kas Transparan',
        icon: Icons.account_balance_wallet_outlined,
        selectedIcon: Icons.account_balance_wallet_rounded,
        index: index++,
      ),
    );

    // 8. Common Baseline: Pengumuman RT (Accessible to EVERY resident and admin; editable by leadership)
    items.add(
      SidebarItemData(
        keyId: 'announcements',
        title: 'Pengumuman RT',
        icon: Icons.campaign_outlined,
        selectedIcon: Icons.campaign_rounded,
        index: index++,
      ),
    );

    // 9. Common Baseline: Panic Button (Accessible to EVERY resident and admin)
    items.add(
      SidebarItemData(
        keyId: 'panic',
        title: 'Panic Button',
        icon: Icons.contact_emergency_outlined,
        selectedIcon: Icons.contact_emergency_rounded,
        index: index++,
        badge: 'Siaga',
      ),
    );

    // 10. Administrative: Buku Tamu Satpam (Admin, Chairperson, Vice Chairperson, Secretary)
    if (user?.canAccessSecurityGuestbookAdmin ?? false) {
      items.add(
        SidebarItemData(
          keyId: 'guestbook',
          title: 'Buku Tamu Satpam',
          icon: Icons.shield_outlined,
          selectedIcon: Icons.shield_rounded,
          index: index++,
        ),
      );
    }

    return items;
  }
}

class DashboardSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final UserModel? user;
  final VoidCallback onLogout;
  final int pendingCount;
  final int pendingBillsCount;

  const DashboardSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.user,
    required this.onLogout,
    this.pendingCount = 0,
    this.pendingBillsCount = 0,
  });

  List<SidebarItemData> get menuItems => NavigationItemBuilder.buildNavigationItems(
        user,
        pendingCount: pendingCount,
        pendingBillsCount: pendingBillsCount,
      );

  @override
  Widget build(BuildContext context) {
    final items = menuItems;

    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Column(
        children: [
          // Header Logo & Branding
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFF1F5F9)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.holiday_village_rounded,
                    color: AppTheme.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TetangGo',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.secondary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          user?.hasAdminAccess ?? false ? 'Portal Pengurus RT' : 'Portal Warga',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Menu Items List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, i) {
                final item = items[i];
                final isSelected = selectedIndex == item.index;

                return _SidebarItemTile(
                  item: item,
                  isSelected: isSelected,
                  onTap: () => onItemSelected(item.index),
                );
              },
            ),
          ),

          // Footer User Profile & Quick Logout
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFFF1F5F9)),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.primary.withOpacity(0.15),
                  child: Text(
                    (user?.name.isNotEmpty ?? false)
                        ? user!.name.substring(0, 1).toUpperCase()
                        : 'A',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryDark,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user?.displayName ?? 'Pengurus RT',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        user?.roleDisplay ?? 'Warga',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  color: AppTheme.danger,
                  tooltip: 'Keluar',
                  onPressed: onLogout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItemTile extends StatelessWidget {
  final SidebarItemData item;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarItemTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? item.selectedIcon : item.icon,
                size: 20,
                color: isSelected ? AppTheme.primaryDark : AppTheme.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppTheme.primaryDark : AppTheme.textPrimary,
                  ),
                ),
              ),
              if (item.badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryDark : AppTheme.danger,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    item.badge!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
