import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/cashbook_repository.dart';

class RecordTransactionDialog extends StatefulWidget {
  final CashbookRepository repository;
  final String initialType; // 'expense' or 'income'
  final VoidCallback onSuccess;

  const RecordTransactionDialog({
    super.key,
    required this.repository,
    this.initialType = 'expense',
    required this.onSuccess,
  });

  @override
  State<RecordTransactionDialog> createState() =>
      _RecordTransactionDialogState();
}

class _RecordTransactionDialogState extends State<RecordTransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _type;
  late String _category;
  late DateTime _selectedDate;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  Uint8List? _pickedFileBytes;
  String? _pickedFileName;
  bool _isLoading = false;
  String? _errorMessage;

  final List<Map<String, String>> _expenseCategories = [
    {'value': 'kebersihan', 'label': 'Kebersihan & Sampah'},
    {'value': 'keamanan', 'label': 'Keamanan & Pos Ronda'},
    {'value': 'perbaikan_fasilitas', 'label': 'Perbaikan Fasilitas Lingkungan'},
    {'value': 'kegiatan_sosial', 'label': 'Kegiatan Sosial / Kerja Bakti'},
    {'value': 'operasional', 'label': 'Operasional Cluster / ATK'},
    {'value': 'lainnya', 'label': 'Lain-lain'},
  ];

  final List<Map<String, String>> _incomeCategories = [
    {'value': 'donasi', 'label': 'Donasi / Sumbangan Warga'},
    {'value': 'iuran', 'label': 'Iuran Tambahan / Khusus'},
    {'value': 'lainnya', 'label': 'Pemasukan Lainnya'},
  ];

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _selectedDate = DateTime.now();
    _category = _type == 'expense' ? 'perbaikan_fasilitas' : 'donasi';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onTypeChanged(String newType) {
    setState(() {
      _type = newType;
      _category = newType == 'expense' ? 'perbaikan_fasilitas' : 'donasi';
    });
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          setState(() {
            _pickedFileBytes = file.bytes;
            _pickedFileName = file.name;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memilih file: $e')),
      );
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final cleanAmountStr =
        _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = double.tryParse(cleanAmountStr);
    if (amount == null || amount <= 0) {
      setState(() => _errorMessage = 'Nominal harus lebih besar dari Rp 0');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      await widget.repository.createManualTransaction(
        type: _type,
        category: _category,
        amount: amount,
        transactionDate: dateStr,
        description: _descriptionController.text.trim(),
        imageBytes: _pickedFileBytes,
        fileName: _pickedFileName,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.primary,
            content: Text(_type == 'expense'
                ? 'Pengeluaran kas berhasil dicatat'
                : 'Pemasukan kas berhasil dicatat'),
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    final categories =
        _type == 'expense' ? _expenseCategories : _incomeCategories;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _type == 'expense'
                          ? 'Catat Pengeluaran Kas'
                          : 'Catat Pemasukan / Donasi',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Type Toggle Buttons
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _onTypeChanged('expense'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _type == 'expense'
                                  ? AppTheme.danger
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.arrow_upward_rounded,
                                    size: 16,
                                    color: _type == 'expense'
                                        ? Colors.white
                                        : Colors.grey.shade700),
                                const SizedBox(width: 6),
                                Text(
                                  'Kas Keluar (Pengeluaran)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: _type == 'expense'
                                        ? Colors.white
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _onTypeChanged('income'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _type == 'income'
                                  ? AppTheme.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.arrow_downward_rounded,
                                    size: 16,
                                    color: _type == 'income'
                                        ? Colors.white
                                        : Colors.grey.shade700),
                                const SizedBox(width: 6),
                                Text(
                                  'Kas Masuk (Pemasukan)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: _type == 'income'
                                        ? Colors.white
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: AppTheme.danger.withOpacity(0.3)),
                    ),
                    child: Text(_errorMessage!,
                        style: const TextStyle(
                            color: AppTheme.danger, fontSize: 12)),
                  ),

                // Kategori Dropdown
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(
                    labelText: 'Kategori Transaksi',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: categories.map((cat) {
                    return DropdownMenuItem<String>(
                      value: cat['value'],
                      child: Text(cat['label']!),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _category = val);
                  },
                ),
                const SizedBox(height: 16),

                // Nominal Input
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Nominal Transaksi (Rp)',
                    prefixText: 'Rp ',
                    prefixIcon: Icon(Icons.attach_money_rounded),
                    hintText: '50000',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty)
                      return 'Nominal wajib diisi';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Tanggal Transaksi Picker
                InkWell(
                  onTap: _selectDate,
                  borderRadius: BorderRadius.circular(10),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Tanggal Transaksi',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                      suffixIcon: Icon(Icons.edit_calendar_rounded, size: 18),
                    ),
                    child: Text(
                      DateFormat('EEEE, d MMMM yyyy', 'id_ID')
                          .format(_selectedDate),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Deskripsi Input
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Deskripsi / Keperluan Belanja',
                    hintText: _type == 'expense'
                        ? 'Contoh: Pembelian 3 lampu LED pos ronda dan perbaikan kabel'
                        : 'Contoh: Donasi sukarela bapak Ahmad untuk takjil musholla',
                    alignLabelWithHint: true,
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(bottom: 40),
                      child: Icon(Icons.description_outlined),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty)
                      return 'Deskripsi wajib diisi';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Bukti Nota / Foto Upload
                const Text(
                  'Foto Nota / Kuitansi Belanja (Opsional):',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 8),

                if (_pickedFileBytes == null)
                  OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.upload_file_rounded),
                    label:
                        const Text('Pilih Foto Nota / Struk (JPG, PNG, PDF)'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                          color: Colors.grey.shade400,
                          style: BorderStyle.solid),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: AppTheme.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.receipt_long_rounded,
                            color: AppTheme.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _pickedFileName ?? 'File nota terpilih',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryDark),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              size: 18, color: AppTheme.danger),
                          onPressed: () => setState(() {
                            _pickedFileBytes = null;
                            _pickedFileName = null;
                          }),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed:
                          _isLoading ? null : () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _type == 'expense'
                            ? AppTheme.danger
                            : AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(_type == 'expense'
                              ? 'Simpan Pengeluaran'
                              : 'Simpan Pemasukan'),
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
