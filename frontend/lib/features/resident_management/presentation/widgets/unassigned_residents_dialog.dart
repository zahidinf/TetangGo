import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/resident_repository.dart';
import '../../domain/models/house_model.dart';
import '../../domain/models/occupant_model.dart';

class UnassignedResidentsDialog extends StatefulWidget {
  final VoidCallback onMapped;

  const UnassignedResidentsDialog({super.key, required this.onMapped});

  @override
  State<UnassignedResidentsDialog> createState() => _UnassignedResidentsDialogState();
}

class _UnassignedResidentsDialogState extends State<UnassignedResidentsDialog> {
  bool _isLoading = true;
  List<UnassignedResidentModel> _residents = [];
  String? _errorMessage;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUnassigned();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUnassigned() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = context.read<ResidentRepository>();
      final list = await repo.getUnassignedResidents(search: _searchController.text.trim());
      if (mounted) {
        setState(() {
          _residents = list;
          _isLoading = false;
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

  void _showQuickMapDialog(UnassignedResidentModel resident) {
    showDialog(
      context: context,
      builder: (ctx) => _QuickMapToHouseDialog(
        resident: resident,
        onSuccess: () {
          _fetchUnassigned();
          widget.onMapped();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.person_search_rounded, color: Color(0xFFD97706), size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Warga Belum Terpetakan',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_residents.length} Warga',
                                style: const TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Daftar akun warga aktif yang belum memiliki atau belum terhubung dengan nomor rumah',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Search Bar
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Cari nama atau no. handphone warga...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  _fetchUnassigned();
                                },
                              )
                            : null,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onSubmitted: (_) => _fetchUnassigned(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _fetchUnassigned,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cari'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_errorMessage!, style: const TextStyle(color: AppTheme.danger, fontSize: 13)),
                ),

              // List of unassigned
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _residents.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.check_circle_outline_rounded, size: 56, color: AppTheme.success),
                                  SizedBox(height: 12),
                                  Text(
                                    'Semua warga sudah terpetakan!',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Tidak ada akun warga aktif yang belum memiliki rumah.',
                                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _residents.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final resident = _residents[index];
                              return Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                elevation: 0,
                                color: Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor: AppTheme.primary.withOpacity(0.12),
                                        child: Text(
                                          resident.name.isNotEmpty ? resident.name[0].toUpperCase() : 'W',
                                          style: const TextStyle(
                                            color: AppTheme.primaryDark,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  resident.displayName,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFFEF3C7),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: const Text(
                                                    'Belum Ada Rumah',
                                                    style: TextStyle(
                                                      color: Color(0xFFB45309),
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${resident.phone} • ${resident.email}',
                                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: () => _showQuickMapDialog(resident),
                                        icon: const Icon(Icons.add_home_rounded, size: 16),
                                        label: const Text('Petakan ke Rumah'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.primary,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          elevation: 0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Tutup'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickMapToHouseDialog extends StatefulWidget {
  final UnassignedResidentModel resident;
  final VoidCallback onSuccess;

  const _QuickMapToHouseDialog({
    required this.resident,
    required this.onSuccess,
  });

  @override
  State<_QuickMapToHouseDialog> createState() => _QuickMapToHouseDialogState();
}

class _QuickMapToHouseDialogState extends State<_QuickMapToHouseDialog> {
  bool _isLoading = true;
  List<HouseModel> _allHouses = [];
  List<String> _blocks = [];
  String? _selectedBlock;
  HouseModel? _selectedHouse;
  String _occupantType = 'pemilik';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchHouses();
  }

  Future<void> _fetchHouses() async {
    setState(() => _isLoading = true);
    try {
      final repo = context.read<ResidentRepository>();
      final list = await repo.getHouses();
      final blocks = list.map((h) => h.block).toSet().toList()..sort();

      if (mounted) {
        setState(() {
          _allHouses = list;
          _blocks = blocks;
          if (_blocks.isNotEmpty) {
            _selectedBlock = _blocks.first;
          }
          _isLoading = false;
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

  List<HouseModel> get _filteredHouses {
    if (_selectedBlock == null) return _allHouses;
    return _allHouses.where((h) => h.block == _selectedBlock).toList();
  }

  Future<void> _submitMapping() async {
    if (_selectedHouse == null) {
      setState(() => _errorMessage = 'Silakan pilih nomor rumah');
      return;
    }

    try {
      final repo = context.read<ResidentRepository>();
      await repo.assignResident(
        houseId: _selectedHouse!.id,
        userId: widget.resident.id,
        occupantType: _occupantType,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.resident.name} berhasil dipetakan ke ${_selectedHouse!.label}!'),
            backgroundColor: AppTheme.success,
          ),
        );
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.add_home_work_rounded, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Petakan: ${widget.resident.name}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_errorMessage!, style: const TextStyle(color: AppTheme.danger, fontSize: 12)),
              ),

            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else ...[
              // Step 1: Pilih Blok
              const Text('1. Pilih Blok Rumah:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedBlock,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: _blocks.map((b) => DropdownMenuItem(value: b, child: Text('Blok $b'))).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedBlock = val;
                    _selectedHouse = null;
                  });
                },
              ),
              const SizedBox(height: 12),

              // Step 2: Pilih Nomor Rumah
              const Text('2. Pilih Nomor Rumah:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<HouseModel>(
                value: _selectedHouse,
                isExpanded: true,
                hint: const Text('Pilih nomor rumah di blok ini'),
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: _filteredHouses.map((h) {
                  return DropdownMenuItem(
                    value: h,
                    child: Text('${h.label} (${h.statusDisplay})'),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedHouse = val),
              ),
              const SizedBox(height: 12),

              // Step 3: Status Kepemilikan
              const Text('3. Status Kepemilikan:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _occupantType,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: const [
                  DropdownMenuItem(value: 'pemilik', child: Text('Pemilik Rumah')),
                  DropdownMenuItem(value: 'pengontrak', child: Text('Penyewa / Kontrak')),
                  DropdownMenuItem(value: 'anggota_keluarga', child: Text('Anggota Keluarga')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _occupantType = val);
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _submitMapping,
          child: const Text('Petakan'),
        ),
      ],
    );
  }
}
