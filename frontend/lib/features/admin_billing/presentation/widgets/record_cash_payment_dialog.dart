import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../billing/data/billing_repository.dart';
import '../../../billing/domain/models/billing_models.dart';

class RecordCashPaymentDialog extends StatefulWidget {
  final BillingRepository repository;
  final VoidCallback onSuccess;

  const RecordCashPaymentDialog({
    super.key,
    required this.repository,
    required this.onSuccess,
  });

  @override
  State<RecordCashPaymentDialog> createState() =>
      _RecordCashPaymentDialogState();
}

class _RecordCashPaymentDialogState extends State<RecordCashPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();

  bool _isLoadingInitial = true;
  bool _isLoadingPeriods = false;
  bool _isSubmitting = false;

  List<ResidentBillingOptionModel> _residents = [];
  ResidentBillingOptionModel? _selectedResident;

  List<EligibleDuesPeriodModel> _periods = [];
  EligibleDuesPeriodModel? _selectedPeriod;

  DateTime _paymentDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadResidents();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String _formatCurrency(double amount) {
    try {
      final formatter = NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      );
      return formatter.format(amount);
    } catch (_) {
      return 'Rp ${amount.toStringAsFixed(0)}';
    }
  }

  String _formatDate(DateTime dt) {
    try {
      return DateFormat('d MMMM yyyy', 'id_ID').format(dt);
    } catch (_) {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }

  Future<void> _loadResidents() async {
    setState(() => _isLoadingInitial = true);
    try {
      final list = await widget.repository.getEligibleResidents();
      if (mounted) {
        setState(() {
          _residents = list;
          _isLoadingInitial = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingInitial = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat daftar warga: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  Future<void> _onResidentChanged(ResidentBillingOptionModel? resident) async {
    setState(() {
      _selectedResident = resident;
      _selectedPeriod = null;
      _periods = [];
    });

    if (resident == null) return;

    setState(() => _isLoadingPeriods = true);
    try {
      final periods = await widget.repository
          .getResidentEligiblePeriods(resident.residentId);
      if (mounted) {
        setState(() {
          _periods = periods;
          if (_periods.isNotEmpty) {
            _selectedPeriod = _periods.firstWhere(
              (p) => p.isEligible,
              orElse: () => _periods.first,
            );
          }
          _isLoadingPeriods = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPeriods = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat periode iuran warga: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && mounted) {
      setState(() => _paymentDate = picked);
    }
  }

  Future<void> _submitDirectCash() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedResident == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih warga pembayar terlebih dahulu!'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }
    if (_selectedPeriod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih periode iuran yang valid!'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    if (_selectedPeriod!.isPaid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Pembayaran untuk periode ini sudah lunas. Silakan periksa riwayat pembayaran sebelum melanjutkan.'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    if (_selectedPeriod!.isPending) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Pembayaran untuk periode ini sedang menunggu verifikasi. Selesaikan verifikasi terlebih dahulu sebelum mencatat pembayaran tunai.'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    if (!_selectedPeriod!.isEligible) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Periode iuran ini tidak dapat dibayar.'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    // Step 1: Confirmation Summary Modal
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.payments_rounded, color: Colors.green),
            SizedBox(width: 8),
            Text('Konfirmasi Pembayaran Tunai',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pastikan uang tunai fisik telah diterima bendahara/pengurus sebelum melanjutkan.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  _summaryRow('Warga', _selectedResident!.residentName),
                  _summaryRow(
                      'Hunian',
                      _selectedResident!.occupancyIdentifier.isNotEmpty
                          ? _selectedResident!.occupancyIdentifier
                          : 'Blok ${_selectedResident!.houseBlock} No. ${_selectedResident!.houseNumber}'),
                  _summaryRow('Periode', _selectedPeriod!.billingPeriod),
                  _summaryRow(
                      'Nominal', _formatCurrency(_selectedPeriod!.amount),
                      isBold: true),
                  _summaryRow('Tanggal', _formatDate(_paymentDate)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Konfirmasi & Catat Lunas'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSubmitting = true);
    try {
      await widget.repository.recordDirectCashPayment(
        residentId: _selectedResident!.residentId,
        billId: _selectedPeriod!.billId,
        amount: _selectedPeriod!.amount,
        paymentDate: _paymentDate,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Pembayaran tunai berhasil dicatat dan langsung tercatat di buku kas!'),
            backgroundColor: AppTheme.success,
          ),
        );
        widget.onSuccess();
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
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _summaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: isBold ? Colors.green.shade800 : AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _isLoadingInitial
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: _formKey,
                  child: SingleChildScrollView(
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
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.point_of_sale_rounded,
                                  color: Colors.green.shade700, size: 26),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Catat Pembayaran Tunai (Cash)',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textPrimary),
                                  ),
                                  Text(
                                    'Penerimaan uang iuran fisik oleh pengurus/bendahara',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary),
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
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 16),

                        // Dropdown Warga
                        const Text(
                          'Pilih Warga Pembayar *',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<ResidentBillingOptionModel>(
                          key: const Key('residentCashDropdown'),
                          value: _selectedResident,
                          isExpanded: true,
                          decoration: InputDecoration(
                            hintText: 'Pilih warga...',
                            prefixIcon: const Icon(Icons.person_search_outlined,
                                size: 20),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                          ),
                          items: _residents.map((r) {
                            return DropdownMenuItem<ResidentBillingOptionModel>(
                              value: r,
                              child: Text(
                                r.displayName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: _onResidentChanged,
                          validator: (v) =>
                              v == null ? 'Warga pembayar wajib dipilih' : null,
                        ),
                        const SizedBox(height: 16),

                        // Periode Iuran Selector
                        const Text(
                          'Pilih Periode Iuran Tagihan *',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 8),
                        if (_isLoadingPeriods)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                          )
                        else if (_selectedResident == null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Pilih warga terlebih dahulu untuk melihat daftar periode iuran.',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          )
                        else if (_periods.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: const [
                                Icon(Icons.info_outline,
                                    color: Colors.grey, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Belum ada data periode iuran yang tersedia dalam sistem.',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          DropdownButtonFormField<EligibleDuesPeriodModel>(
                            key: const Key('periodCashDropdown'),
                            value: _selectedPeriod,
                            isExpanded: true,
                            decoration: InputDecoration(
                              hintText: 'Pilih periode tagihan...',
                              prefixIcon: const Icon(
                                  Icons.calendar_month_outlined,
                                  size: 20),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                            ),
                            items: _periods.map((p) {
                              Color badgeColor;
                              String badgeText;
                              switch (p.status) {
                                case 'paid':
                                  badgeColor = Colors.green;
                                  badgeText = 'Lunas';
                                  break;
                                case 'pending_verification':
                                  badgeColor = Colors.orange;
                                  badgeText = 'Menunggu';
                                  break;
                                case 'rejected':
                                  badgeColor = Colors.red;
                                  badgeText = 'Ditolak';
                                  break;
                                default:
                                  badgeColor = Colors.grey.shade700;
                                  badgeText = 'Belum Bayar';
                              }

                              return DropdownMenuItem<EligibleDuesPeriodModel>(
                                value: p,
                                child: Row(
                                  children: [
                                    Text(p.billingPeriod,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13)),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: badgeColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        badgeText,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: badgeColor,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(_formatCurrency(p.amount),
                                        style: TextStyle(
                                            color: Colors.green.shade700,
                                            fontSize: 12)),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (p) =>
                                setState(() => _selectedPeriod = p),
                            validator: (v) => v == null
                                ? 'Periode iuran wajib dipilih'
                                : null,
                          ),
                          if (_selectedPeriod != null &&
                              _selectedPeriod!.isPaid) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.cancel_outlined,
                                      color: Colors.red.shade700, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Pembayaran untuk periode ini sudah lunas. Silakan periksa riwayat pembayaran sebelum melanjutkan.',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.red.shade800,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else if (_selectedPeriod != null &&
                              _selectedPeriod!.isPending) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: Colors.orange.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.hourglass_empty_rounded,
                                      color: Colors.orange.shade700, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Pembayaran untuk periode ini sedang menunggu verifikasi. Selesaikan verifikasi terlebih dahulu sebelum mencatat pembayaran tunai.',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.orange.shade800,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                        const SizedBox(height: 16),

                        // Tanggal Pembayaran
                        const Text(
                          'Tanggal Pembayaran *',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 14),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.event,
                                    size: 20, color: AppTheme.primary),
                                const SizedBox(width: 10),
                                Text(
                                  _formatDate(_paymentDate),
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600),
                                ),
                                const Spacer(),
                                const Text('Ubah',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Catatan Tambahan
                        const Text(
                          'Catatan Tambahan (Opsional)',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          key: const Key('cashNotesInput'),
                          controller: _notesController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText:
                                'Contoh: Uang tunai diterima di kantor sekretariat Cluster...',
                            prefixIcon:
                                const Icon(Icons.note_alt_outlined, size: 20),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Submit Button
                        ElevatedButton(
                          key: const Key('submitDirectCashBtn'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: (_isSubmitting ||
                                  _periods.isEmpty ||
                                  _selectedPeriod == null)
                              ? null
                              : _submitDirectCash,
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text(
                                  'Lanjutkan & Konfirmasi',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                ),
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
