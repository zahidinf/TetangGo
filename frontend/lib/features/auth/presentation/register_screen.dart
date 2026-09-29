import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../resident_management/data/resident_repository.dart';
import '../../resident_management/domain/models/house_model.dart';
import '../data/auth_repository.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isLoadingHouses = true;

  List<HouseModel> _houses = [];
  HouseModel? _selectedHouse;
  String _ownershipStatus = 'pemilik'; // 'pemilik' or 'pengontrak'
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchHouses();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _fetchHouses() async {
    try {
      final repo = context.read<ResidentRepository>();
      final list = await repo.getAvailableHouses();
      if (mounted) {
        setState(() {
          _houses = list;
          _isLoadingHouses = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingHouses = false;
        });
      }
    }
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedHouse == null) {
      setState(() {
        _errorMessage = 'Silakan pilih unit rumah yang Anda tempati';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authRepo = context.read<AuthRepository>();
      await authRepo.register(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        houseId: _selectedHouse!.id,
        ownershipStatus: _ownershipStatus,
      );

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 52),
          title: const Text('Pendaftaran Berhasil!', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text(
            'Akun Anda telah terdaftar dan masuk dalam antrean verifikasi Pengurus RT. '
            'Silakan masuk untuk melihat status pendaftaran.',
            textAlign: TextAlign.center,
          ),
          actions: [
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/login');
                },
                child: const Text('Kembali ke Login'),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => context.go('/login'),
        ),
        title: const Text(
          'Registrasi Warga Baru',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontSize: 18),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              elevation: 0,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.primary, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Daftar Warga TetangGo',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Lengkapi data hunian untuk bergabung ke cluster',
                                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: AppTheme.danger.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_errorMessage!, style: const TextStyle(color: AppTheme.danger, fontSize: 13)),
                              ),
                            ],
                          ),
                        ),

                      // Nama Lengkap
                      const Text('Nama Lengkap', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          hintText: 'Contoh: Budi Santoso',
                          prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
                      ),
                      const SizedBox(height: 16),

                      // Nomor WhatsApp
                      const Text('Nomor WhatsApp / HP', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: 'Contoh: 081234567890',
                          prefixIcon: const Icon(Icons.phone_iphone_rounded, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Nomor WhatsApp wajib diisi';
                          if (v.trim().length < 9) return 'Nomor HP tidak valid';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Email
                      const Text('Alamat Email', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'nama@domain.com',
                          prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Email wajib diisi';
                          if (!v.contains('@') || !v.contains('.')) return 'Format email tidak valid';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Dropdown Rumah
                      const Text('Pilih Hunian yang Ditinggali', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      _isLoadingHouses
                          ? const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)))
                          : DropdownButtonFormField<HouseModel>(
                              value: _selectedHouse,
                              hint: const Text('Pilih Blok dan Nomor Rumah'),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.home_outlined, size: 20),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              items: _houses.map((h) {
                                return DropdownMenuItem<HouseModel>(
                                  value: h,
                                  child: Text('Blok ${h.block} No. ${h.houseNumber} (${h.statusDisplay})'),
                                );
                              }).toList(),
                              onChanged: (val) => setState(() => _selectedHouse = val),
                              validator: (v) => v == null ? 'Rumah wajib dipilih' : null,
                            ),
                      const SizedBox(height: 16),

                      // Status Kepemilikan
                      const Text('Status Kepemilikan Hunian', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _ownershipStatus = 'pemilik'),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: _ownershipStatus == 'pemilik' ? AppTheme.primary.withOpacity(0.08) : Colors.transparent,
                                  border: Border.all(
                                    color: _ownershipStatus == 'pemilik' ? AppTheme.primary : const Color(0xFFCBD5E1),
                                    width: _ownershipStatus == 'pemilik' ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _ownershipStatus == 'pemilik' ? Icons.radio_button_checked : Icons.radio_button_off,
                                      color: _ownershipStatus == 'pemilik' ? AppTheme.primary : Colors.grey,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('Pemilik Rumah', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _ownershipStatus = 'pengontrak'),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: _ownershipStatus == 'pengontrak' ? AppTheme.primary.withOpacity(0.08) : Colors.transparent,
                                  border: Border.all(
                                    color: _ownershipStatus == 'pengontrak' ? AppTheme.primary : const Color(0xFFCBD5E1),
                                    width: _ownershipStatus == 'pengontrak' ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _ownershipStatus == 'pengontrak' ? Icons.radio_button_checked : Icons.radio_button_off,
                                      color: _ownershipStatus == 'pengontrak' ? AppTheme.primary : Colors.grey,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('Penyewa / Kontrak', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Password
                      const Text('Kata Sandi', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          hintText: 'Minimal 6 karakter',
                          prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Kata sandi wajib diisi';
                          if (v.length < 6) return 'Minimal 6 karakter';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Konfirmasi Password
                      const Text('Konfirmasi Kata Sandi', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        decoration: InputDecoration(
                          hintText: 'Ulangi kata sandi Anda',
                          prefixIcon: const Icon(Icons.lock_reset_rounded, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureConfirmPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
                            onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Konfirmasi kata sandi wajib diisi';
                          if (v != _passwordController.text) return 'Kata sandi tidak cocok';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Tombol Submit
                      ElevatedButton(
                        onPressed: _isLoading ? null : _onSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                'Daftar Sekarang',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                      ),
                      const SizedBox(height: 16),

                      // Back to login
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Sudah punya akun?', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                          TextButton(
                            onPressed: () => context.go('/login'),
                            child: const Text('Masuk di sini', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
