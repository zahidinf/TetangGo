import 'package:equatable/equatable.dart';
import '../../domain/models/complaint_model.dart';

abstract class AdminComplaintEvent extends Equatable {
  const AdminComplaintEvent();

  @override
  List<Object?> get props => [];
}

class LoadKanbanComplaintsEvent extends AdminComplaintEvent {
  final String? category;
  final String? officer;
  final String? search;
  final String? startDate;
  final String? endDate;

  const LoadKanbanComplaintsEvent({
    this.category,
    this.officer,
    this.search,
    this.startDate,
    this.endDate,
  });

  @override
  List<Object?> get props => [category, officer, search, startDate, endDate];
}

class LoadAdminComplaintsListEvent extends AdminComplaintEvent {
  final String? status;
  final String? category;
  final String? officer;
  final String? search;
  final String? startDate;
  final String? endDate;
  final int page;
  final int limit;

  const LoadAdminComplaintsListEvent({
    this.status,
    this.category,
    this.officer,
    this.search,
    this.startDate,
    this.endDate,
    this.page = 1,
    this.limit = 10,
  });

  @override
  List<Object?> get props => [
        status,
        category,
        officer,
        search,
        startDate,
        endDate,
        page,
        limit,
      ];
}

class LoadAdminComplaintDetailEvent extends AdminComplaintEvent {
  final int id;

  const LoadAdminComplaintDetailEvent(this.id);

  @override
  List<Object?> get props => [id];
}

class AssignOfficerSubmittedEvent extends AdminComplaintEvent {
  final int complaintId;
  final String officerName;
  final int? officerUserId;
  final String? notes;
  final String? status;

  const AssignOfficerSubmittedEvent({
    required this.complaintId,
    required this.officerName,
    this.officerUserId,
    this.notes,
    this.status,
  });

  @override
  List<Object?> get props => [
        complaintId,
        officerName,
        officerUserId,
        notes,
        status,
      ];
}

class UpdateComplaintStatusSubmittedEvent extends AdminComplaintEvent {
  final int complaintId;
  final ComplaintStatus status;

  const UpdateComplaintStatusSubmittedEvent({
    required this.complaintId,
    required this.status,
  });

  @override
  List<Object?> get props => [complaintId, status];
}

class LoadEligibleOfficersEvent extends AdminComplaintEvent {
  const LoadEligibleOfficersEvent();
}
