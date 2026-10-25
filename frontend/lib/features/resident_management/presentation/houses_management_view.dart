import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/resident_repository.dart';
import '../domain/models/house_model.dart';
import 'residents_management_view.dart';
import 'widgets/house_detail_dialog.dart';
import 'widgets/house_occupants_dialog.dart';
import 'widgets/unassigned_residents_dialog.dart';
import 'widgets/table_pagination_control.dart';

class HousesManagementView extends StatefulWidget {
  final int initialTab;
  const HousesManagementView({super.key, this.initialTab = 0});

  @override
  State<HousesManagementView> createState() => _HousesManagementViewState();
}

class _HousesManagementViewState extends State<HousesManagementView> {
  late int _activeTab;
  bool _isLoading = true;
  List<HouseModel> _houses = [];
  String? _errorMessage;
  final Set<int> _selectedHouseIds = {};

  String? _selectedBlock;
  String? _selectedStatus;
  final _searchController = TextEditingController();

  int _currentPage = 1;
  int _pageSize = 15;

  List<String> _blocks = [];

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
    _fetchBlocks();
    _fetchHouses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchBlocks() async {
    try {
      final repo = context.read<ResidentRepository>();
      final serverBlocks = await repo.getHouseBlocks();
      if (mounted) {
        setState(() {
          _blocks = serverBlocks.toSet().toList()..sort();
          if (_selectedBlock != null && !_blocks.contains(_selectedBlock)) {
            _selectedBlock = null;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchHouses() async {
    final hasExistingData = _houses.isNotEmpty;
    if (!hasExistingData) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final repo = context.read<ResidentRepository>();
      final result = await repo.getHouses(
        block: _selectedBlock,
        status: _selectedStatus,
        search: _searchController.text.trim(),
      );
      if (mounted) {
        setState(() {
          _houses = result;
          _isLoading = false;
          _selectedHouseIds.removeWhere((id) => !result.any((h) => h.id == id));
          final maxPage =
              result.isNotEmpty ? (result.length / _pageSize).ceil() : 1;
          if (_currentPage > maxPage) {
            _currentPage = maxPage;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _showHouseDetailDialog(HouseModel house) {
    showDialog(
      context: context,
      builder: (ctx) => HouseDetailDialog(
        initialHouse: house,
        onDataChanged: _fetchHouses,
      ),
    );
  }

  void _showHouseOccupantsDialog(HouseModel house) {
    showDialog(
      context: context,
      builder: (ctx) => HouseOccupantsDialog(
        house: house,
        onDataChanged: _fetchHouses,
      ),
    );
  }

  void _showUnassignedResidentsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => UnassignedResidentsDialog(
        onMapped: _fetchHouses,
      ),
    );
  }

  void _showAddOrEditHouseDialog({HouseModel? house}) {
    final isEdit = house != null;
    final blockController = TextEditingController(text: house?.block ?? '');
    final numberController =
        TextEditingController(text: house?.houseNumber ?? '');
    String status = house?.status.toLowerCase() ?? 'kosong';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            isEdit ? 'Ubah Data Rumah' : 'Tambah Unit Rumah Baru',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Blok Rumah',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: blockController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'Contoh: A, B, C, D',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Nomor Rumah',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: numberController,
                  decoration: InputDecoration(
                    hintText: 'Contoh: 01, 12A, 15',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Status Rumah',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'milik', child: Text('Dihuni Pemilik')),
                    DropdownMenuItem(
                        value: 'kontrak', child: Text('Disewa / Kontrak')),
                    DropdownMenuItem(value: 'kosong', child: Text('Kosong')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => status = val);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final block = blockController.text.trim();
                final number = numberController.text.trim();
                if (block.isEmpty || number.isEmpty) {
                  return;
                }
                Navigator.pop(dialogCtx);

                try {
                  final repo = context.read<ResidentRepository>();
                  if (isEdit) {
                    await repo.updateHouse(house.id, block, number, status);
                  } else {
                    await repo.createHouse(block, number, status);
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEdit
                            ? 'Data rumah diperbarui'
                            : 'Rumah berhasil ditambahkan'),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                    _fetchBlocks();
                    _fetchHouses();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text(e.toString().replaceFirst('Exception: ', '')),
                        backgroundColor: AppTheme.danger,
                      ),
                    );
                  }
                }
              },
              child: Text(isEdit ? 'Simpan Perubahan' : 'Tambah Unit'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirm(HouseModel house) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Unit Rumah',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Yakin ingin menghapus data hunian ${house.label}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final repo = context.read<ResidentRepository>();
                await repo.deleteHouse(house.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Rumah berhasil dihapus'),
                        backgroundColor: AppTheme.success),
                  );
                  _fetchBlocks();
                  _fetchHouses();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text(e.toString().replaceFirst('Exception: ', '')),
                      backgroundColor: AppTheme.danger,
                    ),
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

  void _showBulkDeleteConfirm() {
    final count = _selectedHouseIds.length;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 24),
            SizedBox(width: 8),
            Text('Hapus Hunian Terpilih',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'Hapus $count data hunian yang dipilih? Data yang dihapus tidak dapat dikembalikan.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final idsToDelete = _selectedHouseIds.toList();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('Menghapus ${idsToDelete.length} data hunian...'),
                  duration: const Duration(seconds: 1),
                ),
              );

              try {
                final repo = context.read<ResidentRepository>();
                final deletedCount = await repo.bulkDeleteHouses(idsToDelete);
                if (mounted) {
                  setState(() {
                    _selectedHouseIds.clear();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('$deletedCount data hunian berhasil dihapus'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                  _fetchBlocks();
                  _fetchHouses();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text(e.toString().replaceFirst('Exception: ', '')),
                      backgroundColor: AppTheme.danger,
                    ),
                  );
                }
              }
            },
            child: const Text('Ya, Hapus'),
          ),
        ],
      ),
    );
  }

  Widget _buildBulkActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: AppTheme.primary, size: 20),
          const SizedBox(width: 10),
          Text(
            '${_selectedHouseIds.length} hunian dipilih',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => setState(() {
              _selectedHouseIds.addAll(_houses.map((h) => h.id));
            }),
            icon: const Icon(Icons.select_all_rounded, size: 16),
            label: Text('Pilih Semua (${_houses.length})'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => setState(() => _selectedHouseIds.clear()),
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('Batal Pilihan'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _showBulkDeleteConfirm,
            icon: const Icon(Icons.delete_sweep_rounded, size: 18),
            label: Text('Hapus Terpilih (${_selectedHouseIds.length})'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color text;
    String label;

    switch (status.toLowerCase()) {
      case 'milik':
        bg = const Color(0xFFDCFCE7);
        text = const Color(0xFF15803D);
        label = 'Dihuni Pemilik';
        break;
      case 'kontrak':
        bg = const Color(0xFFE0E7FF);
        text = const Color(0xFF4338CA);
        label = 'Kontrak';
        break;
      case 'kosong':
      default:
        bg = const Color(0xFFF1F5F9);
        text = const Color(0xFF64748B);
        label = 'Kosong';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTabButton(0, 'Kavling & Hunian', Icons.home_work_rounded),
          const SizedBox(width: 4),
          _buildTabButton(1, 'Manajemen Akun Warga', Icons.people_alt_rounded),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String title, IconData icon) {
    final isSelected = _activeTab == index;
    return InkWell(
      onTap: () => setState(() => _activeTab = index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_activeTab == 1) {
      return ResidentsManagementView(headerWidget: _buildTabBar());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTabBar(),
              const SizedBox(height: 16),
              // Header
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 16,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Master Data Hunian & Warga',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Kelola kavling hunian, nomor rumah, dan data penghuni cluster',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _showUnassignedResidentsDialog,
                        icon: const Icon(Icons.person_search_rounded,
                            size: 18, color: Color(0xFFD97706)),
                        label: const Text('Warga Belum Terpetakan',
                            style: TextStyle(color: Color(0xFFB45309))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFDE68A)),
                          backgroundColor: const Color(0xFFFFFBEB),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showAddOrEditHouseDialog(),
                        icon: const Icon(Icons.add_home_rounded, size: 18),
                        label: const Text('Tambah Rumah Baru'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Filter Bar
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                elevation: 0,
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Search box
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Cari nomor rumah atau nama warga...',
                            prefixIcon:
                                const Icon(Icons.search_rounded, size: 20),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      _currentPage = 1;
                                      _fetchHouses();
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                          onSubmitted: (_) {
                            _currentPage = 1;
                            _fetchHouses();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Blok Filter
                      DropdownButton<String?>(
                        value: _blocks.any((b) => b == _selectedBlock)
                            ? _selectedBlock
                            : null,
                        underline: const SizedBox(),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Semua Blok'),
                          ),
                          ..._blocks
                              .toSet()
                              .map((b) => DropdownMenuItem<String?>(
                                    value: b,
                                    child: Text('Blok $b'),
                                  )),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedBlock = val;
                            _currentPage = 1;
                          });
                          _fetchHouses();
                        },
                      ),
                      const SizedBox(width: 12),

                      // Status Filter
                      DropdownButton<String?>(
                        value: const ['milik', 'kontrak', 'kosong']
                                .contains(_selectedStatus)
                            ? _selectedStatus
                            : null,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Semua Status'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'milik',
                            child: Text('MILIK'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'kontrak',
                            child: Text('KONTRAK'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'kosong',
                            child: Text('KOSONG'),
                          ),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedStatus = val;
                            _currentPage = 1;
                          });
                          _fetchHouses();
                        },
                      ),
                      const SizedBox(width: 12),

                      IconButton(
                        tooltip: 'Segarkan',
                        icon: const Icon(Icons.refresh_rounded),
                        onPressed: _fetchHouses,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppTheme.danger, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_errorMessage!,
                            style: const TextStyle(color: AppTheme.danger)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.danger,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                        ),
                        onPressed: _fetchHouses,
                        child: const Text('Coba Lagi',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),

              // Bulk Action Bar
              if (_selectedHouseIds.isNotEmpty) ...[
                _buildBulkActionBar(),
                const SizedBox(height: 16),
              ],

              // Data Table Card
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                elevation: 0,
                color: Colors.white,
                child: (_isLoading && _houses.isEmpty)
                    ? const Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _houses.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(48),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.home_work_outlined,
                                      size: 56, color: Colors.grey),
                                  SizedBox(height: 12),
                                  Text(
                                    'Tidak ada data yang sesuai dengan filter yang dipilih.',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Builder(
                            builder: (context) {
                              final totalItems = _houses.length;
                              final totalPages = totalItems > 0
                                  ? (totalItems / _pageSize).ceil()
                                  : 1;
                              final clampedPage = _currentPage > totalPages
                                  ? totalPages
                                  : (_currentPage < 1 ? 1 : _currentPage);
                              final startIndex = (clampedPage - 1) * _pageSize;
                              final pagedHouses = _houses
                                  .skip(startIndex)
                                  .take(_pageSize)
                                  .toList();

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      headingRowColor: WidgetStateProperty.all(
                                          const Color(0xFFF8FAFC)),
                                      columnSpacing: 28,
                                      columns: const [
                                        DataColumn(
                                            label: Text('No. Rumah',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold))),
                                        DataColumn(
                                            label: Text('Status Huni',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold))),
                                        DataColumn(
                                            label: Text('Kepala Keluarga',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold))),
                                        DataColumn(
                                            label: Text('Anggota Keluarga',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold))),
                                        DataColumn(
                                            label: Text('Kendaraan',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold))),
                                        DataColumn(
                                            label: Text('No. Kontak',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold))),
                                        DataColumn(
                                            label: Text('Aksi',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold))),
                                      ],
                                      rows: pagedHouses.map((h) {
                                        final isSelected =
                                            _selectedHouseIds.contains(h.id);
                                        return DataRow(
                                          selected: isSelected,
                                          onSelectChanged: (bool? selected) {
                                            setState(() {
                                              if (selected == true) {
                                                _selectedHouseIds.add(h.id);
                                              } else {
                                                _selectedHouseIds.remove(h.id);
                                              }
                                            });
                                          },
                                          cells: [
                                            DataCell(
                                              Row(
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: AppTheme.primary
                                                          .withOpacity(0.08),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    child: const Icon(
                                                        Icons.home_rounded,
                                                        color: AppTheme.primary,
                                                        size: 18),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Text(
                                                    'Blok ${h.block} No. ${h.houseNumber}',
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                              onTap: () =>
                                                  _showHouseDetailDialog(h),
                                            ),
                                            DataCell(
                                              _buildStatusBadge(h.status),
                                              onTap: () =>
                                                  _showHouseDetailDialog(h),
                                            ),
                                            DataCell(
                                              Text(
                                                h.residentName ?? '—',
                                                style: TextStyle(
                                                  fontWeight:
                                                      h.residentName != null
                                                          ? FontWeight.w600
                                                          : FontWeight.normal,
                                                  color: h.residentName != null
                                                      ? AppTheme.textPrimary
                                                      : Colors.grey,
                                                ),
                                              ),
                                              onTap: () =>
                                                  _showHouseDetailDialog(h),
                                            ),
                                            DataCell(
                                              Text(
                                                '${h.totalOccupants} Jiwa',
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w600),
                                              ),
                                              onTap: () =>
                                                  _showHouseDetailDialog(h),
                                            ),
                                            DataCell(
                                              Text('${h.vehicleCount} Unit'),
                                              onTap: () =>
                                                  _showHouseDetailDialog(h),
                                            ),
                                            DataCell(
                                              Text(h.residentPhone ?? '—'),
                                              onTap: () =>
                                                  _showHouseDetailDialog(h),
                                            ),
                                            DataCell(
                                              Row(
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(
                                                        Icons
                                                            .visibility_outlined,
                                                        size: 18,
                                                        color:
                                                            AppTheme.primary),
                                                    tooltip:
                                                        'Detail Hunian Lengkap',
                                                    onPressed: () =>
                                                        _showHouseDetailDialog(
                                                            h),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(
                                                        Icons
                                                            .people_alt_outlined,
                                                        size: 18,
                                                        color:
                                                            Color(0xFF6366F1)),
                                                    tooltip:
                                                        'Kelola Pemetaan Warga',
                                                    onPressed: () =>
                                                        _showHouseOccupantsDialog(
                                                            h),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(
                                                        Icons.edit_outlined,
                                                        size: 18,
                                                        color: AppTheme
                                                            .textSecondary),
                                                    tooltip: 'Ubah Data Rumah',
                                                    onPressed: () =>
                                                        _showAddOrEditHouseDialog(
                                                            house: h),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(
                                                        Icons
                                                            .delete_outline_rounded,
                                                        size: 18,
                                                        color: AppTheme.danger),
                                                    tooltip: 'Hapus Rumah',
                                                    onPressed: () =>
                                                        _showDeleteConfirm(h),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  TablePaginationControl(
                                    currentPage: clampedPage,
                                    totalItems: totalItems,
                                    pageSize: _pageSize,
                                    keyPrefix: 'houses_pagination',
                                    isDesktop:
                                        MediaQuery.of(context).size.width >=
                                            768,
                                    onPageChanged: (newPage) {
                                      setState(() => _currentPage = newPage);
                                    },
                                    onPageSizeChanged: (newSize) {
                                      setState(() {
                                        _pageSize = newSize;
                                        _currentPage = 1;
                                      });
                                    },
                                  ),
                                ],
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
