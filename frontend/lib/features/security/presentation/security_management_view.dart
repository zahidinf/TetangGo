import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/bloc/auth_bloc.dart';
import '../data/security_repository.dart';
import '../domain/models/security_models.dart';
import 'widgets/add_security_dialog.dart';
import 'widgets/security_assignment_dialog.dart';

class SecurityManagementView extends StatefulWidget {
  final Widget? headerWidget;

  const SecurityManagementView({super.key, this.headerWidget});

  @override
  State<SecurityManagementView> createState() => _SecurityManagementViewState();
}

class _SecurityManagementViewState extends State<SecurityManagementView> {
  final _searchController = TextEditingController();
  SecurityRepository get _repo => context.read<SecurityRepository>();

  bool _isLoading = true;
  String? _errorMessage;

  List<SecurityUserModel> _allUsers = [];
  List<SecurityAssignmentModel> _allAssignments = [];
  String _selectedStatusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final hasExistingData = _allUsers.isNotEmpty;
    if (!hasExistingData) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final results = await Future.wait([
        _repo.getAdminSecurityUsers(),
        _repo.getAdminAssignments(),
      ]);

      if (mounted) {
        final rawUsers = results[0] as List<SecurityUserModel>;
        final assignments = results[1] as List<SecurityAssignmentModel>;

        // Map assignments to users
        final usersWithAssignments = rawUsers.map((u) {
          final userAssigns =
              assignments.where((a) => a.userId == u.id).toList();
          return u.copyWith(assignments: userAssigns);
        }).toList();

        setState(() {
          _allUsers = usersWithAssignments;
          _allAssignments = assignments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  void _showAddSecurityDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AddSecurityDialog(
        onSaved: _loadData,
      ),
    );
  }

  void _showAssignmentDialog(SecurityUserModel user) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SecurityAssignmentDialog(
        user: user,
        onUpdated: _loadData,
      ),
    );
  }

  Future<void> _confirmToggleStatus(SecurityUserModel user) async {
    final newStatus = user.isActive ? 'inactive' : 'active';
    final actionLabel = user.isActive ? 'Nonaktifkan' : 'Aktifkan';
    final actionColor = user.isActive ? AppTheme.danger : AppTheme.success;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              user.isActive
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_outline_rounded,
              color: actionColor,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text('$actionLabel Akun Satpam',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          user.isActive
              ? 'Nonaktifkan akun "${user.displayName}"? Petugas ini tidak akan dapat login atau merespon alarm darurat pos satpam.'
              : 'Aktifkan kembali akun "${user.displayName}" agar dapat bertugas dan menerima sinyal darurat pos satpam?',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: actionColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _repo.setSecurityUserStatus(user.id, newStatus);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Status akun "${user.displayName}" berhasil diubah menjadi ${newStatus == 'active' ? 'Aktif' : 'Non-Aktif'}.'),
              backgroundColor: AppTheme.success,
            ),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: AppTheme.danger,
            ),
          );
        }
      }
    }
  }

  List<SecurityUserModel> get _filteredUsers {
    final query = _searchController.text.trim().toLowerCase();
    return _allUsers.where((u) {
      if (_selectedStatusFilter == 'active' && !u.isActive) return false;
      if (_selectedStatusFilter == 'inactive' && u.isActive) return false;

      if (query.isNotEmpty) {
        final matchesName = u.name.toLowerCase().contains(query);
        final matchesPhone = u.phone.toLowerCase().contains(query);
        final matchesEmail = u.email.toLowerCase().contains(query);
        return matchesName || matchesPhone || matchesEmail;
      }
      return true;
    }).toList();
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bg,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authUser = context.watch<AuthBloc>().state.user;

    // RBAC: Verify authorized leadership access
    if (authUser == null || !authUser.canAccessLeadership) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.gpp_bad_rounded, size: 56, color: AppTheme.danger),
              SizedBox(height: 16),
              Text(
                'Akses Terbatas: Hanya Pengurus',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary),
              ),
              SizedBox(height: 6),
              Text(
                'Menu Manajemen Satpam hanya dapat diakses oleh Admin, Ketua, dan Wakil Ketua.',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final totalUsers = _allUsers.length;
    final activeUsers = _allUsers.where((u) => u.isActive).length;
    final inactiveUsers = _allUsers.where((u) => !u.isActive).length;
    final activeAssignmentsCount =
        _allAssignments.where((a) => a.isActive).length;

    final displayUsers = _filteredUsers;

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

              // Header Bar
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
                        'Manajemen Petugas Keamanan (Satpam)',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Kelola akun petugas satpam cluster dan penugasan lingkungan kerja pos satpam',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _showAddSecurityDialog,
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: const Text('+ Tambah Satpam Baru'),
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
              const SizedBox(height: 20),

              // Summary Cards
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 768;
                  if (isCompact) {
                    return Column(
                      children: [
                        Row(
                          children: [
                            _buildSummaryCard(
                              title: 'Total Akun Satpam',
                              value: totalUsers.toString(),
                              icon: Icons.badge_outlined,
                              color: AppTheme.primary,
                              bg: AppTheme.primary.withOpacity(0.1),
                            ),
                            const SizedBox(width: 12),
                            _buildSummaryCard(
                              title: 'Satpam Aktif',
                              value: activeUsers.toString(),
                              icon: Icons.check_circle_outline_rounded,
                              color: const Color(0xFF16A34A),
                              bg: const Color(0xFFDCFCE7),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildSummaryCard(
                              title: 'Satpam Nonaktif',
                              value: inactiveUsers.toString(),
                              icon: Icons.cancel_outlined,
                              color: const Color(0xFF64748B),
                              bg: const Color(0xFFF1F5F9),
                            ),
                            const SizedBox(width: 12),
                            _buildSummaryCard(
                              title: 'Penugasan Aktif',
                              value: activeAssignmentsCount.toString(),
                              icon: Icons.shield_outlined,
                              color: const Color(0xFF2563EB),
                              bg: const Color(0xFFDBEAFE),
                            ),
                          ],
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      _buildSummaryCard(
                        title: 'Total Akun Satpam',
                        value: totalUsers.toString(),
                        icon: Icons.badge_outlined,
                        color: AppTheme.primary,
                        bg: AppTheme.primary.withOpacity(0.1),
                      ),
                      const SizedBox(width: 14),
                      _buildSummaryCard(
                        title: 'Satpam Aktif',
                        value: activeUsers.toString(),
                        icon: Icons.check_circle_outline_rounded,
                        color: const Color(0xFF16A34A),
                        bg: const Color(0xFFDCFCE7),
                      ),
                      const SizedBox(width: 14),
                      _buildSummaryCard(
                        title: 'Satpam Nonaktif',
                        value: inactiveUsers.toString(),
                        icon: Icons.cancel_outlined,
                        color: const Color(0xFF64748B),
                        bg: const Color(0xFFF1F5F9),
                      ),
                      const SizedBox(width: 14),
                      _buildSummaryCard(
                        title: 'Penugasan Aktif',
                        value: activeAssignmentsCount.toString(),
                        icon: Icons.shield_outlined,
                        color: const Color(0xFF2563EB),
                        bg: const Color(0xFFDBEAFE),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),

              // Filter & Search Bar
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
                      // Search field
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Cari satpam (nama, HP, email)...',
                            prefixIcon:
                                const Icon(Icons.search_rounded, size: 20),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded,
                                        size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Status filter
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: _selectedStatusFilter,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'all', child: Text('Semua Status')),
                            DropdownMenuItem(
                                value: 'active', child: Text('Aktif Saja')),
                            DropdownMenuItem(
                                value: 'inactive',
                                child: Text('Nonaktif Saja')),
                          ],
                          onChanged: (val) {
                            if (val != null)
                              setState(() => _selectedStatusFilter = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Refresh button
                      IconButton(
                        tooltip: 'Segarkan Data',
                        icon: const Icon(Icons.refresh_rounded,
                            color: AppTheme.primary),
                        onPressed: _loadData,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Content Area
              if (_isLoading && _allUsers.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(48.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_errorMessage != null && _allUsers.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: AppTheme.danger, size: 40),
                        const SizedBox(height: 12),
                        Text(_errorMessage!,
                            style: const TextStyle(color: AppTheme.danger)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                            onPressed: _loadData,
                            child: const Text('Coba Lagi')),
                      ],
                    ),
                  ),
                )
              else if (displayUsers.isEmpty)
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(48.0),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.shield_outlined,
                              size: 48, color: AppTheme.textSecondary),
                          const SizedBox(height: 12),
                          Text(
                            _allUsers.isEmpty
                                ? 'Belum ada akun petugas satpam terdaftar.\nKlik "+ Tambah Satpam Baru" untuk mendaftarkan satpam pertama.'
                                : 'Tidak ada satpam yang sesuai dengan filter pencarian.',
                            style: const TextStyle(
                                color: AppTheme.textSecondary, height: 1.4),
                            textAlign: TextAlign.center,
                          ),
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
                      constraints: const BoxConstraints(minWidth: 1000),
                      child: DataTable(
                        headingRowColor:
                            WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                        horizontalMargin: 20,
                        columnSpacing: 24,
                        headingTextStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                        ),
                        columns: const [
                          DataColumn(label: Text('AVATAR')),
                          DataColumn(label: Text('NAMA SATPAM')),
                          DataColumn(label: Text('NO. WHATSAPP / HP')),
                          DataColumn(label: Text('EMAIL')),
                          DataColumn(label: Text('STATUS AKUN')),
                          DataColumn(label: Text('LINGKUNGAN PENUGASAN')),
                          DataColumn(label: Text('AKSI')),
                        ],
                        rows: displayUsers.map((user) {
                          final activeAssignments = user.assignments
                              .where((a) => a.isActive)
                              .toList();

                          return DataRow(
                            cells: [
                              // Avatar
                              DataCell(
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: user.isActive
                                      ? AppTheme.primary.withOpacity(0.12)
                                      : const Color(0xFFE2E8F0),
                                  child: Text(
                                    user.name.isNotEmpty
                                        ? user.name[0].toUpperCase()
                                        : 'S',
                                    style: TextStyle(
                                      color: user.isActive
                                          ? AppTheme.primary
                                          : const Color(0xFF64748B),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),

                              // Nama
                              DataCell(
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.displayName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textPrimary),
                                    ),
                                    const Text(
                                      'Petugas Keamanan (Satpam)',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                              ),

                              // Phone
                              DataCell(
                                Text(user.phone,
                                    style: const TextStyle(fontSize: 13)),
                              ),

                              // Email
                              DataCell(
                                Text(user.email,
                                    style: const TextStyle(fontSize: 13)),
                              ),

                              // Status Badge
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: user.isActive
                                        ? const Color(0xFFDCFCE7)
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    user.isActive ? 'Aktif' : 'Non-Aktif',
                                    style: TextStyle(
                                      color: user.isActive
                                          ? const Color(0xFF15803D)
                                          : const Color(0xFF64748B),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),

                              // Assigned Neighborhoods
                              DataCell(
                                activeAssignments.isEmpty
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF3C7),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'Belum Ditugaskan',
                                          style: TextStyle(
                                            color: Color(0xFFB45309),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      )
                                    : Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: activeAssignments.map((a) {
                                          return Chip(
                                            materialTapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 4),
                                            labelPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 4),
                                            avatar: const Icon(
                                                Icons.location_on_rounded,
                                                size: 14,
                                                color: AppTheme.primary),
                                            label: Text(
                                              a.neighborhoodName,
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500),
                                            ),
                                            backgroundColor:
                                                const Color(0xFFEFF6FF),
                                            side: const BorderSide(
                                                color: Color(0xFFBFDBFE)),
                                          );
                                        }).toList(),
                                      ),
                              ),

                              // Aksi
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // 1. Atur Penugasan
                                    Tooltip(
                                      message: 'Atur Penugasan Lingkungan',
                                      child: IconButton(
                                        icon: const Icon(
                                            Icons.assignment_ind_outlined,
                                            size: 20,
                                            color: AppTheme.primary),
                                        onPressed: () =>
                                            _showAssignmentDialog(user),
                                      ),
                                    ),

                                    // 2. Aktivasi / Nonaktifkan
                                    Tooltip(
                                      message: user.isActive
                                          ? 'Nonaktifkan Akun'
                                          : 'Aktifkan Akun',
                                      child: IconButton(
                                        icon: Icon(
                                          user.isActive
                                              ? Icons.toggle_on_rounded
                                              : Icons.toggle_off_outlined,
                                          size: 26,
                                          color: user.isActive
                                              ? const Color(0xFF16A34A)
                                              : const Color(0xFF94A3B8),
                                        ),
                                        onPressed: () =>
                                            _confirmToggleStatus(user),
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
