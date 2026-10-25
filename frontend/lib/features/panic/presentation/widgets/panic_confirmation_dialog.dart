import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../data/panic_repository.dart';
import '../../domain/models/panic_models.dart';

class PanicConfirmationDialog extends StatefulWidget {
  final UserModel user;
  final PanicRepository repository;
  final double? latitude;
  final double? longitude;
  final String? locationSource;
  final VoidCallback? onAlarmSent;

  const PanicConfirmationDialog({
    super.key,
    required this.user,
    required this.repository,
    this.latitude,
    this.longitude,
    this.locationSource,
    this.onAlarmSent,
  });

  static Future<void> show({
    required BuildContext context,
    required UserModel user,
    required PanicRepository repository,
    double? latitude,
    double? longitude,
    String? locationSource,
    VoidCallback? onAlarmSent,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PanicConfirmationDialog(
        user: user,
        repository: repository,
        latitude: latitude,
        longitude: longitude,
        locationSource: locationSource,
        onAlarmSent: onAlarmSent,
      ),
    );
  }

  @override
  State<PanicConfirmationDialog> createState() =>
      _PanicConfirmationDialogState();
}

class _PanicConfirmationDialogState extends State<PanicConfirmationDialog> {
  PanicCategory _selectedCategory = PanicCategory.kejahatan;
  final TextEditingController _notesController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;
  IncidentReportModel? _createdIncident;
  late final String _idempotencyKey;

  @override
  void initState() {
    super.initState();
    // Unique idempotency key per alarm attempt session
    _idempotencyKey =
        'panic_${widget.user.id}_${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitAlarm() async {
    if (_isSubmitting) return; // Strict double-tap / concurrent prevention

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final desc = _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : 'Aktivasi tombol darurat (${_selectedCategory.label}) oleh ${widget.user.displayName}';

      final incident = await widget.repository.sendEmergencyAlarm(
        category: _selectedCategory.code,
        title: 'DARURAT: ${_selectedCategory.label}',
        description: desc,
        latitude: widget.latitude,
        longitude: widget.longitude,
        locationSource: widget.locationSource ??
            (widget.latitude != null ? 'GPS' : 'HOUSE_FALLBACK'),
        idempotencyKey: _idempotencyKey,
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _createdIncident = incident;
        });
        widget.onAlarmSent?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDone = _createdIncident != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 12,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: isDone ? _buildSuccessView() : _buildFormView(),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Alarm
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.crisis_alert_rounded,
                  color: AppTheme.danger,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Peringatan Darurat',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.danger,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Pilih jenis darurat & kirim sinyal ke satpam',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Info Terverifikasi Pelapor
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_user_rounded,
                        size: 16, color: AppTheme.primaryDark),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Pelapor: ${widget.user.displayName}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.home_rounded,
                        size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Lokasi: ${widget.user.houseDisplay}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      widget.latitude != null
                          ? Icons.my_location_rounded
                          : Icons.location_city_rounded,
                      size: 16,
                      color: widget.latitude != null
                          ? AppTheme.primary
                          : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.latitude != null
                            ? 'Koordinat GPS akurat'
                            : 'Fallback: Alamat Rumah Terdaftar',
                        style: TextStyle(
                          fontSize: 11,
                          color: widget.latitude != null
                              ? AppTheme.primaryDark
                              : AppTheme.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Pilihan Kategori
          const Text(
            'Kategori Insiden Darurat:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          _buildCategoryCard(
            category: PanicCategory.kejahatan,
            icon: Icons.local_police_rounded,
            color: const Color(0xFFDC2626),
          ),
          const SizedBox(height: 8),
          _buildCategoryCard(
            category: PanicCategory.kebakaran,
            icon: Icons.local_fire_department_rounded,
            color: const Color(0xFFEA580C),
          ),
          const SizedBox(height: 8),
          _buildCategoryCard(
            category: PanicCategory.medis,
            icon: Icons.medical_services_rounded,
            color: const Color(0xFFE11D48),
          ),
          const SizedBox(height: 14),

          // Catatan tambahan opsional
          TextField(
            controller: _notesController,
            enabled: !_isSubmitting,
            decoration: InputDecoration(
              labelText: 'Catatan tambahan (opsional)',
              hintText: 'Contoh: Maling membawa motor di depan pos',
              prefixIcon: const Icon(Icons.edit_note_rounded, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Error Banner with Retry
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppTheme.danger, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _isSubmitting ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Batal'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitAlarm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.danger,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 2,
                  ),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    _isSubmitting
                        ? 'Mengirim...'
                        : (_errorMessage != null
                            ? 'Coba Lagi'
                            : 'KIRIM ALARM SEKARANG'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard({
    required PanicCategory category,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedCategory == category;

    return InkWell(
      onTap: _isSubmitting
          ? null
          : () {
              setState(() {
                _selectedCategory = category;
              });
            },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.08)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFCBD5E1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? color : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    category.description,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? color : const Color(0xFF94A3B8),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    final inc = _createdIncident!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.success.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            color: AppTheme.success,
            size: 56,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'SINYAL DARURAT TERKIRIM!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppTheme.success,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Laporan insiden #${inc.id} (${inc.category}) telah berhasil disiarkan secara realtime ke seluruh pos keamanan lingkungan.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textPrimary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Status: ${inc.status}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: AppTheme.primaryDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Pelapor: ${widget.user.displayName}',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary),
              ),
              Text(
                'Lokasi: ${widget.user.houseDisplay}',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryDark,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Tutup & Kembali ke Beranda',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}
