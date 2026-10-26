import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../data/repositories/invitation_repository.dart';
import '../../domain/models/invitation_model.dart';

class SecurityGuestbookScreen extends StatefulWidget {
  final UserModel? user;

  const SecurityGuestbookScreen({super.key, this.user});

  @override
  State<SecurityGuestbookScreen> createState() => _SecurityGuestbookScreenState();
}

class _SecurityGuestbookScreenState extends State<SecurityGuestbookScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _tokenInputController = TextEditingController();

  bool _isVerifying = false;
  String? _lastScannedPayload;

  // Visit history state
  List<GuestVisitGroupModel> _visitGroups = [];
  final Set<int> _expandedInvitationIds = {};
  bool _isLoadingVisits = false;
  String? _visitsErrorMessage;
  String? _selectedStatusFilter;
  String? _selectedTypeFilter;

  bool get isSecurityOfficer => widget.user?.isSecurity ?? false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: isSecurityOfficer ? 2 : 1,
      vsync: this,
    );

    _loadVisits();
  }

  Future<void> _loadVisits() async {
    setState(() {
      _isLoadingVisits = true;
      _visitsErrorMessage = null;
    });

    try {
      final repo = context.read<InvitationRepository>();
      final list = await repo.getGroupedGuestVisits(
        search: _searchController.text.trim(),
        status: _selectedStatusFilter,
        visitType: _selectedTypeFilter,
      );
      if (mounted) {
        setState(() {
          _visitGroups = list;
          _isLoadingVisits = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingVisits = false;
          _visitsErrorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _verifyCode(String rawCode) async {
    if (_isVerifying) return;
    setState(() => _isVerifying = true);

    try {
      final repo = context.read<InvitationRepository>();
      final result = await repo.verifyInvitation(rawCode);

      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
        _showVerificationDialog(result, rawCode);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isVerifying = false);
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
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _tokenInputController.dispose();
    super.dispose();
  }

  void _showVerificationDialog(VerifyInvitationResult result, String rawCode) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final inv = result.invitation;
        final isValid = result.valid;
        final hasActiveVisit = result.activeVisit != null;

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                isValid ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: isValid ? AppTheme.success : AppTheme.danger,
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isValid ? 'Izin Masuk Sah' : 'Verifikasi Gagal',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isValid ? AppTheme.success : AppTheme.danger,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isValid
                        ? AppTheme.success.withValues(alpha: 0.1)
                        : AppTheme.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    result.message,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isValid ? AppTheme.success : AppTheme.danger,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (inv != null) ...[
                  _buildDetailRow('Kode Undangan', inv.invitationCode),
                  _buildDetailRow('Nama Tamu', inv.guestName),
                  _buildDetailRow('Jenis', inv.visitType.label),
                  if (inv.houseDisplay.isNotEmpty)
                    _buildDetailRow('Tujuan', inv.houseDisplay),
                  if (inv.hostName != null && inv.hostName!.isNotEmpty)
                    _buildDetailRow('Tuan Rumah', inv.hostName!),
                  if (inv.phone != null && inv.phone!.isNotEmpty)
                    _buildDetailRow('No. Handphone', inv.phone!),
                  _buildDetailRow(
                    'Berlaku s/d',
                    DateFormat('dd MMM yyyy, HH:mm').format(inv.validUntil),
                  ),
                ],
                if (hasActiveVisit) ...[
                  const Divider(height: 24),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.blue, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tamu telah check-in pada ${DateFormat('HH:mm').format(result.activeVisit!.checkInAt)} WIB. Siap untuk check-out.',
                            style: const TextStyle(fontSize: 12, color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _lastScannedPayload = null;
              },
              child: const Text('Tutup', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            if (isSecurityOfficer && isValid && !hasActiveVisit) ...[
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await _performCheckIn(rawCode);
                },
                icon: const Icon(Icons.login_rounded, size: 16),
                label: const Text('Check-In Masuk'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
            if (isSecurityOfficer && hasActiveVisit) ...[
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _showCheckOutOptionsDialog(
                    visitID: result.activeVisit!.id,
                    invitationCode: inv?.invitationCode,
                    guestName: inv?.guestName ?? 'Tamu',
                  );
                },
                icon: const Icon(Icons.logout_rounded, size: 16),
                label: const Text('Pilihan Check-Out'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade800,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _performCheckIn(String rawCode) async {
    try {
      final repo = context.read<InvitationRepository>();
      await repo.checkInGuest(code: rawCode);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Check-in berhasil. Kunjungan dimulai.'),
            backgroundColor: AppTheme.success,
          ),
        );
        _lastScannedPayload = null;
        _loadVisits();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal Check-In: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  void _showCheckOutOptionsDialog({
    required int visitID,
    String? invitationCode,
    required String guestName,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.logout_rounded, color: Colors.orange.shade800, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Pilihan Check-Out',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tamu "$guestName" ${invitationCode != null ? '($invitationCode)' : ''} sedang aktif berkunjung. Pilih tindakan checkout:',
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 18),

              // Option 1: Checkout Saja
              InkWell(
                onTap: () {
                  Navigator.of(dialogCtx).pop();
                  _performCheckOut(visitID: visitID, endInvitation: false);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.directions_walk_rounded, color: Colors.blue.shade700, size: 24),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Checkout saja',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Mengakhiri sesi saat ini. QR tetap berlaku untuk kunjungan berikutnya.',
                              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Option 2: Checkout dan Akhiri Undangan
              InkWell(
                onTap: () {
                  Navigator.of(dialogCtx).pop();
                  _confirmCheckOutAndEnd(visitID: visitID, guestName: guestName);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.no_meeting_room_rounded, color: AppTheme.danger, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Checkout dan akhiri undangan',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppTheme.danger,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Mengakhiri sesi sekaligus membuat QR Code tidak berlaku lagi.',
                              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
            ),
          ],
        );
      },
    );
  }

  void _confirmCheckOutAndEnd({
    required int visitID,
    required String guestName,
  }) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Konfirmasi Pengakhiran'),
        content: Text(
          'Checkout dan akhiri undangan ini untuk "$guestName"? QR tidak dapat digunakan lagi untuk kunjungan berikutnya.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Kembali'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              _performCheckOut(visitID: visitID, endInvitation: true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Checkout & Akhiri', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _performCheckOut({int? visitID, String? code, bool endInvitation = false}) async {
    try {
      final repo = context.read<InvitationRepository>();
      await repo.checkOutGuest(visitID: visitID, code: code, endInvitation: endInvitation);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(endInvitation
                ? 'Check-out berhasil. Undangan telah diakhiri secara permanen.'
                : 'Check-out berhasil. Sesi kunjungan ditutup.'),
            backgroundColor: AppTheme.success,
          ),
        );
        _lastScannedPayload = null;
        _loadVisits();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal Check-Out: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.shield_rounded, color: AppTheme.primary, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Buku Tamu Satpam',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                isSecurityOfficer
                                    ? 'Operasional Pemindaian & Log Akses Gerbang'
                                    : 'Log Kunjungan Tamu & Kurir (Mode Read-Only)',
                                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: _loadVisits,
                        icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary),
                        tooltip: 'Muat ulang data',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (isSecurityOfficer)
                    TabBar(
                      controller: _tabController,
                      labelColor: AppTheme.primary,
                      unselectedLabelColor: AppTheme.textSecondary,
                      indicatorColor: AppTheme.primary,
                      indicatorWeight: 3,
                      tabs: const [
                        Tab(icon: Icon(Icons.qr_code_scanner_rounded), text: 'Pemindai QR Gerbang'),
                        Tab(icon: Icon(Icons.history_rounded), text: 'Riwayat Kunjungan'),
                      ],
                    )
                  else
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                ],
              ),
            ),

            // Tab Content
            Expanded(
              child: isSecurityOfficer
                  ? TabBarView(
                      controller: _tabController,
                      children: [
                        _buildScannerView(),
                        _buildHistoryView(),
                      ],
                    )
                  : _buildHistoryView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            children: [
              // Scanner box container
              Container(
                height: 360,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _GateScannerView(
                      isVerifying: _isVerifying,
                      onCodeScanned: (code) {
                        if (code == _lastScannedPayload) return;
                        _lastScannedPayload = code;
                        _verifyCode(code);
                      },
                    ),

                    // Scanning Overlay frame
                    IgnorePointer(
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.primary, width: 3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),

                    // Verifying indicator
                    if (_isVerifying)
                      Container(
                        color: Colors.black54,
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: Colors.white),
                              SizedBox(height: 12),
                              Text(
                                'Memverifikasi izin ke gerbang...',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Manual token / QR Payload fallback input
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.keyboard_alt_outlined, color: AppTheme.primary, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Input Manual Kode Undangan',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Jika kamera bermasalah atau barcode tidak terbaca, masukkan kode undangan (misal: INV-XXXX-XXXX) secara manual.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _tokenInputController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              hintText: 'Contoh: INV-1234-ABCD',
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: _isVerifying
                              ? null
                              : () {
                                  final val = _tokenInputController.text.trim();
                                  if (val.isNotEmpty) {
                                    _verifyCode(val);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Verifikasi'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryView() {
    return Column(
      children: [
        // Filter bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onSubmitted: (_) => _loadVisits(),
                  decoration: InputDecoration(
                    hintText: 'Cari nama tamu, kode, atau alamat hunian...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Filter Status dropdown
              DropdownButton<String?>(
                value: _selectedStatusFilter,
                hint: const Text('Semua Status', style: TextStyle(fontSize: 12)),
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Semua Status')),
                  DropdownMenuItem(value: 'CHECKED_IN', child: Text('Sedang Berkunjung')),
                  DropdownMenuItem(value: 'CHECKED_OUT', child: Text('Selesai')),
                ],
                onChanged: (val) {
                  setState(() => _selectedStatusFilter = val);
                  _loadVisits();
                },
              ),
            ],
          ),
        ),

        // List View
        Expanded(
          child: _isLoadingVisits
              ? const Center(child: CircularProgressIndicator())
              : _visitsErrorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 40),
                          const SizedBox(height: 12),
                          Text(_visitsErrorMessage!, style: const TextStyle(color: AppTheme.danger)),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _loadVisits,
                            child: const Text('Coba Lagi'),
                          ),
                        ],
                      ),
                    )
                  : _visitGroups.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.assignment_outlined, size: 54, color: Colors.grey.shade400),
                              const SizedBox(height: 14),
                              const Text(
                                'Belum ada riwayat kunjungan tamu.',
                                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(20),
                          itemCount: _visitGroups.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final group = _visitGroups[index];
                            final isExpanded = _expandedInvitationIds.contains(group.invitationID);
                            final hasActive = group.hasActiveSession;

                            // Badge Status Undangan (QR)
                            Color invStatusColor;
                            String invStatusText;
                            switch (group.invitationStatus) {
                              case InvitationStatus.active:
                                if (group.validUntil.isBefore(DateTime.now())) {
                                  invStatusColor = AppTheme.danger;
                                  invStatusText = 'Kedaluwarsa';
                                } else {
                                  invStatusColor = AppTheme.success;
                                  invStatusText = 'QR Aktif';
                                }
                                break;
                              case InvitationStatus.completed:
                                invStatusColor = Colors.teal;
                                invStatusText = 'QR Selesai';
                                break;
                              case InvitationStatus.cancelled:
                                invStatusColor = AppTheme.danger;
                                invStatusText = 'QR Dibatalkan';
                                break;
                              case InvitationStatus.expired:
                                invStatusColor = AppTheme.danger;
                                invStatusText = 'QR Kedaluwarsa';
                                break;
                              case InvitationStatus.used:
                                invStatusColor = Colors.blueGrey;
                                invStatusText = 'QR Terpakai';
                                break;
                            }

                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: hasActive
                                      ? AppTheme.primary.withValues(alpha: 0.5)
                                      : const Color(0xFFE2E8F0),
                                  width: hasActive ? 1.5 : 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Main Entry Row
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Leading Avatar / Icon
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: hasActive
                                                ? AppTheme.primary.withValues(alpha: 0.1)
                                                : Colors.grey.shade100,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            hasActive
                                                ? Icons.person_pin_circle_rounded
                                                : Icons.badge_outlined,
                                            color: hasActive
                                                ? AppTheme.primary
                                                : AppTheme.textSecondary,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 14),

                                        // Center Details
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Guest Name and Badges
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 4,
                                                crossAxisAlignment: WrapCrossAlignment.center,
                                                children: [
                                                  Text(
                                                    group.guestName,
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppTheme.textPrimary,
                                                    ),
                                                  ),
                                                  // Badge Sesi Kunjungan
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 7, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: hasActive
                                                          ? AppTheme.primary.withValues(alpha: 0.12)
                                                          : Colors.grey.shade200,
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                    child: Text(
                                                      hasActive ? 'Sedang Berkunjung' : 'Selesai',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: hasActive
                                                            ? AppTheme.primary
                                                            : AppTheme.textSecondary,
                                                      ),
                                                    ),
                                                  ),
                                                  // Badge Status Undangan (QR)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 7, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: invStatusColor.withValues(alpha: 0.12),
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                    child: Text(
                                                      invStatusText,
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: invStatusColor,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),

                                              // Metadata Info
                                              Text(
                                                '${group.invitationCode} • ${group.visitType.label} • Tujuan: ${group.houseDisplay}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppTheme.textSecondary,
                                                ),
                                              ),
                                              if (group.hostName.isNotEmpty)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 2),
                                                  child: Text(
                                                    'Tuan Rumah: ${group.hostName}',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: AppTheme.textSecondary,
                                                    ),
                                                  ),
                                                ),
                                              const SizedBox(height: 6),

                                              // Summary Stats
                                              Wrap(
                                                spacing: 12,
                                                runSpacing: 4,
                                                crossAxisAlignment: WrapCrossAlignment.center,
                                                children: [
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.history_rounded,
                                                          size: 14, color: Colors.blue.shade700),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Total Sesi: ${group.totalVisits}',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w600,
                                                          color: AppTheme.textSecondary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.access_time_rounded,
                                                          size: 14, color: Colors.grey.shade600),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Aktivitas: ${DateFormat('dd MMM HH:mm').format(group.latestActivityAt)} WIB',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          color: AppTheme.textSecondary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Trailing Actions
                                        Column(
                                          children: [
                                            if (isSecurityOfficer && hasActive && group.activeVisitID != null)
                                              OutlinedButton.icon(
                                                onPressed: () {
                                                  _showCheckOutOptionsDialog(
                                                    visitID: group.activeVisitID!,
                                                    invitationCode: group.invitationCode,
                                                    guestName: group.guestName,
                                                  );
                                                },
                                                icon: const Icon(Icons.logout_rounded, size: 14),
                                                label: const Text('Checkout', style: TextStyle(fontSize: 12)),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: Colors.orange.shade800,
                                                  side: BorderSide(color: Colors.orange.shade400),
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                  visualDensity: VisualDensity.compact,
                                                ),
                                              ),
                                            IconButton(
                                              tooltip: isExpanded ? 'Tutup Riwayat Sesi' : 'Buka Riwayat Sesi',
                                              icon: Icon(
                                                isExpanded
                                                    ? Icons.keyboard_arrow_up_rounded
                                                    : Icons.keyboard_arrow_down_rounded,
                                                color: AppTheme.primary,
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  if (isExpanded) {
                                                    _expandedInvitationIds.remove(group.invitationID);
                                                  } else {
                                                    _expandedInvitationIds.add(group.invitationID);
                                                  }
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Expanded Session History
                                  if (isExpanded) ...[
                                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      color: const Color(0xFFF8FAFC),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.timeline_rounded,
                                                  size: 16, color: AppTheme.primary),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Rincian Seluruh Siklus Kunjungan (${group.visits.length} Sesi)',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.textPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          if (group.visits.isEmpty)
                                            const Text(
                                              'Belum ada rincian siklus tercatat.',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  fontStyle: FontStyle.italic,
                                                  color: AppTheme.textSecondary),
                                            )
                                          else
                                            ListView.separated(
                                              shrinkWrap: true,
                                              physics: const NeverScrollableScrollPhysics(),
                                              itemCount: group.visits.length,
                                              separatorBuilder: (_, __) =>
                                                  const Divider(height: 12, color: Color(0xFFE2E8F0)),
                                              itemBuilder: (ctx, vIdx) {
                                                final v = group.visits[vIdx];
                                                final isSessActive = v.status == VisitStatus.checkedIn;
                                                return Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    CircleAvatar(
                                                      radius: 11,
                                                      backgroundColor: isSessActive
                                                          ? AppTheme.primary.withValues(alpha: 0.15)
                                                          : Colors.grey.shade300,
                                                      child: Text(
                                                        '${vIdx + 1}',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                          color: isSessActive
                                                              ? AppTheme.primary
                                                              : AppTheme.textSecondary,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              Icon(Icons.login_rounded,
                                                                  size: 13,
                                                                  color: Colors.blue.shade700),
                                                              const SizedBox(width: 4),
                                                              Text(
                                                                'Masuk: ${DateFormat('dd MMM yyyy, HH:mm').format(v.checkInAt)} WIB (${v.checkInByName ?? 'Satpam'})',
                                                                style: const TextStyle(
                                                                    fontSize: 11,
                                                                    fontWeight: FontWeight.w600),
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(height: 3),
                                                          Row(
                                                            children: [
                                                              Icon(
                                                                isSessActive
                                                                    ? Icons.timelapse_rounded
                                                                    : Icons.logout_rounded,
                                                                size: 13,
                                                                color: isSessActive
                                                                    ? AppTheme.primary
                                                                    : Colors.orange.shade700,
                                                              ),
                                                              const SizedBox(width: 4),
                                                              Text(
                                                                v.checkOutAt != null
                                                                    ? 'Keluar: ${DateFormat('dd MMM yyyy, HH:mm').format(v.checkOutAt!)} WIB (${v.checkOutByName ?? 'Satpam'})'
                                                                    : 'Status: Masih Berada di Dalam (Belum Check-Out)',
                                                                style: TextStyle(
                                                                  fontSize: 11,
                                                                  fontWeight: isSessActive
                                                                      ? FontWeight.bold
                                                                      : FontWeight.normal,
                                                                  color: isSessActive
                                                                      ? AppTheme.primary
                                                                      : AppTheme.textSecondary,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          if (v.notes != null && v.notes!.isNotEmpty)
                                                            Padding(
                                                              padding: const EdgeInsets.only(top: 2),
                                                              child: Text(
                                                                'Catatan: ${v.notes}',
                                                                style: const TextStyle(
                                                                  fontSize: 10,
                                                                  fontStyle: FontStyle.italic,
                                                                  color: AppTheme.textSecondary,
                                                                ),
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              },
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}

// Dedicated isolated lifecycle widget for camera scanner to prevent controller re-use after dispose
class _GateScannerView extends StatefulWidget {
  final ValueChanged<String> onCodeScanned;
  final bool isVerifying;

  const _GateScannerView({
    required this.onCodeScanned,
    required this.isVerifying,
  });

  @override
  State<_GateScannerView> createState() => _GateScannerViewState();
}

class _GateScannerViewState extends State<_GateScannerView> {
  MobileScannerController? _controller;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    if (_isDisposed) return;
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
      autoStart: true,
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    final c = _controller;
    _controller = null;
    if (c != null) {
      c.dispose();
    }
    super.dispose();
  }

  void _handleDetect(BarcodeCapture capture) {
    if (widget.isVerifying || _isDisposed) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;
    final rawValue = barcode.rawValue!.trim();
    if (rawValue.isNotEmpty) {
      widget.onCodeScanned(rawValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 54),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _initController();
                });
              },
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Aktifkan Kamera'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return MobileScanner(
      key: ValueKey(_controller.hashCode),
      controller: _controller!,
      onDetect: _handleDetect,
      errorBuilder: (context, error) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.videocam_off_rounded, color: Colors.white70, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Kamera tidak tersedia atau izin ditolak.\n($error)',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      final old = _controller;
                      _controller = null;
                      old?.dispose();
                      _initController();
                    });
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Coba Lagi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
