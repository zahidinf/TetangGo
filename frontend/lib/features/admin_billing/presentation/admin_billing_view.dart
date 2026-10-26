import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/image_url_helper.dart';
import '../../billing/data/billing_repository.dart';
import '../../billing/domain/models/billing_models.dart';
import '../../billing/presentation/widgets/digital_receipt_dialog.dart';
import '../../billing/presentation/resident_billing_screen.dart';
import 'widgets/full_image_preview_dialog.dart';
import 'widgets/payment_settings_dialog.dart';
import 'widgets/record_cash_payment_dialog.dart';
import 'widgets/bulk_process_payment_dialog.dart';

class AdminBillingView extends StatefulWidget {
  final VoidCallback? onPendingCountUpdated;
  final VoidCallback? onNavigateToResidentBilling;
  final bool hasResidentAccess;

  const AdminBillingView({
    super.key,
    this.onPendingCountUpdated,
    this.onNavigateToResidentBilling,
    this.hasResidentAccess = false,
  });

  @override
  State<AdminBillingView> createState() => AdminBillingViewState();
}

class AdminBillingViewState extends State<AdminBillingView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  PaymentSettingModel? _settings;
  List<PendingPaymentModel> _pendingPayments = [];
  bool _isLoadingPending = true;
  String? _errorPending;

  // Rekapitulasi State
  BillingSummaryModel? _summary;
  bool _isLoadingSummary = true;
  String? _errorSummary;
  late final TextEditingController _periodFilterController;
  String? _selectedBlock;
  List<String> _blocks = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.hasResidentAccess ? 3 : 2,
      vsync: this,
    );
    _periodFilterController = TextEditingController(
        text: DateFormat('yyyy-MM').format(DateTime.now()));

    _loadInitialData();
  }

  void switchToResidentBillingTab() {
    if (widget.hasResidentAccess) {
      _tabController.animateTo(2);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _periodFilterController.dispose();
    super.dispose();
  }

  String _formatCurrency(double amount) {
    try {
      final currencyFormatter = NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      );
      return currencyFormatter.format(amount);
    } catch (_) {
      // Fallback jika locale gagal load
      final formatted = amount.toStringAsFixed(0).replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]}.',
          );
      return 'Rp $formatted';
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    try {
      return DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(dt);
    } catch (_) {
      // Fallback jika locale gagal load
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadSettings(),
      _loadPendingPayments(),
      _loadBlocks(),
      _loadSummary(),
    ]);
  }

  Future<void> _loadBlocks() async {
    try {
      final repo = context.read<BillingRepository>();
      final blocks = await repo.getHouseBlocks();
      if (mounted) {
        setState(() {
          _blocks = blocks.toSet().toList()..sort();
          if (_selectedBlock != null && !_blocks.contains(_selectedBlock)) {
            _selectedBlock = null;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadSettings() async {
    try {
      final repo = context.read<BillingRepository>();
      final s = await repo.getPaymentSettings();
      if (mounted) setState(() => _settings = s);
    } catch (_) {}
  }

  Future<void> _loadPendingPayments() async {
    final hasExistingData = _pendingPayments.isNotEmpty;
    if (!hasExistingData) {
      setState(() {
        _isLoadingPending = true;
        _errorPending = null;
      });
    }

    try {
      final repo = context.read<BillingRepository>();
      final list = await repo.getPendingPayments();
      if (mounted) {
        setState(() {
          _pendingPayments = list;
          _isLoadingPending = false;
        });
        widget.onPendingCountUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorPending = e.toString().replaceAll('Exception: ', '');
          _isLoadingPending = false;
        });
      }
    }
  }

  Future<void> _loadSummary() async {
    final hasExistingData = _summary != null;
    if (!hasExistingData) {
      setState(() {
        _isLoadingSummary = true;
        _errorSummary = null;
      });
    }

    try {
      final repo = context.read<BillingRepository>();
      final s = await repo.getBillingSummary(
        period: _periodFilterController.text.trim(),
        block: _selectedBlock,
      );
      if (mounted) {
        setState(() {
          _summary = s;
          _isLoadingSummary = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorSummary = e.toString().replaceAll('Exception: ', '');
          _isLoadingSummary = false;
        });
      }
    }
  }

  void _openRecordCashDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => RecordCashPaymentDialog(
        repository: context.read<BillingRepository>(),
        onSuccess: () {
          _loadInitialData();
          widget.onPendingCountUpdated?.call();
        },
      ),
    );
  }

  void _openSettingsDialog() {
    if (_settings == null) return;
    showDialog(
      context: context,
      builder: (_) => PaymentSettingsDialog(
        setting: _settings!,
        repository: context.read<BillingRepository>(),
        onUpdated: () {
          _loadSettings();
          _loadPendingPayments();
          _loadSummary();
        },
      ),
    );
  }

  void _openBulkProcessDialog(BillingSummaryModel sum) {
    if (!sum.isPeriodGenerated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Tagihan periode ini belum diterbitkan. Silakan generate tagihan terlebih dahulu.'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    final unpaidBills = sum.houseBills
        .where((b) =>
            b.billId != null &&
            b.status != 'paid' &&
            b.status != 'pending' &&
            b.status != 'no_bill')
        .toList();

    if (unpaidBills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada unit yang belum lunas pada periode ini.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BulkProcessPaymentDialog(
        repository: context.read<BillingRepository>(),
        period: sum.period,
        unpaidBills: unpaidBills,
        onSuccess: () {
          _loadInitialData();
          widget.onPendingCountUpdated?.call();
        },
      ),
    );
  }

  void _previewFullImage(String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (_) => FullImagePreviewDialog(
        imageUrl: imageUrl,
        title: title,
      ),
    );
  }

  Future<void> _approvePayment(PendingPaymentModel item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Setujui Pembayaran (Lunas)',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Konfirmasi persetujuan pembayaran untuk Blok ${item.houseBlock} No. ${item.houseNumber} (${item.residentName}) sebesar ${_formatCurrency(item.amountPaid)}?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Setujui & Terbitkan Resi'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final repo = context.read<BillingRepository>();
      await repo.verifyPayment(
        billId: item.billId,
        action: 'approve',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Pembayaran Blok ${item.houseBlock} No. ${item.houseNumber} berhasil disetujui (Lunas)!'),
            backgroundColor: AppTheme.success,
          ),
        );
        _loadPendingPayments();
        _loadSummary();
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
    }
  }

  Future<void> _generateIndividualBill(
      HouseBillStatusModel item, String period) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Terbitkan Tagihan Individual',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Terbitkan tagihan iuran periode $period untuk:'),
            const SizedBox(height: 8),
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
                  Text('Unit: Blok ${item.block} No. ${item.houseNumber}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Penghuni: ${item.residentName}'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Nominal tagihan akan otomatis mengikuti nominal pembayaran yang sudah ada pada periode $period atau konfigurasi tarif iuran yang berlaku.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Terbitkan Tagihan'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final repo = context.read<BillingRepository>();
      await repo.generateIndividualBill(item.houseId, period);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Tagihan individual Blok ${item.block} No. ${item.houseNumber} periode $period berhasil diterbitkan!'),
            backgroundColor: AppTheme.success,
          ),
        );
        _loadSummary();
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
    }
  }

  Future<void> _rejectPayment(PendingPaymentModel item) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Tolak Bukti Pembayaran',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tolak pembayaran Blok ${item.houseBlock} No. ${item.houseNumber} (${item.residentName}). Berikan alasan yang jelas:',
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Alasan Penolakan *',
                  hintText:
                      'Contoh: Foto buram / nominal tidak sesuai / nama pengirim beda...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Alasan penolakan wajib diisi'
                    : null,
              ),
            ],
          ),
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
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Tolak Pembayaran'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final repo = context.read<BillingRepository>();
      await repo.verifyPayment(
        billId: item.billId,
        action: 'reject',
        rejectionReason: reasonController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Pembayaran Blok ${item.houseBlock} No. ${item.houseNumber} telah ditolak.'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadPendingPayments();
        _loadSummary();
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            color: Colors.white,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.receipt_long_rounded,
                      color: AppTheme.primary, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Iuran Lingkungan (IPL) & Pembayaran',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary),
                      ),
                      Text(
                        'Verifikasi struk transfer warga dan pantau rekapitulasi kas iuran bulanan',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (widget.onNavigateToResidentBilling != null) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                    onPressed: () {
                      if (widget.hasResidentAccess) {
                        _tabController.animateTo(2);
                      } else {
                        widget.onNavigateToResidentBilling?.call();
                      }
                    },
                    icon: const Icon(Icons.payment_rounded, size: 18),
                    label: const Text('Bayar Iuran Saya',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                ],
                ElevatedButton.icon(
                  key: const Key('openRecordCashBtn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                  onPressed: _openRecordCashDialog,
                  icon: const Icon(Icons.payments_outlined, size: 18),
                  label: const Text('Catat Pembayaran Tunai',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                  onPressed: _openSettingsDialog,
                  icon: const Icon(Icons.settings_outlined, size: 18),
                  label: const Text('Pengaturan & Generate',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          // Tab Bar
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.primary,
              indicatorWeight: 3,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.verified_user_outlined, size: 18),
                      const SizedBox(width: 8),
                      const Text('Verifikasi Pembayaran'),
                      if (_pendingPayments.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.danger,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_pendingPayments.length}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assessment_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Rekapitulasi Iuran Lingkungan'),
                    ],
                  ),
                ),
                if (widget.hasResidentAccess)
                  const Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.payments_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('Tagihan Saya'),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildVerificationTab(),
                _buildSummaryTab(),
                if (widget.hasResidentAccess)
                  ResidentBillingScreen(
                    onBillUpdated: () {
                      widget.onPendingCountUpdated?.call();
                      _loadInitialData();
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: VERIFIKASI PEMBAYARAN (PENDING)
  // ==========================================
  Widget _buildVerificationTab() {
    if (_isLoadingPending && _pendingPayments.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorPending != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
            const SizedBox(height: 8),
            Text(_errorPending!,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ElevatedButton(
                onPressed: _loadPendingPayments,
                child: const Text('Coba Lagi')),
          ],
        ),
      );
    }

    if (_pendingPayments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.task_alt_rounded,
                  size: 64, color: Colors.green.shade400),
              const SizedBox(height: 16),
              const Text(
                'Semua Pembayaran Telah Diverifikasi',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tidak ada bukti pembayaran iuran yang menunggu peninjauan saat ini.',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _loadPendingPayments,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Segarkan'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPendingPayments,
      child: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: _pendingPayments.length,
        itemBuilder: (context, index) {
          final item = _pendingPayments[index];
          final imgUrl = getFullImageUrl(item.proofImageUrl);

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bukti Transfer / Cash Icon Thumbnail
                  item.isCash
                      ? Container(
                          width: 100,
                          height: 110,
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.payments_rounded,
                                  color: Colors.amber.shade800, size: 36),
                              const SizedBox(height: 6),
                              Text(
                                'TUNAI / CASH',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            ],
                          ),
                        )
                      : InkWell(
                          onTap: () => _previewFullImage(
                            item.proofImageUrl,
                            'Bukti Transfer - Blok ${item.houseBlock} No. ${item.houseNumber}',
                          ),
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 100,
                                  height: 110,
                                  color: Colors.grey.shade100,
                                  child: Image.network(
                                    imgUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Center(
                                      child: Icon(Icons.broken_image,
                                          color: Colors.grey),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.65),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.zoom_in,
                                      color: Colors.white, size: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                  const SizedBox(width: 18),

                  // Data Info Pembayaran
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Blok ${item.houseBlock} No. ${item.houseNumber}',
                                style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Periode: ${item.billingPeriod}',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _formatDate(item.createdAt),
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.residentName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppTheme.textPrimary),
                        ),
                        if (item.residentPhone.isNotEmpty)
                          Text(
                            item.residentPhone,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              'Metode: ',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: item.isCash
                                    ? Colors.green.shade50
                                    : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.isCash ? 'TUNAI (CASH)' : 'TRANSFER BANK',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: item.isCash
                                      ? Colors.green.shade800
                                      : AppTheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!item.isCash) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                'Pengirim: ',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade600),
                              ),
                              Text(
                                '${item.senderBank ?? '-'} a.n ${item.senderName ?? '-'}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary),
                              ),
                            ],
                          ),
                        ],
                        if (item.notes != null && item.notes!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Catatan: "${item.notes}"',
                            style: const TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: AppTheme.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),

                  // Nominal & Actions
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatCurrency(item.amountPaid),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.danger,
                              side: const BorderSide(color: AppTheme.danger),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                            onPressed: () => _rejectPayment(item),
                            icon: const Icon(Icons.close, size: 16),
                            label: const Text('Tolak'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.success,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                            ),
                            onPressed: () => _approvePayment(item),
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Setujui (Lunas)',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // TAB 2: REKAPITULASI IURAN LINGKUNGAN
  // ==========================================
  Widget _buildSummaryTab() {
    final sum = _summary;

    return RefreshIndicator(
      onRefresh: _loadSummary,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _periodFilterController,
                    decoration: InputDecoration(
                      labelText: 'Periode (YYYY-MM)',
                      hintText: '2026-10',
                      prefixIcon: const Icon(Icons.date_range, size: 20),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: _blocks.contains(_selectedBlock)
                        ? _selectedBlock
                        : null,
                    decoration: InputDecoration(
                      labelText: 'Filter Blok',
                      prefixIcon: const Icon(Icons.grid_view, size: 20),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Semua Blok'),
                      ),
                      ..._blocks.toSet().map(
                            (b) => DropdownMenuItem<String?>(
                              value: b,
                              child: Text('Blok $b'),
                            ),
                          ),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedBlock = val);
                    },
                  ),
                ),
                const SizedBox(width: 14),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 15),
                  ),
                  onPressed: _loadSummary,
                  icon: const Icon(Icons.filter_alt_rounded, size: 18),
                  label: const Text('Terapkan',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Content Area
          if (_isLoadingSummary && _summary == null)
            const Padding(
              padding: EdgeInsets.all(48.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_errorSummary != null)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline,
                        size: 48, color: Colors.red.shade400),
                    const SizedBox(height: 8),
                    Text(_errorSummary!,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.danger)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _loadSummary,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Coba Lagi'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.danger,
                          foregroundColor: Colors.white),
                    ),
                  ],
                ),
              ),
            )
          else if (sum == null)
            const Padding(
              padding: EdgeInsets.all(48.0),
              child: Center(
                child: Text(
                    'Tidak ada data yang sesuai dengan filter yang dipilih.',
                    style: TextStyle(color: Colors.grey)),
              ),
            )
          else ...[
            if (!sum.isPeriodGenerated)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 36, color: Colors.amber.shade900),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Periode ${sum.period} Belum Diterbitkan',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.amber.shade900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tagihan iuran untuk periode ini belum diterbitkan oleh pengurus. Pembayaran massal dan pencatatan iuran tidak dapat dilakukan pada periode yang belum diterbitkan.',
                            style: TextStyle(
                                fontSize: 12, color: Colors.amber.shade900),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _openSettingsDialog,
                      icon: const Icon(Icons.add_circle_outline, size: 16),
                      label: const Text('Terbitkan Tagihan'),
                    ),
                  ],
                ),
              ),
            Builder(
              builder: (context) {
                final progress = sum.totalHouses > 0
                    ? (sum.paidHouses / sum.totalHouses)
                    : 0.0;
                final percentage = (progress * 100).toStringAsFixed(1);
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.analytics_outlined,
                                  color: AppTheme.primary, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Progres Pembayaran Iuran Periode Terpilih',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppTheme.textPrimary),
                              ),
                            ],
                          ),
                          Text(
                            '$percentage% (${sum.paidHouses}/${sum.totalHouses} Unit Lunas)',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primary,
                                fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 10,
                          backgroundColor: Colors.grey.shade100,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progress >= 1.0
                                ? AppTheme.success
                                : AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            // 3 Kartu Ringkasan (Stat Cards)
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    title: 'Total Tagihan',
                    amount: sum.totalPaidAmount + sum.totalUnpaidAmount,
                    subtitle: '${sum.totalHouses} Unit Rumah',
                    icon: Icons.payments_outlined,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    title: 'Sudah Terbayar',
                    amount: sum.totalPaidAmount,
                    subtitle: '${sum.paidHouses} Rumah Lunas',
                    icon: Icons.check_circle_outline,
                    color: AppTheme.success,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    title: 'Belum Terbayar / Menunggak',
                    amount: sum.totalUnpaidAmount,
                    subtitle: '${sum.unpaidHouses} Rumah Menunggak',
                    icon: Icons.pending_actions_rounded,
                    color: AppTheme.danger,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Tabel Daftar Rumah
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        const Text(
                          'Rincian Status Iuran Per Unit Rumah',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppTheme.textPrimary),
                        ),
                        const Spacer(),
                        if (sum.isPeriodGenerated)
                          ElevatedButton.icon(
                            key: const Key('bulkPayBtn'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                            onPressed: () => _openBulkProcessDialog(sum),
                            icon:
                                const Icon(Icons.playlist_add_check, size: 16),
                            label: const Text('Proses Bayar Massal',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        const SizedBox(width: 12),
                        Text(
                          'Periode: ${sum.period}',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  if (sum.houseBills.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inbox_outlined,
                                size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'Belum ada data tagihan untuk periode ${sum.period.isNotEmpty ? sum.period : _periodFilterController.text.trim()}',
                              style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor:
                            WidgetStateProperty.all(Colors.grey.shade50),
                        columnSpacing: 28,
                        columns: const [
                          DataColumn(
                              label: Text('Blok & No Rumah',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('Nama Warga / Pemilik',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('Nominal',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('Status Iuran',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('Tanggal Bayar',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('Aksi',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: sum.houseBills.map((item) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Blok ${item.block} No. ${item.houseNumber}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primary,
                                        fontSize: 12),
                                  ),
                                ),
                              ),
                              DataCell(
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(item.residentName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13)),
                                    if (item.residentPhone.isNotEmpty &&
                                        item.residentPhone != '-')
                                      Text(item.residentPhone,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade500)),
                                  ],
                                ),
                              ),
                              DataCell(
                                Text(
                                  _formatCurrency(item.amount),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ),
                              ),
                              DataCell(_buildStatusBadge(item.status)),
                              DataCell(
                                Text(
                                  item.paidAt != null
                                      ? _formatDate(item.paidAt!)
                                      : '-',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700),
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (item.status == 'no_bill')
                                      IconButton(
                                        icon: const Icon(
                                            Icons.note_add_outlined,
                                            color: Colors.indigo,
                                            size: 20),
                                        tooltip: 'Terbitkan Tagihan Individual',
                                        onPressed: () =>
                                            _generateIndividualBill(
                                                item, sum.period),
                                      ),
                                    if (item.proofImageUrl != null &&
                                        item.proofImageUrl!.isNotEmpty)
                                      IconButton(
                                        icon: const Icon(Icons.image_outlined,
                                            color: AppTheme.primary, size: 20),
                                        tooltip: 'Lihat Struk',
                                        onPressed: () => _previewFullImage(
                                          item.proofImageUrl!,
                                          'Bukti Bayar Blok ${item.block} No. ${item.houseNumber}',
                                        ),
                                      ),
                                    if (item.status == 'paid' &&
                                        item.billId != null)
                                      IconButton(
                                        icon: const Icon(
                                            Icons.receipt_long_rounded,
                                            color: Colors.green,
                                            size: 20),
                                        tooltip: 'Kuitansi Digital',
                                        onPressed: () {
                                          final bill = BillModel(
                                            id: item.billId ?? 0,
                                            houseId: item.houseId,
                                            billingPeriod: sum.period,
                                            amount: item.amount,
                                            status: 'paid',
                                            createdAt:
                                                item.paidAt ?? DateTime.now(),
                                            updatedAt:
                                                item.paidAt ?? DateTime.now(),
                                            block: item.block,
                                            houseNumber: item.houseNumber,
                                            payment: PaymentModel(
                                              id: 0,
                                              billId: item.billId ?? 0,
                                              amountPaid: item.amount,
                                              proofImageUrl:
                                                  item.proofImageUrl ?? '',
                                              verifiedAt: item.paidAt
                                                  ?.toIso8601String(),
                                              createdAt:
                                                  item.paidAt ?? DateTime.now(),
                                            ),
                                          );
                                          showDialog(
                                            context: context,
                                            builder: (_) =>
                                                DigitalReceiptDialog(
                                              bill: bill,
                                              residentName: item.residentName,
                                              residentPhone: item.residentPhone,
                                            ),
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required double amount,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _formatCurrency(amount),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color == AppTheme.danger
                  ? Colors.red.shade700
                  : AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'paid':
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
        label = 'Lunas';
        break;
      case 'pending_verification':
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade800;
        label = 'Menunggu Verifikasi';
        break;
      case 'rejected':
        bg = Colors.red.shade50;
        fg = Colors.red.shade700;
        label = 'Ditolak';
        break;
      case 'no_bill':
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade700;
        label = 'Belum Terbit';
        break;
      default:
        bg = Colors.red.shade50;
        fg = Colors.red.shade700;
        label = 'Belum Bayar';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
