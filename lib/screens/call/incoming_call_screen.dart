import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import '../../widgets/cached_network_image_widget.dart';

/// 수신 전화 풀스크린 (미래지향적 디자인 + 고급 애니메이션)
class IncomingCallScreen extends StatefulWidget {
  final String callerName;
  final String callerNumber;
  final String? callerAvatar;
  final Uint8List? contactPhoto;
  final String channel;
  final String linkedid;
  final String receiverNumber;
  final String callType; // 'external' (외부 수신), 'internal' (내부 수신), 'unknown'
  final String? myCompanyName;
  final String? myExtension; // 실제 내 단말번호 (예: 1010)
  final String? myOutboundCid;
  final String? myExternalCidName;
  final String? myExternalCidNumber;
  final bool? isCallForwardEnabled; // 착신전환 활성화 여부
  final String? callForwardDestination; // 착신전환 번호
  final bool shouldPlaySound; // 벨소리 재생 여부
  final bool shouldVibrate; // 진동 여부
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const IncomingCallScreen({
    super.key,
    required this.callerName,
    required this.callerNumber,
    this.callerAvatar,
    this.contactPhoto,
    required this.channel,
    required this.linkedid,
    required this.receiverNumber,
    required this.callType,
    this.myCompanyName,
    this.myExtension, // 실제 내 단말번호 (예: 1010)
    this.myOutboundCid,
    this.myExternalCidName,
    this.myExternalCidNumber,
    this.isCallForwardEnabled,
    this.callForwardDestination,
    this.shouldPlaySound = true, // 기본값: 벨소리 켜짐
    this.shouldVibrate = true, // 기본값: 진동 켜짐
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with TickerProviderStateMixin {
  late AnimationController _rippleController;
  late AnimationController _glowController;
  late AnimationController _fadeController;
  late AnimationController _scaleController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  // 🎵 벨소리 재생 관련
  AudioPlayer? _audioPlayer;
  
  // 📳 진동 관련
  bool _isVibrating = false;
  
  // 🔥 Firestore 리스너 (방법 3: 실시간 취소 감지)
  StreamSubscription<DocumentSnapshot>? _callHistoryListener;
  
  // 🔒 초기 데이터 로드 플래그 (첫 번째 스냅샷은 무시)
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();

    // 🌊 파동 애니메이션 (연속 반복)
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    // ✨ 글로우 애니메이션 (펄스 효과)
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // 🎭 페이드 인 애니메이션
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    // 🔍 스케일 애니메이션
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutBack,
    );

    // 시작 애니메이션 실행
    _fadeController.forward();
    _scaleController.forward();
    
    // 🎵 벨소리 및 진동 시작
    _startRingtoneAndVibration();
    
    // 🔥 Firestore 리스너 시작 (방법 3: 실시간 취소 감지)
    _startCallHistoryListener();
  }

  @override
  void dispose() {
    if (kDebugMode) {
      debugPrint('🧹 [INCOMING-CALL] dispose() 시작 - 모든 리소스 정리');
    }
    
    // 🔥 Firestore 리스너 즉시 취소 (가장 먼저!)
    if (_callHistoryListener != null) {
      _callHistoryListener!.cancel();
      _callHistoryListener = null;
      if (kDebugMode) {
        debugPrint('✅ [INCOMING-CALL] Firestore 리스너 취소 완료');
      }
    }
    
    // 애니메이션 컨트롤러 정리
    _rippleController.dispose();
    _glowController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    
    // 벨소리/진동 중지
    _stopRingtoneAndVibration();
    
    if (kDebugMode) {
      debugPrint('✅ [INCOMING-CALL] dispose() 완료 - 모든 리소스 정리됨');
    }
    
    super.dispose();
  }
  
  /// 🔥 Firestore 리스너 시작 (방법 3: 실시간 취소 감지)
  /// 
  /// call_history 문서의 cancelled 필드를 실시간으로 감지하여
  /// 다른 기기에서 통화를 처리하면 현재 화면을 자동으로 닫습니다.
  /// 
  /// ⚠️ 안전 장치: 로그아웃 시에도 안전하게 작동하도록 오류 처리 강화
  void _startCallHistoryListener() {
    if (kDebugMode) {
      debugPrint('🔥 [FIRESTORE-LISTENER] call_history 리스너 시작');
      debugPrint('   linkedid: ${widget.linkedid}');
    }
    
    _callHistoryListener = FirebaseFirestore.instance
        .collection('call_history')
        .doc(widget.linkedid)
        .snapshots()
        .listen(
      (snapshot) {
        // ⚠️ 안전 장치 1: userId 체크 먼저 (로그아웃 시 null)
        // 초기 로드 체크보다 먼저 확인하여 로그아웃 즉시 감지
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          if (kDebugMode) {
            debugPrint('⚠️ [FIRESTORE-LISTENER] 사용자 로그아웃됨 - 리스너 취소 및 화면 닫기');
          }
          
          // 리스너 즉시 취소 (Firestore 오류 방지)
          _callHistoryListener?.cancel();
          _callHistoryListener = null;
          
          // 벨소리/진동 중지
          _stopRingtoneAndVibration();
          
          // 화면 닫기
          if (mounted) {
            Navigator.of(context).pop();
            if (kDebugMode) {
              debugPrint('✅ [FIRESTORE-LISTENER] 로그아웃으로 인한 화면 닫기 완료');
            }
          }
          return;
        }
        
        // 🔒 초기 로드 무시 (기존 데이터는 무시하고 변경사항만 감지)
        if (_isInitialLoad) {
          _isInitialLoad = false;
          if (kDebugMode) {
            debugPrint('🔥 [FIRESTORE-LISTENER] 초기 데이터 로드 - 무시');
            if (snapshot.exists) {
              final data = snapshot.data();
              final cancelled = data?['cancelled'] as bool? ?? false;
              debugPrint('   초기 cancelled 상태: $cancelled (무시됨)');
            }
          }
          return;
        }
        
        // ⚠️ 안전 장치 2: mounted 체크
        if (!mounted) {
          if (kDebugMode) {
            debugPrint('⚠️ [FIRESTORE-LISTENER] 위젯이 dispose됨 - 리스너 무시');
          }
          return;
        }
        
        if (snapshot.exists) {
          final data = snapshot.data();
          final cancelled = data?['cancelled'] as bool? ?? false;
          final cancelledBy = data?['cancelledBy'] as String? ?? 'unknown';
          
          if (cancelled) {
            if (kDebugMode) {
              debugPrint('🛑 [FIRESTORE-LISTENER] 통화 취소 감지! (변경 감지됨)');
              debugPrint('   linkedid: ${widget.linkedid}');
              debugPrint('   cancelledBy: $cancelledBy');
            }
            
            // 벨소리 및 진동 중지
            _stopRingtoneAndVibration();
            
            // 화면 닫기
            if (mounted) {
              Navigator.of(context).pop();
              
              if (kDebugMode) {
                debugPrint('✅ [FIRESTORE-LISTENER] IncomingCallScreen 닫힌');
              }
            }
          }
        }
      },
      onError: (error) {
        if (kDebugMode) {
          debugPrint('❌ [FIRESTORE-LISTENER] 오류: $error');
          debugPrint('   오류 타입: ${error.runtimeType}');
        }
        
        // ⚠️ 안전 장치 3: 리스너 취소 및 화면 닫기
        _callHistoryListener?.cancel();
        _callHistoryListener = null;
        _stopRingtoneAndVibration();
        
        if (mounted) {
          Navigator.of(context).pop();
          if (kDebugMode) {
            debugPrint('🔒 [FIRESTORE-LISTENER] 오류로 인해 리스너 취소 및 화면 닫힘');
          }
        }
      },
      cancelOnError: true, // 오류 발생 시 리스너 자동 취소
    );
  }

  /// 🎵 벨소리 및 진동 시작
  Future<void> _startRingtoneAndVibration() async {
    debugPrint('🔔 [RINGTONE] 벨소리/진동 시작');
    debugPrint('   - shouldPlaySound: ${widget.shouldPlaySound}');
    debugPrint('   - shouldVibrate: ${widget.shouldVibrate}');
    
    // 🎵 벨소리 재생 (설정이 켜져있을 때)
    if (widget.shouldPlaySound) {
      try {
        // Android: 시스템 기본 벨소리 사용
        if (Platform.isAndroid) {
          await FlutterRingtonePlayer().play(
            android: AndroidSounds.ringtone, // 안드로이드 기본 벨소리
            ios: IosSounds.glass, // iOS 플랫폼 파라미터 (Android에서는 무시됨)
            looping: true, // 반복 재생
            volume: 1.0, // 최대 볼륨
          );
          debugPrint('✅ [RINGTONE] 안드로이드 기본 벨소리 재생 시작 (반복 모드)');
        } 
        // iOS: audioplayers 사용 (포그라운드에서 더 안정적)
        else if (Platform.isIOS) {
          try {
            // AudioPlayer 초기화 (없으면 생성)
            _audioPlayer ??= AudioPlayer();
            
            // 오디오 모드 설정 (iOS에서 중요!)
            await _audioPlayer!.setReleaseMode(ReleaseMode.loop); // 반복 재생
            await _audioPlayer!.setVolume(1.0); // 최대 볼륨
            
            // 벨소리 파일 재생
            await _audioPlayer!.play(AssetSource('audio/ringtone.mp3'));
            
            debugPrint('✅ [RINGTONE] iOS 커스텀 벨소리 재생 시작 (audioplayers)');
          } catch (e) {
            debugPrint('❌ [RINGTONE] iOS audioplayers 재생 실패: $e');
            debugPrint('   → FlutterRingtonePlayer fallback 시도');
            
            // Fallback: FlutterRingtonePlayer 시도
            try {
              await FlutterRingtonePlayer().play(
                android: AndroidSounds.ringtone,
                ios: IosSounds.glass,
                looping: true,
                volume: 1.0,
              );
              debugPrint('✅ [RINGTONE] iOS FlutterRingtonePlayer fallback 성공');
            } catch (fallbackError) {
              debugPrint('❌ [RINGTONE] iOS fallback도 실패: $fallbackError');
            }
          }
        } 
        else {
          debugPrint('⚠️ [RINGTONE] 웹 플랫폼 - 시스템 벨소리 미지원');
        }
      } catch (e) {
        debugPrint('❌ [RINGTONE] 벨소리 재생 실패: $e');
      }
    } else {
      debugPrint('⏭️ [RINGTONE] 벨소리 비활성화 - 재생 건너뜀');
    }
    
    // 📳 진동 시작 (설정이 켜져있을 때)
    if (widget.shouldVibrate) {
      try {
        // 플랫폼 확인
        final platform = Platform.isIOS ? 'iOS' : Platform.isAndroid ? 'Android' : 'Web/Other';
        debugPrint('📱 [VIBRATION] 플랫폼: $platform');
        
        // 기기 진동 지원 확인
        final hasVibrator = await Vibration.hasVibrator();
        debugPrint('📳 [VIBRATION] 기기 진동 지원: $hasVibrator');
        
        if (hasVibrator == true) {
          _isVibrating = true;
          // 진동 패턴 시작 (반복)
          _vibrateRepeatedly();
          debugPrint('✅ [VIBRATION] 진동 시작 (반복 패턴)');
        } else if (hasVibrator == null) {
          // iOS에서 null을 반환하는 경우가 있음 - 그래도 시도
          debugPrint('⚠️ [VIBRATION] 진동 지원 확인 결과 null - 진동 시도');
          _isVibrating = true;
          _vibrateRepeatedly();
        } else {
          debugPrint('⚠️ [VIBRATION] 기기가 진동을 지원하지 않음');
        }
        
        // iOS 추가 정보
        if (Platform.isIOS) {
          debugPrint('💡 [iOS] 진동이 작동하지 않는다면 다음을 확인하세요:');
          debugPrint('   1. iOS 무음 모드 스위치가 꺼져 있는지 확인');
          debugPrint('   2. 설정 > 사운드 및 햅틱 > 진동 설정 확인');
          debugPrint('   3. 방해금지 모드가 비활성화되어 있는지 확인');
        }
      } catch (e) {
        debugPrint('❌ [VIBRATION] 진동 시작 실패: $e');
        debugPrint('   스택 트레이스: ${StackTrace.current}');
      }
    } else {
      debugPrint('⏭️ [VIBRATION] 진동 비활성화 - 건너뜀');
    }
  }
  
  /// 📳 반복 진동 실행
  Future<void> _vibrateRepeatedly() async {
    int vibrationCount = 0;
    while (_isVibrating && mounted) {
      try {
        vibrationCount++;
        if (vibrationCount % 10 == 1) {
          // 10회마다 한 번씩 로그 (너무 많은 로그 방지)
          debugPrint('📳 [VIBRATION] 진동 실행 중... (횟수: $vibrationCount)');
        }
        
        // 진동 패턴: 500ms 진동, 200ms 정지, 500ms 진동, 1000ms 정지, 반복
        await Vibration.vibrate(duration: 500);
        await Future.delayed(const Duration(milliseconds: 200));
        
        if (!_isVibrating || !mounted) break;
        
        await Vibration.vibrate(duration: 500);
        await Future.delayed(const Duration(milliseconds: 1000));
      } catch (e) {
        debugPrint('❌ [VIBRATION] 진동 오류 (횟수: $vibrationCount): $e');
        
        // iOS에서 특정 오류가 발생하면 짧은 진동으로 폴백
        if (Platform.isIOS && e.toString().contains('duration')) {
          debugPrint('💡 [iOS] duration 파라미터 오류 - 기본 진동으로 폴백');
          try {
            await Vibration.vibrate(); // duration 없이 기본 진동
            await Future.delayed(const Duration(milliseconds: 1000));
          } catch (fallbackError) {
            debugPrint('❌ [iOS] 폴백 진동도 실패: $fallbackError');
            break;
          }
        } else {
          break;
        }
      }
    }
    debugPrint('🛑 [VIBRATION] 진동 루프 종료 (총 횟수: $vibrationCount)');
  }
  
  /// 🛑 벨소리 및 진동 중지
  Future<void> _stopRingtoneAndVibration() async {
    debugPrint('🛑 [RINGTONE] 벨소리/진동 중지');
    
    // 🎵 벨소리 중지
    if (widget.shouldPlaySound) {
      try {
        // Android: 시스템 벨소리 중지
        if (Platform.isAndroid) {
          await FlutterRingtonePlayer().stop();
          debugPrint('✅ [RINGTONE] 안드로이드 시스템 벨소리 중지 완료');
        }
        // iOS: AudioPlayer + FlutterRingtonePlayer 모두 중지
        else if (Platform.isIOS) {
          // AudioPlayer 중지 (메인 방법)
          if (_audioPlayer != null) {
            await _audioPlayer!.stop();
            await _audioPlayer!.dispose();
            _audioPlayer = null;
            debugPrint('✅ [RINGTONE] iOS AudioPlayer 중지 완료');
          }
          
          // FlutterRingtonePlayer도 중지 (fallback이 실행되었을 경우 대비)
          try {
            await FlutterRingtonePlayer().stop();
            debugPrint('✅ [RINGTONE] iOS FlutterRingtonePlayer 중지 완료');
          } catch (e) {
            debugPrint('⚠️ [RINGTONE] FlutterRingtonePlayer 중지 실패 (무시): $e');
          }
        }
      } catch (e) {
        debugPrint('❌ [RINGTONE] 벨소리 중지 오류: $e');
      }
    }
    
    // 📳 진동 중지
    if (_isVibrating) {
      try {
        _isVibrating = false;
        await Vibration.cancel();
        debugPrint('✅ [VIBRATION] 진동 중지 완료');
      } catch (e) {
        debugPrint('❌ [VIBRATION] 진동 중지 오류: $e');
      }
    }
  }

  /// 전화 수락 애니메이션
  Future<void> _acceptCall() async {
    await _stopRingtoneAndVibration();
    await _scaleController.reverse();
    
    // 🛑 다른 기기의 알림 취소 (하이브리드 방식)
    _cancelOtherDevicesNotification('answered');
    
    widget.onAccept();
  }

  /// 전화 거절 애니메이션
  Future<void> _rejectCall() async {
    await _stopRingtoneAndVibration();
    await _fadeController.reverse();
    
    // 🛑 다른 기기의 알림 취소 (하이브리드 방식)
    _cancelOtherDevicesNotification('rejected');
    
    widget.onReject();
  }
  
  /// 🛑 다른 기기의 알림 취소 (하이브리드: Cloud Function + Firestore)
  /// 
  /// 방법 1 (FCM 푸시): Cloud Function을 호출하여 모든 기기에 취소 메시지 전송
  /// 방법 3 (Firestore): call_history 문서 업데이트로 실시간 리스너가 감지
  /// 
  /// ⚠️ 안전 장치: 로그아웃 등으로 userId가 없어도 안전하게 처리
  Future<void> _cancelOtherDevicesNotification(String action) async {
    try {
      if (kDebugMode) {
        debugPrint('🛑 [CANCEL] 다른 기기 알림 취소 시작');
        debugPrint('   linkedid: ${widget.linkedid}');
        debugPrint('   action: $action');
      }
      
      // ⚠️ 안전 장치: userId 체크 (로그아웃 시 null)
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (kDebugMode) {
          debugPrint('⚠️ [CANCEL] 사용자가 로그아웃됨 - 알림 취소 건너뜀');
          debugPrint('   → 로그아웃 시에는 다른 기기 취소가 불필요합니다');
        }
        return;
      }
      
      final userId = currentUser.uid;
      
      // 🔥 방법 1: Cloud Function 호출 (FCM 푸시)
      // 백그라운드/종료 상태의 기기에 즉시 전달
      try {
        if (kDebugMode) {
          debugPrint('📞 [CANCEL] Cloud Function 호출 시작...');
          debugPrint('   Function: cancelIncomingCallNotification');
          debugPrint('   linkedid: ${widget.linkedid}');
          debugPrint('   userId: $userId');
          debugPrint('   action: $action');
        }
        
        final functions = FirebaseFunctions.instanceFor(region: 'asia-northeast3');
        final result = await functions.httpsCallable('cancelIncomingCallNotification').call({
          'linkedid': widget.linkedid,
          'userId': userId,
          'action': action,
        }).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            if (kDebugMode) {
              debugPrint('⏱️ [CANCEL] Cloud Function 타임아웃 (10초)');
              debugPrint('   → Firestore 리스너(방법 3)가 대신 처리할 것입니다');
            }
            throw TimeoutException('Cloud Function timeout');
          },
        );
        
        if (kDebugMode) {
          debugPrint('✅ [CANCEL] Cloud Function 호출 완료 (FCM 푸시)');
          debugPrint('   Response: ${result.data}');
        }
      } on TimeoutException {
        if (kDebugMode) {
          debugPrint('⚠️ [CANCEL] Cloud Function 타임아웃 - Firestore 리스너가 처리합니다');
        }
      } on FirebaseFunctionsException catch (e) {
        if (kDebugMode) {
          debugPrint('❌ [CANCEL] Firebase Functions 오류:');
          debugPrint('   Code: ${e.code}');
          debugPrint('   Message: ${e.message}');
          debugPrint('   Details: ${e.details}');
          debugPrint('   → Firestore 리스너(방법 3)가 대신 처리할 것입니다');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ [CANCEL] Cloud Function 호출 오류: $e');
          debugPrint('   Type: ${e.runtimeType}');
          debugPrint('   → Firestore 리스너(방법 3)가 대신 처리할 것입니다');
        }
      }
      
      // 🔥 방법 3: Firestore 업데이트는 Cloud Function에서 자동으로 수행됨
      // (포그라운드 앱들이 실시간 리스너로 감지)
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [CANCEL] 알림 취소 오류: $e');
        debugPrint('   → 다른 기기의 Firestore 리스너가 처리할 수 있습니다');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: _buildGradientBackground(),
          child: SafeArea(
            child: Stack(
              children: [
                // 🌊 배경 파동 효과 (3개 레이어)
                _buildRippleEffect(),

                // 📱 메인 콘텐츠
                LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            children: [
                              const SizedBox(height: 20),

                              // 🏢 내 단말번호 정보 (상단)
                              _buildMyExtensionInfo(),

                              const SizedBox(height: 16),

                              // 📞 "수신 전화" 텍스트
                              _buildHeaderText(),

                              const Spacer(flex: 2),

                              // 👤 발신자 정보 (아바타 + 이름 + 번호)
                              ScaleTransition(
                                scale: _scaleAnimation,
                                child: _buildCallerInfo(),
                              ),

                              const Spacer(flex: 3),

                              // ✅ 확인 버튼 (아이콘+레이블)
                              _buildConfirmButtonWithIcon(),

                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 🎨 동적 그라데이션 배경 (통화 타입별 색상)
  BoxDecoration _buildGradientBackground() {
    // 통화 타입에 따른 색상 테마
    List<Color> gradientColors;
    
    if (widget.callType == 'external') {
      // 외부 수신: 따뜻한 오렌지-레드 그라데이션
      gradientColors = [
        const Color(0xFF1a1a2e), // 다크 네이비
        const Color(0xFF16213e), // 미디엄 네이비
        const Color(0xFF0f3460), // 딥 블루-퍼플
      ];
    } else if (widget.callType == 'internal') {
      // 내부 수신: 차분한 그린-블루 그라데이션
      gradientColors = [
        const Color(0xFF0d1b2a), // 다크 블루
        const Color(0xFF1b263b), // 미디엄 블루
        const Color(0xFF415a77), // 라이트 블루-그레이
      ];
    } else {
      // 기본: 기존 블루 그라데이션
      gradientColors = [
        const Color(0xFF0F2027), // 다크 블루
        const Color(0xFF203A43), // 미디엄 블루
        const Color(0xFF2C5364), // 라이트 블루
      ];
    }
    
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: gradientColors,
        stops: const [0.0, 0.5, 1.0],
      ),
    );
  }

  /// 🌊 파동 효과 (3개 레이어)
  Widget _buildRippleEffect() {
    return Positioned.fill(
      child: Center(
        child: AnimatedBuilder(
          animation: _rippleController,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                _buildRippleLayer(0.0, 0.3, 1.0),
                _buildRippleLayer(0.33, 0.25, 0.7),
                _buildRippleLayer(0.66, 0.20, 0.4),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 단일 파동 레이어
  Widget _buildRippleLayer(double delay, double baseOpacity, double maxScale) {
    final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _rippleController,
        curve: Interval(delay, 1.0, curve: Curves.easeOut),
      ),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final scale = 1.0 + (animation.value * maxScale);
        final opacity = baseOpacity * (1.0 - animation.value);

        return Transform.scale(
          scale: scale,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(opacity),
                width: 2,
              ),
            ),
          ),
        );
      },
    );
  }

  /// 🏢 내 단말번호 정보 (상단) - 통화 타입별 색상
  Widget _buildMyExtensionInfo() {
    // receiverNumber와 착신전환 정보가 모두 없으면 표시하지 않음
    final hasReceiverNumber = widget.receiverNumber.isNotEmpty;
    final hasCompanyName = widget.myCompanyName != null && widget.myCompanyName!.isNotEmpty;
    final hasCallForward = widget.isCallForwardEnabled == true && 
                           widget.callForwardDestination != null && 
                           widget.callForwardDestination!.isNotEmpty &&
                           widget.callForwardDestination != '00000000000';
    
    if (!hasReceiverNumber && !hasCompanyName) {
      return const SizedBox.shrink();
    }

    // 통화 타입별 색상
    Color borderColor;
    if (widget.callType == 'external') {
      borderColor = const Color(0xFFe76f51).withOpacity(0.4);
    } else if (widget.callType == 'internal') {
      borderColor = const Color(0xFF06d6a0).withOpacity(0.4);
    } else {
      borderColor = Colors.white.withOpacity(0.3);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      margin: const EdgeInsets.symmetric(horizontal: 40),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // 조직명 (첫 번째 줄)
          if (hasCompanyName)
            Text(
              widget.myCompanyName!,
              style: TextStyle(
                color: Colors.white.withOpacity(0.95),
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          
          // 간격 (조직명이 있을 때만)
          if (hasCompanyName && hasReceiverNumber)
            const SizedBox(height: 6),
          
          // 수신 단말번호 표시 (착신전환 상태에 따라 다르게 표시)
          if (hasReceiverNumber)
            _buildReceiverNumberDisplay(hasCallForward),
        ],
      ),
    );
  }

  /// 수신 단말번호 표시 (착신전환 상태에 따라 다르게 표시)
  Widget _buildReceiverNumberDisplay(bool hasCallForward) {
    if (hasCallForward) {
      // 착신전환 활성화: 단말번호 → 착신번호 (주황색)
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 단말번호
          Text(
            widget.receiverNumber,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 15,
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: 8),
          // 화살표 아이콘
          Icon(
            Icons.arrow_forward,
            color: const Color(0xFFFF9800),
            size: 16,
          ),
          const SizedBox(width: 8),
          // 착신전환 번호 (주황색)
          Text(
            widget.callForwardDestination!,
            style: const TextStyle(
              color: Color(0xFFFF9800),
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      );
    } else {
      // 착신전환 비활성화: 단말번호만 표시
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.phone_in_talk,
            color: Colors.white.withOpacity(0.8),
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            widget.receiverNumber,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 15,
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
            ),
          ),
        ],
      );
    }
  }

  /// 📞 헤더 텍스트 (통화 타입에 따라 변경 + 색상 구분)
  Widget _buildHeaderText() {
    // 통화 타입에 따른 헤더 텍스트 및 색상 결정
    String headerText;
    Color accentColor;
    IconData headerIcon;
    
    if (widget.callType == 'external') {
      headerText = '외부 수신 통화';
      accentColor = const Color(0xFFe76f51); // 따뜻한 오렌지
      headerIcon = Icons.call_received;
    } else if (widget.callType == 'internal') {
      headerText = '내부 수신 통화';
      accentColor = const Color(0xFF06d6a0); // 민트 그린
      headerIcon = Icons.phone_in_talk_rounded;
    } else {
      headerText = '수신 전화';
      accentColor = Colors.white;
      headerIcon = Icons.phone_in_talk_rounded;
    }
    
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: accentColor.withOpacity(0.4),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.3),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                headerIcon,
                color: accentColor.withOpacity(0.95),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                headerText,
                style: TextStyle(
                  color: accentColor.withOpacity(0.95),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 👤 발신자 정보 (통화 타입에 따라 순서 변경)
  Widget _buildCallerInfo() {
    // 외부 수신 통화: 외부발신 정보 먼저 표시 → 실제 발신자 정보
    // 내부 수신 통화: 실제 발신자 정보만 표시
    
    if (widget.callType == 'external') {
      return _buildExternalCallInfo();
    } else {
      return _buildInternalCallInfo();
    }
  }
  
  /// 외부 수신 통화 정보 (외부CID → 발신자)
  Widget _buildExternalCallInfo() {
    return Column(
      children: [
        // 👤 아바타 (글로우 효과)
        AnimatedBuilder(
          animation: _glowController,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.3 * _glowController.value),
                    blurRadius: 40 * _glowController.value,
                    spreadRadius: 10 * _glowController.value,
                  ),
                ],
              ),
              child: _buildAvatar(),
            );
          },
        ),

        const SizedBox(height: 40),

        // 📋 외부발신 정보 (externalCidName, externalCidNumber) - 먼저 표시
        if (widget.myExternalCidName != null && widget.myExternalCidName!.isNotEmpty ||
            widget.myExternalCidNumber != null && widget.myExternalCidNumber!.isNotEmpty) ...[
          
          // 외부발신 이름 (첫 번째 줄) - 발신자 이름과 동일한 크기 및 스타일
          if (widget.myExternalCidName != null && widget.myExternalCidName!.isNotEmpty)
            Text(
              widget.myExternalCidName!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                shadows: [
                  Shadow(
                    color: Colors.black38,
                    offset: Offset(0, 2),
                    blurRadius: 8,
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          
          // 간격 (이름과 번호 사이)
          if (widget.myExternalCidName != null && 
              widget.myExternalCidName!.isNotEmpty &&
              widget.myExternalCidNumber != null &&
              widget.myExternalCidNumber!.isNotEmpty)
            const SizedBox(height: 12),
          
          // 외부발신 번호 (두 번째 줄)
          if (widget.myExternalCidNumber != null && widget.myExternalCidNumber!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.25),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.call_made,
                    color: Colors.white.withOpacity(0.8),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.myExternalCidNumber!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 32), // 외부발신 정보와 발신자 정보 간격
        ],
        
        // 📝 실제 발신자 이름 (두 번째 표시)
        Text(
          widget.callerName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            shadows: [
              Shadow(
                color: Colors.black38,
                offset: Offset(0, 2),
                blurRadius: 8,
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 12),

        // 📞 전화번호 (세 번째 표시)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Text(
            widget.callerNumber,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 18,
              fontWeight: FontWeight.w500,
              letterSpacing: 2,
            ),
          ),
        ),
      ],
    );
  }
  
  /// 내부 수신 통화 정보 (발신자만)
  Widget _buildInternalCallInfo() {
    return Column(
      children: [
        // 👤 아바타 (글로우 효과)
        AnimatedBuilder(
          animation: _glowController,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.3 * _glowController.value),
                    blurRadius: 40 * _glowController.value,
                    spreadRadius: 10 * _glowController.value,
                  ),
                ],
              ),
              child: _buildAvatar(),
            );
          },
        ),

        const SizedBox(height: 40),

        // 📝 발신자 이름
        Text(
          widget.callerName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            shadows: [
              Shadow(
                color: Colors.black38,
                offset: Offset(0, 2),
                blurRadius: 8,
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 12),

        // 📞 전화번호
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Text(
            widget.callerNumber,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 18,
              fontWeight: FontWeight.w500,
              letterSpacing: 2,
            ),
          ),
        ),
      ],
    );
  }

  /// 👤 아바타 위젯
  Widget _buildAvatar() {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: widget.contactPhoto == null
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.shade400,
                  Colors.purple.shade400,
                ],
              )
            : null,
        color: widget.contactPhoto != null ? Colors.white : null,
        border: Border.all(
          color: Colors.white,
          width: 4,
        ),
      ),
      child: ClipOval(
        child: _buildAvatarContent(),
      ),
    );
  }

  /// 아바타 콘텐츠 (우선순위: 연락처 사진 > callerAvatar > app_logo)
  Widget _buildAvatarContent() {
    // 1순위: 연락처 사진
    if (widget.contactPhoto != null) {
      return Image.memory(
        widget.contactPhoto!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildAppLogo(),
      );
    }
    
    // 2순위: callerAvatar (URL)
    if (widget.callerAvatar != null && widget.callerAvatar!.isNotEmpty) {
      return CachedNetworkImageWidget(
        imageUrl: widget.callerAvatar!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildAppLogo(),
      );
    }
    
    // 3순위: app_logo (기본 이미지)
    return _buildAppLogo();
  }

  /// 기본 app_logo 아이콘
  Widget _buildAppLogo() {
    return Image.asset(
      'assets/icons/app_icon.png',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(),
    );
  }

  /// 최후 대안: 이니셜 아바타
  Widget _buildDefaultAvatar() {
    final initial = widget.callerName.isNotEmpty
        ? widget.callerName[0].toUpperCase()
        : '?';

    return Container(
      color: Colors.blue.shade400,
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 56,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// ✅ 확인 버튼 (아이콘+레이블)
  Widget _buildConfirmButtonWithIcon() {
    return Center(
      child: GestureDetector(
        onTap: () async {
          // Firestore 리스너 즉시 취소
          if (_callHistoryListener != null) {
            await _callHistoryListener!.cancel();
            _callHistoryListener = null;
          }
          
          // 벨소리/진동 중지
          await _stopRingtoneAndVibration();
          
          // 다른 기기의 알림 취소
          _cancelOtherDevicesNotification('answered');
          
          // 통화 기록 저장
          await _saveCallHistory();
          
          // 화면 닫기
          if (mounted) {
            Navigator.of(context).pop();
          }
        },
        child: Column(
          children: [
            // 버튼 (글로우 효과)
            AnimatedBuilder(
              animation: _glowController,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.5 * _glowController.value),
                        blurRadius: 30 * _glowController.value,
                        spreadRadius: 5 * _glowController.value,
                      ),
                    ],
                  ),
                  child: Container(
                    width: 75,
                    height: 75,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.blue.shade400,
                          Colors.blue.shade600,
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            // 레이블
            Text(
              '확인',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🎯 수락/거절 버튼 (기존 아이콘 버전 - 유지)
  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // ❌ 거절 버튼
          _buildActionButton(
            icon: Icons.call_end_rounded,
            color: Colors.red,
            label: '거절',
            onTap: _rejectCall,
          ),

          // ✅ 수락 버튼
          _buildActionButton(
            icon: Icons.call_rounded,
            color: Colors.green,
            label: '수락',
            onTap: _acceptCall,
            isPrimary: true,
          ),
        ],
      ),
    );
  }

  /// 단일 액션 버튼
  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          // 버튼 (글로우 효과)
          AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: isPrimary
                      ? [
                          BoxShadow(
                            color: color.withOpacity(0.5 * _glowController.value),
                            blurRadius: 30 * _glowController.value,
                            spreadRadius: 5 * _glowController.value,
                          ),
                        ]
                      : null,
                ),
                child: Container(
                  width: 75,
                  height: 75,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color,
                        color.withOpacity(0.8),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          // 레이블
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// 📝 통화 기록 저장
  Future<void> _saveCallHistory() async {
    try {
      // ⚠️ 안전 장치 1: 위젯이 dispose되었는지 확인
      if (!mounted) {
        if (kDebugMode) {
          debugPrint('⚠️ [SAVE-HISTORY] 위젯이 dispose됨 - 통화 기록 저장 건너뜀');
        }
        return;
      }
      
      // ⚠️ 안전 장치 2: 사용자 로그인 상태 확인
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (kDebugMode) {
          debugPrint('⚠️ [SAVE-HISTORY] 사용자 로그아웃됨 - 통화 기록 저장 건너뜀');
        }
        return;
      }
      
      final userId = currentUser.uid;

      final callHistoryData = {
        'userId': userId,
        'callerNumber': widget.callerNumber,
        'callerName': widget.callerName,
        'receiverNumber': widget.receiverNumber,
        'extensionUsed': widget.myExtension, // 실제 내 단말번호 (예: 1010)
        'channel': widget.channel,
        'linkedid': widget.linkedid,
        'callType': 'incoming',
        'callSubType': widget.callType, // 'external', 'internal', 'unknown'
        'status': 'confirmed',
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': DateTime.now(),
        
        // 내 단말번호 정보
        if (widget.myCompanyName != null) 'myCompanyName': widget.myCompanyName,
        if (widget.myOutboundCid != null) 'myOutboundCid': widget.myOutboundCid,
        if (widget.myExternalCidName != null) 'myExternalCidName': widget.myExternalCidName,
        if (widget.myExternalCidNumber != null) 'myExternalCidNumber': widget.myExternalCidNumber,
      };

      // ⚠️ 안전 장치 3: Firestore 쓰기 전 다시 한번 로그인 상태 확인
      if (FirebaseAuth.instance.currentUser == null) {
        if (kDebugMode) {
          debugPrint('⚠️ [SAVE-HISTORY] Firestore 쓰기 직전 로그아웃 감지 - 저장 중단');
        }
        return;
      }

      await FirebaseFirestore.instance
          .collection('call_history')
          .add(callHistoryData);

      if (kDebugMode) {
        debugPrint('✅ [SAVE-HISTORY] 통화 기록 저장 완료');
        debugPrint('  발신자: ${widget.callerName} (${widget.callerNumber})');
        debugPrint('  수신번호: ${widget.receiverNumber}');
        debugPrint('  타입: incoming (confirmed)');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [SAVE-HISTORY] 통화 기록 저장 실패: $e');
        // 로그아웃으로 인한 권한 오류는 조용히 무시
        if (e.toString().contains('permission') || e.toString().contains('unauthorized')) {
          debugPrint('   → 권한 오류 (로그아웃 가능성) - 무시');
        }
      }
    }
  }
}
