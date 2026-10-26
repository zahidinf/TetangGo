import 'package:equatable/equatable.dart';
import '../../domain/models/invitation_model.dart';

abstract class InvitationState extends Equatable {
  const InvitationState();

  @override
  List<Object?> get props => [];
}

class InvitationInitial extends InvitationState {
  const InvitationInitial();
}

class InvitationLoading extends InvitationState {
  const InvitationLoading();
}

class InvitationLoaded extends InvitationState {
  final List<GuestInvitationModel> invitations;
  final GuestInvitationModel? activeInvitation;
  final String? actionMessage;

  const InvitationLoaded({
    required this.invitations,
    this.activeInvitation,
    this.actionMessage,
  });

  InvitationLoaded copyWith({
    List<GuestInvitationModel>? invitations,
    GuestInvitationModel? activeInvitation,
    String? actionMessage,
  }) {
    return InvitationLoaded(
      invitations: invitations ?? this.invitations,
      activeInvitation: activeInvitation ?? this.activeInvitation,
      actionMessage: actionMessage,
    );
  }

  @override
  List<Object?> get props => [invitations, activeInvitation, actionMessage];
}

class InvitationError extends InvitationState {
  final String message;

  const InvitationError(this.message);

  @override
  List<Object?> get props => [message];
}

abstract class InvitationEvent extends Equatable {
  const InvitationEvent();

  @override
  List<Object?> get props => [];
}

class LoadInvitations extends InvitationEvent {
  const LoadInvitations();
}

class CreateInvitationEvent extends InvitationEvent {
  final String guestName;
  final VisitType visitType;
  final String? phone;
  final String? notes;
  final int validHours;

  const CreateInvitationEvent({
    required this.guestName,
    required this.visitType,
    this.phone,
    this.notes,
    this.validHours = 24,
  });

  @override
  List<Object?> get props => [guestName, visitType, phone, notes, validHours];
}

class CancelInvitationEvent extends InvitationEvent {
  final int invitationId;
  final String? reason;

  const CancelInvitationEvent({
    required this.invitationId,
    this.reason,
  });

  @override
  List<Object?> get props => [invitationId, reason];
}

class CompleteInvitationEvent extends InvitationEvent {
  final int invitationId;

  const CompleteInvitationEvent({
    required this.invitationId,
  });

  @override
  List<Object?> get props => [invitationId];
}
