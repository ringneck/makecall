import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';
import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'fcm_notification_service.dart';

/// FCM 알림 사운드 재생 서비스
/// 
/// 기기 승인, 착신전환 등 일반 FCM 알림에서 사운드를 재생합니다.
/// 수신 전화와 달리 짧은 알림음(3초)만 재생합니다.
class FCMNotificationSoundService {
  static AudioPlayer? _audioPlayer;
  static bool _isPlaying = false;

  /// 🎵 알림 사운드 재생 (3초 후 자동 중지)
  /// 
  /// [duration] - 재생 시간 (초), 기본값 3초
  static Future<void> playNotificationSound({int duration = 3}) async {
    if (_isPlaying) {
      if (kDebugMode) {
        debugPrint('⚠️ [FCM-SOUND] 이미 재생 중');
      }
      return;
    }

    // 🔔 사용자 알림 설정 확인
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (kDebugMode) {
        debugPrint('⚠️ [FCM-SOUND] 로그아웃 상태 - 사운드 재생 건너뜀');
      }
      return;
    }

    try {
      final settings = await FCMNotificationService().getUserNotificationSettings(currentUser.uid);
      final soundEnabled = settings?['soundEnabled'] ?? true;

      if (kDebugMode) {
        debugPrint('🔔 [FCM-SOUND] 사용자 알림 설정:');
        debugPrint('   - soundEnabled: $soundEnabled');
      }

      // 소리가 꺼져있으면 재생하지 않음
      if (!soundEnabled) {
        if (kDebugMode) {
          debugPrint('⏭️ [FCM-SOUND] 알림음이 비활성화되어 재생 건너뜀');
        }
        return;
      }

      _isPlaying = true;

      if (kDebugMode) {
        debugPrint('🔔 [FCM-SOUND] 알림 사운드 재생 시작');
      }

      // AudioPlayer 초기화
      _audioPlayer ??= AudioPlayer();

      // iOS: audioplayers 사용
      if (Platform.isIOS) {
        try {
          // 오디오 설정
          await _audioPlayer!.setReleaseMode(ReleaseMode.stop); // 반복 없음
          await _audioPlayer!.setVolume(1.0); // 최대 볼륨

          // 벨소리 파일 재생
          await _audioPlayer!.play(AssetSource('audio/ringtone.mp3'));

          if (kDebugMode) {
            debugPrint('✅ [FCM-SOUND] iOS 알림 사운드 재생');
          }

          // duration초 후 자동 중지
          Future.delayed(Duration(seconds: duration), () {
            stopNotificationSound();
          });
        } catch (e) {
          if (kDebugMode) {
            debugPrint('❌ [FCM-SOUND] iOS 재생 실패: $e');
          }
          _isPlaying = false;
        }
      }
      // Android: audioplayers 사용 (시스템 벨소리 대신)
      else if (Platform.isAndroid) {
        try {
          await _audioPlayer!.setReleaseMode(ReleaseMode.stop);
          await _audioPlayer!.setVolume(1.0);
          await _audioPlayer!.play(AssetSource('audio/ringtone.mp3'));

          if (kDebugMode) {
            debugPrint('✅ [FCM-SOUND] Android 알림 사운드 재생');
          }

          // duration초 후 자동 중지
          Future.delayed(Duration(seconds: duration), () {
            stopNotificationSound();
          });
        } catch (e) {
          if (kDebugMode) {
            debugPrint('❌ [FCM-SOUND] Android 재생 실패: $e');
          }
          _isPlaying = false;
        }
      } else {
        if (kDebugMode) {
          debugPrint('⚠️ [FCM-SOUND] 웹 플랫폼 - 사운드 미지원');
        }
        _isPlaying = false;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [FCM-SOUND] 재생 오류: $e');
      }
      _isPlaying = false;
    }
  }

  /// 🔇 알림 사운드 중지
  static Future<void> stopNotificationSound() async {
    if (!_isPlaying) return;

    try {
      await _audioPlayer?.stop();
      _isPlaying = false;

      if (kDebugMode) {
        debugPrint('🔇 [FCM-SOUND] 알림 사운드 중지');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [FCM-SOUND] 중지 오류: $e');
      }
    }
  }

  /// 📳 진동 재생 (1회)
  static Future<void> playVibration() async {
    // 🔔 사용자 알림 설정 확인
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (kDebugMode) {
        debugPrint('⚠️ [FCM-VIBRATION] 로그아웃 상태 - 진동 재생 건너뜀');
      }
      return;
    }

    try {
      final settings = await FCMNotificationService().getUserNotificationSettings(currentUser.uid);
      final vibrationEnabled = settings?['vibrationEnabled'] ?? true;

      if (kDebugMode) {
        debugPrint('📳 [FCM-VIBRATION] 사용자 알림 설정:');
        debugPrint('   - vibrationEnabled: $vibrationEnabled');
      }

      // 진동이 꺼져있으면 재생하지 않음
      if (!vibrationEnabled) {
        if (kDebugMode) {
          debugPrint('⏭️ [FCM-VIBRATION] 진동이 비활성화되어 재생 건너뜀');
        }
        return;
      }

      final hasVibrator = await Vibration.hasVibrator();

      if (hasVibrator == true) {
        // 짧은 진동 1회 (500ms)
        await Vibration.vibrate(duration: 500);

        if (kDebugMode) {
          debugPrint('📳 [FCM-VIBRATION] 진동 재생 (500ms)');
        }
      } else {
        if (kDebugMode) {
          debugPrint('⚠️ [FCM-VIBRATION] 기기가 진동을 지원하지 않음');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [FCM-VIBRATION] 진동 오류: $e');
      }
    }
  }

  /// 🎵 알림 사운드 + 진동 재생
  static Future<void> playNotificationWithVibration({int duration = 3}) async {
    await Future.wait([
      playNotificationSound(duration: duration),
      playVibration(),
    ]);
  }

  /// 🧹 리소스 정리
  static Future<void> dispose() async {
    await stopNotificationSound();
    await _audioPlayer?.dispose();
    _audioPlayer = null;
  }
}
