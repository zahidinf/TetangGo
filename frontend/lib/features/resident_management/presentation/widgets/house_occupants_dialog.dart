import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/resident_repository.dart';
import '../../domain/models/house_model.dart';
import '../../domain/models/occupant_model.dart';

class HouseOccupantsDialog extends StatefulWidget {
  final HouseModel house;
  final VoidCallback onDataChanged;

  const HouseOccupantsDialog({
    super.key,
    required this.house,
    required this.onDataChanged,
  });

  @override
  State<HouseOccupantsDialog> createState() => _HouseOccupantsDialogState();
}

class _HouseOccupantsDialogState extends State<HouseOccupantsDialog> {
  bool _isLoading = true;
  List<HouseOccupantModel> _occupants = [];
  String? _errorMessage;
  late String _currentStatus;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.house.status.toLowerCase();
    _fetchOccupants();
  }

  Future<void> _fetchOccupants() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = context.read<ResidentRepository>();
      final list = await repo.getHouseOccupants(widget.house.id);
      if (mounted) {
        setState(() {
          _occupants = list;
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

  Future<void> _updateHouseStatus(String newStatus) async {
    if (newStatus == _currentStatus) return;

    try {
      final repo = context.read<ResidentRepository>();
      await repo.updateHouse(widget.house.id, widget.house.block,
          widget.house.houseNumber, newStatus);
      if (mounted) {
        setState(() => _currentStatus = newStatus);
        widget.onDataChanged();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Status rumah diperbarui'),
              backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString().replaceFirst('Exception: ', '')),
              backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  void _showRemoveResidentDialog(HouseOccupantModel occupant) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.person_remove_rounded,
            color: AppTheme.danger, size: 48),
        title: const Text('Lepas Hubungan Warga',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Keluarkan ${occupant.displayName} dari ${widget.house.label}?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Akun warga akan tetap aktif di sistem, namun tidak lagi terikat dengan unit rumah ini.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ],
        ),
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
                await repo.removeResident(
                    houseId: widget.house.id, userId: occupant.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Warga berhasil dilepas dari rumah'),
                        backgroundColor: AppTheme.success),
                  );
                  _fetchOccupants();
                  widget.onDataChanged();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content:
                            Text(e.toString().replaceFirst('Exception: ', '')),
                        backgroundColor: AppTheme.danger),
                  );
                }
              }
            },
            child: const Text('Lepas Warga'),
          ),
        ],
      ),
    );
  }

  void _showAssignResidentDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _AssignResidentSubDialog(
        currentHouse: widget.house,
        onSuccess: () {
          _fetchOccupants();
          widget.onDataChanged();
        },
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: const ['milik', 'kontrak', 'kosong'].contains(_currentStatus)
              ? _currentStatus
              : 'kosong',
          isDense: true,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary),
          items: const [
            DropdownMenuItem(value: 'milik', child: Text('Dihuni Pemilik')),
            DropdownMenuItem(value: 'kontrak', child: Text('Disewa / Kontrak')),
            DropdownMenuItem(value: 'kosong', child: Text('Rumah Kosong')),
          ],
          onChanged: (val) {
            if (val != null) _updateHouseStatus(val);
          },
        ),
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
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Modal
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.cottage_rounded,
                        color: AppTheme.primary, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detail & Penghuni ${widget.house.label}',
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text('Status Huni: ',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textSecondary)),
                            const SizedBox(width: 6),
                            _buildStatusDropdown(),
                          ],
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
              const Divider(height: 28),

              // Sub-header & Action Petakan
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Daftar Akun Penghuni',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_occupants.length} Akun Warga',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _showAssignResidentDialog,
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                    label: const Text('Petakan Warga',
                        style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
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
                  child: Text(_errorMessage!,
                      style: const TextStyle(
                          color: AppTheme.danger, fontSize: 13)),
                ),

              // Occupants List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _occupants.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.person_off_outlined,
                                      size: 52, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Belum ada akun warga di rumah ini',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textPrimary),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Klik tombol "+ Petakan Warga" di atas untuk menambahkan warga terdaftar.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _occupants.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final occ = _occupants[index];
                              return Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(
                                      color: Color(0xFFE2E8F0)),
                                ),
                                elevation: 0,
                                color: Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor:
                                            AppTheme.primary.withOpacity(0.12),
                                        child: Text(
                                          occ.name.isNotEmpty
                                              ? occ.name[0].toUpperCase()
                                              : 'W',
                                          style: const TextStyle(
                                            color: AppTheme.primaryDark,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  occ.displayName,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        occ.ownershipStatus ==
                                                                'pengontrak'
                                                            ? const Color(
                                                                0xFFEEF2FF)
                                                            : const Color(
                                                                0xFFDCFCE7),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                  ),
                                                  child: Text(
                                                    occ.ownershipDisplay,
                                                    style: TextStyle(
                                                      color:
                                                          occ.ownershipStatus ==
                                                                  'pengontrak'
                                                              ? const Color(
                                                                  0xFF4338CA)
                                                              : const Color(
                                                                  0xFF15803D),
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${occ.phone} • ${occ.email}',
                                              style: const TextStyle(
                                                  color: AppTheme.textSecondary,
                                                  fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.link_off_rounded,
                                            color: AppTheme.danger, size: 20),
                                        tooltip: 'Lepas Warga dari Rumah Ini',
                                        onPressed: () =>
                                            _showRemoveResidentDialog(occ),
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

class _AssignResidentSubDialog extends StatefulWidget {
  final HouseModel currentHouse;
  final VoidCallback onSuccess;

  const _AssignResidentSubDialog({
    required this.currentHouse,
    required this.onSuccess,
  });

  @override
  State<_AssignResidentSubDialog> createState() =>
      _AssignResidentSubDialogState();
}

class _AssignResidentSubDialogState extends State<_AssignResidentSubDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  List<UnassignedResidentModel> _unassignedResidents = [];
  UnassignedResidentModel? _selectedUnassigned;

  List<HouseModel> _allHouses = [];
  HouseModel? _selectedSourceHouse;
  List<HouseOccupantModel> _sourceOccupants = [];
  HouseOccupantModel? _selectedSourceOccupant;

  String _occupantType = 'pemilik';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final repo = context.read<ResidentRepository>();
      final unassigned = await repo.getUnassignedResidents();
      final houses = await repo.getHouses();
      if (mounted) {
        setState(() {
          _unassignedResidents = unassigned;
          _allHouses =
              houses.where((h) => h.id != widget.currentHouse.id).toList();
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

  Future<void> _onSourceHouseSelected(HouseModel? house) async {
    setState(() {
      _selectedSourceHouse = house;
      _selectedSourceOccupant = null;
      _sourceOccupants = [];
    });
    if (house == null) return;

    try {
      final repo = context.read<ResidentRepository>();
      final occupants = await repo.getHouseOccupants(house.id);
      if (mounted) {
        setState(() => _sourceOccupants = occupants);
      }
    } catch (_) {}
  }

  Future<void> _submitAssignment() async {
    final repo = context.read<ResidentRepository>();
    final isUnassignedTab = _tabController.index == 0;

    int? targetUserId;
    if (isUnassignedTab) {
      targetUserId = _selectedUnassigned?.id;
    } else {
      targetUserId = _selectedSourceOccupant?.id;
    }

    if (targetUserId == null) {
      setState(() => _errorMessage = 'Silakan pilih warga terlebih dahulu');
      return;
    }

    try {
      if (isUnassignedTab) {
        await repo.assignResident(
          houseId: widget.currentHouse.id,
          userId: targetUserId,
          occupantType: _occupantType,
        );
      } else {
        await repo.transferHouse(
          userId: targetUserId,
          newHouseId: widget.currentHouse.id,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Warga berhasil dipetakan ke rumah ini'),
              backgroundColor: AppTheme.success),
        );
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(
            () => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Petakan Warga ke ${widget.currentHouse.label}',
          style: const TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TabBar(
              controller: _tabController,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.primary,
              tabs: const [
                Tab(text: 'Warga Belum Ada Rumah'),
                Tab(text: 'Pindah dari Rumah Lain'),
              ],
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_errorMessage!,
                    style:
                        const TextStyle(color: AppTheme.danger, fontSize: 12)),
              ),
            _isLoading
                ? const Center(
                    child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator()))
                : SizedBox(
                    height: 190,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Tab 1: Unassigned
                        _unassignedResidents.isEmpty
                            ? const Center(
                                child: Text(
                                    'Tidak ada warga berstatus belum terpetakan saat ini.',
                                    style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 13)),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Pilih Warga:',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<
                                      UnassignedResidentModel>(
                                    value: _selectedUnassigned,
                                    isExpanded: true,
                                    hint: const Text(
                                        'Pilih dari daftar warga belum terpetakan'),
                                    decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8))),
                                    items: _unassignedResidents.map((u) {
                                      return DropdownMenuItem(
                                          value: u,
                                          child: Text(
                                              '${u.displayName} (${u.phone})'));
                                    }).toList(),
                                    onChanged: (val) => setState(
                                        () => _selectedUnassigned = val),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text('Status Kepemilikan:',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    value: _occupantType,
                                    decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8))),
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'pemilik',
                                          child: Text('Pemilik Rumah')),
                                      DropdownMenuItem(
                                          value: 'pengontrak',
                                          child: Text('Penyewa / Pengontrak')),
                                      DropdownMenuItem(
                                          value: 'anggota_keluarga',
                                          child: Text('Anggota Keluarga')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null)
                                        setState(() => _occupantType = val);
                                    },
                                  ),
                                ],
                              ),

                        // Tab 2: Pindah dari rumah lain
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Pilih Rumah Asal:',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<HouseModel>(
                              value: _selectedSourceHouse,
                              isExpanded: true,
                              hint: const Text('Pilih nomor rumah asal warga'),
                              decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8))),
                              items: _allHouses.map((h) {
                                return DropdownMenuItem(
                                    value: h,
                                    child: Text(
                                        '${h.label} (${h.statusDisplay})'));
                              }).toList(),
                              onChanged: _onSourceHouseSelected,
                            ),
                            const SizedBox(height: 12),
                            const Text('Pilih Warga yang Dipindahkan:',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<HouseOccupantModel>(
                              value: _selectedSourceOccupant,
                              isExpanded: true,
                              hint: Text(_selectedSourceHouse == null
                                  ? 'Pilih rumah asal dulu'
                                  : 'Pilih warga'),
                              decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8))),
                              items: _sourceOccupants.map((o) {
                                return DropdownMenuItem(
                                    value: o,
                                    child:
                                        Text('${o.displayName} (${o.phone})'));
                              }).toList(),
                              onChanged: (val) =>
                                  setState(() => _selectedSourceOccupant = val),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _submitAssignment,
          child: const Text('Simpan Pemetaan'),
        ),
      ],
    );
  }
}
