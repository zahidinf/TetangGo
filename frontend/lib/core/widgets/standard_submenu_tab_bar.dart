import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class StandardSubmenuItem {
  final IconData icon;
  final String label;
  final int? badgeCount;

  const StandardSubmenuItem({
    required this.icon,
    required this.label,
    this.badgeCount,
  });
}

class StandardSubmenuTabBar extends StatelessWidget {
  final TabController controller;
  final List<StandardSubmenuItem> items;
  final bool? isScrollable;

  const StandardSubmenuTabBar({
    super.key,
    required this.controller,
    required this.items,
    this.isScrollable,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    final scrollable = isScrollable ?? !isDesktop;

    return Container(
      color: Colors.white,
      child: TabBar(
        controller: controller,
        isScrollable: scrollable,
        labelColor: AppTheme.primary,
        unselectedLabelColor: AppTheme.textSecondary,
        indicatorColor: AppTheme.primary,
        indicatorWeight: 3,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
        tabs: items.map((item) {
          return Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: scrollable ? MainAxisSize.min : MainAxisSize.max,
              children: [
                Icon(item.icon, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    item.label,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (item.badgeCount != null && item.badgeCount! > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.danger,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${item.badgeCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
