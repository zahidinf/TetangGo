import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../profile/domain/models/family_member_model.dart';
import '../../../profile/domain/models/vehicle_model.dart';
import '../../data/resident_repository.dart';
import '../../domain/models/house_detail_full_model.dart';
import '../../domain/models/house_model.dart';

class HouseDetailDialog extends StatefulWidget {
  final HouseModel initialHouse;
  final VoidCallback onDataChanged;

  const HouseDetailDialog({
    super.key,
    required this.initialHouse,
    required this.onDataChanged,
  });

  @override
  State<HouseDetailDialog> createState() => _HouseDetailDialogState();
}

class _HouseDetailDialogState extends State<HouseDetailDialog> {
  bool _isLoading = true;
  HouseDetailFullModel? _details;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchHouseDetails();
  }

  Future<void> _fetchHouseDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = context.read<ResidentRepository>();
      final res = await repo.getHouseDetails(widget.initialHouse.id);
      if (mounted) {
        setState(() {
          _details = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _showAddFamilyDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String relation = 'istri';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.person_add_alt_1_rounded, color: AppTheme.primary),
              SizedBox(width: 8),
              Text('Tambah Anggota Keluarga', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Nama Lengkap *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: relation,
                  decoration: InputDecoration(
                    labelText: 'Hubungan Keluarga *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'istri', child: Text('Istri')),
                    DropdownMenuItem(value: 'suami', child: Text('Suami')),
                    DropdownMenuItem(value: 'anak', child: Text('Anak')),
                    DropdownMenuItem(value: 'orang_tua', child: Text('Orang Tua')),
                    DropdownMenuItem(value: 'famili', child: Text('Famili')),
                    DropdownMenuItem(value: 'lainnya', child: Text('Lainnya')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDlgState(() => relation = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'No. WhatsApp / HP (Opsional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                try {
                  final repo = context.read<ResidentRepository>();
                  await repo.adminAddFamilyMember(
                    houseId: widget.initialHouse.id,
                    name: nameCtrl.text.trim(),
                    relation: relation,
                    phone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('Anggota keluarga berhasil ditambahkan'), backgroundColor: AppTheme.success),
                  );
                  _fetchHouseDetails();
                  widget.onDataChanged();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppTheme.danger),
                  );
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteFamilyConfirm(FamilyMemberModel member) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Anggota Keluarga?'),
        content: Text('Hapus "${member.name}" (${member.relationDisplay}) dari data hunian ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final repo = context.read<ResidentRepository>();
                await repo.adminDeleteFamilyMember(houseId: widget.initialHouse.id, familyId: member.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Anggota keluarga berhasil dihapus'), backgroundColor: AppTheme.success),
                  );
                  _fetchHouseDetails();
                  widget.onDataChanged();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppTheme.danger),
                  );
                }
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _showAddVehicleDialog() {
    final plateCtrl = TextEditingController();
    final modelCtrl = TextEditingController();
    String vehicleType = 'mobil';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.directions_car_rounded, color: AppTheme.primary),
              SizedBox(width: 8),
              Text('Tambah Kendaraan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: plateCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Nomor Plat Kendaraan *',
                    hintText: 'Misal: B 1234 XYZ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: vehicleType,
                  decoration: InputDecoration(
                    labelText: 'Tipe Kendaraan *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'mobil', child: Text('Mobil')),
                    DropdownMenuItem(value: 'motor', child: Text('Sepeda Motor')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDlgState(() => vehicleType = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: modelCtrl,
                  decoration: InputDecoration(
                    labelText: 'Brand / Model (Warna)',
                    hintText: 'Misal: Avanza Putih / Vario Hitam',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                if (plateCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                try {
                  final repo = context.read<ResidentRepository>();
                  await repo.adminAddVehicle(
                    houseId: widget.initialHouse.id,
                    plateNumber: plateCtrl.text.trim(),
                    vehicleType: vehicleType,
                    brandModel: modelCtrl.text.trim().isNotEmpty ? modelCtrl.text.trim() : null,
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('Kendaraan berhasil didaftarkan'), backgroundColor: AppTheme.success),
                  );
                  _fetchHouseDetails();
                  widget.onDataChanged();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppTheme.danger),
                  );
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteVehicleConfirm(VehicleModel vehicle) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Kendaraan?'),
        content: Text('Hapus kendaraan plat "${vehicle.plateNumber}" dari hunian ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final repo = context.read<ResidentRepository>();
                await repo.adminDeleteVehicle(houseId: widget.initialHouse.id, vehicleId: vehicle.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kendaraan berhasil dihapus'), backgroundColor: AppTheme.success),
                  );
                  _fetchHouseDetails();
                  widget.onDataChanged();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppTheme.danger),
                  );
                }
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color text;
    String label;

    switch (status.toLowerCase()) {
      case 'milik':
        bg = const Color(0xFFDCFCE7);
        text = const Color(0xFF15803D);
        label = 'Dihuni Pemilik';
        break;
      case 'kontrak':
        bg = const Color(0xFFDBEAFE);
        text = const Color(0xFF1D4ED8);
        label = 'Kontrak / Sewa';
        break;
      case 'kosong':
      default:
        bg = const Color(0xFFF1F5F9);
        text = const Color(0xFF64748B);
        label = 'Kosong';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final house = _details?.house ?? widget.initialHouse;
    final totalOcc = _details?.totalMembers ?? widget.initialHouse.totalOccupants;
    final head = _details?.headOfFamily;
    final familyList = _details?.familyMembers ?? [];
    final vehicleList = _details?.vehicles ?? [];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 780),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Dialog
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.cottage_rounded, color: AppTheme.primary, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hunian Blok ${house.block} No. ${house.houseNumber}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _buildStatusBadge(house.status),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Total Penghuni: $totalOcc Jiwa',
                                style: const TextStyle(
                                  color: Color(0xFFB45309),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 28),

              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_errorMessage!, style: const TextStyle(color: AppTheme.danger, fontSize: 13)),
                ),

              // Content Body
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Seksi Kepala Keluarga
                            const Text(
                              'Kepala Keluarga / Akun Terdaftar',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(height: 8),
                            Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              color: const Color(0xFFF8FAFC),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: head == null
                                    ? Row(
                                        children: [
                                          Icon(Icons.person_off_outlined, color: Colors.grey.shade400, size: 28),
                                          const SizedBox(width: 12),
                                          const Text(
                                            'Belum ada akun warga terdaftar di hunian ini',
                                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                          ),
                                        ],
                                      )
                                    : Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 24,
                                            backgroundColor: AppTheme.primary.withOpacity(0.15),
                                            child: Text(
                                              head.name.isNotEmpty ? head.name[0].toUpperCase() : 'W',
                                              style: const TextStyle(
                                                color: AppTheme.primaryDark,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  head.name,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    const Icon(Icons.phone_outlined, size: 14, color: AppTheme.textSecondary),
                                                    const SizedBox(width: 4),
                                                    Text(head.phone, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                                    const SizedBox(width: 12),
                                                    const Icon(Icons.email_outlined, size: 14, color: AppTheme.textSecondary),
                                                    const SizedBox(width: 4),
                                                    Text(head.email, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.copy_rounded, size: 18, color: AppTheme.primary),
                                            tooltip: 'Salin No. HP / WhatsApp',
                                            onPressed: () {
                                              Clipboard.setData(ClipboardData(text: head.phone));
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('No. WhatsApp disalin ke clipboard')),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // 2. Seksi Anggota Keluarga
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Anggota Keluarga',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${familyList.length} Orang',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                                TextButton.icon(
                                  onPressed: _showAddFamilyDialog,
                                  icon: const Icon(Icons.add_rounded, size: 16),
                                  label: const Text('+ Tambah Anggota', style: TextStyle(fontSize: 13)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (familyList.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: Colors.grey.shade50,
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: const Center(
                                  child: Text('Belum ada data anggota keluarga tambahan.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: familyList.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 6),
                                itemBuilder: (context, index) {
                                  final m = familyList[index];
                                  return Card(
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor: const Color(0xFFF1F5F9),
                                            child: const Icon(Icons.person_rounded, size: 18, color: AppTheme.textSecondary),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFEEF2FF),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        m.relationDisplay,
                                                        style: const TextStyle(
                                                          color: Color(0xFF4338CA),
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (m.phone != null && m.phone!.isNotEmpty) ...[
                                                  const SizedBox(height: 2),
                                                  Text('No. HP: ${m.phone}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                                ],
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.danger, size: 18),
                                            tooltip: 'Hapus Anggota',
                                            onPressed: () => _showDeleteFamilyConfirm(m),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            const SizedBox(height: 20),

                            // 3. Seksi Kendaraan
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Kendaraan Terdaftar',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${vehicleList.length} Unit',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                                TextButton.icon(
                                  onPressed: _showAddVehicleDialog,
                                  icon: const Icon(Icons.add_rounded, size: 16),
                                  label: const Text('+ Tambah Kendaraan', style: TextStyle(fontSize: 13)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (vehicleList.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: Colors.grey.shade50,
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: const Center(
                                  child: Text('Belum ada kendaraan terdaftar pada unit rumah ini.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: vehicleList.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 6),
                                itemBuilder: (context, index) {
                                  final v = vehicleList[index];
                                  return Card(
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor: const Color(0xFFF1F5F9),
                                            child: Icon(
                                              v.isCar ? Icons.directions_car_rounded : Icons.two_wheeler_rounded,
                                              size: 18,
                                              color: AppTheme.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF1E293B),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    v.plateNumber,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Text(
                                                  v.brandModel ?? v.typeDisplay,
                                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.danger, size: 18),
                                            tooltip: 'Hapus Kendaraan',
                                            onPressed: () => _showDeleteVehicleConfirm(v),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Tutup'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
