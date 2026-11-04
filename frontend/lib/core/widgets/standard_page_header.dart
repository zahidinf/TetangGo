import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Komponen Page Header terstandarisasi untuk halaman-halaman TetangGo.
///
/// Desktop:
/// - Judul dan deskripsi berada di sebelah kiri (Expanded).
/// - Seluruh tombol aksi berada di sebelah kanan (WrapAlignment.end).
/// - Jarak antar tombol konsisten (8px) dan alignment vertikal rapi (center).
///
/// Mobile:
/// - Judul dan deskripsi berada di bagian atas dan tetap mudah dibaca.
/// - Tombol aksi berada di baris tersendiri di bawah judul (WrapAlignment.start).
/// - Jika ruang horizontal tidak mencukupi (misal 320px), tombol otomatis wrap tanpa overflow.
class StandardPageHeader extends StatelessWidget {
  final String title;
  final TextStyle? titleStyle;
  final Widget? titleBadge;
  final String? subtitle;
  final TextStyle? subtitleStyle;
  final Widget? icon;
  final List<Widget> actions;
  final double breakpoint;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;

  const StandardPageHeader({
    super.key,
    required this.title,
    this.titleStyle,
    this.titleBadge,
    this.subtitle,
    this.subtitleStyle,
    this.icon,
    this.actions = const [],
    this.breakpoint = 700,
    this.padding,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= breakpoint;

        final titleText = Text(
          title,
          style: titleStyle ??
              const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
        );

        final titleRow = titleBadge == null
            ? titleText
            : Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  titleText,
                  titleBadge!,
                ],
              );

        final titleColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            titleRow,
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: subtitleStyle ??
                    const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
              ),
            ],
          ],
        );

        final headerInfo = icon == null
            ? titleColumn
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  icon!,
                  const SizedBox(width: 14),
                  Expanded(child: titleColumn),
                ],
              );

        final actionWidgets = actions.isEmpty
            ? null
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: isDesktop ? WrapAlignment.end : WrapAlignment.start,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: actions,
              );

        final Widget content;
        if (isDesktop) {
          content = Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: headerInfo),
              if (actionWidgets != null) ...[
                const SizedBox(width: 16),
                actionWidgets,
              ],
            ],
          );
        } else {
          content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              headerInfo,
              if (actionWidgets != null) ...[
                const SizedBox(height: 12),
                actionWidgets,
              ],
            ],
          );
        }

        if (backgroundColor != null || padding != null) {
          return Container(
            color: backgroundColor,
            padding: padding,
            child: content,
          );
        }

        return content;
      },
    );
  }
}
