import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/invitation_model.dart';

class CreateInvitationDialog extends StatefulWidget {
  final Function({
    required String guestName,
    required VisitType visitType,
    String? phone,
    String? notes,
    required int validHours,
  }) onSubmit;

  const CreateInvitationDialog({
    super.key,
    required this.onSubmit,
  });

  static Future<void> show(
    BuildContext context, {
    required Function({
      required String guestName,
      required VisitType visitType,
      String? phone,
      String? notes,
      required int validHours,
    }) onSubmit,
  }) {
    return showDialog(
      context: context,
      builder: (context) => CreateInvitationDialog(onSubmit: onSubmit),
    );
  }

  @override
  State<CreateInvitationDialog> createState() => _CreateInvitationDialogState();
}

class _CreateInvitationDialogState extends State<CreateInvitationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();

  VisitType _visitType = VisitType.tamu;
  int _validHours = 24;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.onSubmit(
        guestName: _nameController.text.trim(),
        visitType: _visitType,
        phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        validHours: _validHours,
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.primary),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Buat Undangan Tamu',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                      splashRadius: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Jenis Kunjungan Radio Toggle
                const Text(
                  'Jenis Kunjungan',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _visitType = VisitType.tamu),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          decoration: BoxDecoration(
                            color: _visitType == VisitType.tamu
                                ? AppTheme.primary.withOpacity(0.1)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _visitType == VisitType.tamu
                                  ? AppTheme.primary
                                  : const Color(0xFFCBD5E1),
                              width: _visitType == VisitType.tamu ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.group_rounded,
                                size: 16,
                                color: _visitType == VisitType.tamu ? AppTheme.primary : AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Tamu Warga',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _visitType == VisitType.tamu ? AppTheme.primary : AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _visitType = VisitType.kurir),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                          decoration: BoxDecoration(
                            color: _visitType == VisitType.kurir
                                ? Colors.orange.withOpacity(0.1)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _visitType == VisitType.kurir
                                  ? Colors.orange
                                  : const Color(0xFFCBD5E1),
                              width: _visitType == VisitType.kurir ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.local_shipping_rounded,
                                size: 16,
                                color: _visitType == VisitType.kurir ? Colors.orange : AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Kurir / Paket',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _visitType == VisitType.kurir ? Colors.orange.shade800 : AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Nama Tamu
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Tamu / Kurir *',
                    hintText: 'Contoh: Bapak Joko Susilo / Kurir Shopee',
                    prefixIcon: Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nama tamu wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Nomor Telepon (Opsional)
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Nomor WhatsApp / Telepon (Opsional)',
                    hintText: '08xxxxxxxxxx',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Masa Berlaku Durasi
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  value: _validHours,
                  decoration: const InputDecoration(
                    labelText: 'Masa Berlaku Undangan',
                    prefixIcon: Icon(Icons.timelapse_rounded),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 6, child: Text('6 Jam (Singkat / Paket)', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 12, child: Text('12 Jam (Setengah Hari)', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 24, child: Text('24 Jam (Default)', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 48, child: Text('48 Jam (2 Hari)', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 72, child: Text('72 Jam (3 Hari - Maks)', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _validHours = val);
                  },
                ),
                const SizedBox(height: 16),

                // Catatan Tambahan
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Catatan untuk Petugas Pos Satpam (Opsional)',
                    hintText: 'Contoh: Tamu menginap, membawa mobil hitam B 1234 CD',
                    prefixIcon: Icon(Icons.notes_rounded),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Batal'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.qr_code_2_rounded),
                      label: const Text('Terbitkan QR Code'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
  }
}
