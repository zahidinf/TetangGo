import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/security_repository.dart';
import '../../data/security_siren_service.dart';
import '../../data/security_websocket_service.dart';
import '../../domain/models/security_models.dart';

class EmergencyFullscreenDialog extends StatefulWidget {
  final SecurityIncidentModel incident;
  final SecurityRepository repository;
  final SecuritySirenService sirenService;
  final VoidCallback onAcknowledgeSuccess;
  final VoidCallback? onResolveSuccess;
  final SecurityWebSocketService? wsService;

  const EmergencyFullscreenDialog({
    super.key,
    required this.incident,
    required this.repository,
    required this.sirenService,
    required this.onAcknowledgeSuccess,
    this.onResolveSuccess,
    this.wsService,
  });

  static Future<void> show({
    required BuildContext context,
    required SecurityIncidentModel incident,
    required SecurityRepository repository,
    required SecuritySirenService sirenService,
    required VoidCallback onAcknowledgeSuccess,
    VoidCallback? onResolveSuccess,
    SecurityWebSocketService? wsService,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Darurat Satpam',
      barrierColor: Colors.black.withOpacity(0.85),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return EmergencyFullscreenDialog(
          incident: incident,
          repository: repository,
          sirenService: sirenService,
          onAcknowledgeSuccess: onAcknowledgeSuccess,
          onResolveSuccess: onResolveSuccess,
          wsService: wsService,
        );
      },
    );
  }

  @override
  State<EmergencyFullscreenDialog> createState() =>
      _EmergencyFullscreenDialogState();
}

class _EmergencyFullscreenDialogState extends State<EmergencyFullscreenDialog>
    with SingleTickerProviderStateMixin {
  late SecurityIncidentModel _currentIncident;
  bool _isSubmitting = false;
  String? _errorMessage;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  StreamSubscription? _wsSubscription;

  @override
  void initState() {
    super.initState();
    _currentIncident = widget.incident;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseController.repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _setupWebSocketListener();
  }

  void _setupWebSocketListener() {
    if (widget.wsService == null) return;

    _wsSubscription = widget.wsService!.eventStream.listen((event) async {
      final eventType = event['event_type'] as String?;
      final data = event['data'] as Map<String, dynamic>?;
      final incId = data?['incident_id'] as int? ?? data?['id'] as int?;

      if (incId == _currentIncident.id) {
        if (eventType == 'INCIDENT_ACKNOWLEDGED' ||
            eventType == 'INCIDENT_RESOLVED') {
          try {
            final fresh =
                await widget.repository.getIncidentDetail(_currentIncident.id);
            if (mounted) {
              setState(() {
                _currentIncident = fresh;
                if (!fresh.isActive) {
                  widget.sirenService.stopSiren();
                }
              });
            }
          } catch (_) {}
        }
      }
    });
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Color _getCategoryColor() {
    if (_currentIncident.isResolved) {
      return Colors.green.shade700;
    }
    if (_currentIncident.isAcknowledged) {
      return Colors.amber.shade800;
    }
    switch (_currentIncident.category.toUpperCase()) {
      case 'KEBAKARAN':
        return Colors.deepOrange;
      case 'KEJAHATAN':
        return Colors.red.shade700;
      case 'MEDIS':
        return Colors.blue.shade700;
      default:
        return Colors.red;
    }
  }

  IconData _getCategoryIcon() {
    if (_currentIncident.isResolved) {
      return Icons.task_alt_rounded;
    }
    if (_currentIncident.isAcknowledged) {
      return Icons.shield_rounded;
    }
    switch (_currentIncident.category.toUpperCase()) {
      case 'KEBAKARAN':
        return Icons.local_fire_department_rounded;
      case 'KEJAHATAN':
        return Icons.security_rounded;
      case 'MEDIS':
        return Icons.emergency_rounded;
      default:
        return Icons.warning_rounded;
    }
  }

  Future<void> _handleAcknowledge() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final updated =
          await widget.repository.acknowledgeIncident(_currentIncident.id);
      widget.sirenService.stopSiren();
      if (mounted) {
        setState(() {
          _currentIncident = updated;
          _isSubmitting = false;
        });
        widget.onAcknowledgeSuccess();
      }
    } catch (e) {
      // Resynchronize status from backend to prevent false success and display updated state
      try {
        final fresh =
            await widget.repository.getIncidentDetail(_currentIncident.id);
        if (mounted) {
          setState(() {
            _currentIncident = fresh;
            if (!fresh.isActive) {
              widget.sirenService.stopSiren();
            }
          });
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  void _showResolveConfirmationDialog() {
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: !_isSubmitting,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              key: const Key('resolutionNotesDialog'),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.verified_rounded,
                        color: Colors.green.shade700, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Situasi Terkendali',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Masukkan catatan akhir penanganan sebelum menyelesaikan insiden darurat ini:',
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      key: const Key('resolutionNotesField'),
                      controller: notesController,
                      maxLines: 3,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Catatan Akhir Penanganan *',
                        hintText:
                            'Contoh: Situasi aman terkendali, korban telah ditangani...',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Catatan akhir penyelesaian wajib diisi';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Batal'),
                ),
                ElevatedButton.icon(
                  key: const Key('confirmResolveBtn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(_isSubmitting
                      ? 'Menyimpan...'
                      : 'Konfirmasi & Selesaikan'),
                  onPressed: _isSubmitting
                      ? null
                      : () async {
                          if (formKey.currentState?.validate() ?? false) {
                            final notes = notesController.text.trim();
                            Navigator.of(dialogCtx).pop();
                            await _handleResolve(notes);
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleResolve(String notes) async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final resolved =
          await widget.repository.resolveIncident(_currentIncident.id, notes);
      widget.sirenService.stopSiren();
      if (mounted) {
        setState(() {
          _currentIncident = resolved;
          _isSubmitting = false;
        });
        widget.onResolveSuccess?.call();
        widget.onAcknowledgeSuccess();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Insiden #${_currentIncident.id} berhasil diselesaikan. Situasi aman terkendali.'),
            backgroundColor: Colors.green.shade800,
          ),
        );
      }
    } catch (e) {
      // Resynchronize status from backend to prevent false success
      try {
        final fresh =
            await widget.repository.getIncidentDetail(_currentIncident.id);
        if (mounted) {
          setState(() {
            _currentIncident = fresh;
            if (!fresh.isActive) {
              widget.sirenService.stopSiren();
            }
          });
        }
      } catch (_) {}

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
    final catColor = _getCategoryColor();
    final isHandling = _currentIncident.isAcknowledged;
    final isResolved = _currentIncident.isResolved;

    return WillPopScope(
      onWillPop: () async => !isHandling && !isResolved ? false : true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 620),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: catColor.withOpacity(0.5),
                    blurRadius: 30,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Alert Banner
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 20),
                      color: catColor,
                      child: Row(
                        children: [
                          ScaleTransition(
                            scale: _pulseAnimation,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(_getCategoryIcon(),
                                  color: catColor, size: 36),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isResolved
                                      ? 'SITUASI TERKENDALI / SELESAI'
                                      : isHandling
                                          ? 'SEDANG DITANGANI PETUGAS'
                                          : 'DARURAT POS SATPAM',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _currentIncident.categoryDisplay,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Siren mute toggle (only active for unhandled alert)
                          if (!isHandling && !isResolved) ...[
                            ValueListenableBuilder<bool>(
                              valueListenable:
                                  widget.sirenService.isMutedNotifier,
                              builder: (context, isMuted, _) {
                                return IconButton(
                                  style: IconButton.styleFrom(
                                    backgroundColor:
                                        Colors.white.withOpacity(0.2),
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: Icon(
                                    isMuted
                                        ? Icons.volume_off_rounded
                                        : Icons.volume_up_rounded,
                                  ),
                                  tooltip: isMuted
                                      ? 'Bunyikan Sirene'
                                      : 'Redam Bunyi',
                                  onPressed: () {
                                    if (isMuted) {
                                      widget.sirenService.unmuteSiren();
                                    } else {
                                      widget.sirenService.muteSiren();
                                    }
                                  },
                                );
                              },
                            ),
                          ] else ...[
                            IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  color: Colors.white),
                              tooltip: 'Tutup',
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Content Body
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_errorMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border:
                                      Border.all(color: Colors.red.shade200),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline,
                                        color: Colors.red, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: TextStyle(
                                            color: Colors.red.shade900,
                                            fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Incident Details Card
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Column(
                                children: [
                                  _buildInfoRow(
                                    icon: Icons.home_rounded,
                                    label: 'Blok / No. Rumah',
                                    value: _currentIncident.houseDisplay,
                                    isHighlight: true,
                                  ),
                                  const Divider(height: 20),
                                  _buildInfoRow(
                                    icon: Icons.person_rounded,
                                    label: 'Nama Warga',
                                    value: _currentIncident.reporterName,
                                  ),
                                  if (_currentIncident.reporterPhone != null &&
                                      _currentIncident
                                          .reporterPhone!.isNotEmpty) ...[
                                    const Divider(height: 20),
                                    _buildInfoRow(
                                      icon: Icons.phone_rounded,
                                      label: 'Telepon Darurat',
                                      value:
                                          _currentIncident.reporterPhone!,
                                    ),
                                  ],
                                  const Divider(height: 20),
                                  _buildInfoRow(
                                    icon: Icons.access_time_filled_rounded,
                                    label: 'Waktu Kejadian',
                                    value: _formatReportedTime(
                                        _currentIncident.reportedAt),
                                  ),
                                  if (_currentIncident.latitude != null &&
                                      _currentIncident.longitude != null) ...[
                                    const Divider(height: 20),
                                    _buildInfoRow(
                                      icon: Icons.location_on_rounded,
                                      label: 'Koordinat GPS',
                                      value:
                                          '${_currentIncident.latitude!.toStringAsFixed(6)}, ${_currentIncident.longitude!.toStringAsFixed(6)}',
                                    ),
                                  ],
                                  if (isHandling || isResolved) ...[
                                    const Divider(height: 20),
                                    _buildInfoRow(
                                      icon: Icons.security_rounded,
                                      label: 'Petugas Penanganan',
                                      value: _currentIncident
                                              .assignedSecurityName ??
                                          'Petugas Pos Satpam',
                                      isHighlight: true,
                                    ),
                                    if (_currentIncident.handlingStartedAt !=
                                        null) ...[
                                      const Divider(height: 20),
                                      _buildInfoRow(
                                        icon: Icons.timer_rounded,
                                        label: 'Mulai Penanganan',
                                        value: _formatReportedTime(
                                            _currentIncident
                                                .handlingStartedAt!),
                                      ),
                                    ],
                                  ],
                                  if (isResolved) ...[
                                    if (_currentIncident.resolvedAt !=
                                        null) ...[
                                      const Divider(height: 20),
                                      _buildInfoRow(
                                        icon: Icons.check_circle_rounded,
                                        label: 'Waktu Selesai',
                                        value: _formatReportedTime(
                                            _currentIncident.resolvedAt!),
                                      ),
                                    ],
                                    if (_currentIncident.resolutionNotes !=
                                            null &&
                                        _currentIncident
                                            .resolutionNotes!.isNotEmpty) ...[
                                      const Divider(height: 20),
                                      _buildInfoRow(
                                        icon: Icons.note_alt_rounded,
                                        label: 'Catatan Akhir',
                                        value: _currentIncident
                                            .resolutionNotes!,
                                      ),
                                    ],
                                  ],
                                ],
                              ),
                            ),

                            if (_currentIncident.description.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Text(
                                'Keterangan Tambahan:',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _currentIncident.description,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // Actions Footer
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(catColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(Color catColor) {
    if (_currentIncident.isResolved) {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: BorderSide(color: Colors.green.shade600),
        ),
        icon: Icon(Icons.check_circle_rounded, color: Colors.green.shade700),
        label: Text(
          'Insiden Telah Diselesaikan',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade800,
          ),
        ),
        onPressed: () => Navigator.of(context).pop(),
      );
    }

    if (_currentIncident.isAcknowledged) {
      return ElevatedButton.icon(
        key: const Key('resolveIncidentBtn'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        icon: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : const Icon(Icons.verified_rounded, size: 22),
        label: Text(
          _isSubmitting ? 'Memproses...' : 'Situasi Terkendali',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        onPressed: _isSubmitting ? null : _showResolveConfirmationDialog,
      );
    }

    // Default: ACTIVE / REPORTED
    return ElevatedButton.icon(
      key: const Key('acknowledgeIncidentBtn'),
      style: ElevatedButton.styleFrom(
        backgroundColor: catColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
      icon: _isSubmitting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
          : const Icon(Icons.check_circle_rounded, size: 22),
      label: Text(
        _isSubmitting ? 'Memproses...' : 'Sedang Ditangani',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      onPressed: _isSubmitting ? null : _handleAcknowledge,
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool isHighlight = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon,
            size: 20,
            color: isHighlight ? AppTheme.primary : AppTheme.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: isHighlight ? 16 : 14,
                  fontWeight:
                      isHighlight ? FontWeight.bold : FontWeight.w600,
                  color: isHighlight ? AppTheme.primary : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatReportedTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    return '$day/$month/${dt.year} - $hour:$min WIB';
  }
}
