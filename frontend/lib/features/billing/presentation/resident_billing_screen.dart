import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/bloc/auth_bloc.dart';
import '../data/billing_repository.dart';
import '../domain/models/billing_models.dart';
import 'widgets/digital_receipt_dialog.dart';
import 'widgets/payment_flow_dialog.dart';
import 'widgets/payment_proof_dialog.dart';

class ResidentBillingScreen extends StatefulWidget {
  const ResidentBillingScreen({super.key});

  @override
  State<ResidentBillingScreen> createState() => _ResidentBillingScreenState();
}

class _ResidentBillingScreenState extends State<ResidentBillingScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<BillModel> _bills = [];
  PaymentSettingModel? _setting;
  String _selectedPeriodFilter = 'all'; // 'all' or 'YYYY-MM'

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = context.read<BillingRepository>();
      final results = await Future.wait([
        repo.getResidentBills(),
        repo.getPaymentSettings(),
      ]);

      if (mounted) {
        setState(() {
          _bills = results[0] as List<BillModel>;
          _setting = results[1] as PaymentSettingModel;
          _isLoading = false;
        });
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

  String _formatCurrency(double amount) {
    try {
      final currencyFormatter = NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      );
      return currencyFormatter.format(amount);
    } catch (_) {
      final formatted = amount.toStringAsFixed(0).replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]}.',
          );
      return 'Rp $formatted';
    }
  }

  void _openPaymentDialog(BillModel bill) {
    if (_setting == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PaymentFlowDialog(
        bill: bill,
        setting: _setting!,
        repository: context.read<BillingRepository>(),
        onPaymentSuccess: _fetchData,
      ),
    );
  }

  void _openReceiptDialog(BillModel bill) {
    final user = context.read<AuthBloc>().state.user;
    showDialog(
      context: context,
      builder: (_) => DigitalReceiptDialog(
        bill: bill,
        residentName: user?.displayName ?? 'Warga TetangGo',
        residentPhone: user?.phone,
      ),
    );
  }

  void _openProofDialog(BillModel bill) {
    final payment = bill.payment;
    if (payment == null || payment.proofImageUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto bukti transfer belum tersedia')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (_) => PaymentProofDialog(
        proofImageUrl: payment.proofImageUrl,
        title: 'Bukti Transfer - ${bill.billingPeriod}',
        senderBank: payment.senderBank,
        senderName: payment.senderName,
        amount: payment.amountPaid > 0 ? payment.amountPaid : bill.amount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthBloc>().state.user;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: Colors.red.shade400),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchData,
                icon: const Icon(Icons.refresh, size: 18),
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
    }

    // Periode unik dari daftar tagihan
    final periods = _bills.map((b) => b.billingPeriod).toSet().toList()..sort((a, b) => b.compareTo(a));

    // Filter daftar tagihan sesuai pilihan dropdown
    final displayedBills = _selectedPeriodFilter == 'all'
        ? _bills
        : _bills.where((b) => b.billingPeriod == _selectedPeriodFilter).toList();

    BillModel? currentBill = displayedBills.isNotEmpty ? displayedBills.first : null;
    final otherBills = displayedBills.length > 1 ? displayedBills.sublist(1) : <BillModel>[];

    final billHouseBlock = currentBill?.block ?? user?.houseBlock;
    final billHouseNumber = currentBill?.houseNumber ?? user?.houseNumber;
    final houseUnitDisplay = (billHouseBlock != null && billHouseBlock.isNotEmpty && billHouseNumber != null && billHouseNumber.isNotEmpty)
        ? 'Hunian: Blok $billHouseBlock No. $billHouseNumber'
        : (user?.houseDisplay != null && user!.houseDisplay.isNotEmpty
            ? 'Hunian: ${user.houseDisplay}'
            : 'Hunian: -');

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: AppTheme.primary,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Banner Info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Iuran Pengelolaan Lingkungan (IPL)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    houseUnitDisplay,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
              IconButton(
                onPressed: _fetchData,
                icon: const Icon(Icons.refresh_rounded, color: AppTheme.primary),
                tooltip: 'Segarkan Data',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Bar Pemilih Periode & Tombol Bayar Di Muka
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: (periods.contains(_selectedPeriodFilter) || _selectedPeriodFilter == 'all')
                        ? _selectedPeriodFilter
                        : 'all',
                    decoration: InputDecoration(
                      labelText: 'Pilih Periode Tagihan',
                      prefixIcon: const Icon(Icons.filter_list, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem(value: 'all', child: Text('Semua Tagihan')),
                      ...periods.map((p) {
                        return DropdownMenuItem(
                          value: p,
                          child: Text('Periode $p'),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedPeriodFilter = val);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Card Tagihan Utama Bulan Berjalan / Yang Dipilih
          if (currentBill != null)
            _buildMainBillCard(currentBill)
          else
            _buildEmptyBillCard(),

          const SizedBox(height: 28),

          // Riwayat / Daftar Tagihan Lainnya
          Text(
            _selectedPeriodFilter == 'all'
                ? 'Riwayat Tagihan Lainnya'
                : 'Tagihan Lainnya pada Filter',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 12),

          if (otherBills.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Center(
                child: Text(
                  'Tidak ada tagihan lain pada pilihan ini.',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
              ),
            )
          else
            ...otherBills.map((bill) => _buildPastBillItem(bill)),
        ],
      ),
    );
  }

  Widget _buildEmptyBillCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 54, color: AppTheme.primary.withOpacity(0.6)),
          const SizedBox(height: 12),
          const Text(
            'Tagihan Belum Diterbitkan',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Tagihan iuran untuk periode ini belum diterbitkan oleh admin/pengurus. Pembayaran hanya dapat dilakukan setelah tagihan resmi diterbitkan.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _fetchData,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Periksa Ulang Tagihan'),
          ),
        ],
      ),
    );
  }

  Widget _buildMainBillCard(BillModel bill) {
    Color statusBgColor;
    Color statusTextColor;
    String statusLabel;
    IconData statusIcon;

    switch (bill.status) {
      case 'paid':
        statusBgColor = Colors.green.shade50;
        statusTextColor = Colors.green.shade700;
        statusLabel = 'Lunas';
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'pending_verification':
        statusBgColor = Colors.orange.shade50;
        statusTextColor = Colors.orange.shade800;
        statusLabel = 'Menunggu Verifikasi';
        statusIcon = Icons.hourglass_top_rounded;
        break;
      case 'rejected':
        statusBgColor = Colors.red.shade50;
        statusTextColor = Colors.red.shade700;
        statusLabel = 'Ditolak';
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusBgColor = Colors.red.shade50;
        statusTextColor = Colors.red.shade700;
        statusLabel = 'Belum Bayar';
        statusIcon = Icons.error_outline_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: bill.isPaid ? Colors.green.shade200 : AppTheme.primary.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded, size: 18, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Periode: ${bill.billingPeriod}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusTextColor.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusTextColor, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(color: statusTextColor, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Body Card
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Jumlah Tagihan:', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        const SizedBox(height: 4),
                        Text(
                          _formatCurrency(bill.amount),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Jatuh Tempo:', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        const SizedBox(height: 2),
                        const Text(
                          'Tgl 10 Tiap Bulan',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange),
                        ),
                      ],
                    ),
                  ],
                ),

                // Alasan Penolakan Jika Ada
                if (bill.isRejected && bill.payment?.rejectionReason != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, color: AppTheme.danger, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Catatan Penolakan Pengurus RT:',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.danger),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                bill.payment?.rejectionReason ?? 'Tidak ada keterangan penolakan.',
                                style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Action Area Sesuai Status
                const SizedBox(height: 20),

                if (bill.isPaid) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () => _openReceiptDialog(bill),
                    icon: const Icon(Icons.receipt_long_rounded, size: 20),
                    label: const Text('Lihat Kuitansi Digital', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  if (bill.payment?.proofImageUrl.isNotEmpty == true) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: const BorderSide(color: AppTheme.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        minimumSize: const Size.fromHeight(44),
                      ),
                      onPressed: () => _openProofDialog(bill),
                      icon: const Icon(Icons.image_outlined, size: 18),
                      label: const Text('Lihat Bukti Transfer', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ] else if (bill.isPending) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Bukti transfer Anda telah terkirim dan sedang ditinjau oleh bendahara.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (bill.payment?.proofImageUrl.isNotEmpty == true) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: const BorderSide(color: AppTheme.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        minimumSize: const Size.fromHeight(44),
                      ),
                      onPressed: () => _openProofDialog(bill),
                      icon: const Icon(Icons.image_outlined, size: 18),
                      label: const Text('Lihat Bukti Transfer yang Dikirim', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ] else if (bill.isRejected) ...[
                  if (bill.payment?.proofImageUrl.isNotEmpty == true) ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        minimumSize: const Size.fromHeight(44),
                      ),
                      onPressed: () => _openProofDialog(bill),
                      icon: const Icon(Icons.image_outlined, size: 18),
                      label: const Text('Lihat Bukti yang Ditolak', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 10),
                  ],
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () => _openPaymentDialog(bill),
                    icon: const Icon(Icons.upload_file_rounded, size: 20),
                    label: const Text('Upload Ulang Bukti Bayar', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ] else
                  // Status Belum Bayar
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () => _openPaymentDialog(bill),
                    icon: const Icon(Icons.account_balance_wallet_rounded, size: 20),
                    label: const Text('Bayar Sekarang', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPastBillItem(BillModel bill) {
    Color badgeColor = bill.isPaid
        ? Colors.green.shade700
        : bill.isPending
            ? Colors.orange.shade800
            : Colors.red.shade700;

    String badgeText = bill.isPaid
        ? 'Lunas'
        : bill.isPending
            ? 'Menunggu'
            : 'Belum Bayar';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              bill.isPaid ? Icons.check_circle_outline : Icons.receipt_outlined,
              color: bill.isPaid ? Colors.green : Colors.grey.shade700,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Periode ${bill.billingPeriod}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatCurrency(bill.amount),
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badgeText,
              style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 4),
          if (bill.payment?.proofImageUrl.isNotEmpty == true)
            IconButton(
              icon: const Icon(Icons.image_outlined, color: AppTheme.textSecondary, size: 20),
              tooltip: 'Bukti Transfer',
              onPressed: () => _openProofDialog(bill),
            ),
          if (bill.isPaid)
            IconButton(
              icon: const Icon(Icons.receipt_long_rounded, color: AppTheme.primary, size: 20),
              tooltip: 'Kuitansi',
              onPressed: () => _openReceiptDialog(bill),
            )
          else if (bill.isUnpaid || bill.isRejected)
            IconButton(
              icon: const Icon(Icons.payment_rounded, color: AppTheme.primary, size: 20),
              tooltip: 'Bayar',
              onPressed: () => _openPaymentDialog(bill),
            ),
        ],
      ),
    );
  }
}
