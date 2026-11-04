import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/complaint_model.dart';

class AssignOfficerDialog extends StatefulWidget {
  final ComplaintModel complaint;
  final List<EligibleOfficerModel> eligibleOfficers;
  final Function({
    required String officerName,
    int? officerUserId,
    String? notes,
    String? status,
  }) onAssign;

  const AssignOfficerDialog({
    super.key,
    required this.complaint,
    required this.eligibleOfficers,
    required this.onAssign,
  });

  static Future<void> show(
    BuildContext context, {
    required ComplaintModel complaint,
    required List<EligibleOfficerModel> eligibleOfficers,
    required Function({
      required String officerName,
      int? officerUserId,
      String? notes,
      String? status,
    }) onAssign,
  }) {
    return showDialog(
      context: context,
      builder: (_) => AssignOfficerDialog(
        complaint: complaint,
        eligibleOfficers: eligibleOfficers,
        onAssign: onAssign,
      ),
    );
  }

  @override
  State<AssignOfficerDialog> createState() => _AssignOfficerDialogState();
}

class _AssignOfficerDialogState extends State<AssignOfficerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();

  EligibleOfficerModel? _selectedOfficer;
  String? _newStatus;
  bool _isManualInput = false;

  @override
  void initState() {
    super.initState();
    // Default status upgrade recommendation: if "Menunggu", suggest updating to "Diproses"
    if (widget.complaint.status == ComplaintStatus.menunggu) {
      _newStatus = ComplaintStatus.diproses.label;
    }

    if (widget.complaint.assignedOfficer != null) {
      _nameController.text = widget.complaint.assignedOfficer!;
      final match = widget.eligibleOfficers.where(
        (o) => o.name.toLowerCase() == widget.complaint.assignedOfficer!.toLowerCase(),
      );
      if (match.isNotEmpty) {
        _selectedOfficer = match.first;
      } else {
        _isManualInput = true;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isReassign = widget.complaint.assignedOfficer != null &&
        widget.complaint.assignedOfficer!.isNotEmpty;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.engineering_rounded,
                        color: AppTheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isReassign ? 'Ganti Petugas Lapangan' : 'Tugaskan Petugas Lapangan',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark,
                            ),
                          ),
                          Text(
                            'Tiket: ${widget.complaint.ticketNumber}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),

                // Complaint context summary
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.complaint.title,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Kategori: ${widget.complaint.category.label} • Status: ${widget.complaint.status.label}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Mode toggle (Pilih dari daftar petugas aktif vs Ketik nama manual)
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Pilih Petugas / Teknisi',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      icon: Icon(
                        _isManualInput ? Icons.list_alt_rounded : Icons.edit_note_rounded,
                        size: 16,
                      ),
                      label: Text(
                        _isManualInput ? 'Pilih Petugas Terdaftar' : 'Input Manual / Mitra',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () {
                        setState(() {
                          _isManualInput = !_isManualInput;
                          if (!_isManualInput && _selectedOfficer != null) {
                            _nameController.text = _selectedOfficer!.name;
                          }
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                if (!_isManualInput && widget.eligibleOfficers.isNotEmpty)
                  DropdownButtonFormField<EligibleOfficerModel>(
                    value: _selectedOfficer,
                    isExpanded: true,
                    decoration: InputDecoration(
                      hintText: 'Pilih staf atau petugas keamanan...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: widget.eligibleOfficers.map((officer) {
                      return DropdownMenuItem<EligibleOfficerModel>(
                        value: officer,
                        child: Text(
                          '${officer.name} (${officer.role})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedOfficer = val;
                        if (val != null) {
                          _nameController.text = val.name;
                        }
                      });
                    },
                    validator: (val) {
                      if (!_isManualInput && val == null && _nameController.text.trim().isEmpty) {
                        return 'Silakan pilih petugas atau gunakan input manual';
                      }
                      return null;
                    },
                  )
                else
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Nama Petugas / Teknisi',
                      hintText: 'Misal: Pak Joko (Teknisi Listrik)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().length < 2) {
                        return 'Nama petugas minimal 2 karakter';
                      }
                      return null;
                    },
                  ),

                const SizedBox(height: 16),

                // Workflow status option
                DropdownButtonFormField<String>(
                  value: _newStatus,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Perbarui Status Tiket (Opsional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text('Pertahankan status (${widget.complaint.status.label})', overflow: TextOverflow.ellipsis),
                    ),
                    const DropdownMenuItem(
                      value: 'Diproses',
                      child: Text('Ubah ke: Diproses (Dalam Pengerjaan)', overflow: TextOverflow.ellipsis),
                    ),
                    const DropdownMenuItem(
                      value: 'Selesai',
                      child: Text('Ubah ke: Selesai', overflow: TextOverflow.ellipsis),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _newStatus = val;
                    });
                  },
                ),

                const SizedBox(height: 16),

                // Notes
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Catatan Penugasan (Instruksi kerja / alasan)',
                    hintText: 'Misal: Cek sekring penerangan jalan blok B...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),

                const SizedBox(height: 24),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Batal'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        if (_formKey.currentState?.validate() ?? false) {
                          final officerName = _nameController.text.trim();
                          final officerUserId = (!_isManualInput && _selectedOfficer != null)
                              ? _selectedOfficer!.id
                              : null;
                          final notes = _notesController.text.trim();

                          widget.onAssign(
                            officerName: officerName,
                            officerUserId: officerUserId,
                            notes: notes.isNotEmpty ? notes : null,
                            status: _newStatus,
                          );
                          Navigator.of(context).pop();
                        }
                      },
                      child: Text(isReassign ? 'Perbarui Penugasan' : 'Tugaskan'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
