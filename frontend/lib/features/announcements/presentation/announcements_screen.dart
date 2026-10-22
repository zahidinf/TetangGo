import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/image_url_helper.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../data/announcements_repository.dart';
import '../domain/models/announcement_model.dart';
import 'widgets/announcement_detail_dialog.dart';
import 'widgets/announcement_form_dialog.dart';

class AnnouncementsScreen extends StatefulWidget {
  final bool isAdmin;

  const AnnouncementsScreen({super.key, required this.isAdmin});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  List<AnnouncementModel> _announcements = [];

  String _selectedCategory = 'all';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAnnouncements() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = context.read<AnnouncementsRepository>();
      final list = await repo.getAnnouncements(
        category: _selectedCategory,
        search: _searchController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _announcements = list;
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

  void _openCreateOrEditDialog([AnnouncementModel? announcement]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AnnouncementFormDialog(
        repository: context.read<AnnouncementsRepository>(),
        initialAnnouncement: announcement,
        onSuccess: _loadAnnouncements,
      ),
    );
  }

  void _confirmDelete(AnnouncementModel a) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Pengumuman', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Apakah Anda yakin ingin menghapus pengumuman "${a.title}"?'),
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
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                final repo = context.read<AnnouncementsRepository>();
                await repo.deleteAnnouncement(a.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pengumuman berhasil dihapus')),
                  );
                  _loadAnnouncements();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(backgroundColor: AppTheme.danger, content: Text('Gagal menghapus: $e')),
                  );
                }
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(dt.toLocal());
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'darurat':
        return AppTheme.danger;
      case 'penting':
        return const Color(0xFFF59E0B);
      case 'biasa':
      default:
        return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    // Separate pinned / emergency announcements for top highlight banner
    final pinnedOrUrgent = _announcements.where((a) => a.isPinned || a.isUrgent).toList();
    final regularList = _announcements.where((a) => !a.isPinned && !a.isUrgent).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: RefreshIndicator(
        onRefresh: _loadAnnouncements,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(isDesktop ? 24 : 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  _buildHeader(isDesktop),
                  const SizedBox(height: 20),

                  // Search & Category Filters
                  _buildSearchAndFilters(),
                  const SizedBox(height: 20),

                  // Error Banner
                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withOpacity(0.1),
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
                            onPressed: _loadAnnouncements,
                            child: const Text('Coba Lagi'),
                          ),
                        ],
                      ),
                    ),

                  if (_isLoading && _announcements.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_announcements.isEmpty)
                    _buildEmptyState()
                  else ...[
                    // Highlight Banner (Pinned / Urgent)
                    if (pinnedOrUrgent.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(Icons.push_pin_rounded, color: AppTheme.danger, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'PENGUMUMAN PENTING & DISMATKAN (${pinnedOrUrgent.length})',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: AppTheme.danger,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...pinnedOrUrgent.map((a) => _buildAnnouncementCard(a, isHighlight: true)),
                      const SizedBox(height: 20),
                    ],

                    // Regular Announcements
                    if (regularList.isNotEmpty) ...[
                      const Text(
                        'Semua Pengumuman Lingkungan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...regularList.map((a) => _buildAnnouncementCard(a, isHighlight: false)),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDesktop) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Papan Pengumuman Resmi RT',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Informasi resmi dan himbauan pengurus cluster lingkungan secara terpusat.',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        if (widget.isAdmin) ...[
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () => _openCreateOrEditDialog(),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('+ Buat Pengumuman Baru'),
          ),
        ],
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onSubmitted: (_) => _loadAnnouncements(),
                  decoration: InputDecoration(
                    hintText: 'Cari pengumuman...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _loadAnnouncements();
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.search_rounded),
                onPressed: _loadAnnouncements,
                tooltip: 'Cari',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Kategori:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
              ChoiceChip(
                label: const Text('Semua'),
                selected: _selectedCategory == 'all',
                onSelected: (val) {
                  if (val) {
                    setState(() => _selectedCategory = 'all');
                    _loadAnnouncements();
                  }
                },
              ),
              ChoiceChip(
                label: const Text('Darurat / Mendesak'),
                selected: _selectedCategory == 'darurat',
                selectedColor: AppTheme.danger.withOpacity(0.15),
                onSelected: (val) {
                  if (val) {
                    setState(() => _selectedCategory = 'darurat');
                    _loadAnnouncements();
                  }
                },
              ),
              ChoiceChip(
                label: const Text('Penting'),
                selected: _selectedCategory == 'penting',
                selectedColor: const Color(0xFFF59E0B).withOpacity(0.15),
                onSelected: (val) {
                  if (val) {
                    setState(() => _selectedCategory = 'penting');
                    _loadAnnouncements();
                  }
                },
              ),
              ChoiceChip(
                label: const Text('Biasa'),
                selected: _selectedCategory == 'biasa',
                selectedColor: AppTheme.primary.withOpacity(0.15),
                onSelected: (val) {
                  if (val) {
                    setState(() => _selectedCategory = 'biasa');
                    _loadAnnouncements();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(Icons.campaign_outlined, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 14),
          const Text(
            'Belum ada pengumuman resmi',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Pengumuman resmi dari pengurus RT akan muncul di papan ini.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementCard(AnnouncementModel a, {required bool isHighlight}) {
    final catColor = _getCategoryColor(a.category);
    final fullImageUrl = a.imageUrl != null ? getFullImageUrl(a.imageUrl!) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlight ? catColor.withOpacity(0.5) : const Color(0xFFE2E8F0),
          width: isHighlight ? 1.5 : 1.0,
        ),
        boxShadow: isHighlight
            ? [
                BoxShadow(
                  color: catColor.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            showDialog(
              context: context,
              builder: (ctx) => AnnouncementDetailDialog(announcement: a),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail image if exists
                if (fullImageUrl.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey.shade100,
                      child: Image.network(
                        fullImageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_rounded, color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],

                // Main Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badges Row
                      Row(
                        children: [
                          if (a.isPinned) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.danger.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.push_pin_rounded, size: 10, color: AppTheme.danger),
                                  SizedBox(width: 2),
                                  Text('PIN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.danger)),
                                ],
                              ),
                            ),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: catColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              a.categoryDisplay,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: catColor,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formatDate(a.createdAt),
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Title
                      Text(
                        a.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Summary Snippet
                      Text(
                        a.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Author & Read prompt
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Dipublikasikan oleh: ${a.authorName}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                          const Row(
                            children: [
                              Text(
                                'Baca Selengkapnya',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primary),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_rounded, size: 14, color: AppTheme.primary),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Admin Edit & Delete Actions
                if (widget.isAdmin) ...[
                  const SizedBox(width: 8),
                  Column(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primary),
                        tooltip: 'Edit Pengumuman',
                        onPressed: () => _openCreateOrEditDialog(a),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.danger),
                        tooltip: 'Hapus Pengumuman',
                        onPressed: () => _confirmDelete(a),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
