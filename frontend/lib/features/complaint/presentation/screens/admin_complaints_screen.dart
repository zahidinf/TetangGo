import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/standard_page_header.dart';
import '../../../../core/widgets/standard_submenu_tab_bar.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../data/repositories/complaint_repository.dart';
import '../../domain/models/complaint_model.dart';
import '../bloc/admin_complaint_bloc.dart';
import '../bloc/admin_complaint_event.dart';
import '../bloc/admin_complaint_state.dart';
import '../bloc/complaint_bloc.dart';
import '../bloc/complaint_event.dart';
import '../widgets/admin_complaint_detail_dialog.dart';
import '../widgets/assign_officer_dialog.dart';
import '../widgets/complaint_card_widget.dart';
import '../widgets/complaint_kanban_column.dart';
import '../widgets/create_complaint_dialog.dart';
import 'resident_complaints_screen.dart';

class AdminComplaintsScreen extends StatefulWidget {
  final UserModel? currentUser;

  const AdminComplaintsScreen({super.key, this.currentUser});

  @override
  State<AdminComplaintsScreen> createState() => _AdminComplaintsScreenState();
}

class _AdminComplaintsScreenState extends State<AdminComplaintsScreen>
    with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  String? _selectedCategory;
  String? _selectedStatus;
  late TabController _mobileTabController;
  TabController? _topTabController;

  bool get _canManageLeadership =>
      widget.currentUser?.canAccessLeadership ?? false;

  bool get _canAccessLaporCluster =>
      widget.currentUser?.hasHousingAssociation ?? false;

  @override
  void initState() {
    super.initState();
    _mobileTabController = TabController(length: 4, vsync: this);
    if (_canAccessLaporCluster) {
      _topTabController = TabController(length: 2, vsync: this);
      _topTabController!.addListener(() {
        if (!mounted) return;
        setState(() {});
        if (_topTabController!.index == 1) {
          try {
            context.read<ComplaintBloc>().add(const LoadComplaintsEvent(page: 1, refresh: true));
          } catch (_) {}
        }
      });
    }

    final bloc = context.read<AdminComplaintBloc>();
    bloc.add(const LoadKanbanComplaintsEvent());
    bloc.add(const LoadAdminComplaintsListEvent());
    bloc.add(const LoadEligibleOfficersEvent());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mobileTabController.dispose();
    _topTabController?.dispose();
    super.dispose();
  }

  void _applyFilters() {
    final search = _searchController.text.trim();
    final bloc = context.read<AdminComplaintBloc>();

    bloc.add(LoadKanbanComplaintsEvent(
      category: _selectedCategory,
      search: search.isNotEmpty ? search : null,
    ));

    bloc.add(LoadAdminComplaintsListEvent(
      status: _selectedStatus,
      category: _selectedCategory,
      search: search.isNotEmpty ? search : null,
      page: 1,
    ));
  }

  void _openDetail(ComplaintModel complaint) async {
    final bloc = context.read<AdminComplaintBloc>();
    final dio = context.read<DioClient>();
    final repo = context.read<ComplaintRepository>();

    // Load detail
    bloc.add(LoadAdminComplaintDetailEvent(complaint.id));

    try {
      final detail = await repo.getAdminComplaintDetail(complaint.id);
      if (!mounted) return;

      AdminComplaintDetailDialog.show(
        context,
        complaint: detail.complaint,
        assignments: detail.assignments,
        dioClient: dio,
        canAssign: _canManageLeadership,
        onAssignTapped: () {
          Navigator.of(context).pop();
          _openAssign(detail.complaint);
        },
        onStatusChanged: (newStatus) {
          Navigator.of(context).pop();
          _updateStatus(detail.complaint, newStatus);
        },
      );
    } catch (_) {
      // Fallback with current model if network error
      if (!mounted) return;
      AdminComplaintDetailDialog.show(
        context,
        complaint: complaint,
        assignments: const [],
        dioClient: dio,
        canAssign: _canManageLeadership,
        onAssignTapped: () {
          Navigator.of(context).pop();
          _openAssign(complaint);
        },
        onStatusChanged: (newStatus) {
          Navigator.of(context).pop();
          _updateStatus(complaint, newStatus);
        },
      );
    }
  }

  void _openAssign(ComplaintModel complaint) {
    final bloc = context.read<AdminComplaintBloc>();
    AssignOfficerDialog.show(
      context,
      complaint: complaint,
      eligibleOfficers: bloc.state.eligibleOfficers,
      onAssign: ({
        required String officerName,
        int? officerUserId,
        String? notes,
        String? status,
      }) {
        bloc.add(AssignOfficerSubmittedEvent(
          complaintId: complaint.id,
          officerName: officerName,
          officerUserId: officerUserId,
          notes: notes,
          status: status,
        ));
      },
    );
  }

  void _updateStatus(ComplaintModel complaint, ComplaintStatus status) {
    context.read<AdminComplaintBloc>().add(
          UpdateComplaintStatusSubmittedEvent(
            complaintId: complaint.id,
            status: status,
          ),
        );
  }

  int get _topNavigationIndex => _topTabController?.index ?? 0;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktopOrWeb = screenWidth >= 900;

    return BlocConsumer<AdminComplaintBloc, AdminComplaintState>(
      listener: (context, state) {
        if (state.actionSuccessMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.actionSuccessMessage!),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (state.actionErrorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.actionErrorMessage!),
              backgroundColor: AppTheme.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppTheme.background,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_canAccessLaporCluster) _buildSubNavigationTabs(isDesktopOrWeb),
              if (_topNavigationIndex == 0) ...[
                _buildFilterBar(isDesktopOrWeb),
                Expanded(
                  child: isDesktopOrWeb
                      ? _buildKanbanBoard(state)
                      : _buildMobileView(state),
                ),
              ] else ...[
                const Expanded(
                  child: ResidentComplaintsScreen(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubNavigationTabs(bool isDesktop) {
    if (_topTabController == null) return const SizedBox.shrink();

    return StandardSubmenuTabBar(
      controller: _topTabController!,
      isScrollable: isDesktop ? false : true,
      items: const [
        StandardSubmenuItem(
          icon: Icons.view_kanban_rounded,
          label: 'Semua Pengaduan Cluster',
        ),
        StandardSubmenuItem(
          icon: Icons.report_problem_rounded,
          label: 'Lapor Cluster (Laporan Saya)',
        ),
      ],
    );
  }

  Widget _buildFilterBar(bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 24 : 16,
        vertical: 12,
      ),
      color: Colors.white,
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Search box
          SizedBox(
            width: isDesktop ? 280 : double.infinity,
            height: 40,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari tiket, judul, warga...',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          _applyFilters();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onSubmitted: (_) => _applyFilters(),
            ),
          ),

          // Category filter
          SizedBox(
            width: isDesktop ? 200 : 170,
            height: 40,
            child: DropdownButtonFormField<String>(
              value: _selectedCategory,
              isExpanded: true,
              decoration: InputDecoration(
                hintText: 'Kategori',
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Semua Kategori', overflow: TextOverflow.ellipsis)),
                ...ComplaintCategory.values.map(
                  (c) => DropdownMenuItem(value: c.label, child: Text(c.label, overflow: TextOverflow.ellipsis)),
                ),
              ],
              onChanged: (val) {
                setState(() => _selectedCategory = val);
                _applyFilters();
              },
            ),
          ),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.filter_list_rounded, size: 16),
            label: const Text('Filter'),
            onPressed: _applyFilters,
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // DESKTOP / WEB: KANBAN BOARD (3 Columns)
  // ----------------------------------------------------
  Widget _buildKanbanBoard(AdminComplaintState state) {
    if (state.isLoadingKanban && state.kanbanData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.kanbanErrorMessage != null && state.kanbanData == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
            const SizedBox(height: 12),
            Text(state.kanbanErrorMessage!, style: const TextStyle(color: AppTheme.danger)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                context.read<AdminComplaintBloc>().add(const LoadKanbanComplaintsEvent());
              },
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    final data = state.kanbanData;
    final menungguList = data?.menunggu ?? [];
    final diprosesList = data?.diproses ?? [];
    final selesaiList = data?.selesai ?? [];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ComplaintKanbanColumn(
            title: 'Menunggu',
            status: ComplaintStatus.menunggu,
            complaints: menungguList,
            headerColor: AppTheme.accent,
            canManage: _canManageLeadership,
            onComplaintTap: _openDetail,
            onAssignTapped: _openAssign,
            onStatusChange: _updateStatus,
          ),
          ComplaintKanbanColumn(
            title: 'Dalam Pengerjaan',
            status: ComplaintStatus.diproses,
            complaints: diprosesList,
            headerColor: AppTheme.primary,
            canManage: _canManageLeadership,
            onComplaintTap: _openDetail,
            onAssignTapped: _openAssign,
            onStatusChange: _updateStatus,
          ),
          ComplaintKanbanColumn(
            title: 'Selesai',
            status: ComplaintStatus.selesai,
            complaints: selesaiList,
            headerColor: AppTheme.success,
            canManage: _canManageLeadership,
            onComplaintTap: _openDetail,
            onAssignTapped: _openAssign,
            onStatusChange: _updateStatus,
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // MOBILE: RESPONSIVE TABS & LIST
  // ----------------------------------------------------
  Widget _buildMobileView(AdminComplaintState state) {
    final data = state.kanbanData;
    final menungguList = data?.menunggu ?? [];
    final diprosesList = data?.diproses ?? [];
    final selesaiList = data?.selesai ?? [];
    final allList = state.complaintsList;

    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _mobileTabController,
            isScrollable: true,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textMuted,
            indicatorColor: AppTheme.primary,
            tabs: [
              Tab(text: 'Semua (${state.totalComplaints})'),
              Tab(text: 'Menunggu (${menungguList.length})'),
              Tab(text: 'Diproses (${diprosesList.length})'),
              Tab(text: 'Selesai (${selesaiList.length})'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _mobileTabController,
            children: [
              _buildMobileList(allList, state.isLoadingList),
              _buildMobileList(menungguList, state.isLoadingKanban),
              _buildMobileList(diprosesList, state.isLoadingKanban),
              _buildMobileList(selesaiList, state.isLoadingKanban),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileList(List<ComplaintModel> items, bool isLoading) {
    if (isLoading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (items.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              const Text(
                'Tidak ada tiket pengaduan',
                style: TextStyle(color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<AdminComplaintBloc>().add(const LoadKanbanComplaintsEvent());
        context.read<AdminComplaintBloc>().add(const LoadAdminComplaintsListEvent());
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = items[index];
          return ComplaintCardWidget(
            complaint: item,
            canManage: _canManageLeadership,
            onTap: () => _openDetail(item),
            onAssignTapped: _canManageLeadership ? () => _openAssign(item) : null,
            onStatusChanged: _canManageLeadership
                ? (newSt) => _updateStatus(item, newSt)
                : null,
          );
        },
      ),
    );
  }
}
