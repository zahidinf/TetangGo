import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/announcements_repository.dart';
import '../../domain/models/announcement_model.dart';

class AnnouncementFormDialog extends StatefulWidget {
  final AnnouncementsRepository repository;
  final AnnouncementModel? initialAnnouncement; // if editing
  final VoidCallback onSuccess;

  const AnnouncementFormDialog({
    super.key,
    required this.repository,
    this.initialAnnouncement,
    required this.onSuccess,
  });

  @override
  State<AnnouncementFormDialog> createState() => _AnnouncementFormDialogState();
}

class _AnnouncementFormDialogState extends State<AnnouncementFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late String _category;
  late bool _isPinned;

  Uint8List? _pickedFileBytes;
  String? _pickedFileName;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final a = widget.initialAnnouncement;
    _titleController = TextEditingController(text: a?.title ?? '');
    _contentController = TextEditingController(text: a?.content ?? '');
    _category = a?.category ?? 'biasa';
    _isPinned = a?.isPinned ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          setState(() {
            _pickedFileBytes = file.bytes;
            _pickedFileName = file.name;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memilih file: $e')),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.initialAnnouncement == null) {
        // Create
        await widget.repository.createAnnouncement(
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          category: _category,
          isPinned: _isPinned,
          imageBytes: _pickedFileBytes,
          fileName: _pickedFileName,
        );
      } else {
        // Update
        await widget.repository.updateAnnouncement(
          id: widget.initialAnnouncement!.id,
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          category: _category,
          isPinned: _isPinned,
          imageBytes: _pickedFileBytes,
          fileName: _pickedFileName,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.primary,
            content: Text(
              widget.initialAnnouncement == null
                  ? 'Pengumuman resmi berhasil dipublikasikan'
                  : 'Pengumuman resmi berhasil diperbarui',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialAnnouncement != null;

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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing
                          ? 'Edit Pengumuman Resmi'
                          : 'Publikasikan Pengumuman Baru',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: AppTheme.danger.withOpacity(0.3)),
                    ),
                    child: Text(_errorMessage!,
                        style: const TextStyle(
                            color: AppTheme.danger, fontSize: 12)),
                  ),

                // Judul
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Judul Pengumuman',
                    hintText:
                        'Contoh: Jadwal Kerja Bakti & Pembersihan Selokan',
                    prefixIcon: Icon(Icons.campaign_outlined),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty)
                      return 'Judul wajib diisi';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Kategori
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(
                    labelText: 'Tingkat Kepentingan (Kategori)',
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'biasa', child: Text('Biasa (Informasi Umum)')),
                    DropdownMenuItem(
                        value: 'penting',
                        child: Text('Penting (Perhatian Khusus)')),
                    DropdownMenuItem(
                        value: 'darurat',
                        child: Text('Darurat / Mendesak (Segera)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _category = val);
                  },
                ),
                const SizedBox(height: 16),

                // Isi Pengumuman
                TextFormField(
                  controller: _contentController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Isi Lengkap Pengumuman',
                    hintText:
                        'Tuliskan rincian kegiatan, lokasi, waktu, dan instruksi bagi warga...',
                    alignLabelWithHint: true,
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(bottom: 80),
                      child: Icon(Icons.subject_rounded),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty)
                      return 'Isi pengumuman wajib diisi';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Upload Gambar Poster
                const Text(
                  'Lampiran Gambar / Poster Kegiatan (Opsional):',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 8),

                if (_pickedFileBytes == null)
                  OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.image_outlined),
                    label: Text(
                      widget.initialAnnouncement?.imageUrl != null
                          ? 'Ganti Gambar Poster'
                          : 'Pilih File Gambar Poster (JPG, PNG)',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: AppTheme.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.image_rounded,
                            color: AppTheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _pickedFileName ?? 'Poster terpilih',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryDark),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              size: 18, color: AppTheme.danger),
                          onPressed: () => setState(() {
                            _pickedFileBytes = null;
                            _pickedFileName = null;
                          }),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),

                // Switch Pin
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.push_pin_outlined,
                              color: AppTheme.danger, size: 20),
                          SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sematkan di Atas (Pin Pengumuman)',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary),
                              ),
                              Text(
                                'Akan selalu tampil di paling atas feed warga',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: _isPinned,
                        activeColor: AppTheme.primary,
                        onChanged: (val) => setState(() => _isPinned = val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed:
                          _isLoading ? null : () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              isEditing ? 'Simpan Perubahan' : 'Publikasikan'),
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
