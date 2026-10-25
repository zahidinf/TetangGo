import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/cashbook_models.dart';

class ExportReportDialog extends StatelessWidget {
  final CashbookSummaryModel summary;
  final List<CashTransactionModel> transactions;

  const ExportReportDialog({
    super.key,
    required this.summary,
    required this.transactions,
  });

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(amount);
  }

  String _generateCSV() {
    final buffer = StringBuffer();
    buffer.writeln('ID,Tanggal,Tipe,Kategori,Nominal,Keterangan,Pencatat');
    for (final tx in transactions) {
      final cleanDesc = tx.description.replaceAll('"', '""');
      buffer.writeln(
          '${tx.id},${tx.transactionDate},${tx.type},${tx.category},${tx.amount},"$cleanDesc",${tx.creatorName}');
    }
    return buffer.toString();
  }

  String _generateTextReport() {
    final buffer = StringBuffer();
    final nowStr =
        DateFormat('d MMMM yyyy, HH:mm', 'id_ID').format(DateTime.now());
    buffer.writeln('==============================================');
    buffer.writeln('   LAPORAN REKAPITULASI BUKU KAS TETANGGO    ');
    buffer.writeln('    "Tetangga Kompak, Lingkungan Terjaga"     ');
    buffer.writeln('==============================================');
    buffer.writeln('Waktu Cetak       : $nowStr');
    buffer.writeln(
        'Saldo Kas Saat Ini: ${_formatCurrency(summary.currentBalance)}');
    buffer
        .writeln('Total Pemasukan   : ${_formatCurrency(summary.totalIncome)}');
    buffer.writeln(
        'Total Pengeluaran : ${_formatCurrency(summary.totalExpense)}');
    buffer.writeln('----------------------------------------------');
    buffer.writeln('RINCIAN MUTASI TRANSAKSI:');
    buffer.writeln('');

    for (var i = 0; i < transactions.length; i++) {
      final tx = transactions[i];
      final prefix = tx.isIncome ? '[+] MASUK ' : '[-] KELUAR';
      buffer.writeln('${i + 1}. $prefix | ${tx.transactionDate}');
      buffer.writeln('   Kategori : ${tx.categoryDisplay}');
      buffer.writeln('   Nominal  : ${_formatCurrency(tx.amount)}');
      buffer.writeln('   Keperluan: ${tx.description}');
      buffer.writeln('   Admin    : ${tx.creatorName}');
      buffer.writeln('');
    }
    buffer.writeln('==============================================');
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 650),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.print_rounded, color: AppTheme.primary),
                      SizedBox(width: 8),
                      Text(
                        'Ekspor / Cetak Rekap Mutasi Kas',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 20, color: Colors.blue.shade700),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Total ${transactions.length} mutasi siap diekspor ke format CSV (Excel) atau teks rekap resmi.',
                        style: TextStyle(
                            fontSize: 12, color: Colors.blue.shade900),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _generateTextReport(),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Color(0xFFE2E8F0),
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      final csv = _generateCSV();
                      Clipboard.setData(ClipboardData(text: csv));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Data CSV disalin ke clipboard! Siap di-paste ke Excel.')),
                      );
                    },
                    icon: const Icon(Icons.table_chart_rounded, size: 16),
                    label: const Text('Salin Format CSV'),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      final textReport = _generateTextReport();
                      Clipboard.setData(ClipboardData(text: textReport));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Laporan lengkap disalin ke clipboard!')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Salin Rekap Teks'),
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
