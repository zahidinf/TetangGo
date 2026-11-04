import 'package:equatable/equatable.dart';
import '../../domain/models/complaint_model.dart';

abstract class ComplaintEvent extends Equatable {
  const ComplaintEvent();

  @override
  List<Object?> get props => [];
}

class LoadComplaintsEvent extends ComplaintEvent {
  final int page;
  final bool refresh;

  const LoadComplaintsEvent({this.page = 1, this.refresh = false});

  @override
  List<Object?> get props => [page, refresh];
}

class CreateComplaintSubmittedEvent extends ComplaintEvent {
  final String title;
  final String description;
  final ComplaintCategory category;
  final List<int>? photoBytes;
  final String? photoFileName;

  const CreateComplaintSubmittedEvent({
    required this.title,
    required this.description,
    required this.category,
    this.photoBytes,
    this.photoFileName,
  });

  @override
  List<Object?> get props => [
        title,
        description,
        category,
        photoBytes,
        photoFileName,
      ];
}

class LoadComplaintDetailEvent extends ComplaintEvent {
  final int id;

  const LoadComplaintDetailEvent(this.id);

  @override
  List<Object?> get props => [id];
}
