import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/resident_repository.dart';
import '../domain/models/house_model.dart';
import '../domain/models/resident_user_model.dart';
import 'widgets/reset_password_dialog.dart';
import 'widgets/user_form_dialog.dart';

class ResidentsManagementView extends StatefulWidget {
  final Widget? headerWidget;
  const ResidentsManagementView({super.key, this.headerWidget});

  @override
  State<ResidentsManagementView> createState() => _ResidentsManagementViewState();
}

class _ResidentsManagementViewState extends State<ResidentsManagementView> {
  final _searchController = TextEditingController();
  ResidentRepository get _repo => context.read<ResidentRepository>();

  bool _isLoading = true;
  String? _errorMessage;
  List<ResidentUserModel> _users = [];
  List<HouseModel> _houses = [];

  String? _selectedStatus;
  int? _selectedHouseId;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _fetchHouses(),
      _fetchUsers(),
    ]);
  }

  Future<void> _fetchHouses() async {
    try {
      final houses = await _repo.getHouses();
      if (mounted) {
        setState(() => _houses = houses);
      }
    } catch (_) {}
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final users = await _repo.getAdminUsers(
        search: _searchController.text.trim(),
        status: _selectedStatus,
        houseId: _selectedHouseId,
      );

      if (mounted) {
        setState(() {
          _users = users;
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

  void _showAddUserDialog() {
    showDialog(
      context: context,
      builder: (ctx) => UserFormDialog(
        houses: _houses,
        onSaved: () {
          _fetchUsers();
          _fetchHouses();
        },
      ),
    );
  }

  void _showEditUserDialog(ResidentUserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => UserFormDialog(
        userToEdit: user,
        houses: _houses,
        onSaved: () {
          _fetchUsers();
          _fetchHouses();
        },
      ),
    );
  }

  void _showResetPasswordDialog(ResidentUserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => ResetPasswordDialog(
        user: user,
        onResetSuccess: _fetchUsers,
      ),
    );
  }

  void _showDeleteUserConfirm(ResidentUserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 24),
            SizedBox(width: 8),
            Text('Hapus Akun Warga', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'Hapus akun "${user.name}"? Data akun ini akan dihapus permanen dari sistem.',
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _repo.adminDeleteUser(user.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Akun warga "${user.name}" berhasil dihapus'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                  _fetchUsers();
                  _fetchHouses();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString().replaceFirst('Exception: ', '')),
                      backgroundColor: AppTheme.danger,
                    ),
                  );
                }
              }
            },
            child: const Text('Hapus Akun'),
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
      case 'active':
        bg = const Color(0xFFDCFCE7);
        text = const Color(0xFF15803D);
        label = 'Aktif';
        break;
      case 'pending_verification':
        bg = const Color(0xFFFEF3C7);
        text = const Color(0xFFB45309);
        label = 'Menunggu';
        break;
      case 'rejected':
        bg = const Color(0xFFFEE2E2);
        text = const Color(0xFFB91C1C);
        label = 'Ditolak';
        break;
      case 'inactive':
      default:
        bg = const Color(0xFFF1F5F9);
        text = const Color(0xFF64748B);
        label = 'Non-Aktif';
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
        style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.headerWidget != null) ...[
                widget.headerWidget!,
                const SizedBox(height: 16),
              ],
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Manajemen Data Warga',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Kelola akun seluruh warga RT, perbarui data hunian, reset password, dan status akun',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _showAddUserDialog,
                    icon: const Icon(Icons.person_add_rounded, size: 18),
                    label: const Text('+ Tambah Warga Baru'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
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
                      // Search Box
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Cari Nama, No WhatsApp, atau Email...',
                            prefixIcon: const Icon(Icons.search_rounded, size: 20),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      _fetchUsers();
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          onSubmitted: (_) => _fetchUsers(),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Status Dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: const ['active', 'pending_verification', 'inactive'].contains(_selectedStatus)
                                ? _selectedStatus
                                : null,
                            items: const [
                              DropdownMenuItem<String?>(value: null, child: Text('Semua Status', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem<String?>(value: 'active', child: Text('Status: Aktif', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem<String?>(value: 'pending_verification', child: Text('Status: Menunggu', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem<String?>(value: 'inactive', child: Text('Status: Non-Aktif', style: TextStyle(fontSize: 13))),
                            ],
                            onChanged: (val) {
                              setState(() => _selectedStatus = val);
                              _fetchUsers();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // House Filter Dropdown
                      Builder(builder: (context) {
                        final uniqueHouses = <int, HouseModel>{};
                        for (final h in _houses) {
                          uniqueHouses[h.id] = h;
                        }
                        final houseList = uniqueHouses.values.toList();
                        final currentHouseValue = houseList.any((h) => h.id == _selectedHouseId) ? _selectedHouseId : null;

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int?>(
                              value: currentHouseValue,
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('Semua Hunian', style: TextStyle(fontSize: 13)),
                                ),
                                ...houseList.map((h) => DropdownMenuItem<int?>(
                                      value: h.id,
                                      child: Text(h.label, style: const TextStyle(fontSize: 13)),
                                    )),
                              ],
                              onChanged: (val) {
                                setState(() => _selectedHouseId = val);
                                _fetchUsers();
                              },
                            ),
                          ),
                        );
                      }),
                      const SizedBox(width: 12),

                      // Refresh button
                      IconButton(
                        tooltip: 'Segarkan Data',
                        icon: const Icon(Icons.refresh_rounded, color: AppTheme.primary),
                        onPressed: () {
                          _fetchHouses();
                          _fetchUsers();
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Content Area
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(48.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_errorMessage != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 40),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, style: const TextStyle(color: AppTheme.danger)),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _fetchUsers, child: const Text('Coba Lagi')),
                      ],
                    ),
                  ),
                )
              else if (_users.isEmpty)
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: const Padding(
                    padding: EdgeInsets.all(48.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.people_outline_rounded, size: 48, color: AppTheme.textSecondary),
                          SizedBox(height: 12),
                          Text('Tidak ada data yang sesuai dengan filter yang dipilih.', style: TextStyle(color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                )
              else
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  elevation: 0,
                  clipBehavior: Clip.antiAlias,
                  color: Colors.white,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 950),
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                        horizontalMargin: 20,
                        columnSpacing: 24,
                        headingTextStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                        ),
                        columns: const [
                          DataColumn(label: Text('AVATAR')),
                          DataColumn(label: Text('NAMA LENGKAP')),
                          DataColumn(label: Text('NO. WHATSAPP')),
                          DataColumn(label: Text('EMAIL')),
                          DataColumn(label: Text('HUNIAN (BLOK & NO)')),
                          DataColumn(label: Text('STATUS')),
                          DataColumn(label: Text('AKSI')),
                        ],
                        rows: _users.map((user) {
                          return DataRow(
                            cells: [
                              // Avatar
                              DataCell(
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: AppTheme.primary.withOpacity(0.12),
                                  child: Text(
                                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                                    style: const TextStyle(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              // Nama Lengkap
                              DataCell(
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.name,
                                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                                    ),
                                    Text(
                                      user.role.toUpperCase(),
                                      style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              // No WhatsApp
                              DataCell(
                                Text(user.phone, style: const TextStyle(fontSize: 13)),
                              ),
                              // Email
                              DataCell(
                                Text(user.email, style: const TextStyle(fontSize: 13)),
                              ),
                              // Hunian
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      user.house != null ? Icons.home_rounded : Icons.home_outlined,
                                      size: 16,
                                      color: user.house != null ? AppTheme.primary : AppTheme.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      user.houseDisplay,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: user.house != null ? FontWeight.w500 : FontWeight.normal,
                                        color: user.house != null ? AppTheme.textPrimary : AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Status Badge
                              DataCell(_buildStatusBadge(user.status)),
                              // Aksi: 1. Edit (Pensil), 2. Reset Password (Kunci), 3. Hapus (Sampah Merah)
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // 1. Edit
                                    Tooltip(
                                      message: 'Edit Data Warga',
                                      child: IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primary),
                                        onPressed: () => _showEditUserDialog(user),
                                      ),
                                    ),
                                    // 2. Reset Password
                                    Tooltip(
                                      message: 'Reset Kata Sandi',
                                      child: IconButton(
                                        icon: const Icon(Icons.key_outlined, size: 18, color: Color(0xFFD97706)),
                                        onPressed: () => _showResetPasswordDialog(user),
                                      ),
                                    ),
                                    // 3. Hapus
                                    Tooltip(
                                      message: 'Hapus Akun Warga',
                                      child: IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.danger),
                                        onPressed: () => _showDeleteUserConfirm(user),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
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
