import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/invitation_repository.dart';
import 'invitation_state.dart';

class InvitationBloc extends Bloc<InvitationEvent, InvitationState> {
  final InvitationRepository _repository;

  InvitationBloc({required InvitationRepository repository})
      : _repository = repository,
        super(const InvitationInitial()) {
    on<LoadInvitations>(_onLoadInvitations);
    on<CreateInvitationEvent>(_onCreateInvitation);
    on<CancelInvitationEvent>(_onCancelInvitation);
    on<CompleteInvitationEvent>(_onCompleteInvitation);
  }

  Future<void> _onLoadInvitations(
    LoadInvitations event,
    Emitter<InvitationState> emit,
  ) async {
    emit(const InvitationLoading());
    try {
      final list = await _repository.getMyInvitations();
      emit(InvitationLoaded(invitations: list));
    } catch (e) {
      emit(InvitationError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onCreateInvitation(
    CreateInvitationEvent event,
    Emitter<InvitationState> emit,
  ) async {
    final currentState = state;
    emit(const InvitationLoading());
    try {
      final newInv = await _repository.createInvitation(
        guestName: event.guestName,
        visitType: event.visitType,
        phone: event.phone,
        notes: event.notes,
        validHours: event.validHours,
      );

      final list = await _repository.getMyInvitations();
      emit(InvitationLoaded(
        invitations: list,
        activeInvitation: newInv,
        actionMessage: 'Undangan berhasil dibuat!',
      ));
    } catch (e) {
      emit(InvitationError(e.toString().replaceAll('Exception: ', '')));
      // Recover list if previously loaded
      if (currentState is InvitationLoaded) {
        emit(currentState);
      }
    }
  }

  Future<void> _onCancelInvitation(
    CancelInvitationEvent event,
    Emitter<InvitationState> emit,
  ) async {
    emit(const InvitationLoading());
    try {
      await _repository.cancelInvitation(
        event.invitationId,
        reason: event.reason,
      );
      final list = await _repository.getMyInvitations();
      emit(InvitationLoaded(
        invitations: list,
        actionMessage: 'Undangan berhasil dibatalkan',
      ));
    } catch (e) {
      emit(InvitationError(e.toString().replaceAll('Exception: ', '')));
      // reload
      try {
        final list = await _repository.getMyInvitations();
        emit(InvitationLoaded(invitations: list));
      } catch (_) {}
    }
  }

  Future<void> _onCompleteInvitation(
    CompleteInvitationEvent event,
    Emitter<InvitationState> emit,
  ) async {
    emit(const InvitationLoading());
    try {
      await _repository.completeInvitation(event.invitationId);
      final list = await _repository.getMyInvitations();
      emit(InvitationLoaded(
        invitations: list,
        actionMessage: 'Undangan berhasil diakhiri',
      ));
    } catch (e) {
      emit(InvitationError(e.toString().replaceAll('Exception: ', '')));
      // reload
      try {
        final list = await _repository.getMyInvitations();
        emit(InvitationLoaded(invitations: list));
      } catch (_) {}
    }
  }
}
