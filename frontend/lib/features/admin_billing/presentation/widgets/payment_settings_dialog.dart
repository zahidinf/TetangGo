import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../billing/data/billing_repository.dart';
import '../../../billing/domain/models/billing_models.dart';

class PaymentSettingsDialog extends StatefulWidget {
  final PaymentSettingModel setting;
  final BillingRepository repository;
  final VoidCallback onUpdated;

  const PaymentSettingsDialog({
    super.key,
    required this.setting,
    required this.repository,
    required this.onUpdated,
  });

  @override
  State<PaymentSettingsDialog> createState() => _PaymentSettingsDialogState();
}

class _PaymentSettingsDialogState extends State<PaymentSettingsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _bankNameController;
  late final TextEditingController _accountNumberController;
  late final TextEditingController _accountHolderController;
  late final TextEditingController _monthlyFeeController;
  late final TextEditingController _periodController;

  bool _isSavingSetting = false;
  bool _isGeneratingBills = false;

  @override
  void initState() {
    super.initState();
    _bankNameController = TextEditingController(text: widget.setting.bankName);
    _accountNumberController = TextEditingController(text: widget.setting.accountNumber);
    _accountHolderController = TextEditingController(text: widget.setting.accountHolder);
    _monthlyFeeController = TextEditingController(text: widget.setting.monthlyFee.toStringAsFixed(0));

    // Default periode bulan ini
    _periodController = TextEditingController(text: DateFormat('yyyy-MM').format(DateTime.now()));
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountHolderController.dispose();
    _monthlyFeeController.dispose();
    _periodController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    final fee = double.tryParse(_monthlyFeeController.text.trim()) ?? 0;
    if (fee <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal iuran harus lebih besar dari 0'), backgroundColor: AppTheme.danger),
      );
      return;
    }

    setState(() => _isSavingSetting = true);
    try {
      await widget.repository.updatePaymentSettings(
        bankName: _bankNameController.text.trim(),
        accountNumber: _accountNumberController.text.trim(),
        accountHolder: _accountHolderController.text.trim(),
        monthlyFee: fee,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengaturan iuran berhasil disimpan!'), backgroundColor: AppTheme.success),
        );
        widget.onUpdated();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingSetting = false);
    }
  }

  Future<void> _triggerGenerateBills() async {
    final period = _periodController.text.trim();
    if (period.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Konfirmasi Penerbitan Tagihan', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Apakah Anda yakin ingin menerbitkan tagihan IPL periode $period untuk seluruh rumah berpenghuni?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.amber.shade900),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Catatan: Periode yang sudah memiliki pembayaran dari warga akan otomatis terkunci dan tidak dapat diubah.',
                      style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Terbitkan'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isGeneratingBills = true);
    try {
      final count = await widget.repository.generateMonthlyBills(period);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Berhasil menerbitkan $count tagihan baru untuk periode $period!'),
            backgroundColor: AppTheme.success,
          ),
        );
        widget.onUpdated();
      }
    } catch (e) {
      if (mounted) {
        final rawMsg = e.toString().replaceAll('Exception: ', '');
        final displayMsg = rawMsg.toLowerCase().contains('terkunci')
            ? 'Gagal: Periode ini sudah memiliki transaksi pembayaran dan tidak dapat di-generate ulang.'
            : rawMsg;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(displayMsg),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingBills = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 680),
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
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.tune_rounded, color: AppTheme.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Pengaturan Iuran & Rekening RT',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Form Fields Rekening
                const Text(
                  'Data Rekening Kas RT',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _bankNameController,
                  decoration: InputDecoration(
                    labelText: 'Nama Bank / E-Wallet *',
                    hintText: 'Contoh: BCA, Mandiri, BRI',
                    prefixIcon: const Icon(Icons.account_balance, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama bank wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _accountNumberController,
                  decoration: InputDecoration(
                    labelText: 'Nomor Rekening *',
                    hintText: 'Contoh: 8830192831',
                    prefixIcon: const Icon(Icons.credit_card, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Nomor rekening wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _accountHolderController,
                  decoration: InputDecoration(
                    labelText: 'Atas Nama Rekening *',
                    hintText: 'Contoh: Kas RT 05 RW 01',
                    prefixIcon: const Icon(Icons.person, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Atas nama rekening wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _monthlyFeeController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Tarif Iuran Bulanan Default (Rp) *',
                    hintText: 'Contoh: 100000',
                    prefixIcon: const Icon(Icons.payments_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Tarif iuran wajib diisi' : null,
                ),
                const SizedBox(height: 16),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _isSavingSetting ? null : _saveSettings,
                  child: _isSavingSetting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Simpan Pengaturan Rekening', style: TextStyle(fontWeight: FontWeight.bold)),
                ),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),

                // Generator Tagihan Bulanan
                const Text(
                  'Penerbitan Tagihan Bulanan Massal',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  'Buat tagihan iuran baru secara otomatis untuk seluruh rumah berpenghuni pada periode tertentu.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _periodController,
                        decoration: InputDecoration(
                          labelText: 'Periode (YYYY-MM)',
                          hintText: '2026-10',
                          prefixIcon: const Icon(Icons.date_range, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      onPressed: _isGeneratingBills ? null : _triggerGenerateBills,
                      icon: _isGeneratingBills
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.flash_on_rounded, size: 18),
                      label: const Text('Generate Tagihan', style: TextStyle(fontWeight: FontWeight.bold)),
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
