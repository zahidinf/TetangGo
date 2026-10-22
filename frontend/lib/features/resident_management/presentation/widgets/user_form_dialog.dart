import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/honorific_helper.dart';
import '../../data/resident_repository.dart';
import '../../domain/models/house_model.dart';
import '../../domain/models/resident_user_model.dart';
import 'house_detail_dialog.dart';

class UserFormDialog extends StatefulWidget {
  final ResidentUserModel? userToEdit;
  final VoidCallback onSaved;
  final List<HouseModel> houses;

  const UserFormDialog({
    super.key,
    this.userToEdit,
    required this.onSaved,
    required this.houses,
  });

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;

  int? _selectedHouseId;
  String _selectedSalutation = HonorificHelper.bapak;
  String _selectedStatus = 'active';
  String _selectedRole = 'RESIDENT';
  String _selectedOwnership = 'pemilik';

  bool _isPasswordVisible = false;
  bool _isLoading = false;

  bool get isEdit => widget.userToEdit != null;

  @override
  void initState() {
    super.initState();
    final u = widget.userToEdit;
    _selectedSalutation = HonorificHelper.normalize(u?.salutation);
    _nameController = TextEditingController(text: u?.name ?? '');
    _phoneController = TextEditingController(text: u?.phone ?? '');
    _emailController = TextEditingController(text: u?.email ?? '');
    _passwordController = TextEditingController();

    if (u != null) {
      _selectedHouseId = u.houseId;
      _selectedStatus = u.status;
      _selectedRole = u.role;
      _selectedOwnership = u.ownershipStatus.isNotEmpty ? u.ownershipStatus : 'pemilik';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final salutationToSend = HonorificHelper.normalize(_selectedSalutation);

    try {
      final repo = context.read<ResidentRepository>();
      if (isEdit) {
        await repo.adminUpdateUser(
          userId: widget.userToEdit!.id,
          salutation: salutationToSend,
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim(),
          houseId: _selectedHouseId,
          role: _selectedRole,
          status: _selectedStatus,
          ownershipStatus: _selectedOwnership,
        );
      } else {
        await repo.adminCreateUser(
          salutation: salutationToSend,
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          houseId: _selectedHouseId,
          role: _selectedRole,
          status: _selectedStatus,
          ownershipStatus: _selectedOwnership,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEdit
                  ? 'Data warga "${_nameController.text.trim()}" berhasil diperbarui'
                  : 'Warga "${_nameController.text.trim()}" berhasil didaftarkan',
            ),
            backgroundColor: AppTheme.success,
          ),
        );
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isEdit ? Icons.edit_rounded : Icons.person_add_rounded,
                          color: AppTheme.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEdit ? 'Edit Data Warga' : 'Tambah Warga Baru',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isEdit
                                  ? 'Perbarui informasi identitas dan hunian warga'
                                  : 'Daftarkan akun warga secara manual oleh Admin RT',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(height: 28),

                  // Sapaan / Salutation & Nama Lengkap
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 130,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Sapaan *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              key: const ValueKey('salutation_dropdown'),
                              isExpanded: true,
                              value: _selectedSalutation,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              ),
                              items: HonorificHelper.canonicalOptions.map((opt) {
                                return DropdownMenuItem(value: opt, child: Text(opt));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedSalutation = HonorificHelper.normalize(val));
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Nama Lengkap *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                hintText: 'Contoh: Budi Santoso',
                                prefixIcon: const Icon(Icons.person_outline, size: 20),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Nama lengkap wajib diisi';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Nomor WhatsApp
                  const Text('Nomor WhatsApp *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: 'Contoh: 081234567890',
                      prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Nomor WhatsApp wajib diisi';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Email
                  const Text('Alamat Email *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'Contoh: budi@gmail.com',
                      prefixIcon: const Icon(Icons.email_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Alamat email wajib diisi';
                      if (!val.contains('@')) return 'Format email tidak valid';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Password (Hanya untuk tambah warga)
                  if (!isEdit) ...[
                    const Text('Kata Sandi *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        hintText: 'Minimal 6 karakter',
                        prefixIcon: const Icon(Icons.lock_outline, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                            size: 18,
                          ),
                          onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().length < 6) {
                          return 'Password minimal 6 karakter';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Pilihan Hunian (Rumah)
                  const Text('Hunian (Kavling / Nomor Rumah)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  Builder(builder: (context) {
                    final uniqueHouses = <int, HouseModel>{};
                    for (final h in widget.houses) {
                      uniqueHouses[h.id] = h;
                    }
                    final list = uniqueHouses.values.toList();
                    final selectedVal = list.any((h) => h.id == _selectedHouseId) ? _selectedHouseId : null;

                    return DropdownButtonFormField<int?>(
                      isExpanded: true,
                      value: selectedVal,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.home_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Belum Ditetapkan / Tidak Ada', style: TextStyle(color: AppTheme.textSecondary)),
                        ),
                        ...list.map((h) => DropdownMenuItem<int?>(
                              value: h.id,
                              child: Text(
                                '${h.label} (${h.status.toUpperCase()})',
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                            )),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedHouseId = val);
                      },
                    );
                  }),
                  const SizedBox(height: 14),

                  // Status Kepemilikan (jika ada rumah)
                  if (_selectedHouseId != null) ...[
                    const Text('Status Kepemilikan Hunian', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _selectedOwnership,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'pemilik', child: Text('Pemilik Rumah')),
                        DropdownMenuItem(value: 'pengontrak', child: Text('Pengontrak / Penyewa')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedOwnership = val);
                      },
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Status Akun
                  const Text('Status Akun Warga', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _selectedStatus,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('Aktif')),
                      DropdownMenuItem(value: 'inactive', child: Text('Non-Aktif')),
                      DropdownMenuItem(value: 'pending_verification', child: Text('Menunggu Verifikasi')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedStatus = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Peran Organisasi / Role
                  const Text('Peran Organisasi / Role', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: const ['ADMIN', 'CHAIRPERSON', 'VICE_CHAIRPERSON', 'TREASURER', 'SECRETARY', 'RESIDENT'].contains(_selectedRole.toUpperCase())
                        ? _selectedRole.toUpperCase()
                        : 'RESIDENT',
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'RESIDENT', child: Text('Warga (RESIDENT)')),
                      DropdownMenuItem(value: 'CHAIRPERSON', child: Text('Ketua (CHAIRPERSON)')),
                      DropdownMenuItem(value: 'VICE_CHAIRPERSON', child: Text('Wakil Ketua (VICE_CHAIRPERSON)')),
                      DropdownMenuItem(value: 'TREASURER', child: Text('Bendahara (TREASURER)')),
                      DropdownMenuItem(value: 'SECRETARY', child: Text('Sekretaris (SECRETARY)')),
                      DropdownMenuItem(value: 'ADMIN', child: Text('Administrator (ADMIN)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedRole = val);
                    },
                  ),
                  if (widget.userToEdit?.house != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFC7D2FE)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.family_restroom_rounded, color: Color(0xFF4F46E5), size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Keluarga & Kendaraan Terdaftar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF312E81))),
                                Text('Unit ${widget.userToEdit!.houseDisplay}', style: const TextStyle(fontSize: 11, color: Color(0xFF4338CA))),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              showDialog(
                                context: context,
                                builder: (ctx) => HouseDetailDialog(
                                  initialHouse: widget.userToEdit!.house!,
                                  onDataChanged: widget.onSaved,
                                ),
                              );
                            },
                            child: const Text('Kelola'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        child: const Text('Batal'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _isLoading ? null : _submit,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(isEdit ? 'Simpan Perubahan' : 'Daftarkan Warga'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
