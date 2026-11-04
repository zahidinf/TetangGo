import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/complaint_model.dart';
import '../bloc/complaint_bloc.dart';
import '../bloc/complaint_event.dart';
import '../bloc/complaint_state.dart';

class CreateComplaintDialog extends StatefulWidget {
  const CreateComplaintDialog({super.key});

  static Future<ComplaintModel?> show(BuildContext context) {
    return showDialog<ComplaintModel>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: context.read<ComplaintBloc>(),
        child: const CreateComplaintDialog(),
      ),
    );
  }

  @override
  State<CreateComplaintDialog> createState() => _CreateComplaintDialogState();
}

class _CreateComplaintDialogState extends State<CreateComplaintDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  ComplaintCategory _selectedCategory = ComplaintCategory.lampuJalan;
  Uint8List? _selectedPhotoBytes;
  String? _selectedPhotoName;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      if (kIsWeb && source == ImageSource.gallery) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
          withData: true,
        );
        if (result != null && result.files.isNotEmpty) {
          final file = result.files.first;
          if (file.bytes != null) {
            if (file.bytes!.lengthInBytes > 5 * 1024 * 1024) {
              _showError('Ukuran foto maksimal 5MB');
              return;
            }
            setState(() {
              _selectedPhotoBytes = file.bytes;
              _selectedPhotoName = file.name;
            });
          }
        }
        return;
      }

      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );

      if (file != null) {
        final bytes = await file.readAsBytes();
        if (bytes.lengthInBytes > 5 * 1024 * 1024) {
          _showError('Ukuran foto maksimal 5MB');
          return;
        }
        setState(() {
          _selectedPhotoBytes = bytes;
          _selectedPhotoName = file.name;
        });
      }
    } catch (e) {
      _showError('Gagal memilih foto: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.danger,
      ),
    );
  }

  void _showImagePickerSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Pilih Sumber Foto Bukti',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppTheme.primary),
                title: const Text('Ambil Foto Kamera'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppTheme.primary),
                title: const Text('Pilih dari Galeri / Berkas'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    context.read<ComplaintBloc>().add(
          CreateComplaintSubmittedEvent(
            title: _titleController.text.trim(),
            description: _descController.text.trim(),
            category: _selectedCategory,
            photoBytes: _selectedPhotoBytes,
            photoFileName: _selectedPhotoName,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ComplaintBloc, ComplaintState>(
      listenWhen: (prev, curr) => prev.submitStatus != curr.submitStatus,
      listener: (context, state) {
        if (state.submitStatus == ComplaintSubmitStatus.success) {
          Navigator.of(context).pop(state.createdComplaint);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Pengaduan berhasil dibuat! Tiket: ${state.createdComplaint?.ticketNumber}',
              ),
              backgroundColor: AppTheme.success,
              duration: const Duration(seconds: 4),
            ),
          );
        } else if (state.submitStatus == ComplaintSubmitStatus.failure) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.submitErrorMessage ?? 'Gagal membuat pengaduan'),
              backgroundColor: AppTheme.danger,
            ),
          );
        }
      },
      builder: (context, state) {
        final loading = state.submitStatus == ComplaintSubmitStatus.submitting;

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.report_problem_rounded, color: AppTheme.primary),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Lapor Cluster',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                'Laporkan masalah fasilitas lingkungan cluster',
                                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: loading ? null : () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const Divider(height: 28),

                    // Kategori
                    const Text(
                      'Kategori Pengaduan *',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<ComplaintCategory>(
                      initialValue: _selectedCategory,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      items: ComplaintCategory.values.map((cat) {
                        return DropdownMenuItem(
                          value: cat,
                          child: Text(cat.label),
                        );
                      }).toList(),
                      onChanged: loading
                          ? null
                          : (val) {
                              if (val != null) setState(() => _selectedCategory = val);
                            },
                    ),
                    const SizedBox(height: 16),

                    // Judul
                    const Text(
                      'Judul Pengaduan *',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _titleController,
                      enabled: !loading,
                      maxLength: 200,
                      decoration: InputDecoration(
                        hintText: 'Contoh: Lampu jalan depan B1/04 padam',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        counterText: '',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Judul pengaduan cluster wajib diisi';
                        }
                        if (val.trim().length > 200) {
                          return 'Judul maksimal 200 karakter';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Deskripsi
                    const Text(
                      'Deskripsi Masalah *',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descController,
                      enabled: !loading,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Jelaskan letak lokasi dan kondisi fasilitas cluster secara rinci...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.all(14),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Deskripsi pengaduan cluster wajib diisi';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Foto Kerusakan
                    const Text(
                      'Foto Fasilitas / Kerusakan (Opsional)',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    if (_selectedPhotoBytes != null) ...[
                      Stack(
                        children: [
                          Container(
                            height: 180,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.memory(
                              _selectedPhotoBytes!,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: CircleAvatar(
                              backgroundColor: Colors.black54,
                              child: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.white),
                                onPressed: loading
                                    ? null
                                    : () {
                                        setState(() {
                                          _selectedPhotoBytes = null;
                                          _selectedPhotoName = null;
                                        });
                                      },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _selectedPhotoName ?? 'Foto terlampir',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ] else ...[
                      OutlinedButton.icon(
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Ambil atau Unggah Foto Kerusakan'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: loading ? null : _showImagePickerSourceSheet,
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Tombol Aksi
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: loading ? null : () => Navigator.of(context).pop(),
                            child: const Text('Batal'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: loading ? null : _submit,
                            child: loading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text('Kirim Laporan'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
