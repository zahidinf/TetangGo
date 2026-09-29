import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/billing_repository.dart';
import '../../domain/models/billing_models.dart';

class PaymentFlowDialog extends StatefulWidget {
  final BillModel bill;
  final PaymentSettingModel setting;
  final BillingRepository repository;
  final VoidCallback onPaymentSuccess;

  const PaymentFlowDialog({
    super.key,
    required this.bill,
    required this.setting,
    required this.repository,
    required this.onPaymentSuccess,
  });

  @override
  State<PaymentFlowDialog> createState() => _PaymentFlowDialogState();
}

class _PaymentFlowDialogState extends State<PaymentFlowDialog> {
  final _formKey = GlobalKey<FormState>();
  final _senderNameController = TextEditingController();
  final _senderBankController = TextEditingController();
  final _notesController = TextEditingController();

  Uint8List? _selectedFileBytes;
  String? _selectedFileName;
  bool _isLoading = false;

  @override
  void dispose() {
    _senderNameController.dispose();
    _senderBankController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _formatCurrency(double amount) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return currencyFormatter.format(amount);
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Nomor rekening $text berhasil disalin ke clipboard!'),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.size > 5 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Ukuran file maksimal 5MB!'),
                backgroundColor: AppTheme.danger,
              ),
            );
          }
          return;
        }

        if (file.bytes != null) {
          setState(() {
            _selectedFileBytes = file.bytes;
            _selectedFileName = file.name;
          });
        }
      }
    } catch (e) {
      debugPrint('[ERROR PICK FILE]: $e');
      if (!kIsWeb) {
        try {
          final picker = ImagePicker();
          final XFile? image = await picker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 85,
          );
          if (image != null) {
            final bytes = await image.readAsBytes();
            if (bytes.length > 5 * 1024 * 1024) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ukuran file maksimal 5MB!'),
                    backgroundColor: AppTheme.danger,
                  ),
                );
              }
              return;
            }
            setState(() {
              _selectedFileBytes = bytes;
              _selectedFileName = image.name;
            });
            return;
          }
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memilih file: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedFileBytes == null || _selectedFileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap pilih foto struk / bukti transfer!'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await widget.repository.submitPayment(
        billId: widget.bill.id,
        senderBank: _senderBankController.text.trim(),
        senderName: _senderNameController.text.trim(),
        amount: widget.bill.amount,
        notes: _notesController.text.trim(),
        imageBytes: _selectedFileBytes!,
        fileName: _selectedFileName!,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bukti pembayaran berhasil dikirim! Menunggu verifikasi pengurus RT.'),
            backgroundColor: AppTheme.success,
          ),
        );
        widget.onPaymentSuccess();
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 720),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
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
                      child: const Icon(Icons.payment_rounded, color: AppTheme.primary, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Konfirmasi Pembayaran Iuran',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                          ),
                          Text(
                            'Periode: ${widget.bill.billingPeriod}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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

                // Card Rekening Kas RT
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primary, AppTheme.primary.withBlue(160)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'BANK ${widget.setting.bankName.toUpperCase()}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          const Icon(Icons.account_balance_rounded, color: Colors.white70, size: 24),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Nomor Rekening Kas RT:',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            widget.setting.accountNumber,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const Spacer(),
                          InkWell(
                            onTap: () => _copyToClipboard(widget.setting.accountNumber),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.copy_rounded, color: AppTheme.primary, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'Salin',
                                    style: TextStyle(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Atas Nama: ${widget.setting.accountHolder}',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Total yang harus ditransfer: ${_formatCurrency(widget.bill.amount)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Form Data Pengirim
                const Text(
                  'Data Rekening Pengirim',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _senderNameController,
                  decoration: InputDecoration(
                    labelText: 'Nama Pemilik Rekening Pengirim *',
                    hintText: 'Contoh: Ahmad Dahlan',
                    prefixIcon: const Icon(Icons.person_outline, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama pengirim wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _senderBankController,
                  decoration: InputDecoration(
                    labelText: 'Bank / E-Wallet Pengirim *',
                    hintText: 'Contoh: BCA, BRI, Mandiri, GoPay, OVO',
                    prefixIcon: const Icon(Icons.account_balance_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Bank/E-wallet pengirim wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: 'Catatan Tambahan (Opsional)',
                    hintText: 'Catatan untuk bendahara RT...',
                    prefixIcon: const Icon(Icons.note_alt_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 18),

                // Upload Bukti Struk
                const Text(
                  'Unggah Foto Struk / Screenshot Transfer *',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 8),

                InkWell(
                  onTap: _pickImage,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _selectedFileBytes != null ? AppTheme.primary : Colors.grey.shade300,
                        width: 1.5,
                        style: BorderStyle.solid,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey.shade50,
                    ),
                    child: _selectedFileBytes != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(
                                  _selectedFileBytes!,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.6),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                                        onPressed: _pickImage,
                                        tooltip: 'Ganti Foto',
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade700.withOpacity(0.8),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.white, size: 18),
                                        onPressed: () {
                                          setState(() {
                                            _selectedFileBytes = null;
                                            _selectedFileName = null;
                                          });
                                        },
                                        tooltip: 'Hapus Foto',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_rounded, size: 44, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              const Text(
                                'Klik untuk memilih foto bukti transfer',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Format: JPG, JPEG, PNG (Maksimal 5MB)',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                  ),
                ),
                if (_selectedFileName != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: AppTheme.success, size: 16),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _selectedFileName!,
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _isLoading ? null : _submitPayment,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Kirim Bukti Pembayaran',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

typedef PaymentBottomSheet = PaymentFlowDialog;
