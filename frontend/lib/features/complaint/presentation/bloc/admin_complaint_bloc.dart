import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/complaint_repository.dart';
import 'admin_complaint_event.dart';
import 'admin_complaint_state.dart';

class AdminComplaintBloc extends Bloc<AdminComplaintEvent, AdminComplaintState> {
  final ComplaintRepository _repository;

  AdminComplaintBloc({required ComplaintRepository repository})
      : _repository = repository,
        super(const AdminComplaintState()) {
    on<LoadKanbanComplaintsEvent>(_onLoadKanban);
    on<LoadAdminComplaintsListEvent>(_onLoadList);
    on<LoadAdminComplaintDetailEvent>(_onLoadDetail);
    on<AssignOfficerSubmittedEvent>(_onAssignOfficer);
    on<UpdateComplaintStatusSubmittedEvent>(_onUpdateStatus);
    on<LoadEligibleOfficersEvent>(_onLoadEligibleOfficers);
  }

  Future<void> _onLoadKanban(
    LoadKanbanComplaintsEvent event,
    Emitter<AdminComplaintState> emit,
  ) async {
    emit(state.copyWith(
      isLoadingKanban: true,
      kanbanErrorMessage: null,
      filterCategory: event.category,
      filterOfficer: event.officer,
      filterSearch: event.search,
      filterStartDate: event.startDate,
      filterEndDate: event.endDate,
    ));

    try {
      final data = await _repository.getKanbanComplaints(
        category: event.category,
        officer: event.officer,
        search: event.search,
        startDate: event.startDate,
        endDate: event.endDate,
      );
      emit(state.copyWith(
        isLoadingKanban: false,
        kanbanData: data,
        kanbanErrorMessage: null,
      ));
    } catch (e) {
      String msg = 'Gagal memuat papan Kanban pengaduan';
      if (e is DioException) {
        final resp = e.response?.data;
        if (resp is Map && resp['message'] != null) {
          msg = resp['message'].toString();
        }
      }
      emit(state.copyWith(
        isLoadingKanban: false,
        kanbanErrorMessage: msg,
      ));
    }
  }

  Future<void> _onLoadList(
    LoadAdminComplaintsListEvent event,
    Emitter<AdminComplaintState> emit,
  ) async {
    emit(state.copyWith(
      isLoadingList: true,
      listErrorMessage: null,
      filterStatus: event.status,
      filterCategory: event.category,
      filterOfficer: event.officer,
      filterSearch: event.search,
      filterStartDate: event.startDate,
      filterEndDate: event.endDate,
    ));

    try {
      final res = await _repository.getAdminComplaints(
        status: event.status,
        category: event.category,
        officer: event.officer,
        search: event.search,
        startDate: event.startDate,
        endDate: event.endDate,
        page: event.page,
        limit: event.limit,
      );
      emit(state.copyWith(
        isLoadingList: false,
        complaintsList: res.complaints,
        currentPage: res.page,
        totalComplaints: res.total,
        totalPages: res.totalPages,
        listErrorMessage: null,
      ));
    } catch (e) {
      String msg = 'Gagal memuat daftar pengaduan';
      if (e is DioException) {
        final resp = e.response?.data;
        if (resp is Map && resp['message'] != null) {
          msg = resp['message'].toString();
        }
      }
      emit(state.copyWith(
        isLoadingList: false,
        listErrorMessage: msg,
      ));
    }
  }

  Future<void> _onLoadDetail(
    LoadAdminComplaintDetailEvent event,
    Emitter<AdminComplaintState> emit,
  ) async {
    emit(state.copyWith(
      isLoadingDetail: true,
      detailErrorMessage: null,
    ));

    try {
      final detail = await _repository.getAdminComplaintDetail(event.id);
      emit(state.copyWith(
        isLoadingDetail: false,
        selectedComplaint: detail.complaint,
        assignments: detail.assignments,
        detailErrorMessage: null,
      ));
    } catch (e) {
      String msg = 'Gagal memuat detail tiket pengaduan';
      if (e is DioException) {
        final resp = e.response?.data;
        if (resp is Map && resp['message'] != null) {
          msg = resp['message'].toString();
        }
      }
      emit(state.copyWith(
        isLoadingDetail: false,
        detailErrorMessage: msg,
      ));
    }
  }

  Future<void> _onAssignOfficer(
    AssignOfficerSubmittedEvent event,
    Emitter<AdminComplaintState> emit,
  ) async {
    emit(state.copyWith(
      actionStatus: AdminComplaintActionStatus.loading,
      actionErrorMessage: null,
      actionSuccessMessage: null,
    ));

    try {
      final result = await _repository.assignOfficer(
        complaintId: event.complaintId,
        officerName: event.officerName,
        officerUserId: event.officerUserId,
        notes: event.notes,
        status: event.status,
      );

      emit(state.copyWith(
        actionStatus: AdminComplaintActionStatus.success,
        actionSuccessMessage: 'Petugas ${event.officerName} berhasil ditugaskan',
        selectedComplaint: result.complaint,
        assignments: result.assignments,
      ));

      // Refresh kanban and list data in background
      add(LoadKanbanComplaintsEvent(
        category: state.filterCategory,
        officer: state.filterOfficer,
        search: state.filterSearch,
        startDate: state.filterStartDate,
        endDate: state.filterEndDate,
      ));
      add(LoadAdminComplaintsListEvent(
        status: state.filterStatus,
        category: state.filterCategory,
        officer: state.filterOfficer,
        search: state.filterSearch,
        startDate: state.filterStartDate,
        endDate: state.filterEndDate,
        page: state.currentPage,
      ));
    } catch (e) {
      String msg = 'Gagal menugaskan petugas';
      if (e is DioException) {
        final resp = e.response?.data;
        if (resp is Map && resp['message'] != null) {
          msg = resp['message'].toString();
        }
      }
      emit(state.copyWith(
        actionStatus: AdminComplaintActionStatus.failure,
        actionErrorMessage: msg,
      ));
    }
  }

  Future<void> _onUpdateStatus(
    UpdateComplaintStatusSubmittedEvent event,
    Emitter<AdminComplaintState> emit,
  ) async {
    emit(state.copyWith(
      actionStatus: AdminComplaintActionStatus.loading,
      actionErrorMessage: null,
      actionSuccessMessage: null,
    ));

    try {
      final updated = await _repository.updateStatus(
        complaintId: event.complaintId,
        status: event.status,
      );

      emit(state.copyWith(
        actionStatus: AdminComplaintActionStatus.success,
        actionSuccessMessage: 'Status tiket berhasil diubah menjadi ${event.status.label}',
        selectedComplaint: updated,
      ));

      // Refresh kanban and list
      add(LoadKanbanComplaintsEvent(
        category: state.filterCategory,
        officer: state.filterOfficer,
        search: state.filterSearch,
        startDate: state.filterStartDate,
        endDate: state.filterEndDate,
      ));
      add(LoadAdminComplaintsListEvent(
        status: state.filterStatus,
        category: state.filterCategory,
        officer: state.filterOfficer,
        search: state.filterSearch,
        startDate: state.filterStartDate,
        endDate: state.filterEndDate,
        page: state.currentPage,
      ));
    } catch (e) {
      String msg = 'Gagal memperbarui status tiket';
      if (e is DioException) {
        final resp = e.response?.data;
        if (resp is Map && resp['message'] != null) {
          msg = resp['message'].toString();
        }
      }
      emit(state.copyWith(
        actionStatus: AdminComplaintActionStatus.failure,
        actionErrorMessage: msg,
      ));
    }
  }

  Future<void> _onLoadEligibleOfficers(
    LoadEligibleOfficersEvent event,
    Emitter<AdminComplaintState> emit,
  ) async {
    emit(state.copyWith(isLoadingOfficers: true));
    try {
      final officers = await _repository.getEligibleOfficers();
      emit(state.copyWith(
        isLoadingOfficers: false,
        eligibleOfficers: officers,
      ));
    } catch (_) {
      emit(state.copyWith(isLoadingOfficers: false));
    }
  }
}
