import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/domain/models/user_model.dart';

class SidebarItemData {
  final String title;
  final IconData icon;
  final IconData selectedIcon;
  final int index;
  final String? badge;

  const SidebarItemData({
    required this.title,
    required this.icon,
    required this.selectedIcon,
    required this.index,
    this.badge,
  });
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

  List<SidebarItemData> get menuItems {
    final isAdmin = user?.role == 'admin_rt';

    if (isAdmin) {
      return [
        const SidebarItemData(
          title: 'Dashboard',
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard_rounded,
          index: 0,
        ),
        SidebarItemData(
          title: 'Verifikasi Warga',
          icon: Icons.how_to_reg_outlined,
          selectedIcon: Icons.how_to_reg_rounded,
          index: 1,
          badge: pendingCount > 0 ? '$pendingCount Baru' : null,
        ),
        const SidebarItemData(
          title: 'Data Hunian & Warga',
          icon: Icons.home_work_outlined,
          selectedIcon: Icons.home_work_rounded,
          index: 2,
        ),
        const SidebarItemData(
          title: 'Profil & Keluarga',
          icon: Icons.account_circle_outlined,
          selectedIcon: Icons.account_circle_rounded,
          index: 3,
        ),
        SidebarItemData(
          title: 'Iuran & Tagihan',
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long_rounded,
          index: 4,
          badge: pendingBillsCount > 0 ? '$pendingBillsCount Baru' : null,
        ),
        const SidebarItemData(
          title: 'Kas Transparan',
          icon: Icons.account_balance_wallet_outlined,
          selectedIcon: Icons.account_balance_wallet_rounded,
          index: 5,
        ),
        const SidebarItemData(
          title: 'Pengumuman RT',
          icon: Icons.campaign_outlined,
          selectedIcon: Icons.campaign_rounded,
          index: 6,
        ),
        const SidebarItemData(
          title: 'Panic Alert',
          icon: Icons.contact_emergency_outlined,
          selectedIcon: Icons.contact_emergency_rounded,
          index: 7,
          badge: 'Siaga',
        ),
        const SidebarItemData(
          title: 'Buku Tamu Satpam',
          icon: Icons.shield_outlined,
          selectedIcon: Icons.shield_rounded,
          index: 8,
        ),
      ];
    } else {
      // Warga Menu
      return const [
        SidebarItemData(
          title: 'Beranda Lingkungan',
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard_rounded,
          index: 0,
        ),
        SidebarItemData(
          title: 'Profil Hunian & Keluarga',
          icon: Icons.family_restroom_rounded,
          selectedIcon: Icons.family_restroom_rounded,
          index: 1,
        ),
        SidebarItemData(
          title: 'Iuran Warga',
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long_rounded,
          index: 2,
        ),
        SidebarItemData(
          title: 'Pengumuman RT',
          icon: Icons.campaign_outlined,
          selectedIcon: Icons.campaign_rounded,
          index: 3,
        ),
        SidebarItemData(
          title: 'Panic Button',
          icon: Icons.emergency_rounded,
          selectedIcon: Icons.emergency_rounded,
          index: 4,
          badge: 'Siaga',
        ),
      ];
    }
  }

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
                          user?.role == 'admin_rt' ? 'Portal Pengurus RT' : 'Portal Warga',
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
                        user?.name ?? 'Pengurus RT',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        user?.roleDisplay ?? 'Admin RT',
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? item.selectedIcon : item.icon,
                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                size: 20,
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
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: item.badge!.contains('Baru') ? const Color(0xFFFEF3C7) : AppTheme.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    item.badge!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: item.badge!.contains('Baru') ? const Color(0xFFB45309) : AppTheme.danger,
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
