import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/security_repository.dart';
import '../../domain/models/security_models.dart';

class SecurityAssignmentDialog extends StatefulWidget {
  final SecurityUserModel user;
  final VoidCallback onUpdated;

  const SecurityAssignmentDialog({
    super.key,
    required this.user,
    required this.onUpdated,
  });

  @override
  State<SecurityAssignmentDialog> createState() =>
      _SecurityAssignmentDialogState();
}

class _SecurityAssignmentDialogState extends State<SecurityAssignmentDialog> {
  SecurityRepository get _repo => context.read<SecurityRepository>();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  List<NeighborhoodModel> _neighborhoods = [];
  List<SecurityAssignmentModel> _assignments = [];

  int? _selectedNeighborhoodId;
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _repo.getAdminNeighborhoods(),
        _repo.getAdminAssignments(userId: widget.user.id),
      ]);

      if (mounted) {
        final neighborhoods = results[0] as List<NeighborhoodModel>;
        final assignments = results[1] as List<SecurityAssignmentModel>;

        // Select the first available neighborhood that isn't already active
        final activeNeighborhoodIds = assignments
            .where((a) => a.isActive)
            .map((a) => a.neighborhoodId)
            .toSet();
        final available = neighborhoods
            .where((n) => !activeNeighborhoodIds.contains(n.id))
            .toList();

        setState(() {
          _neighborhoods = neighborhoods;
          _assignments = assignments;
          _selectedNeighborhoodId =
              available.isNotEmpty ? available.first.id : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _handleAssign() async {
    if (_selectedNeighborhoodId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih lingkungan tugas terlebih dahulu'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await _repo.createSecurityAssignment(
        userId: widget.user.id,
        neighborhoodId: _selectedNeighborhoodId!,
        notes: _notesController.text.trim(),
      );

      if (mounted) {
        _notesController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Petugas satpam berhasil ditugaskan ke lingkungan.'),
            backgroundColor: AppTheme.success,
          ),
        );
        widget.onUpdated();
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _confirmRevokeAssignment(
      SecurityAssignmentModel assignment) async {
    final notesCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 24),
            SizedBox(width: 8),
            Text('Cabut Penugasan Satpam',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Apakah Anda yakin ingin mencabut penugasan "${widget.user.displayName}" di "${assignment.neighborhoodName}"?',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              decoration: InputDecoration(
                hintText: 'Alasan pencabutan (opsional)',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cabut Penugasan'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isSubmitting = true);
      try {
        await _repo.revokeSecurityAssignment(
          assignment.id,
          notes:
              notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Penugasan di "${assignment.neighborhoodName}" berhasil dicabut.'),
              backgroundColor: AppTheme.success,
            ),
          );
          widget.onUpdated();
          await _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: AppTheme.danger,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _handleReactivateAssignment(
      SecurityAssignmentModel assignment) async {
    setState(() => _isSubmitting = true);
    try {
      await _repo.updateSecurityAssignmentStatus(
        assignment.id,
        isActive: true,
        notes: 'Diaktifkan kembali oleh pengurus',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Penugasan di "${assignment.neighborhoodName}" aktif kembali.'),
            backgroundColor: AppTheme.success,
          ),
        );
        widget.onUpdated();
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeAssignments = _assignments.where((a) => a.isActive).toList();
    final inactiveAssignments = _assignments.where((a) => !a.isActive).toList();

    final activeNeighborhoodIds =
        activeAssignments.map((a) => a.neighborhoodId).toSet();
    final assignableNeighborhoods = _neighborhoods
        .where((n) => !activeNeighborhoodIds.contains(n.id))
        .toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.assignment_ind_rounded,
                        color: AppTheme.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Atur Penugasan: ${widget.user.displayName}',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Kelola penugasan lingkungan/cluster tugas untuk satpam ini',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Content Body
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_errorMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.danger.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: AppTheme.danger.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline_rounded,
                                        color: AppTheme.danger, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.danger),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Add Assignment Section
                            Card(
                              elevation: 0,
                              color: const Color(0xFFF8FAFC),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side:
                                    const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Tambah Penugasan Baru',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14),
                                    ),
                                    const SizedBox(height: 10),
                                    if (assignableNeighborhoods.isEmpty)
                                      const Padding(
                                        padding:
                                            EdgeInsets.symmetric(vertical: 8),
                                        child: Text(
                                          'Petugas ini sudah ditugaskan ke seluruh lingkungan yang tersedia.',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.textSecondary),
                                        ),
                                      )
                                    else ...[
                                      DropdownButtonFormField<int>(
                                        value: _selectedNeighborhoodId,
                                        isExpanded: true,
                                        decoration: InputDecoration(
                                          labelText:
                                              'Pilih Lingkungan / Cluster *',
                                          prefixIcon: const Icon(
                                              Icons.location_city_rounded,
                                              size: 20),
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 12, vertical: 10),
                                        ),
                                        items: assignableNeighborhoods.map((n) {
                                          return DropdownMenuItem<int>(
                                            value: n.id,
                                            child: Text(
                                              '${n.name}${n.code.isNotEmpty ? ' (${n.code})' : ''}',
                                              style:
                                                  const TextStyle(fontSize: 13),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: _isSubmitting
                                            ? null
                                            : (val) {
                                                if (val != null)
                                                  setState(() =>
                                                      _selectedNeighborhoodId =
                                                          val);
                                              },
                                      ),
                                      const SizedBox(height: 10),
                                      TextField(
                                        controller: _notesController,
                                        enabled: !_isSubmitting,
                                        decoration: InputDecoration(
                                          hintText:
                                              'Catatan penugasan / shift (contoh: Shift Siang, Pos Utama)',
                                          prefixIcon: const Icon(
                                              Icons.notes_rounded,
                                              size: 20),
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 12, vertical: 10),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.primary,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 10),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                          ),
                                          icon: _isSubmitting
                                              ? const SizedBox(
                                                  width: 14,
                                                  height: 14,
                                                  child:
                                                      CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.white),
                                                )
                                              : const Icon(Icons.add_rounded,
                                                  size: 16),
                                          label: const Text(
                                              'Tugaskan ke Lingkungan',
                                              style: TextStyle(fontSize: 13)),
                                          onPressed: _isSubmitting
                                              ? null
                                              : _handleAssign,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Active Assignments Section
                            const Text(
                              'Penugasan Aktif Saat Ini',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            if (activeAssignments.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0xFFFDE68A)),
                                ),
                                child: Row(
                                  children: const [
                                    Icon(Icons.warning_amber_rounded,
                                        color: Color(0xFFD97706), size: 20),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Petugas ini belum memiliki penugasan aktif di lingkungan manapun. Akses pos satpam akan ditolak sampai ada penugasan aktif.',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFFB45309)),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: activeAssignments.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, idx) {
                                  final a = activeAssignments[idx];
                                  return Card(
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: const BorderSide(
                                          color: Color(0xFFDCFCE7)),
                                    ),
                                    color: const Color(0xFFF0FDF4),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 12),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFDCFCE7),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                                Icons.shield_rounded,
                                                color: Color(0xFF16A34A),
                                                size: 18),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      a.neighborhoodName,
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 13),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 6,
                                                          vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                            0xFFDCFCE7),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(4),
                                                      ),
                                                      child: const Text(
                                                        'Aktif',
                                                        style: TextStyle(
                                                          color:
                                                              Color(0xFF15803D),
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (a.notes.isNotEmpty) ...[
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Catatan: ${a.notes}',
                                                    style: const TextStyle(
                                                        fontSize: 11,
                                                        color: AppTheme
                                                            .textSecondary),
                                                  ),
                                                ],
                                                if (a.assignedAt != null) ...[
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Ditugaskan sejak: ${a.assignedAt!.day}/${a.assignedAt!.month}/${a.assignedAt!.year}',
                                                    style: const TextStyle(
                                                        fontSize: 10,
                                                        color:
                                                            Color(0xFF64748B)),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          TextButton.icon(
                                            style: TextButton.styleFrom(
                                              foregroundColor: AppTheme.danger,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                            ),
                                            icon: const Icon(
                                                Icons.person_remove_rounded,
                                                size: 16),
                                            label: const Text('Cabut',
                                                style: TextStyle(fontSize: 12)),
                                            onPressed: _isSubmitting
                                                ? null
                                                : () =>
                                                    _confirmRevokeAssignment(a),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),

                            // Inactive / Revoked Assignments History
                            if (inactiveAssignments.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              const Text(
                                'Riwayat Penugasan Nonaktif / Dicabut',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppTheme.textSecondary),
                              ),
                              const SizedBox(height: 8),
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: inactiveAssignments.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 6),
                                itemBuilder: (context, idx) {
                                  final a = inactiveAssignments[idx];
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.history_rounded,
                                            size: 18, color: Color(0xFF94A3B8)),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                a.neighborhoodName,
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF64748B)),
                                              ),
                                              if (a.notes.isNotEmpty)
                                                Text(
                                                  'Catatan: ${a.notes}',
                                                  style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Color(0xFF94A3B8)),
                                                ),
                                            ],
                                          ),
                                        ),
                                        TextButton(
                                          style: TextButton.styleFrom(
                                              foregroundColor:
                                                  AppTheme.primary),
                                          onPressed: _isSubmitting
                                              ? null
                                              : () =>
                                                  _handleReactivateAssignment(
                                                      a),
                                          child: const Text('Aktifkan Lagi',
                                              style: TextStyle(fontSize: 11)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
              ),

              const Divider(height: 24),
              // Footer
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Selesai'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
