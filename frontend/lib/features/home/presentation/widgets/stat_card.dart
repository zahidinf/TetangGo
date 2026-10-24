import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class StatCardData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String trend;
  final bool isPositive;
  final VoidCallback? onTap;

  const StatCardData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.trend,
    this.isPositive = true,
    this.onTap,
  });
}

class StatCard extends StatefulWidget {
  final StatCardData data;

  const StatCard({super.key, required this.data});

  @override
  State<StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<StatCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;

    return MouseRegion(
      cursor: d.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: d.onTap != null ? (_) => setState(() => _isHovered = true) : null,
      onExit: d.onTap != null ? (_) => setState(() => _isHovered = false) : null,
      child: GestureDetector(
        onTap: d.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered && d.onTap != null
                  ? d.color.withOpacity(0.5)
                  : const Color(0xFFE2E8F0),
              width: _isHovered && d.onTap != null ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered && d.onTap != null
                    ? d.color.withOpacity(0.12)
                    : Colors.black.withOpacity(0.02),
                blurRadius: _isHovered && d.onTap != null ? 16 : 8,
                offset: Offset(0, _isHovered && d.onTap != null ? 6 : 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      d.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: d.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(d.icon, color: d.color, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                d.value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (d.isPositive ? AppTheme.primary : AppTheme.danger).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      d.trend,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: d.isPositive ? AppTheme.primaryDark : AppTheme.danger,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      d.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
