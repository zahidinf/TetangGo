import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../auth/presentation/bloc/auth_bloc.dart';
import '../../auth/presentation/bloc/auth_event.dart';
import '../../resident_management/presentation/widgets/table_pagination_control.dart';
import '../data/security_notification_service.dart';
import '../data/security_repository.dart';
import '../data/security_siren_service.dart';
import '../data/security_websocket_service.dart';
import '../domain/models/security_models.dart';
import 'widgets/emergency_fullscreen_dialog.dart';

class SecurityStandbyScreen extends StatefulWidget {
  final SecurityRepository? repository;
  final SecurityWebSocketService? wsService;
  final SecuritySirenService? sirenService;
  final SecurityNotificationService? notificationService;

  const SecurityStandbyScreen({
    super.key,
    this.repository,
    this.wsService,
    this.sirenService,
    this.notificationService,
  });

  @override
  State<SecurityStandbyScreen> createState() => _SecurityStandbyScreenState();
}

class _SecurityStandbyScreenState extends State<SecurityStandbyScreen>
    with SingleTickerProviderStateMixin {
  late final SecurityRepository _repository;
  late final SecurityWebSocketService _wsService;
  late final SecuritySirenService _sirenService;
  SecurityNotificationService? _notificationService;

  late final TabController _tabController;

  bool _isLoading = true;
  String? _errorMessage;

  List<SecurityAssignmentModel> _assignments = [];
  SecurityAssignmentModel? _selectedAssignment;
  List<SecurityIncidentModel> _incidents = [];

  // History state
  bool _historyLoading = false;
  String? _historyErrorMessage;
  List<SecurityIncidentModel> _historyIncidents = [];
  int _historyTotalItems = 0;
  int _historyPage = 1;
  int _historyPageSize = 10;
  String _historyStatusFilter = 'ALL';
  String _historyCategoryFilter = 'ALL';

  StreamSubscription? _wsEventSub;
  StreamSubscription? _notificationSub;
  bool _dialogActive = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    if (widget.repository != null) {
      _repository = widget.repository!;
    } else {
      final dio = context.read<DioClient>();
      _repository = SecurityRepository(dio);
    }
    _wsService = widget.wsService ?? context.read<SecurityWebSocketService>();
    _sirenService = widget.sirenService ?? context.read<SecuritySirenService>();
    _notificationService = widget.notificationService;

    _initStandbyData();
    _setupWebSocket();
    _setupNotificationListener();
  }

  void _setupNotificationListener() {
    if (_notificationService != null) {
      _notificationSub =
          _notificationService!.onNavigateToIncident.listen((incidentId) {
        _fetchDetailAndShowEmergency(incidentId);
      });
    }
  }

  Future<void> _initStandbyData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final assignments = await _repository.getMyAssignments();
      if (assignments.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Akun Anda tidak memiliki penugasan aktif di lingkungan manapun. Akses operasional pos satpam ditolak.';
        });
        return;
      }

      final incidents = await _repository.getActiveIncidents();

      setState(() {
        _assignments = assignments;
        _selectedAssignment = assignments.first;
        _incidents = incidents;
        _isLoading = false;
      });

      // Load initial history in parallel
      _loadHistoryData();

      // If any active unhandled incident exists when loading, trigger siren & dialog
      _checkAndTriggerTopActiveIncident(incidents);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _loadHistoryData() async {
    setState(() {
      _historyLoading = true;
      _historyErrorMessage = null;
    });

    try {
      final res = await _repository.getIncidents(
        page: _historyPage,
        limit: _historyPageSize,
        status: _historyStatusFilter == 'ALL' ? null : _historyStatusFilter,
        category:
            _historyCategoryFilter == 'ALL' ? null : _historyCategoryFilter,
        neighborhoodId: _selectedAssignment?.neighborhoodId,
      );

      if (mounted) {
        setState(() {
          _historyIncidents = res.incidents;
          _historyTotalItems = res.total;
          _historyLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _historyLoading = false;
          _historyErrorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  void _setupWebSocket() {
    _wsService.connect();

    _wsEventSub = _wsService.eventStream.listen((event) async {
      final eventType = event['event_type'] as String?;
      debugPrint('[SecurityStandby] Received event: $eventType');

      if (eventType == 'INCIDENT_CREATED') {
        final data = event['data'] as Map<String, dynamic>?;
        final incId = data?['incident_id'] as int? ?? data?['id'] as int?;
        if (incId != null) {
          _fetchDetailAndShowEmergency(incId);
        }
      } else if (eventType == 'INCIDENT_RESOLVED') {
        _sirenService.stopSiren();
      }

      // Refresh both active incidents and history upon relevant realtime event
      await _refreshIncidents(triggerTop: false);
      await _loadHistoryData();
    });

    // When connection recovers from reconnect, refresh incidents
    _wsService.statusNotifier.addListener(_onWsStatusChanged);
  }

  void _onWsStatusChanged() {
    if (_wsService.status == WsConnectionStatus.connected) {
      debugPrint(
          '[SecurityStandby] WS connected. Recovering active incidents via API.');
      _refreshIncidents(triggerTop: true);
      _loadHistoryData();
    }
  }

  Future<void> _refreshIncidents({bool triggerTop = true}) async {
    try {
      final fresh = await _repository.getActiveIncidents();
      if (mounted) {
        setState(() {
          _incidents = fresh;
        });
        if (triggerTop) {
          _checkAndTriggerTopActiveIncident(fresh);
        }
      }
    } catch (e) {
      debugPrint('[SecurityStandby] Refresh error: $e');
    }
  }

  void _checkAndTriggerTopActiveIncident(List<SecurityIncidentModel> list) {
    if (_dialogActive) return;
    // Find first incident with status ACTIVE
    final active = list.where((i) => i.isActive).toList();
    if (active.isNotEmpty) {
      _fetchDetailAndShowEmergency(active.first.id);
    } else {
      _sirenService.stopSiren();
    }
  }

  Future<void> _fetchDetailAndShowEmergency(int incidentId) async {
    if (_dialogActive) return;

    try {
      // Backend scopes strictly by security assignment
      final detail = await _repository.getIncidentDetail(incidentId);

      if (!mounted) return;
      _dialogActive = true;
      if (detail.isActive) {
        _sirenService.startSiren();
      } else {
        _sirenService.stopSiren();
      }

      await EmergencyFullscreenDialog.show(
        context: context,
        incident: detail,
        repository: _repository,
        sirenService: _sirenService,
        wsService: _wsService,
        onAcknowledgeSuccess: () {
          _refreshIncidents(triggerTop: false);
          _loadHistoryData();
        },
        onResolveSuccess: () {
          _dialogActive = false;
          _refreshIncidents(triggerTop: false);
          _loadHistoryData();
        },
      );
      _dialogActive = false;
    } catch (e) {
      _dialogActive = false;
      debugPrint('[SecurityStandby] Failed getting incident detail: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _wsService.statusNotifier.removeListener(_onWsStatusChanged);
    _wsEventSub?.cancel();
    _wsEventSub = null;
    _notificationSub?.cancel();
    _notificationSub = null;
    _wsService.disconnect();
    _sirenService.stopSiren();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthBloc>().state.user;

    // Reject non-security or inactive users immediately
    if (user == null || !user.isSecurity || !user.isActive) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mode Pos Satpam')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.block_rounded, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Akses Operasional Ditolak',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Halaman siaga hanya dapat diakses oleh akun Security yang aktif dengan surat tugas resmi.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    context.read<AuthBloc>().add(AuthLogoutRequested());
                  },
                  child: const Text('Keluar Akun'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Memverifikasi penugasan pos satpam...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Pos Satpam TetangGo'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              onPressed: () {
                context.read<AuthBloc>().add(AuthLogoutRequested());
              },
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 64, color: Colors.orange),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Coba Lagi'),
                  onPressed: _initStandbyData,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Filter active incidents by selected neighborhood
    final filteredIncidents = _selectedAssignment == null
        ? _incidents
        : _incidents
            .where(
                (i) => i.neighborhoodId == _selectedAssignment!.neighborhoodId)
            .toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield_rounded,
                  color: AppTheme.primary, size: 22),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SIAGA POS SATPAM',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Petugas: ${user.name}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // WebSocket status chip
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: ValueListenableBuilder<WsConnectionStatus>(
              valueListenable: _wsService.statusNotifier,
              builder: (context, status, _) {
                Color chipColor;
                String chipText;
                switch (status) {
                  case WsConnectionStatus.connected:
                    chipColor = Colors.green;
                    chipText = 'Online';
                    break;
                  case WsConnectionStatus.connecting:
                  case WsConnectionStatus.reconnecting:
                    chipColor = Colors.orange;
                    chipText = 'Menghubungkan';
                    break;
                  case WsConnectionStatus.disconnected:
                    chipColor = Colors.red;
                    chipText = 'Terputus';
                    break;
                }

                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: chipColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: chipColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: chipColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        chipText,
                        style: TextStyle(
                          color: chipColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan',
            onPressed: () {
              _refreshIncidents();
              _loadHistoryData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.red),
            tooltip: 'Keluar',
            onPressed: () {
              context.read<AuthBloc>().add(AuthLogoutRequested());
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.crisis_alert_rounded, size: 18),
                  const SizedBox(width: 8),
                  const Text('Insiden Aktif'),
                  if (filteredIncidents.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${filteredIncidents.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.history_rounded, size: 18),
                  const SizedBox(width: 8),
                  const Text('Riwayat Kejadian'),
                  if (_historyTotalItems > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$_historyTotalItems',
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Neighborhood assignment selector bar
          if (_assignments.length > 1) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.white,
              child: Row(
                children: [
                  const Icon(Icons.location_city_rounded,
                      size: 20, color: AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  const Text(
                    'Pilih Lingkungan Tugas: ',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<SecurityAssignmentModel>(
                      value: _selectedAssignment,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: _assignments.map((a) {
                        return DropdownMenuItem(
                          value: a,
                          child: Text(
                            a.neighborhoodName,
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedAssignment = val;
                            _historyPage = 1;
                          });
                          _loadHistoryData();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
          ] else if (_assignments.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppTheme.primary.withValues(alpha: 0.06),
              child: Row(
                children: [
                  const Icon(Icons.apartment_rounded,
                      size: 18, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Lingkungan Tugas Aktif: ${_assignments.first.neighborhoodName}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildActiveTab(filteredIncidents),
                _buildHistoryTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // TAB 1: ACTIVE INCIDENTS
  // ----------------------------------------------------

  Widget _buildActiveTab(List<SecurityIncidentModel> filteredIncidents) {
    return Column(
      children: [
        // Incidents count header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text(
                'Daftar Insiden Aktif',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: filteredIncidents.isEmpty
                      ? Colors.green.shade100
                      : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${filteredIncidents.length}',
                  style: TextStyle(
                    color: filteredIncidents.isEmpty
                        ? Colors.green.shade900
                        : Colors.red.shade900,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              ValueListenableBuilder<bool>(
                valueListenable: _sirenService.isPlayingNotifier,
                builder: (context, isPlaying, _) {
                  if (!isPlaying) return const SizedBox();
                  return OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                    ),
                    icon: const Icon(Icons.volume_off_rounded, size: 16),
                    label: const Text('Redam Sirene',
                        style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      _sirenService.stopSiren();
                    },
                  );
                },
              ),
            ],
          ),
        ),

        // Incident List
        Expanded(
          child: filteredIncidents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline_rounded,
                          size: 64, color: Colors.green.shade400),
                      const SizedBox(height: 12),
                      const Text(
                        'Kondisi Lingkungan Aman',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tidak ada laporan insiden darurat saat ini.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredIncidents.length,
                  itemBuilder: (context, index) {
                    final inc = filteredIncidents[index];
                    return _buildIncidentCard(inc);
                  },
                ),
        ),
      ],
    );
  }

  // ----------------------------------------------------
  // TAB 2: RIWAYAT KEJADIAN DARURAT (US-1)
  // ----------------------------------------------------

  Widget _buildHistoryTab(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    return RefreshIndicator(
      onRefresh: _loadHistoryData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(isDesktop ? 20 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter Bar
            _buildHistoryFilterBar(),
            const SizedBox(height: 16),

            // Error Banner
            if (_historyErrorMessage != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppTheme.danger.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppTheme.danger),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _historyErrorMessage!,
                        style: const TextStyle(
                            color: AppTheme.danger, fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: _loadHistoryData,
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            ],

            // Content Body
            if (_historyLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 50),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_historyIncidents.isEmpty)
              _buildHistoryEmptyState()
            else ...[
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _historyIncidents.length,
                itemBuilder: (context, index) {
                  final inc = _historyIncidents[index];
                  return _buildHistoryIncidentCard(inc);
                },
              ),
              const SizedBox(height: 16),
              // Pagination
              TablePaginationControl(
                currentPage: _historyPage,
                totalItems: _historyTotalItems,
                pageSize: _historyPageSize,
                keyPrefix: 'security_standby_history',
                isDesktop: isDesktop,
                onPageChanged: (newPage) {
                  setState(() => _historyPage = newPage);
                  _loadHistoryData();
                },
                onPageSizeChanged: (newSize) {
                  setState(() {
                    _historyPageSize = newSize;
                    _historyPage = 1;
                  });
                  _loadHistoryData();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryFilterBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status filters
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              const Text(
                'Status: ',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 6),
              _buildFilterChip('Semua', 'ALL', _historyStatusFilter, (val) {
                setState(() {
                  _historyStatusFilter = val;
                  _historyPage = 1;
                });
                _loadHistoryData();
              }),
              const SizedBox(width: 6),
              _buildFilterChip('Dilaporkan', 'REPORTED', _historyStatusFilter,
                  (val) {
                setState(() {
                  _historyStatusFilter = val;
                  _historyPage = 1;
                });
                _loadHistoryData();
              }),
              const SizedBox(width: 6),
              _buildFilterChip(
                  'Sedang Ditangani', 'RESPONDING', _historyStatusFilter,
                  (val) {
                setState(() {
                  _historyStatusFilter = val;
                  _historyPage = 1;
                });
                _loadHistoryData();
              }),
              const SizedBox(width: 6),
              _buildFilterChip('Terkendali', 'RESOLVED', _historyStatusFilter,
                  (val) {
                setState(() {
                  _historyStatusFilter = val;
                  _historyPage = 1;
                });
                _loadHistoryData();
              }),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Category filters
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              const Text(
                'Kategori: ',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 6),
              _buildFilterChip('Semua', 'ALL', _historyCategoryFilter, (val) {
                setState(() {
                  _historyCategoryFilter = val;
                  _historyPage = 1;
                });
                _loadHistoryData();
              }),
              const SizedBox(width: 6),
              _buildFilterChip(
                  'Kejahatan', 'KEJAHATAN', _historyCategoryFilter, (val) {
                setState(() {
                  _historyCategoryFilter = val;
                  _historyPage = 1;
                });
                _loadHistoryData();
              }),
              const SizedBox(width: 6),
              _buildFilterChip(
                  'Kebakaran', 'KEBAKARAN', _historyCategoryFilter, (val) {
                setState(() {
                  _historyCategoryFilter = val;
                  _historyPage = 1;
                });
                _loadHistoryData();
              }),
              const SizedBox(width: 6),
              _buildFilterChip('Medis', 'MEDIS', _historyCategoryFilter,
                  (val) {
                setState(() {
                  _historyCategoryFilter = val;
                  _historyPage = 1;
                });
                _loadHistoryData();
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value, String currentValue,
      ValueChanged<String> onSelected) {
    final isSelected = currentValue == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(value),
      selectedColor: AppTheme.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
      ),
      side: BorderSide(
        color: isSelected ? AppTheme.primary : Colors.grey.shade300,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
    );
  }

  Widget _buildHistoryEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_toggle_off_rounded,
              size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            'Tidak Ada Riwayat Kejadian',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tidak ditemukan laporan kejadian darurat untuk filter yang dipilih.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryIncidentCard(SecurityIncidentModel inc) {
    Color statusColor;
    String statusText;
    if (inc.isActive) {
      statusColor = AppTheme.danger;
      statusText = 'Dilaporkan';
    } else if (inc.isAcknowledged) {
      statusColor = Colors.orange;
      statusText = 'Sedang Ditangani';
    } else {
      statusColor = AppTheme.success;
      statusText = 'Terkendali';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: inc.isActive ? Colors.red.shade200 : Colors.grey.shade200,
          width: inc.isActive ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          _fetchDetailAndShowEmergency(inc.id);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top bar: ID, Category, Status, Time
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '#${inc.id}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(inc.category)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      inc.category.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _getCategoryColor(inc.category),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDateTime(inc.reportedAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Location & Reporter
              Row(
                children: [
                  const Icon(Icons.home_outlined,
                      size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    inc.houseDisplay,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.person_outline,
                      size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      inc.reporterName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              if (inc.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  inc.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
              // Timeline details (Resolution or Handling notes)
              if (inc.isAcknowledged && inc.handlingStartedAt != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.timer_outlined,
                        size: 14, color: Colors.orange),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Ditangani sejak ${_formatDateTime(inc.handlingStartedAt!)}${inc.assignedSecurityName != null ? ' oleh ${inc.assignedSecurityName}' : ''}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (inc.isResolved) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_outline_rounded,
                        size: 14, color: AppTheme.success),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        inc.resolvedAt != null
                            ? 'Terkendali pada ${_formatDateTime(inc.resolvedAt!)}${inc.resolutionNotes != null && inc.resolutionNotes!.isNotEmpty ? ' — "${inc.resolutionNotes}"' : ''}'
                            : (inc.resolutionNotes ?? 'Situasi aman terkendali'),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIncidentCard(SecurityIncidentModel inc) {
    Color statusColor;
    String statusText;
    if (inc.isActive) {
      statusColor = Colors.red;
      statusText = 'SIAGA BARU';
    } else if (inc.isAcknowledged) {
      statusColor = Colors.orange;
      statusText = 'SEDANG DITANGANI';
    } else {
      statusColor = Colors.green;
      statusText = 'SELESAI';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: inc.isActive ? Colors.red.shade300 : Colors.grey.shade300,
          width: inc.isActive ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          _fetchDetailAndShowEmergency(inc.id);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    inc.categoryDisplay,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatTime(inc.reportedAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.home_outlined,
                      size: 18, color: AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    inc.houseDisplay,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.person_outline,
                      size: 18, color: AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      inc.reporterName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              if (inc.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  inc.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
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

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min WIB';
  }

  String _formatDateTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y, $h:$min WIB';
  }
}
