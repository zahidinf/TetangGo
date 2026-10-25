import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../security/data/security_repository.dart';
import '../../../security/domain/models/security_models.dart';

class AdminIncidentCorrectionDialog extends StatefulWidget {
  final SecurityIncidentModel incident;
  final ValueChanged<SecurityIncidentModel>? onSuccess;

  const AdminIncidentCorrectionDialog({
    super.key,
    required this.incident,
    this.onSuccess,
  });

  @override
  State<AdminIncidentCorrectionDialog> createState() =>
      _AdminIncidentCorrectionDialogState();
}

class _AdminIncidentCorrectionDialogState
    extends State<AdminIncidentCorrectionDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _status;
  late String _category;
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _notesController;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _status = widget.incident.status.toUpperCase();
    if (_status == 'REPORTED') _status = 'ACTIVE';
    if (_status == 'ACKNOWLEDGED') _status = 'RESPONDING';

    _category = widget.incident.category.toUpperCase();
    if (_category != 'KEJAHATAN' &&
        _category != 'KEBAKARAN' &&
        _category != 'MEDIS') {
      _category = 'KEJAHATAN';
    }

    _titleController = TextEditingController(text: widget.incident.title);
    _descController = TextEditingController(text: widget.incident.description);
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitCorrection() async {
    if (!_formKey.currentState!.validate()) return;

    final notes = _notesController.text.trim();
    if (notes.isEmpty) {
      setState(() {
        _errorMessage = 'Alasan / catatan koreksi wajib diisi untuk audit trail.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final repo = context.read<SecurityRepository>();
      final updated = await repo.correctIncident(
        widget.incident.id,
        status: _status,
        category: _category,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        notes: notes,
      );

      if (mounted) {
        widget.onSuccess?.call(updated);
        Navigator.of(context).pop(updated);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Laporan insiden berhasil dikoreksi dan dicatat dalam audit trail.'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.edit_note_rounded,
                        color: AppTheme.primaryDark,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Koreksi Laporan Kejadian #${widget.incident.id}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Akses Khusus Admin • Perubahan tercatat resmi di Audit Trail',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Error Banner
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: AppTheme.danger, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                                color: AppTheme.danger, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Status Koreksi
                const Text(
                  'Status Penanganan',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _status,
                  decoration: InputDecoration(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'ACTIVE',
                      child: Text('Dilaporkan (Aktif)'),
                    ),
                    DropdownMenuItem(
                      value: 'RESPONDING',
                      child: Text('Sedang Ditangani (Aktif)'),
                    ),
                    DropdownMenuItem(
                      value: 'RESOLVED',
                      child: Text('Terkendali (Selesai)'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _status = val);
                  },
                ),
                const SizedBox(height: 16),

                // Kategori Kejadian
                const Text(
                  'Kategori Kejadian',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: InputDecoration(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'KEJAHATAN',
                      child: Text('Kejahatan / Kriminal'),
                    ),
                    DropdownMenuItem(
                      value: 'KEBAKARAN',
                      child: Text('Kebakaran & Api'),
                    ),
                    DropdownMenuItem(
                      value: 'MEDIS',
                      child: Text('Darurat Medis / Kesehatan'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _category = val);
                  },
                ),
                const SizedBox(height: 16),

                // Judul
                const Text(
                  'Judul Laporan',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    hintText: 'Contoh: Insiden Medis RT 02',
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Judul laporan tidak boleh kosong'
                      : null,
                ),
                const SizedBox(height: 16),

                // Deskripsi
                const Text(
                  'Deskripsi Insiden',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Detail insiden dan tindak lanjut...',
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Catatan Koreksi / Alasan (Wajib)
                const Row(
                  children: [
                    Text(
                      'Alasan / Catatan Koreksi',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(width: 4),
                    Text(
                      '*Wajib untuk Audit',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Jelaskan alasan koreksi status atau data kejadian ini...',
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Catatan koreksi wajib diisi'
                      : null,
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Batal'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submitCorrection,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline_rounded,
                              size: 18),
                      label: Text(_isSubmitting ? 'Menyimpan...' : 'Simpan Koreksi'),
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
