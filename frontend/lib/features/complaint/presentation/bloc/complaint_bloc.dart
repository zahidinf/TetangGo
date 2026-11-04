import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/complaint_repository.dart';
import 'complaint_event.dart';
import 'complaint_state.dart';

class ComplaintBloc extends Bloc<ComplaintEvent, ComplaintState> {
  final ComplaintRepository _repository;

  ComplaintBloc({required ComplaintRepository repository})
      : _repository = repository,
        super(const ComplaintState()) {
    on<LoadComplaintsEvent>(_onLoadComplaints);
    on<CreateComplaintSubmittedEvent>(_onCreateComplaint);
    on<LoadComplaintDetailEvent>(_onLoadComplaintDetail);
  }

  Future<void> _onLoadComplaints(
    LoadComplaintsEvent event,
    Emitter<ComplaintState> emit,
  ) async {
    emit(state.copyWith(listStatus: ComplaintListStatus.loading));
    try {
      final res = await _repository.getMyComplaints(
        page: event.page,
        limit: 10,
      );
      emit(state.copyWith(
        listStatus: ComplaintListStatus.success,
        complaints: res.complaints,
        currentPage: event.page,
        totalComplaints: res.total,
        totalPages: res.totalPages,
        listErrorMessage: null,
      ));
    } catch (e) {
      String message = 'Gagal memuat pengaduan cluster';
      if (e is DioException) {
        final resp = e.response?.data;
        if (resp is Map && resp['message'] != null) {
          message = resp['message'].toString();
        }
      }
      emit(state.copyWith(
        listStatus: ComplaintListStatus.failure,
        listErrorMessage: message,
      ));
    }
  }

  Future<void> _onCreateComplaint(
    CreateComplaintSubmittedEvent event,
    Emitter<ComplaintState> emit,
  ) async {
    emit(state.copyWith(
      submitStatus: ComplaintSubmitStatus.submitting,
      submitErrorMessage: null,
    ));

    try {
      Uint8List? bytes;
      if (event.photoBytes != null) {
        bytes = Uint8List.fromList(event.photoBytes!);
      }

      final created = await _repository.createComplaint(
        title: event.title,
        description: event.description,
        category: event.category,
        photoBytes: bytes,
        photoFileName: event.photoFileName,
      );

      emit(state.copyWith(
        submitStatus: ComplaintSubmitStatus.success,
        createdComplaint: created,
        submitErrorMessage: null,
      ));

      // Reload first page
      add(const LoadComplaintsEvent(page: 1, refresh: true));
    } catch (e) {
      String message = 'Gagal mengirim pengaduan cluster';
      if (e is DioException) {
        final resp = e.response?.data;
        if (resp is Map && resp['message'] != null) {
          message = resp['message'].toString();
        }
      }
      emit(state.copyWith(
        submitStatus: ComplaintSubmitStatus.failure,
        submitErrorMessage: message,
      ));
    }
  }

  Future<void> _onLoadComplaintDetail(
    LoadComplaintDetailEvent event,
    Emitter<ComplaintState> emit,
  ) async {
    emit(state.copyWith(isLoadingDetail: true, detailErrorMessage: null));
    try {
      final detail = await _repository.getComplaintDetail(event.id);
      emit(state.copyWith(
        selectedComplaint: detail,
        isLoadingDetail: false,
        detailErrorMessage: null,
      ));
    } catch (e) {
      String message = 'Gagal memuat detail pengaduan cluster';
      if (e is DioException) {
        final resp = e.response?.data;
        if (resp is Map && resp['message'] != null) {
          message = resp['message'].toString();
        }
      }
      emit(state.copyWith(
        isLoadingDetail: false,
        detailErrorMessage: message,
      ));
    }
  }
}
