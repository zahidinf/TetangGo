import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Platform-safe Audio & Siren Controller for Security Standby
///
/// Limits and OS Constraints:
/// - iOS: Background execution limits prevent arbitrary continuous sound without
///   Audio Background Mode capability (`UIBackgroundModes: audio`) and active AVAudioSession category.
///   When app is in background or terminated, standard push notifications (APNs / FCM) with critical sound
///   must be used; in-app siren loops only play while app process is alive / foreground.
/// - Android: Background playback or full-screen intent requires Foreground Service
///   with type `mediaPlayback` or `specialUse`, plus `USE_FULL_SCREEN_INTENT` permission.
///   Cannot guarantee overriding Do Not Disturb (DND) or total silence mode across all OEM forks
///   (MIUI, EMUI, ColorOS, Samsung OneUI) without manual user-granted DND access policy permission.
/// - Desktop / Web / In-app: Beeps rhythmically through system alert channel or haptic pulse.
class SecuritySirenService {
  static final SecuritySirenService _instance =
      SecuritySirenService._internal();
  factory SecuritySirenService() => _instance;
  SecuritySirenService._internal();

  Timer? _loopTimer;
  bool _isPlaying = false;
  bool _isMuted = false;
  bool _isDisposed = false;

  bool get isPlaying => _isPlaying;
  bool get isMuted => _isMuted;

  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isMutedNotifier = ValueNotifier<bool>(false);

  /// Start pulsing siren sequence
  void startSiren() {
    if (_isDisposed || _isPlaying) return;
    _isPlaying = true;
    _isMuted = false;
    isPlayingNotifier.value = true;
    isMutedNotifier.value = false;

    _triggerPulse();
    _loopTimer = Timer.periodic(const Duration(milliseconds: 900), (timer) {
      if (!_isDisposed && !_isMuted && _isPlaying) {
        _triggerPulse();
      }
    });
  }

  void _triggerPulse() {
    try {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.heavyImpact();
    } catch (e) {
      debugPrint('Siren audio error: $e');
    }
  }

  /// Temporarily mute siren sound (e.g. while guard reads modal details)
  void muteSiren() {
    if (_isDisposed) return;
    _isMuted = true;
    isMutedNotifier.value = true;
  }

  /// Unmute siren sound
  void unmuteSiren() {
    if (_isDisposed) return;
    _isMuted = false;
    isMutedNotifier.value = false;
  }

  /// Stop siren completely (e.g. incident acknowledged or resolved)
  void stopSiren() {
    _isPlaying = false;
    _isMuted = false;
    _loopTimer?.cancel();
    _loopTimer = null;
    if (!_isDisposed) {
      isPlayingNotifier.value = false;
      isMutedNotifier.value = false;
    }
  }

  void dispose() {
    _isDisposed = true;
    stopSiren();
    isPlayingNotifier.dispose();
    isMutedNotifier.dispose();
  }
}
