import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../auth/domain/models/user_model.dart';
import '../../resident_management/presentation/widgets/table_pagination_control.dart';
import '../../security/data/security_repository.dart';
import '../../security/domain/models/security_models.dart';
import 'widgets/admin_incident_correction_dialog.dart';
import 'widgets/emergency_incident_detail_dialog.dart';

class EmergencyMonitoringScreen extends StatefulWidget {
  final UserModel? user;
  final VoidCallback? onIncidentCountChanged;

  const EmergencyMonitoringScreen({
    super.key,
    required this.user,
    this.onIncidentCountChanged,
  });

  @override
  State<EmergencyMonitoringScreen> createState() =>
      _EmergencyMonitoringScreenState();
}

class _EmergencyMonitoringScreenState extends State<EmergencyMonitoringScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<SecurityIncidentModel> _incidents = [];
  int _totalItems = 0;
  int _currentPage = 1;
  int _pageSize = 10;
  int _activeCount = 0;

  String _statusFilter = 'ALL';
  String _categoryFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = context.read<SecurityRepository>();

      // Fetch active count concurrently for the dynamic header status
      final countFuture = repo.getActiveIncidentCount();
      final listFuture = repo.getIncidents(
        page: _currentPage,
        limit: _pageSize,
        status: _statusFilter == 'ALL' ? null : _statusFilter,
        category: _categoryFilter == 'ALL' ? null : _categoryFilter,
      );

      final results = await Future.wait<dynamic>([countFuture, listFuture]);
      final activeCount = (results[0] as int?) ?? 0;
      final incidentRes = results[1] as IncidentListResponse;

      if (mounted) {
        setState(() {
          _activeCount = activeCount;
          _incidents = incidentRes.incidents;
          _totalItems = incidentRes.total;
          _isLoading = false;
        });
        widget.onIncidentCountChanged?.call();
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

  void _onStatusFilterSelected(String status) {
    if (_statusFilter == status) return;
    setState(() {
      _statusFilter = status;
      _currentPage = 1;
    });
    _loadData();
  }

  void _onCategoryFilterSelected(String category) {
    if (_categoryFilter == category) return;
    setState(() {
      _categoryFilter = category;
      _currentPage = 1;
    });
    _loadData();
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
      case 'REPORTED':
        return AppTheme.danger;
      case 'RESPONDING':
      case 'ACKNOWLEDGED':
        return Colors.orange;
      case 'RESOLVED':
        return AppTheme.success;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
      case 'REPORTED':
        return 'Dilaporkan';
      case 'RESPONDING':
      case 'ACKNOWLEDGED':
        return 'Sedang Ditangani';
      case 'RESOLVED':
        return 'Terkendali';
      default:
        return status;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toUpperCase()) {
      case 'KEJAHATAN':
        return AppTheme.danger;
      case 'KEBAKARAN':
        return Colors.deepOrange;
      case 'MEDIS':
        return Colors.blue;
      default:
        return AppTheme.primaryDark;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final canViewFullHistory =
        widget.user?.canAccessFullEmergencyHistory ?? false;
    final isAdmin = widget.user?.isAdmin ?? false;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(isDesktop ? 24 : 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1300),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  _buildHeader(isDesktop),
                  const SizedBox(height: 18),

                  // Prominent Active Status Banner
                  _buildActiveStatusBanner(isDesktop),
                  const SizedBox(height: 20),

                  // Filter Bars
                  _buildFilterBars(canViewFullHistory),
                  const SizedBox(height: 16),

                  // Error Banner
                  if (_errorMessage != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: AppTheme.danger.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: AppTheme.danger),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                  color: AppTheme.danger, fontSize: 13),
                            ),
                          ),
                          TextButton(
                            onPressed: _loadData,
                            child: const Text('Coba Lagi'),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Content Body
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_incidents.isEmpty)
                    _buildEmptyState()
                  else
                    _buildIncidentList(isDesktop, isAdmin),

                  const SizedBox(height: 16),

                  // Standard Table Pagination Control
                  if (!_isLoading && _incidents.isNotEmpty)
                    TablePaginationControl(
                      currentPage: _currentPage,
                      totalItems: _totalItems,
                      pageSize: _pageSize,
                      keyPrefix: 'emergency_incidents',
                      isDesktop: isDesktop,
                      onPageChanged: (newPage) {
                        setState(() => _currentPage = newPage);
                        _loadData();
                      },
                      onPageSizeChanged: (newSize) {
                        setState(() {
                          _pageSize = newSize;
                          _currentPage = 1;
                        });
                        _loadData();
                      },
                    ),
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.emergency_rounded,
                  color: AppTheme.danger,
                  size: 28,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Kejadian Darurat',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _activeCount > 0
                        ? AppTheme.danger.withOpacity(0.12)
                        : AppTheme.success.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _activeCount > 0
                          ? AppTheme.danger.withOpacity(0.3)
                          : AppTheme.success.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    _activeCount > 0 ? 'Siaga $_activeCount' : 'Aman',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color:
                          _activeCount > 0 ? AppTheme.danger : AppTheme.success,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              widget.user?.canAccessFullEmergencyHistory ?? false
                  ? 'Pusat monitoring, riwayat lengkap, dan penanganan kejadian darurat cluster'
                  : 'Monitoring laporan kejadian darurat aktif di lingkungan Anda',
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        IconButton(
          onPressed: _loadData,
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Muat Ulang',
          color: AppTheme.primaryDark,
        ),
      ],
    );
  }

  Widget _buildActiveStatusBanner(bool isDesktop) {
    final hasActive = _activeCount > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: hasActive
            ? AppTheme.danger.withOpacity(0.08)
            : AppTheme.success.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasActive
              ? AppTheme.danger.withOpacity(0.25)
              : AppTheme.success.withOpacity(0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasActive
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline_rounded,
            color: hasActive ? AppTheme.danger : AppTheme.success,
            size: 26,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasActive
                      ? 'Status Cluster: Siaga $_activeCount Kejadian Aktif'
                      : 'Status Cluster: Kondisi Aman',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: hasActive ? AppTheme.danger : AppTheme.success,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasActive
                      ? 'Terdapat $_activeCount insiden darurat yang berstatus Dilaporkan atau Sedang Ditangani oleh petugas.'
                      : 'Tidak ada laporan darurat yang sedang aktif di lingkungan saat ini.',
                  style: TextStyle(
                    fontSize: 12,
                    color: hasActive
                        ? AppTheme.danger.withOpacity(0.9)
                        : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBars(bool canViewFullHistory) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (canViewFullHistory) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text(
                  'Status:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                _buildFilterChip('Semua Status', 'ALL', _statusFilter,
                    _onStatusFilterSelected),
                _buildFilterChip('Dilaporkan', 'ACTIVE', _statusFilter,
                    _onStatusFilterSelected),
                _buildFilterChip('Sedang Ditangani', 'RESPONDING',
                    _statusFilter, _onStatusFilterSelected),
                _buildFilterChip('Terkendali', 'RESOLVED', _statusFilter,
                    _onStatusFilterSelected),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              const Text(
                'Kategori:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              _buildFilterChip('Semua Kategori', 'ALL', _categoryFilter,
                  _onCategoryFilterSelected),
              _buildFilterChip('Kejahatan', 'KEJAHATAN', _categoryFilter,
                  _onCategoryFilterSelected),
              _buildFilterChip('Kebakaran', 'KEBAKARAN', _categoryFilter,
                  _onCategoryFilterSelected),
              _buildFilterChip(
                  'Medis', 'MEDIS', _categoryFilter, _onCategoryFilterSelected),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value, String selectedValue,
      ValueChanged<String> onSelected) {
    final isSelected = selectedValue == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onSelected(value),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? Colors.white : AppTheme.textPrimary,
        ),
        backgroundColor: Colors.white,
        selectedColor: AppTheme.primaryDark,
        checkmarkColor: Colors.white,
        side: BorderSide(
          color: isSelected ? AppTheme.primaryDark : const Color(0xFFE2E8F0),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: AppTheme.success,
              size: 42,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tidak Ada Laporan Kejadian',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Belum ada laporan darurat yang sesuai dengan kriteria filter saat ini.',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentList(bool isDesktop, bool isAdmin) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _incidents.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final incident = _incidents[index];
        final statusColor = _getStatusColor(incident.status);
        final categoryColor = _getCategoryColor(incident.category);

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: incident.isActive
                  ? AppTheme.danger.withOpacity(0.3)
                  : const Color(0xFFE2E8F0),
              width: incident.isActive ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: ID, Category, Status, Timestamp
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '#${incident.id} • ${incident.categoryDisplay}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: categoryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      _getStatusLabel(incident.status),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${dateFormat.format(incident.reportedAt)} WIB',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Title and Description
              Text(
                incident.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (incident.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  incident.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // Location & Reporter info
              Row(
                children: [
                  const Icon(Icons.home_outlined,
                      size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    incident.houseDisplay,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Icon(Icons.person_outline_rounded,
                      size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    incident.reporterName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Bottom Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => EmergencyIncidentDetailDialog(
                          incident: incident,
                          user: widget.user,
                          onIncidentUpdated: _loadData,
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text('Lihat Detail',
                        style: TextStyle(fontSize: 12)),
                  ),
                  if (isAdmin) ...[
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () {
                        showDialog<SecurityIncidentModel>(
                          context: context,
                          builder: (ctx) => AdminIncidentCorrectionDialog(
                            incident: incident,
                            onSuccess: (_) => _loadData(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.edit_note_rounded, size: 16),
                      label: const Text('Koreksi (Admin)',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
