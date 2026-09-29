import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/billing_models.dart';
import 'payment_proof_dialog.dart';

class DigitalReceiptDialog extends StatelessWidget {
  final BillModel bill;
  final String residentName;
  final String? residentPhone;

  const DigitalReceiptDialog({
    super.key,
    required this.bill,
    this.residentName = 'Warga RT',
    this.residentPhone,
  });

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

  String _formatDate(dynamic rawDate) {
    if (rawDate == null) return '-';
    if (rawDate is DateTime) {
      try {
        return DateFormat('d MMMM yyyy, HH:mm', 'id_ID').format(rawDate);
      } catch (_) {
        return rawDate.toString();
      }
    }
    final str = rawDate.toString().trim();
    if (str.isEmpty) return '-';
    try {
      final dt = DateTime.parse(str);
      return DateFormat('d MMMM yyyy, HH:mm', 'id_ID').format(dt);
    } catch (_) {
      return str;
    }
  }

  @override
  Widget build(BuildContext context) {
    final payment = bill.payment;
    final houseInfo = (bill.block != null && bill.block!.isNotEmpty && bill.houseNumber != null && bill.houseNumber!.isNotEmpty)
        ? 'Blok ${bill.block} No. ${bill.houseNumber}'
        : (bill.houseId > 0 ? 'Rumah ID #${bill.houseId}' : '-');
    final receiptNumber = 'KW-${bill.id}-${bill.billingPeriod.replaceAll('-', '')}';

    final senderBank = payment?.senderBank;
    final senderName = payment?.senderName;
    final verifiedByName = payment?.verifiedByName;
    final proofUrl = payment?.proofImageUrl;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: AppTheme.primary, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'KUITANSI PEMBAYARAN DIGITAL',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Kas Iuran Lingkungan TetangGo',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // No Kuitansi
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('No. Kuitansi:', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                      Text(
                        receiptNumber,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Rincian Data
                _buildRow('Warga / Pembayar', residentName.isNotEmpty ? residentName : 'Warga RT'),
                if (residentPhone != null && residentPhone!.isNotEmpty)
                  _buildRow('No. Telepon', residentPhone!),
                _buildRow('Unit Hunian', houseInfo),
                _buildRow('Periode Tagihan', bill.billingPeriod.isNotEmpty ? bill.billingPeriod : '-'),
                _buildRow('Status', 'LUNAS', valueColor: AppTheme.success),
                if (senderBank != null && senderBank.isNotEmpty)
                  _buildRow('Bank Pengirim', '$senderBank${(senderName != null && senderName.isNotEmpty) ? " a.n $senderName" : ""}'),
                _buildRow('Tanggal Lunas', _formatDate(payment?.verifiedAt ?? bill.updatedAt)),
                if (verifiedByName != null && verifiedByName.isNotEmpty)
                  _buildRow('Diverifikasi Oleh', verifiedByName),

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Total Nominal
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Iuran Lunas', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    Text(
                      _formatCurrency(bill.amount),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Digital Stamp "LUNAS - DIVERIFIKASI PENGURUS RT"
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      border: Border.all(color: Colors.green.shade600, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_rounded, color: Colors.green.shade700, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'LUNAS',
                              style: TextStyle(
                                color: Colors.green.shade800,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'DIVERIFIKASI PENGURUS RT',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                Row(
                  children: [
                    if (proofUrl != null && proofUrl.isNotEmpty)
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primary,
                            side: const BorderSide(color: AppTheme.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => PaymentProofDialog(
                                proofImageUrl: proofUrl,
                                title: 'Bukti Transfer - ${bill.billingPeriod}',
                                senderBank: senderBank,
                                senderName: senderName,
                                amount: (payment != null && payment.amountPaid > 0) ? payment.amountPaid : bill.amount,
                              ),
                            );
                          },
                          icon: const Icon(Icons.image_outlined, size: 18),
                          label: const Text('Lihat Bukti Transfer', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                      ),
                    if (proofUrl != null && proofUrl.isNotEmpty)
                      const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          const Text(': ', style: TextStyle(fontSize: 12, color: Colors.grey)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
