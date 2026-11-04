import 'package:equatable/equatable.dart';
import '../../domain/models/complaint_model.dart';

enum AdminComplaintViewMode { kanban, list }
enum AdminComplaintActionStatus { initial, loading, success, failure }

class AdminComplaintState extends Equatable {
  final AdminComplaintViewMode viewMode;

  // Kanban State
  final bool isLoadingKanban;
  final KanbanComplaintsData? kanbanData;
  final String? kanbanErrorMessage;

  // List State (Mobile / Table)
  final bool isLoadingList;
  final List<ComplaintModel> complaintsList;
  final int currentPage;
  final int totalComplaints;
  final int totalPages;
  final String? listErrorMessage;

  // Filters
  final String? filterStatus;
  final String? filterCategory;
  final String? filterOfficer;
  final String? filterSearch;
  final String? filterStartDate;
  final String? filterEndDate;

  // Detail & Assignments
  final bool isLoadingDetail;
  final ComplaintModel? selectedComplaint;
  final List<ComplaintAssignmentModel> assignments;
  final String? detailErrorMessage;

  // Action (Assign / Status Update)
  final AdminComplaintActionStatus actionStatus;
  final String? actionSuccessMessage;
  final String? actionErrorMessage;

  // Eligible Officers
  final bool isLoadingOfficers;
  final List<EligibleOfficerModel> eligibleOfficers;

  const AdminComplaintState({
    this.viewMode = AdminComplaintViewMode.kanban,
    this.isLoadingKanban = false,
    this.kanbanData,
    this.kanbanErrorMessage,
    this.isLoadingList = false,
    this.complaintsList = const [],
    this.currentPage = 1,
    this.totalComplaints = 0,
    this.totalPages = 1,
    this.listErrorMessage,
    this.filterStatus,
    this.filterCategory,
    this.filterOfficer,
    this.filterSearch,
    this.filterStartDate,
    this.filterEndDate,
    this.isLoadingDetail = false,
    this.selectedComplaint,
    this.assignments = const [],
    this.detailErrorMessage,
    this.actionStatus = AdminComplaintActionStatus.initial,
    this.actionSuccessMessage,
    this.actionErrorMessage,
    this.isLoadingOfficers = false,
    this.eligibleOfficers = const [],
  });

  AdminComplaintState copyWith({
    AdminComplaintViewMode? viewMode,
    bool? isLoadingKanban,
    KanbanComplaintsData? kanbanData,
    String? kanbanErrorMessage,
    bool? isLoadingList,
    List<ComplaintModel>? complaintsList,
    int? currentPage,
    int? totalComplaints,
    int? totalPages,
    String? listErrorMessage,
    String? filterStatus,
    String? filterCategory,
    String? filterOfficer,
    String? filterSearch,
    String? filterStartDate,
    String? filterEndDate,
    bool? isLoadingDetail,
    ComplaintModel? selectedComplaint,
    List<ComplaintAssignmentModel>? assignments,
    String? detailErrorMessage,
    AdminComplaintActionStatus? actionStatus,
    String? actionSuccessMessage,
    String? actionErrorMessage,
    bool? isLoadingOfficers,
    List<EligibleOfficerModel>? eligibleOfficers,
    bool clearDetail = false,
  }) {
    return AdminComplaintState(
      viewMode: viewMode ?? this.viewMode,
      isLoadingKanban: isLoadingKanban ?? this.isLoadingKanban,
      kanbanData: kanbanData ?? this.kanbanData,
      kanbanErrorMessage: kanbanErrorMessage,
      isLoadingList: isLoadingList ?? this.isLoadingList,
      complaintsList: complaintsList ?? this.complaintsList,
      currentPage: currentPage ?? this.currentPage,
      totalComplaints: totalComplaints ?? this.totalComplaints,
      totalPages: totalPages ?? this.totalPages,
      listErrorMessage: listErrorMessage,
      filterStatus: filterStatus ?? this.filterStatus,
      filterCategory: filterCategory ?? this.filterCategory,
      filterOfficer: filterOfficer ?? this.filterOfficer,
      filterSearch: filterSearch ?? this.filterSearch,
      filterStartDate: filterStartDate ?? this.filterStartDate,
      filterEndDate: filterEndDate ?? this.filterEndDate,
      isLoadingDetail: isLoadingDetail ?? this.isLoadingDetail,
      selectedComplaint: clearDetail ? null : (selectedComplaint ?? this.selectedComplaint),
      assignments: clearDetail ? const [] : (assignments ?? this.assignments),
      detailErrorMessage: detailErrorMessage,
      actionStatus: actionStatus ?? this.actionStatus,
      actionSuccessMessage: actionSuccessMessage,
      actionErrorMessage: actionErrorMessage,
      isLoadingOfficers: isLoadingOfficers ?? this.isLoadingOfficers,
      eligibleOfficers: eligibleOfficers ?? this.eligibleOfficers,
    );
  }

  @override
  List<Object?> get props => [
        viewMode,
        isLoadingKanban,
        kanbanData,
        kanbanErrorMessage,
        isLoadingList,
        complaintsList,
        currentPage,
        totalComplaints,
        totalPages,
        listErrorMessage,
        filterStatus,
        filterCategory,
        filterOfficer,
        filterSearch,
        filterStartDate,
        filterEndDate,
        isLoadingDetail,
        selectedComplaint,
        assignments,
        detailErrorMessage,
        actionStatus,
        actionSuccessMessage,
        actionErrorMessage,
        isLoadingOfficers,
        eligibleOfficers,
      ];
}
