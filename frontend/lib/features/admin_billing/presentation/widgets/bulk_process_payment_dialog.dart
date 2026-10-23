import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../billing/data/billing_repository.dart';
import '../../../billing/domain/models/billing_models.dart';

class BulkProcessPaymentDialog extends StatefulWidget {
  final BillingRepository repository;
  final String period;
  final List<HouseBillStatusModel> unpaidBills;
  final VoidCallback onSuccess;

  const BulkProcessPaymentDialog({
    super.key,
    required this.repository,
    required this.period,
    required this.unpaidBills,
    required this.onSuccess,
  });

  @override
  State<BulkProcessPaymentDialog> createState() => _BulkProcessPaymentDialogState();
}

class _BulkProcessPaymentDialogState extends State<BulkProcessPaymentDialog> {
  final Set<int> _selectedBillIds = {};
  String _paymentMethod = 'CASH'; // 'CASH' or 'TRANSFER'
  final TextEditingController _notesController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Default select all eligible unpaid bills
    for (final bill in widget.unpaidBills) {
      if (bill.billId != null) {
        _selectedBillIds.add(bill.billId!);
      }
    }
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

  double get _totalSelectedAmount {
    double sum = 0.0;
    for (final b in widget.unpaidBills) {
      if (b.billId != null && _selectedBillIds.contains(b.billId!)) {
        sum += b.amount;
      }
    }
    return sum;
  }

  Future<void> _submitBulkPayment() async {
    if (_selectedBillIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih minimal satu rumah untuk diproses!'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.repository.bulkProcessPayments(
        period: widget.period,
        paymentMethod: _paymentMethod,
        billIds: _selectedBillIds.toList(),
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      );

      if (!mounted) return;

      widget.onSuccess();
      Navigator.of(context).pop();

      _showResultDialog(result);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  void _showResultDialog(BulkProcessResultModel result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              result.failedCount == 0 ? Icons.check_circle : Icons.warning_amber_rounded,
              color: result.failedCount == 0 ? Colors.green : Colors.orange,
              size: 28,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Hasil Pembayaran Massal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Periode: ${result.period}', style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('Metode: ${result.paymentMethod == 'CASH' ? 'Tunai (Langsung Lunas)' : 'Transfer (Pending)'}'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text('Total', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text('${result.totalProcessed}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  Column(
                    children: [
                      const Text('Berhasil', style: TextStyle(fontSize: 12, color: Colors.green)),
                      Text('${result.successCount}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                    ],
                  ),
                  Column(
                    children: [
                      const Text('Gagal', style: TextStyle(fontSize: 12, color: Colors.red)),
                      Text('${result.failedCount}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
                    ],
                  ),
                ],
              ),
            ),
            if (result.failedCount > 0) ...[
              const SizedBox(height: 12),
              const Text('Rincian Gagal:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.danger)),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 150),
                child: ListView(
                  shrinkWrap: true,
                  children: result.results.where((r) => !r.success).map((r) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '• Blok ${r.houseBlock} No. ${r.houseNumber} (${r.residentName}): ${r.message}',
                        style: const TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allCount = widget.unpaidBills.where((b) => b.billId != null).length;
    final isAllSelected = _selectedBillIds.length == allCount && allCount > 0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.playlist_add_check, color: AppTheme.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Proses Pembayaran Massal',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textPrimary),
                        ),
                        Text(
                          'Periode Iuran: ${widget.period}',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24),

              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, size: 20, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

              // Metode Pembayaran
              const Text('Metode Pembayaran:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _isSubmitting ? null : () => setState(() => _paymentMethod = 'CASH'),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: _paymentMethod == 'CASH' ? Colors.green.shade50 : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _paymentMethod == 'CASH' ? Colors.green : Colors.grey.shade300,
                            width: _paymentMethod == 'CASH' ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.payments, size: 20, color: _paymentMethod == 'CASH' ? Colors.green.shade800 : Colors.grey),
                            const SizedBox(width: 8),
                            Text(
                              'Tunai (CASH)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _paymentMethod == 'CASH' ? Colors.green.shade800 : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _isSubmitting ? null : () => setState(() => _paymentMethod = 'TRANSFER'),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: _paymentMethod == 'TRANSFER' ? AppTheme.primary.withOpacity(0.08) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _paymentMethod == 'TRANSFER' ? AppTheme.primary : Colors.grey.shade300,
                            width: _paymentMethod == 'TRANSFER' ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.account_balance, size: 20, color: _paymentMethod == 'TRANSFER' ? AppTheme.primary : Colors.grey),
                            const SizedBox(width: 8),
                            Text(
                              'Transfer Bank',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _paymentMethod == 'TRANSFER' ? AppTheme.primary : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Penjelasan Metode
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _paymentMethod == 'CASH' ? Colors.green.shade50 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _paymentMethod == 'CASH' ? Colors.green.shade200 : Colors.blue.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: _paymentMethod == 'CASH' ? Colors.green.shade800 : Colors.blue.shade800,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _paymentMethod == 'CASH'
                            ? 'Tunai: Langsung LUNAS & dicatat otomatis ke Buku Kas RT tanpa double counting.'
                            : 'Transfer: Didaftarkan sebagai Menunggu Verifikasi (Pending) dan tidak langsung mengubah buku kas.',
                        style: TextStyle(
                          fontSize: 12,
                          color: _paymentMethod == 'CASH' ? Colors.green.shade900 : Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Catatan Opsional
              TextField(
                controller: _notesController,
                enabled: !_isSubmitting,
                decoration: InputDecoration(
                  labelText: 'Catatan (Opsional)',
                  hintText: 'Contoh: Pembayaran massal arisan RT / titip bendahara',
                  prefixIcon: const Icon(Icons.note_alt_outlined, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 14),

              // Daftar Rumah Unpaid
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text('Pilih Unit yang Dibayar:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: _isSubmitting || allCount == 0
                        ? null
                        : () {
                            setState(() {
                              if (isAllSelected) {
                                _selectedBillIds.clear();
                              } else {
                                for (final b in widget.unpaidBills) {
                                  if (b.billId != null) _selectedBillIds.add(b.billId!);
                                }
                              }
                            });
                          },
                    icon: Icon(isAllSelected ? Icons.deselect : Icons.select_all, size: 16),
                    label: Text(isAllSelected ? 'Batal Semua' : 'Pilih Semua ($allCount)'),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: widget.unpaidBills.isEmpty
                      ? const Center(
                          child: Text(
                            'Tidak ada tagihan belum lunas pada periode ini.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.separated(
                          itemCount: widget.unpaidBills.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = widget.unpaidBills[index];
                            if (item.billId == null) return const SizedBox.shrink();
                            final isChecked = _selectedBillIds.contains(item.billId!);

                            return CheckboxListTile(
                              value: isChecked,
                              dense: true,
                              enabled: !_isSubmitting,
                              activeColor: AppTheme.primary,
                              title: Text(
                                'Blok ${item.block} No. ${item.houseNumber} - ${item.residentName}',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              subtitle: Text(
                                'Nominal: ${_formatCurrency(item.amount)}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedBillIds.add(item.billId!);
                                  } else {
                                    _selectedBillIds.remove(item.billId!);
                                  }
                                });
                              },
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Total & Submit
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Total Terpilih: ${_selectedBillIds.length} Unit',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          _formatCurrency(_totalSelectedAmount),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primary),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    key: const Key('submitBulkProcessBtn'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isSubmitting || _selectedBillIds.isEmpty ? null : _submitBulkPayment,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_outline, size: 16),
                    label: Text(_isSubmitting ? 'Memproses...' : 'Proses'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
