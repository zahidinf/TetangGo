import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../data/panic_repository.dart';
import 'panic_confirmation_dialog.dart';

class PanicButtonFab extends StatefulWidget {
  final UserModel user;
  final PanicRepository? repository;
  final VoidCallback? onAlarmSent;

  const PanicButtonFab({
    super.key,
    required this.user,
    this.repository,
    this.onAlarmSent,
  });

  @override
  State<PanicButtonFab> createState() => _PanicButtonFabState();
}

class _PanicButtonFabState extends State<PanicButtonFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _holdController;
  late final Animation<double> _progressAnimation;
  bool _isPressing = false;
  PanicRepository? _resolvedRepo;

  @override
  void initState() {
    super.initState();
    _holdController = AnimationController(
      vsync: this,
      duration:
          const Duration(milliseconds: 3000), // Exact 3-second hold requirement
    );

    _progressAnimation = CurvedAnimation(
      parent: _holdController,
      curve: Curves.linear,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.repository != null) {
      _resolvedRepo = widget.repository;
    } else {
      try {
        final dioClient = RepositoryProvider.of<DioClient>(context);
        _resolvedRepo = PanicRepository(dioClient);
      } catch (_) {
        // Fallback if not registered in RepositoryProvider
        _resolvedRepo = null;
      }
    }
  }

  @override
  void dispose() {
    _holdController.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    setState(() {
      _isPressing = true;
    });
    _holdController.forward(from: 0.0).then((_) {
      if (mounted && _isPressing) {
        _onLongPressComplete();
      }
    });
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_holdController.isAnimating) {
      _cancelHold(showToast: _holdController.value > 0.15);
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (_holdController.isAnimating) {
      _cancelHold(showToast: false);
    }
  }

  void _cancelHold({bool showToast = false}) {
    if (!_isPressing) return;

    setState(() {
      _isPressing = false;
    });
    _holdController.stop();
    _holdController.reset();

    if (showToast && mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Aktivasi dibatalkan: Tahan tombol selama 3 detik penuh untuk darurat.',
            style: TextStyle(fontSize: 12),
          ),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFF475569),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _onLongPressComplete() {
    setState(() {
      _isPressing = false;
    });
    _holdController.reset();

    final repo = widget.repository ?? _resolvedRepo;
    if (repo == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Layanan darurat belum siap.'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
      return;
    }

    PanicConfirmationDialog.show(
      context: context,
      user: widget.user,
      repository: repo,
      onAlarmSent: widget.onAlarmSent,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: AnimatedBuilder(
        animation: _progressAnimation,
        builder: (context, child) {
          final progress = _progressAnimation.value;
          final remainingSeconds = (3.0 * (1.0 - progress)).clamp(0.0, 3.0);

          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Countdown badge indicator while holding
              if (_isPressing)
                Positioned(
                  top: -38,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      'Tahan... ${remainingSeconds.toStringAsFixed(1)}s',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

              // Circular progress ring around the button
              SizedBox(
                width: 76,
                height: 76,
                child: CircularProgressIndicator(
                  value: _isPressing ? progress : 0.0,
                  strokeWidth: 4.5,
                  backgroundColor: _isPressing
                      ? AppTheme.danger.withValues(alpha: 0.25)
                      : Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFFFEF08A), // Bright Yellow highlight during hold
                  ),
                ),
              ),

              // Red Glowing Panic Button
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [
                      Color(0xFFF87171),
                      AppTheme.danger,
                      Color(0xFF991B1B),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.danger.withValues(
                        alpha: _isPressing ? 0.6 : 0.35,
                      ),
                      blurRadius: _isPressing ? 16 : 8,
                      spreadRadius: _isPressing ? 4 : 1,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isPressing
                            ? Icons.crisis_alert_rounded
                            : Icons.emergency_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'PANIC',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
