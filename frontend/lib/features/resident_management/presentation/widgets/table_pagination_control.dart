import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class TablePaginationControl extends StatelessWidget {
  final int currentPage;
  final int totalItems;
  final int pageSize;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int>? onPageSizeChanged;
  final List<int> pageSizeOptions;
  final String keyPrefix;
  final bool isDesktop;

  const TablePaginationControl({
    super.key,
    required this.currentPage,
    required this.totalItems,
    required this.pageSize,
    required this.onPageChanged,
    this.onPageSizeChanged,
    this.pageSizeOptions = const [10, 15, 25, 50],
    required this.keyPrefix,
    this.isDesktop = true,
  });

  @override
  Widget build(BuildContext context) {
    if (totalItems <= 0) {
      return const SizedBox.shrink();
    }

    final totalPages = (totalItems / pageSize).ceil();
    final startRecord = ((currentPage - 1) * pageSize) + 1;
    final endRecord = (currentPage * pageSize) > totalItems
        ? totalItems
        : (currentPage * pageSize);

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRow = isDesktop && constraints.maxWidth >= 600;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Color(0xFFF1F5F9)),
            ),
          ),
          child: useRow
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Menampilkan $startRecord–$endRecord dari $totalItems data (Hal $currentPage dari $totalPages)',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildPaginationButtons(totalPages),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Menampilkan $startRecord–$endRecord dari $totalItems data (Hal $currentPage dari $totalPages)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildPaginationButtons(totalPages),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildPaginationButtons(int totalPages) {
    final canPrev = currentPage > 1;
    final canNext = currentPage < totalPages;

    List<int> pages = [];
    if (totalPages <= 5) {
      pages = List.generate(totalPages, (i) => i + 1);
    } else {
      int start = currentPage - 1;
      int end = currentPage + 1;
      if (start < 1) {
        start = 1;
        end = 3;
      }
      if (end > totalPages) {
        end = totalPages;
        start = totalPages - 2;
      }
      for (int i = start; i <= end; i++) {
        pages.add(i);
      }
      if (!pages.contains(1)) {
        if (pages.first > 2) pages.insert(0, -1);
        pages.insert(0, 1);
      }
      if (!pages.contains(totalPages)) {
        if (pages.last < totalPages - 1) pages.add(-1);
        pages.add(totalPages);
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tombol Sebelumnya
          OutlinedButton(
            key: Key('${keyPrefix}_prev'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              side: BorderSide(
                  color: canPrev
                      ? const Color(0xFFCBD5E1)
                      : const Color(0xFFE2E8F0)),
              foregroundColor:
                  canPrev ? AppTheme.textPrimary : Colors.grey.shade400,
            ),
            onPressed: canPrev ? () => onPageChanged(currentPage - 1) : null,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chevron_left_rounded, size: 16),
                SizedBox(width: 2),
                Text('Sebelumnya', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 6),

          // Nomor Halaman
          for (final p in pages) ...[
            if (p == -1)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '...',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              )
            else ...[
              InkWell(
                key: Key('${keyPrefix}_page_$p'),
                onTap: p == currentPage ? null : () => onPageChanged(p),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p == currentPage
                        ? AppTheme.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: p == currentPage
                          ? AppTheme.primary
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    '$p',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          p == currentPage ? FontWeight.bold : FontWeight.w500,
                      color: p == currentPage
                          ? Colors.white
                          : AppTheme.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ],

          const SizedBox(width: 2),

          // Tombol Berikutnya
          OutlinedButton(
            key: Key('${keyPrefix}_next'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              side: BorderSide(
                  color: canNext
                      ? const Color(0xFFCBD5E1)
                      : const Color(0xFFE2E8F0)),
              foregroundColor:
                  canNext ? AppTheme.textPrimary : Colors.grey.shade400,
            ),
            onPressed: canNext ? () => onPageChanged(currentPage + 1) : null,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Berikutnya', style: TextStyle(fontSize: 12)),
                SizedBox(width: 2),
                Icon(Icons.chevron_right_rounded, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
