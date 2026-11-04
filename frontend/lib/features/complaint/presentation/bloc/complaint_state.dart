import 'package:equatable/equatable.dart';
import '../../domain/models/complaint_model.dart';

enum ComplaintListStatus { initial, loading, success, failure }
enum ComplaintSubmitStatus { initial, submitting, success, failure }

class ComplaintState extends Equatable {
  final ComplaintListStatus listStatus;
  final List<ComplaintModel> complaints;
  final int currentPage;
  final int totalComplaints;
  final int totalPages;
  final String? listErrorMessage;

  final ComplaintSubmitStatus submitStatus;
  final ComplaintModel? createdComplaint;
  final String? submitErrorMessage;

  final ComplaintModel? selectedComplaint;
  final bool isLoadingDetail;
  final String? detailErrorMessage;

  const ComplaintState({
    this.listStatus = ComplaintListStatus.initial,
    this.complaints = const [],
    this.currentPage = 1,
    this.totalComplaints = 0,
    this.totalPages = 1,
    this.listErrorMessage,
    this.submitStatus = ComplaintSubmitStatus.initial,
    this.createdComplaint,
    this.submitErrorMessage,
    this.selectedComplaint,
    this.isLoadingDetail = false,
    this.detailErrorMessage,
  });

  ComplaintState copyWith({
    ComplaintListStatus? listStatus,
    List<ComplaintModel>? complaints,
    int? currentPage,
    int? totalComplaints,
    int? totalPages,
    String? listErrorMessage,
    ComplaintSubmitStatus? submitStatus,
    ComplaintModel? createdComplaint,
    String? submitErrorMessage,
    ComplaintModel? selectedComplaint,
    bool? isLoadingDetail,
    String? detailErrorMessage,
  }) {
    return ComplaintState(
      listStatus: listStatus ?? this.listStatus,
      complaints: complaints ?? this.complaints,
      currentPage: currentPage ?? this.currentPage,
      totalComplaints: totalComplaints ?? this.totalComplaints,
      totalPages: totalPages ?? this.totalPages,
      listErrorMessage: listErrorMessage,
      submitStatus: submitStatus ?? this.submitStatus,
      createdComplaint: createdComplaint,
      submitErrorMessage: submitErrorMessage,
      selectedComplaint: selectedComplaint ?? this.selectedComplaint,
      isLoadingDetail: isLoadingDetail ?? this.isLoadingDetail,
      detailErrorMessage: detailErrorMessage,
    );
  }

  @override
  List<Object?> get props => [
        listStatus,
        complaints,
        currentPage,
        totalComplaints,
        totalPages,
        listErrorMessage,
        submitStatus,
        createdComplaint,
        submitErrorMessage,
        selectedComplaint,
        isLoadingDetail,
        detailErrorMessage,
      ];
}
