import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io' show Platform;
import 'dart:async'; // TimeoutException 사용을 위해 필요
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart'; // 진동 기능
import 'package:audioplayers/audioplayers.dart'; // 사운드 재생
import '../main.dart' show navigatorKey; // GlobalKey for Navigation
import 'dcmiws_service.dart';
import 'auth_service.dart';
import 'database_service.dart';
import 'package:provider/provider.dart';
import '../utils/dialog_utils.dart';

// 🔧 Phase 1, 2, 3, 4, 5 Refactoring: FCM 모듈화
import 'fcm/fcm_platform_utils.dart';
import 'fcm/fcm_token_manager.dart';
import 'fcm/fcm_device_approval_service.dart';
import '../exceptions/max_device_limit_exception.dart';
import 'fcm/fcm_message_handler.dart';
import 'fcm/fcm_notification_service.dart';
import 'fcm/fcm_incoming_call_handler.dart';
import 'fcm/fcm_web_config.dart'; // 🔧 Phase 5: Web FCM 설정 분리

/// 플랫폼 체크 헬퍼 (웹 플랫폼 안전 처리)
bool get _isIOS => !kIsWeb && Platform.isIOS;
bool get _isAndroid => !kIsWeb && Platform.isAndroid;

/// FCM(Firebase Cloud Messaging) 서비스
/// 
/// 다중 기기 로그인 지원 기능 포함:
/// - 새 기기에서 로그인 시 기존 기기에 승인 요청
/// - FCM 메시지를 통한 기기 승인/거부 알림
/// - 여러 기기에서 동시 로그인 가능
class FCMService {
  // 🔧 싱글톤 패턴
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseService _databaseService = DatabaseService();
  
  // 🔧 Phase 1, 2, 3, 4, 5 Refactoring: 모듈화된 유틸리티 클래스
  final FCMPlatformUtils _platformUtils = FCMPlatformUtils();
  final FCMTokenManager _tokenManager = FCMTokenManager();
  final FCMDeviceApprovalService _approvalService = FCMDeviceApprovalService();
  final FCMMessageHandler _messageHandler = FCMMessageHandler();
  final FCMNotificationService _notificationService = FCMNotificationService();
  final FCMIncomingCallHandler _incomingCallHandler = FCMIncomingCallHandler();
  final FCMWebConfig _webConfig = FCMWebConfig(); // 🔧 Phase 5: 웹 FCM 설정
  
  String? _fcmToken;
  static BuildContext? _context; // 전역 BuildContext 저장
  static Function()? _onForceLogout; // 강제 로그아웃 콜백
  static AuthService? _authService; // AuthService 참조
  
  // 🔒 중복 초기화 방지
  static bool _isInitializing = false;
  static String? _initializedUserId;
  static StreamSubscription<String>? _tokenRefreshSubscription;
  // 🔧 Phase 1: _lastSavedToken, _lastSaveTime은 FCMTokenManager로 이동
  
  // 🔒 초기화 완료를 기다리기 위한 Completer
  static Completer<void>? _initializationCompleter;
  
  // 🎨 승인 대기 다이얼로그 관련
  String? _currentApprovalRequestId;
  String? _currentUserId;
  
  // 🔒 중복 메시지 처리 방지
  static final Set<String> _processedMessageIds = {};
  static final Set<String> _processingApprovalIds = {}; // 처리 중인 승인 요청 ID
  static String? _currentDisplayedApprovalId; // 현재 표시 중인 다이얼로그의 승인 요청 ID
  
  // 🔧 Private 생성자: 콜백 설정을 가장 먼저 수행 (iOS Method Channel 호출 대응)
  FCMService._internal() {
    _setupMessageHandlerCallbacks();
  }
  
  /// FCM 토큰 가져오기
  String? get fcmToken => _fcmToken;
  
  /// BuildContext 설정 (main.dart에서 호출)
  static void setContext(BuildContext context) {
    _context = context;
    // 🔧 Phase 2, 3, 4: 모듈에도 Context 전달
    FCMDeviceApprovalService.setContext(context);
    FCMNotificationService.setContext(context);
    FCMIncomingCallHandler.setContext(context);
  }
  
  /// 강제 로그아웃 콜백 설정
  static void setForceLogoutCallback(Function() callback) {
    _onForceLogout = callback;
  }
  
  /// 현재 표시 중인 승인 다이얼로그 ID 설정
  static void setCurrentDisplayedApprovalId(String? approvalRequestId) {
    _currentDisplayedApprovalId = approvalRequestId;
    if (kDebugMode) {
      debugPrint('🔒 [FCM] _currentDisplayedApprovalId 설정: $approvalRequestId');
    }
  }
  
  /// AuthService 설정 (승인 대기 상태 변경용)
  static void setAuthService(AuthService authService) {
    _authService = authService;
    // 🔧 Phase 2: 모듈에도 AuthService 전달
    FCMDeviceApprovalService.setAuthService(authService);
  }
  
  /// ✅ OPTION 1: iOS Method Channel에서 호출하는 공개 메서드
  /// RemoteMessage를 받아서 포그라운드/백그라운드 핸들러로 전달
  /// 
  /// 🔧 Phase 2: FCMMessageHandler 사용
  Future<void> handleRemoteMessage(RemoteMessage message, {required bool isForeground}) async {
    
    // 🔧 안전장치: 콜백이 설정되지 않았다면 지금 설정
    if (_messageHandler.onDeviceApprovalRequest == null) {
      _setupMessageHandlerCallbacks();
    }
    
    if (isForeground) {
      _messageHandler.handleForegroundMessage(message);
    } else {
      _messageHandler.handleMessageOpenedApp(message);
    }
  }
  
  /// 🔧 Phase 2, 3, 4: 메시지 핸들러 콜백 설정
  void _setupMessageHandlerCallbacks() {
    _messageHandler.onForceLogout = _handleForceLogout;
    _messageHandler.onDeviceApprovalRequest = (message) => _approvalService.handleDeviceApprovalRequest(message);
    _messageHandler.onDeviceApprovalResponse = _handleDeviceApprovalResponse;
    _messageHandler.onDeviceApprovalCancelled = _handleDeviceApprovalCancelled;
    _messageHandler.onIncomingCallCancelled = (message) => _incomingCallHandler.handleIncomingCallCancelled(message);
    _messageHandler.onIncomingCall = (message) => _incomingCallHandler.handleIncomingCallFCM(message);
    _messageHandler.onGeneralNotification = (message) {
      // 🔧 Phase 3: 일반 알림 표시를 FCMNotificationService로 위임
      if (kIsWeb) {
        _notificationService.showWebNotification(message);
      } else if (_isAndroid) {
        _notificationService.showAndroidNotification(message);
      } else if (_isIOS) {
        _notificationService.showIOSNotification(message);
      }
    };
  }
  
  /// FCM 초기화
  Future<void> initialize(String userId) async {
    try {
      
      // 🔒 중복 초기화 방지 체크
      if (_isInitializing) {
        if (_initializationCompleter != null) {
          try {
            await _initializationCompleter!.future;
          } catch (e) {
            rethrow; // 승인 실패 시 두 번째 호출도 실패해야 함
          }
        }
        return;
      }
      
      if (_initializedUserId == userId && _fcmToken != null) {
        return;
      }
      _isInitializing = true;
      _initializationCompleter = Completer<void>();
      
      // ✅ STEP 1: 메시지 리스너를 가장 먼저 등록! (메시지 누락 방지)
      
      // 🔧 Phase 2: 메시지 핸들러 콜백 설정
      _setupMessageHandlerCallbacks();
      
      // 포그라운드 메시지 리스너 (🔧 Phase 2: FCMMessageHandler 사용)
      FirebaseMessaging.onMessage.listen(_messageHandler.handleForegroundMessage);
      
      // 백그라운드/종료 상태에서 알림 클릭 시 처리 (🔧 Phase 2: FCMMessageHandler 사용)
      FirebaseMessaging.onMessageOpenedApp.listen(_messageHandler.handleMessageOpenedApp);
      
      // 앱이 종료된 상태에서 알림 클릭으로 시작된 경우 처리
      _messaging.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          _messageHandler.handleMessageOpenedApp(message);
        }
      });
      
      
      // Android 로컬 알림 플러그인 초기화 및 알림 채널 생성
      if (_isAndroid) {
        
        final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
            FlutterLocalNotificationsPlugin();
        
        // Android 초기화 설정
        const AndroidInitializationSettings initializationSettingsAndroid =
            AndroidInitializationSettings('@mipmap/ic_launcher');
        
        const InitializationSettings initializationSettings =
            InitializationSettings(android: initializationSettingsAndroid);
        
        await flutterLocalNotificationsPlugin.initialize(
          initializationSettings,
          onDidReceiveNotificationResponse: (NotificationResponse response) {
            debugPrint('🔔 [FCM] 로컬 알림 클릭됨: ${response.payload}');
            // 알림 클릭 시 추가 동작 가능
          },
        );
        
        
        // 알림 채널 생성 (4가지 조합: 소리/진동 ON/OFF)
        
        final androidPlugin = flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        
        if (androidPlugin != null) {
          // 1️⃣ 소리 O + 진동 O (기본)
          // 🔔 수신전화 전용 채널 (최고 우선순위)
          const incomingCallChannel = AndroidNotificationChannel(
            'incoming_call_channel',
            '수신전화 알림',
            description: '수신전화 풀스크린 알림',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            showBadge: true,
          );
          await androidPlugin.createNotificationChannel(incomingCallChannel);
          
          // 📞 착신전환 전용 채널 (높은 우선순위)
          const callForwardChannel = AndroidNotificationChannel(
            'call_forward_channel',
            '착신전환 알림',
            description: '착신전환 설정 변경 알림',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
            showBadge: true,
          );
          await androidPlugin.createNotificationChannel(callForwardChannel);
          
          // 1️⃣ 소리 O + 진동 O (일반 알림)
          const channel1 = AndroidNotificationChannel(
            'notification_sound_on_vibration_on',
            'Notifications with Sound and Vibration',
            description: 'Notifications with both sound and vibration enabled',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
          );
          await androidPlugin.createNotificationChannel(channel1);
          
          // 2️⃣ 소리 X + 진동 O
          const channel2 = AndroidNotificationChannel(
            'notification_sound_off_vibration_on',
            'Notifications with Vibration Only',
            description: 'Notifications with vibration only (no sound)',
            importance: Importance.high,
            playSound: false,
            enableVibration: true,
          );
          await androidPlugin.createNotificationChannel(channel2);
          
          // 3️⃣ 소리 O + 진동 X
          const channel3 = AndroidNotificationChannel(
            'notification_sound_on_vibration_off',
            'Notifications with Sound Only',
            description: 'Notifications with sound only (no vibration)',
            importance: Importance.high,
            playSound: true,
            enableVibration: false,
          );
          await androidPlugin.createNotificationChannel(channel3);
          
          // 4️⃣ 소리 X + 진동 X
          const channel4 = AndroidNotificationChannel(
            'notification_sound_off_vibration_off',
            'Silent Notifications',
            description: 'Notifications without sound and vibration',
            importance: Importance.high,
            playSound: false,
            enableVibration: false,
          );
          await androidPlugin.createNotificationChannel(channel4);
          
        }
      }
      
      // 알림 권한 요청
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      
      
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        
        // FCM 토큰 가져오기
        
        if (kIsWeb) {
          // 🔧 Phase 5: FCMWebConfig 클래스 사용
          try {
            _fcmToken = await _webConfig.getWebFCMToken();
            if (_fcmToken == null) {
              // 웹에서 FCM 토큰은 없지만, 웹 기기 정보는 저장해야 함
              if (kDebugMode) {
                debugPrint('⚠️ [FCM-WEB] FCM 토큰 없음 - 더미 토큰으로 기기 정보 저장');
              }
              // 웹 플랫폼용 더미 토큰 생성 (fcm_tokens에 기기 등록용)
              _fcmToken = 'web_dummy_token_${DateTime.now().millisecondsSinceEpoch}';
            }
          } catch (e) {
            // 웹에서 FCM 실패 시에도 더미 토큰으로 기기 정보 저장
            if (kDebugMode) {
              debugPrint('⚠️ [FCM-WEB] FCM 에러 발생 - 더미 토큰으로 기기 정보 저장: $e');
            }
            _fcmToken = 'web_dummy_token_${DateTime.now().millisecondsSinceEpoch}';
          }
        } else {
          
          // iOS 전용: APNs 토큰 확인 (재시도 로직 포함)
          if (_isIOS) {
            
            String? apnsToken;
            int retryCount = 0;
            const maxRetries = 5;
            
            // APNs 토큰이 준비될 때까지 재시도
            while (apnsToken == null && retryCount < maxRetries) {
              apnsToken = await _messaging.getAPNSToken();
              
              if (apnsToken == null) {
                retryCount++;
                await Future.delayed(const Duration(milliseconds: 500));
              }
            }
            
            if (apnsToken != null) {
              // ignore: avoid_print
              print('✅ [FCM-INIT] APNs 토큰 취득 성공');
            } else {
              // ignore: avoid_print
              print('⚠️  [FCM-INIT] APNs 토큰 없음 - FCM 토큰 취득 시도는 계속');
              // 🔧 TEMP FIX: APNs 토큰이 없어도 FCM 토큰 취득 시도
              // return; // ← 주석 처리!
            }
          }
          
          _fcmToken = await _messaging.getToken();
          // ignore: avoid_print
          print('🔑 [FCM-INIT] FCM 토큰 취득 시도: ${_fcmToken != null ? "성공 (${_fcmToken!.substring(0, 20)}...)" : "실패 (null)"}');
        }
        
        if (_fcmToken != null) {
          // ignore: avoid_print
          print('💾 [FCM-INIT] FCM 토큰 저장 시작 (userId: $userId)');
          
          // Firestore에 토큰 저장 (🔧 Phase 1: FCMTokenManager 사용)
          await _saveFCMTokenWithApproval(userId, _fcmToken!);
          
          // ignore: avoid_print
          print('✅ [FCM-INIT] FCM 토큰 저장 완료');
          
          // 🔒 토큰 갱신 리스너 중복 등록 방지
          if (_tokenRefreshSubscription == null) {
            _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((newToken) {
              
              _fcmToken = newToken;
              // 🔧 Phase 1: 리팩토링된 메서드 사용
              _saveFCMTokenWithApproval(userId, newToken);
            });
          } else {
          }
          
          // ℹ️ 메시지 리스너는 이미 초기화 최상단에서 등록 완료됨
          // 백그라운드 메시지 핸들러는 main.dart에서 설정
          
        } else {
          // ignore: avoid_print
          print('⚠️ [FCM-INIT] FCM 토큰이 null입니다 - 토큰 저장 스킵');
          if (_isIOS) {
            // ignore: avoid_print
            print('   iOS 플랫폼: APNs 토큰 확인 필요');
          }
        }
      } else {
        // ignore: avoid_print
        print('⚠️ [FCM-INIT] 알림 권한이 거부되었습니다');
        // ignore: avoid_print
        print('   권한 상태: ${settings.authorizationStatus}');
      }
    } on MaxDeviceLimitException catch (e, stackTrace) {
      // 🚫 CRITICAL: 최대 기기 수 초과 - 반드시 상위로 전파
      // ignore: avoid_print
      print('🚫 [FCM-INIT] 최대 기기 수 초과 예외 감지 - 상위로 전파');
      
      // 🔒 CRITICAL: FCM 상태 완전 리셋 (재시도 시 다시 토큰 저장 시도하도록)
      _fcmToken = null;
      _initializedUserId = null;
      _isInitializing = false;
      _initializationCompleter = null;
      
      // ignore: avoid_print
      print('🧹 [FCM-INIT] FCM 상태 리셋 완료 - 다음 로그인 시 재시도 가능');
      
      rethrow;
      
    } catch (e, stackTrace) {
      
      // 🔒 CRITICAL: 기기 승인 관련 오류는 반드시 상위로 전파
      final isApprovalError = e.toString().contains('Device approval') || 
                               e.toString().contains('denied') || 
                               e.toString().contains('timeout');
      
      if (isApprovalError) {
        
        // 🔒 CRITICAL: 승인 실패 시 Completer에 에러를 전달
        // 이렇게 하면 대기 중인 다른 초기화 호출들도 같은 에러를 받음
        _isInitializing = false;
        if (_initializationCompleter != null && !_initializationCompleter!.isCompleted) {
          _initializationCompleter!.completeError(e, stackTrace);
        }
        
        rethrow;
      }
      
      // 일반적인 FCM 초기화 오류는 무시 (앱은 계속 실행)
    } finally {
      // 🔓 초기화 완료 - 잠금 해제
      _isInitializing = false;
      
      // 🔓 초기화 완료 알림 (대기 중인 호출들에게)
      // 승인 실패의 경우 위에서 이미 completeError 호출됨
      if (_initializationCompleter != null && !_initializationCompleter!.isCompleted) {
        _initializationCompleter!.complete();
      }
      
      // ✅ 성공 시에만 userId 저장
      if (_fcmToken != null) {
        _initializedUserId = userId;
        
        // 🚀 고급 패턴: FCM 초기화 완료 이벤트 발행 (AuthService에 알림)
        if (_authService != null) {
          _authService!.setFcmInitialized(true);
          if (kDebugMode) {
            debugPrint('🚀 [FCM] 초기화 완료 이벤트 발행 → AuthService 알림');
          }
        }
      }
    }
  }
  
  /// 🔧 Phase 1 Refactoring: FCM 토큰 저장 및 승인 로직 래퍼
  /// 
  /// FCMTokenManager를 사용하여 토큰 저장 후 필요 시 승인 프로세스 실행
  Future<void> _saveFCMTokenWithApproval(String userId, String token) async {
    try {
      // 🔧 Phase 1: FCMTokenManager 사용하여 토큰 저장
      final (needsApproval, otherDevices) = await _tokenManager.saveFCMToken(
        userId: userId,
        token: token,
      );
      
      // 승인이 필요한 경우 승인 프로세스 실행
      if (needsApproval && otherDevices.isNotEmpty) {
        final deviceId = await _platformUtils.getDeviceId();
        final deviceName = await _platformUtils.getDeviceName();
        final platformLower = _platformUtils.getPlatformName();
        
        // 🔑 CRITICAL: 플랫폼 이름을 대문자로 변환 (일관성 유지)
        String platform;
        if (platformLower == 'android') {
          platform = 'Android';
        } else if (platformLower == 'ios') {
          platform = 'iOS';
        } else {
          platform = platformLower; // web, unknown 등
        }
        
        
        // ✅ 승인 요청 전송 및 승인 대기 (🔧 Phase 2: FCMDeviceApprovalService 사용)
        final approvalRequestId = await _approvalService.sendDeviceApprovalRequestAndWait(
          userId: userId,
          newDeviceId: deviceId,
          newDeviceName: deviceName,
          newPlatform: platform,
          newDeviceToken: token,
        );
        
        if (approvalRequestId == null) {
          throw Exception('Device approval request failed');
        }
        
        
        // 🎨 승인 요청 정보 저장
        _currentApprovalRequestId = approvalRequestId;
        _currentUserId = userId;
        _approvalService.setApprovalRequestInfo(approvalRequestId, userId);
        
        // 🔐 AuthService에 승인 대기 상태 설정
        if (_authService != null) {
          _authService!.setWaitingForApproval(true, approvalRequestId: approvalRequestId);
        }
        
        // 승인 대기 (최대 5분) - 🔧 Phase 2: FCMDeviceApprovalService 사용
        final approved = await _approvalService.waitForDeviceApproval(approvalRequestId);
        
        // 🔐 AuthService 승인 대기 상태 해제
        if (_authService != null) {
          _authService!.setWaitingForApproval(false);
        }
        
        // 🎨 승인 요청 정보 초기화
        _currentApprovalRequestId = null;
        _currentUserId = null;
        _approvalService.setApprovalRequestInfo(null, null);
        
        
        if (!approved) {
          throw Exception('Device approval denied or timeout');
        }
        
      }
      
    } on MaxDeviceLimitException catch (e) {
      // 🚫 최대 기기 수 초과 처리
      // ignore: avoid_print
      print('🚫 [FCM] 최대 기기 수 초과: ${e.toString()}');
      // ignore: avoid_print
      print('🚫 [FCM] 상세 정보:');
      // ignore: avoid_print
      print(e.getDetailedMessage());
      
      // ⚠️ 중요: Exception을 그대로 던져서 UI에서 감지하도록 함
      rethrow;
      
    } catch (e, stackTrace) {
      
      // 🔒 CRITICAL: 승인 관련 오류는 반드시 상위로 전파하여 로그인 차단
      if (e.toString().contains('Device approval') || 
          e.toString().contains('denied') || 
          e.toString().contains('timeout')) {
        rethrow;
      }
      
      // 일반적인 토큰 저장 오류는 무시 (로그인은 계속 진행)
    }
  }
  
  /// ⚠️ DEPRECATED: 레거시 메서드 - FCMTokenManager.saveFCMToken() 사용
  /// 
  /// 이 메서드는 하위 호환성을 위해 유지되며, 내부적으로 _saveFCMTokenWithApproval()을 호출합니다.
  @Deprecated('Use _saveFCMTokenWithApproval() instead')
  Future<void> _saveFCMToken(String userId, String token) async {
    await _saveFCMTokenWithApproval(userId, token);
  }
  
  /// 기존 기기에 기기 승인 요청 FCM 메시지 전송 및 승인 대기
  /// 
  /// 새 기기에서 로그인 시도 시 기존 기기에 승인 요청을 보내고 승인을 기다립니다.
  /// 
  /// Returns: approval request ID (성공 시) 또는 null (실패 시)
  Future<String?> _sendDeviceApprovalRequestAndWait({
    required String userId,
    required String newDeviceId,
    required String newDeviceName,
    required String newPlatform,
    required String newDeviceToken,
  }) async {
    try {
      return await _sendDeviceApprovalRequest(
        userId: userId,
        newDeviceId: newDeviceId,
        newDeviceName: newDeviceName,
        newPlatform: newPlatform,
        newDeviceToken: newDeviceToken,
      );
    } catch (e) {
      debugPrint('❌ [FCM-APPROVAL] 승인 요청 전송 실패: $e');
      return null;
    }
  }
  
  /// ⚠️ DEPRECATED: Use FCMDeviceApprovalService.sendDeviceApprovalRequestAndWait() instead
  /// This method has been moved to FCMDeviceApprovalService for better modularity.
  @Deprecated('Use FCMDeviceApprovalService.sendDeviceApprovalRequestAndWait()')
  Future<String> _sendDeviceApprovalRequest({
    required String userId,
    required String newDeviceId,
    required String newDeviceName,
    required String newPlatform,
    required String newDeviceToken,
  }) async {
    // Delegate to new modular service
    final approvalRequestId = await _approvalService.sendDeviceApprovalRequestAndWait(
      userId: userId,
      newDeviceId: newDeviceId,
      newDeviceName: newDeviceName,
      newPlatform: newPlatform,
      newDeviceToken: newDeviceToken,
    );
    return approvalRequestId ?? '';
  }
  
  /// ⚠️ DEPRECATED: Use FCMDeviceApprovalService.waitForDeviceApproval() instead
  /// This method has been moved to FCMDeviceApprovalService for better modularity.
  @Deprecated('Use FCMDeviceApprovalService.waitForDeviceApproval()')
  Future<bool> _waitForDeviceApproval(String approvalRequestId) async {
    // Delegate to new modular service
    return await _approvalService.waitForDeviceApproval(approvalRequestId);
  }
  
  /// ⚠️ DEPRECATED: Use FCMMessageHandler.handleForegroundMessage() instead
  /// This method has been moved to FCMMessageHandler for better modularity.
  @Deprecated('Use FCMMessageHandler.handleForegroundMessage()')
  void _handleForegroundMessage(RemoteMessage message) {
    // Delegate to new modular service
    _messageHandler.handleForegroundMessage(message);
  }
  
  /// ⚠️ DEPRECATED: Use FCMMessageHandler.handleMessageOpenedApp() instead
  /// This method has been moved to FCMMessageHandler for better modularity.
  @Deprecated('Use FCMMessageHandler.handleMessageOpenedApp()')
  void _handleMessageOpenedApp(RemoteMessage message) {
    // Delegate to new modular service
    _messageHandler.handleMessageOpenedApp(message);
  }
  
  /// FCM 수신 전화 메시지 처리
  /// 
  /// ⚠️ DEPRECATED: Use FCMIncomingCallHandler.handleIncomingCallFCM() instead
  /// This method has been moved to FCMIncomingCallHandler for better modularity.
  @Deprecated('Use FCMIncomingCallHandler.handleIncomingCallFCM()')
  Future<void> _handleIncomingCallFCM(RemoteMessage message) async {
    // Delegate to new modular service
    await _incomingCallHandler.handleIncomingCallFCM(message);
  }
  
  /// ⚠️ DEPRECATED: Use FCMIncomingCallHandler.waitForContextAndShowIncomingCall() instead
  /// This method has been moved to FCMIncomingCallHandler for better modularity.
  @Deprecated('Use FCMIncomingCallHandler.waitForContextAndShowIncomingCall()')
  Future<void> _waitForContextAndShowIncomingCall(RemoteMessage message) async {
    // Delegate to new modular service
    await _incomingCallHandler.waitForContextAndShowIncomingCall(message);
  }
  
  /// 🔧 NEW: Context 준비 대기 후 기기 승인 다이얼로그 표시
  Future<void> _waitForContextAndShowApprovalDialog(RemoteMessage message) async {
    
    // 🔧 FIX: iOS에서는 앱이 active 상태가 될 때까지 충분히 대기
    // 1. 먼저 500ms 대기 (앱 전환 시작 시간)
    await Future.delayed(const Duration(milliseconds: 500));
    
    // 2. 재시도 로직 시작
    _retryShowApprovalDialog(message, 0);
  }
  
  /// 🔧 재시도 로직 (iOS 앱 전환 지연 대응)
  Future<void> _retryShowApprovalDialog(RemoteMessage message, int attempt) async {
    const maxAttempts = 50; // 🔧 5초로 증가 (100ms * 50)
    
    if (attempt >= maxAttempts) {
      print('');
      return;
    }
    
    final context = _context ?? navigatorKey.currentContext;
    
    
    if (context != null && context.mounted) {
      print('');
      
      // 🔧 FIX: iOS에서는 이미 Context가 준비되어 있으므로 직접 호출
      
      // 기기 승인 요청 메시지 처리
      _handleDeviceApprovalRequest(message);
      return;
    }
    
    await Future.delayed(const Duration(milliseconds: 100));
    _retryShowApprovalDialog(message, attempt + 1);
  }
  
  /// 강제 로그아웃 메시지 처리 (레거시 - 하위 호환성 유지)
  /// 
  /// 다른 기기에서 로그인했을 때 현재 세션을 종료합니다.
  void _handleForceLogout(RemoteMessage message) {
    debugPrint('🚨 강제 로그아웃 메시지 수신 (레거시)');
    
    final newDeviceName = message.data['newDeviceName'] ?? '다른 기기';
    final newPlatform = message.data['newPlatform'] ?? 'unknown';
    
    if (_context != null) {
      // 다이얼로그 표시
      showDialog(
        context: _context!,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 12),
              Text('다른 기기에서 로그인됨'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$newDeviceName에서 로그인되어 현재 세션이 종료됩니다.',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '본인이 아닌 경우 비밀번호를 변경하세요.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // 강제 로그아웃 실행
                if (_onForceLogout != null) {
                  _onForceLogout!();
                }
              },
              child: const Text('확인'),
            ),
          ],
        ),
      );
    } else {
      // Context가 없으면 바로 로그아웃
      if (_onForceLogout != null) {
        _onForceLogout!();
      }
    }
    
    debugPrint('✅ 강제 로그아웃 처리 완료');
  }
  
  /// 🔐 보류 중인 기기 승인 요청 처리 (Public 메서드 - iOS 대응)
  /// 
  /// DCMIWSConnectionManager에서 앱이 포그라운드로 돌아올 때 호출됩니다.
  void handlePendingApprovalRequest(RemoteMessage message) {
    
    // Context 대기 후 다이얼로그 표시
    _waitForContextAndShowApprovalDialog(message);
  }
  
  /// ⚠️ DEPRECATED: Use FCMDeviceApprovalService.handleDeviceApprovalRequest() instead
  /// This method has been moved to FCMDeviceApprovalService for better modularity.
  @Deprecated('Use FCMDeviceApprovalService.handleDeviceApprovalRequest()')
  void _handleDeviceApprovalRequest(RemoteMessage message) {
    // Delegate to new modular service
    _approvalService.handleDeviceApprovalRequest(message);
  }
  
  /// 기기 승인 응답 메시지 처리
  /// 
  /// 새 기기에서 기존 기기의 승인 결과를 수신합니다.
  Future<void> _handleDeviceApprovalResponse(RemoteMessage message) async {
    debugPrint('✅ [FCM] 기기 승인 응답 메시지 수신');
    
    final approved = message.data['approved'] == 'true';
    final deviceName = message.data['deviceName'] ?? '기존 기기';
    
    final context = _context ?? navigatorKey.currentContext;
    if (context == null) {
      debugPrint('❌ [FCM] BuildContext 없음');
      return;
    }
    
    if (approved) {
      debugPrint('✅ [FCM] 기기 승인 완료 - 로그인 진행');
      
      // 승인 완료 다이얼로그
      await DialogUtils.showSuccess(
        context,
        '$deviceName에서 승인되었습니다',
        duration: const Duration(seconds: 1),
      );
    } else {
      debugPrint('❌ [FCM] 기기 승인 거부됨 - 로그인 취소');
      
      // 거부 다이얼로그
      await DialogUtils.showError(
        context,
        '$deviceName에서 거부되었습니다',
        duration: const Duration(seconds: 1),
      );
      
      // 로그아웃 처리
      if (_onForceLogout != null) {
        _onForceLogout!();
      }
    }
  }
  
  /// 기기 승인 취소 메시지 처리
  /// 
  /// 다른 기기가 승인했을 때 현재 기기의 승인 다이얼로그를 자동으로 닫습니다.
  void _handleDeviceApprovalCancelled(RemoteMessage message) {
    final approvalRequestId = message.data['approvalRequestId'] as String?;
    
    if (kDebugMode) {
      debugPrint('🛑 [FCM-CANCEL] 승인 취소 메시지 수신: $approvalRequestId');
    }
    
    if (approvalRequestId == null || approvalRequestId.isEmpty) {
      if (kDebugMode) {
        debugPrint('⚠️ [FCM-CANCEL] approvalRequestId 없음');
      }
      return;
    }
    
    // 현재 표시된 다이얼로그와 일치하는지 확인
    if (_currentDisplayedApprovalId != approvalRequestId) {
      if (kDebugMode) {
        debugPrint('⚠️ [FCM-CANCEL] ID 불일치 (현재: $_currentDisplayedApprovalId)');
      }
      return;
    }
    
    // Context 확인
    final context = _context ?? navigatorKey.currentContext;
    if (context == null || !context.mounted) {
      if (kDebugMode) {
        debugPrint('⚠️ [FCM-CANCEL] Context 없음 또는 unmounted');
      }
      return;
    }
    
    // 다이얼로그 자동 닫기
    try {
      Navigator.of(context, rootNavigator: true).pop();
      _currentDisplayedApprovalId = null;
      
      if (kDebugMode) {
        debugPrint('✅ [FCM-CANCEL] 다이얼로그 자동 닫기 완료');
      }
      
      // 성공 메시지 표시
      Future.delayed(const Duration(milliseconds: 300), () {
        if (context.mounted) {
          DialogUtils.showSuccess(
            context,
            '다른 기기에서 승인이 완료되었습니다',
            duration: const Duration(seconds: 1),
          );
        }
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [FCM-CANCEL] 다이얼로그 닫기 실패: $e');
      }
    }
  }
  
  /// ⚠️ DEPRECATED: Use FCMIncomingCallHandler.handleIncomingCallCancelled() instead
  /// This method has been moved to FCMIncomingCallHandler for better modularity.
  @Deprecated('Use FCMIncomingCallHandler.handleIncomingCallCancelled()')
  void _handleIncomingCallCancelled(RemoteMessage message) {
    // Delegate to new modular service
    _incomingCallHandler.handleIncomingCallCancelled(message);
  }
  
  /// ⚠️ DEPRECATED: This method is now handled internally by FCMDeviceApprovalService
  /// Device approval is now processed automatically within FCMDeviceApprovalService.
  @Deprecated('Handled internally by FCMDeviceApprovalService')
  Future<void> _approveDeviceApproval(String approvalRequestId) async {
    debugPrint('⚠️ [FCM] _approveDeviceApproval is deprecated - handled internally by FCMDeviceApprovalService');
  }
  
  /// ⚠️ DEPRECATED: This method is now handled internally by FCMDeviceApprovalService
  /// Device rejection is now processed automatically within FCMDeviceApprovalService.
  @Deprecated('Handled internally by FCMDeviceApprovalService')
  Future<void> _rejectDeviceApproval(String approvalRequestId) async {
    debugPrint('⚠️ [FCM] _rejectDeviceApproval is deprecated - handled internally by FCMDeviceApprovalService');
  }
  
  /// ⚠️ DEPRECATED: Use FCMNotificationService.showAndroidNotification() instead
  /// This method has been moved to FCMNotificationService for better modularity.
  @Deprecated('Use FCMNotificationService.showAndroidNotification()')
  Future<void> _showAndroidNotification(RemoteMessage message) async {
    // Delegate to new modular service
    await _notificationService.showAndroidNotification(message);
  }
  
  /// ⚠️ DEPRECATED: Use FCMNotificationService.showWebNotification() instead
  /// This method has been moved to FCMNotificationService for better modularity.
  @Deprecated('Use FCMNotificationService.showWebNotification()')
  Future<void> _showWebNotification(RemoteMessage message) async {
    // Delegate to new modular service
    await _notificationService.showWebNotification(message);
  }
  
  /// ⚠️ DEPRECATED: Use FCMNotificationService.showIOSNotification() instead
  /// This method has been moved to FCMNotificationService for better modularity.
  @Deprecated('Use FCMNotificationService.showIOSNotification()')
  Future<void> _showIOSNotification(RemoteMessage message) async {
    // Delegate to new modular service
    await _notificationService.showIOSNotification(message);
  }
  
  /// WebSocket 연결 상태 확인 및 재연결
  Future<void> _ensureWebSocketConnection() async {
    try {
      final dcmiwsService = DCMIWSService();
      
      // 이미 연결되어 있으면 스킵
      if (dcmiwsService.isConnected) {
        if (kDebugMode) {
          debugPrint('✅ WebSocket이 이미 연결되어 있습니다');
        }
        return;
      }
      
      if (kDebugMode) {
        debugPrint('🔌 WebSocket 재연결 시도...');
      }
      
      // Firestore에서 사용자의 서버 설정 가져오기
      if (_context == null) return;
      
      final authService = Provider.of<AuthService>(_context!, listen: false);
      final userId = authService.currentUser?.uid;
      
      if (userId == null) {
        if (kDebugMode) {
          debugPrint('❌ 로그인 정보가 없습니다');
        }
        return;
      }
      
      // user_model에서 WebSocket 설정 가져오기 (HTTP Auth 포함)
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      
      if (userData == null) return;
      
      final serverAddress = userData['websocketServerUrl'] as String?;
      final serverPort = userData['websocketServerPort'] as int? ?? 6600;
      final useSSL = userData['websocketUseSSL'] as bool? ?? false;
      final httpAuthId = userData['websocketHttpAuthId'] as String?;
      final httpAuthPassword = userData['websocketHttpAuthPassword'] as String?;
      
      if (serverAddress == null || serverAddress.isEmpty) {
        if (kDebugMode) {
          debugPrint('⚠️  WebSocket 서버 주소가 설정되지 않았습니다');
        }
        return;
      }
      
      if (kDebugMode) {
        debugPrint('🔌 WebSocket 재연결 시도:');
        debugPrint('   - 서버: $serverAddress:$serverPort');
        debugPrint('   - SSL: $useSSL');
        if (httpAuthId != null && httpAuthId.isNotEmpty) {
          debugPrint('   - HTTP Auth: 설정됨 (ID: $httpAuthId)');
        }
      }
      
      // WebSocket 재연결 (HTTP Auth 포함)
      final success = await dcmiwsService.connect(
        serverAddress: serverAddress,
        port: serverPort,
        useSSL: useSSL,
        httpAuthId: httpAuthId,
        httpAuthPassword: httpAuthPassword,
      );
      
      if (kDebugMode) {
        if (success) {
          debugPrint('✅ WebSocket 재연결 성공');
        } else {
          debugPrint('❌ WebSocket 재연결 실패');
        }
      }
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ WebSocket 재연결 오류: $e');
      }
    }
  }
  
  // 🔧 수신 전화 화면 표시 중복 방지 플래그
  bool _isShowingIncomingCall = false;
  
  /// ⚠️ DEPRECATED: Use FCMIncomingCallHandler.showIncomingCallScreen() instead
  /// This method has been moved to FCMIncomingCallHandler for better modularity.
  @Deprecated('Use FCMIncomingCallHandler.showIncomingCallScreen()')
  Future<void> _showIncomingCallScreen(RemoteMessage message, {bool soundEnabled = true, bool vibrationEnabled = true}) async {
    // Delegate to new modular service
    await _incomingCallHandler.showIncomingCallScreen(message, soundEnabled: soundEnabled, vibrationEnabled: vibrationEnabled);
  }
  
  /// ⚠️ DEPRECATED: Use FCMNotificationService.getUserNotificationSettings() instead
  /// This method has been moved to FCMNotificationService for better modularity.
  @Deprecated('Use FCMNotificationService.getUserNotificationSettings()')
  Future<Map<String, dynamic>?> getUserNotificationSettings(String userId) async {
    // Delegate to new modular service
    return await _notificationService.getUserNotificationSettings(userId);
  }
  
  /// ⚠️ DEPRECATED: Use FCMNotificationService.updateNotificationSettings() instead
  /// This method has been moved to FCMNotificationService for better modularity.
  @Deprecated('Use FCMNotificationService.updateNotificationSettings()')
  Future<void> updateNotificationSettings(
    String userId,
    Map<String, dynamic> settings,
  ) async {
    // Delegate to new modular service
    await _notificationService.updateNotificationSettings(userId, settings);
  }
  
  /// 특정 설정 항목만 업데이트
  Future<void> updateSingleSetting(
    String userId,
    String key,
    dynamic value,
  ) async {
    try {
      await _firestore
          .collection('user_notification_settings')
          .doc(userId)
          .set({
        key: value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      if (kDebugMode) {
        debugPrint('✅ 알림 설정 업데이트 완료: $key = $value');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 알림 설정 업데이트 오류: $e');
      }
      rethrow;
    }
  }
  
  /// FCM 토큰 비활성화 (로그아웃 시)
  /// 
  /// ⚠️ 중요: 이 메서드는 오직 fcm_tokens 컬렉션만 삭제합니다!
  /// ✅ 보존되는 데이터:
  ///   - users/{userId}: API/WebSocket 설정, 회사 정보 등
  ///   - my_extensions: 등록된 단말번호 정보
  ///   - call_forward_info: 착신전환 설정
  /// 
  /// 로그아웃 시 현재 기기의 FCM 토큰만 삭제합니다.
  /// 
  /// 🔧 Phase 1 Refactoring: FCMTokenManager 사용
  Future<void> deactivateToken(String userId) async {
    
    await _tokenManager.deactivateToken(userId, _fcmToken);
    
    // 🔧 싱글톤 상태 리셋: 재로그인 시 승인 프로세스가 다시 실행되도록
    _fcmToken = null;
    _initializedUserId = null;
    _isInitializing = false;
    _initializationCompleter = null;
    _tokenManager.clearSaveTracking();
    
  }
  
  /// 🔧 Phase 1 Refactoring: 플랫폼 유틸리티 메서드들을 FCMPlatformUtils로 이동
  /// 
  /// ⚠️ DEPRECATED: 아래 메서드들은 FCMPlatformUtils에서 제공됩니다:
  /// - _getDeviceId() → _platformUtils.getDeviceId()
  /// - _getDeviceName() → _platformUtils.getDeviceName()
  /// - _getPlatformName() → _platformUtils.getPlatformName()
  /// - _getiOSFriendlyName() → _platformUtils.getiOSFriendlyName()
  /// 
  /// 이 주석 블록은 리팩토링 완료 확인을 위해 임시로 유지됩니다.
  
  /// iOS APNs 토큰 상태 확인 (디버깅용)
  Future<Map<String, dynamic>> checkIOSAPNsStatus() async {
    if (!_isIOS) {
      return {'platform': 'not_ios', 'status': 'N/A'};
    }
    
    try {
      final apnsToken = await _messaging.getAPNSToken();
      final fcmToken = await _messaging.getToken();
      
      return {
        'platform': 'ios',
        'apnsToken': apnsToken,
        'apnsTokenAvailable': apnsToken != null,
        'fcmToken': fcmToken,
        'fcmTokenAvailable': fcmToken != null,
        'status': apnsToken != null ? 'ready' : 'apns_token_missing',
      };
    } catch (e) {
      return {
        'platform': 'ios',
        'status': 'error',
        'error': e.toString(),
      };
    }
  }
  
  /// 문자열에서 전화번호 추출 (정규식 사용)
  String? _extractPhoneNumber(String? text) {
    if (text == null) return null;
    
    // 한국 전화번호 패턴 매칭 (010-xxxx-xxxx, 01012345678, 02-1234-5678 등)
    final phonePattern = RegExp(r'0\d{1,2}[-\s]?\d{3,4}[-\s]?\d{4}');
    final match = phonePattern.firstMatch(text);
    
    return match?.group(0);
  }
  
  /// FCM 수신 전화에 대한 통화 기록 생성
  /// 
  /// Firebase Functions에서 이미 생성한 경우 중복 방지
  /// 
  /// ⚠️ iOS 네트워크 이슈 대응:
  /// - Firestore 연결 실패 시에도 수신 전화 화면은 표시
  /// - 통화 기록은 네트워크 복구 후 생성 시도
  Future<void> _createCallHistory({
    required String callerNumber,
    required String callerName,
    required String receiverNumber,
    required String linkedid,
    required String channel,
    required String callType,
  }) async {
    try {
      final authService = AuthService();
      final userId = authService.currentUser?.uid;
      
      if (userId == null) {
        return;
      }
      
      
      // linkedid로 기존 통화 기록 확인 (중복 방지) - 타임아웃 5초
      final existingDoc = await _firestore
          .collection('call_history')
          .doc(linkedid)
          .get()
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw TimeoutException('Firestore get timeout');
            },
          );
      
      if (existingDoc.exists) {
        
        // 상태만 업데이트 (FCM 수신 확인) - 타임아웃 5초
        // 🔧 FIX: cancelled 필드 초기화 (iOS에서 이전 취소 상태가 남아있을 수 있음)
        await _firestore.collection('call_history').doc(linkedid).update({
          'fcmReceived': true,
          'fcmReceivedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'cancelled': false, // 🔧 새 수신 전화이므로 취소 상태 초기화
        }).timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            throw TimeoutException('Firestore update timeout');
          },
        );
        
        return;
      }
      
      // 새 통화 기록 생성 (Firebase Functions에서 생성되지 않은 경우)
      
      await _firestore.collection('call_history').doc(linkedid).set({
        'userId': userId,
        'callerNumber': callerNumber,
        'callerName': callerName,
        'receiverNumber': receiverNumber,
        'channel': channel,
        'linkedid': linkedid,
        'callType': 'incoming',
        'callSubType': callType == 'voice' ? 'external' : callType,
        'status': 'fcm_received', // FCM으로 수신됨
        'fcmReceived': true,
        'cancelled': false, // 🔧 새 수신 전화이므로 취소 상태 초기화
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Firestore set timeout');
        },
      );
      
      
    } on TimeoutException catch (e) {
    } on FirebaseException catch (e) {
    } catch (e, stackTrace) {
    }
  }
  
  /// 승인 대기 다이얼로그 표시
  void _showApprovalWaitingDialog() {
    final context = _context ?? navigatorKey.currentContext;
    if (context == null) {
      return;
    }
    
    
    // 🔧 키보드 숨기기
    FocusScope.of(context).unfocus();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent, // 🎯 투명 (위젯 자체가 화면을 덮음)
      builder: (dialogContext) => PopScope(
        canPop: false, // 뒤로 가기 방지
        child: _ApprovalWaitingDialog(
          onResendRequest: () async {
            if (_currentApprovalRequestId != null && _currentUserId != null) {
              try {
                await resendApprovalRequest(_currentApprovalRequestId!, _currentUserId!);
                
                // 사용자에게 성공 메시지 표시
                final context = _context ?? navigatorKey.currentContext;
                if (context != null && context.mounted) {
                  await DialogUtils.showSuccess(
                    context,
                    '✅ 승인 요청을 다시 전송했습니다',
                    duration: const Duration(seconds: 1),
                  );
                }
              } catch (e) {
                
                // 사용자에게 오류 메시지 표시
                final context = _context ?? navigatorKey.currentContext;
                if (context != null && context.mounted) {
                  await DialogUtils.showError(
                    context,
                    '❌ 재전송 실패: $e',
                    duration: const Duration(seconds: 1),
                  );
                }
              }
            }
          },
        ),
      ),
    );
  }
  
  /// ⚠️ DEPRECATED: Use FCMDeviceApprovalService.resendApprovalRequest() instead
  /// This method has been moved to FCMDeviceApprovalService for better modularity.
  @Deprecated('Use FCMDeviceApprovalService.resendApprovalRequest()')
  Future<void> resendApprovalRequest(String approvalRequestId, String userId) async {
    // Delegate to new modular service
    await _approvalService.resendApprovalRequest(approvalRequestId, userId);
  }
  
  /// 승인 대기 다이얼로그 닫기
  void _dismissApprovalWaitingDialog() {
    final context = _context ?? navigatorKey.currentContext;
    if (context == null) {
      return;
    }
    
    
    // 다이얼로그가 열려있는지 확인하고 닫기
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  /// 📳 새 기기 승인 요청 시 진동 트리거
  /// 
  /// 새 기기에서 로그인 시도가 감지되었을 때 사용자에게 알리기 위한 진동
  Future<void> _triggerDeviceApprovalVibration() async {
    try {
      // 사용자 알림 설정 확인 (수신전화와 동일한 방식)
      final currentUser = AuthService().currentUser;
      if (currentUser == null) {
        debugPrint('⚠️ [VIBRATION-APPROVAL] 사용자 정보 없음 - 진동 스킵');
        return;
      }

      // 수신전화와 동일한 설정 확인 방법 사용
      final settings = await getUserNotificationSettings(currentUser.uid);
      final pushEnabled = settings?['pushEnabled'] ?? true;
      final vibrationEnabled = settings?['vibrationEnabled'] ?? true;

      debugPrint('📦 [VIBRATION-APPROVAL] 알림 설정:');
      debugPrint('   - pushEnabled: $pushEnabled');
      debugPrint('   - vibrationEnabled: $vibrationEnabled');

      // 푸시 알림이 꺼져있으면 진동도 스킵
      if (!pushEnabled) {
        debugPrint('⏭️ [VIBRATION-APPROVAL] 푸시 알림이 비활성화됨 - 진동 스킵');
        return;
      }

      if (!vibrationEnabled) {
        debugPrint('⏭️ [VIBRATION-APPROVAL] 사용자가 진동을 비활성화함 - 진동 스킵');
        return;
      }

      // 플랫폼 확인
      if (kIsWeb) {
        debugPrint('⚠️ [VIBRATION-APPROVAL] 웹 플랫폼 - 진동 미지원');
        return;
      }

      // 기기 진동 지원 확인
      final hasVibrator = await Vibration.hasVibrator();
      debugPrint('📳 [VIBRATION-APPROVAL] 기기 진동 지원: $hasVibrator');

      if (hasVibrator == true || hasVibrator == null) {
        // 짧은 진동 패턴 (보안 알림용)
        // 200ms 진동 → 100ms 정지 → 200ms 진동 → 100ms 정지 → 200ms 진동
        await Vibration.vibrate(duration: 200);
        await Future.delayed(const Duration(milliseconds: 100));
        await Vibration.vibrate(duration: 200);
        await Future.delayed(const Duration(milliseconds: 100));
        await Vibration.vibrate(duration: 200);
        
        debugPrint('✅ [VIBRATION-APPROVAL] 새 기기 승인 요청 진동 완료');
      } else {
        debugPrint('⚠️ [VIBRATION-APPROVAL] 기기가 진동을 지원하지 않음');
      }
    } catch (e) {
      debugPrint('❌ [VIBRATION-APPROVAL] 진동 실행 오류: $e');
    }
  }

  /// 🔊 새 기기 승인 요청 시 사운드 재생
  /// 
  /// 새 기기에서 로그인 시도가 감지되었을 때 사용자에게 알리기 위한 알림음
  Future<void> _triggerDeviceApprovalSound() async {
    AudioPlayer? audioPlayer;
    
    try {
      // 사용자 알림 설정 확인 (수신전화와 동일한 방식)
      final currentUser = AuthService().currentUser;
      if (currentUser == null) {
        debugPrint('⚠️ [SOUND-APPROVAL] 사용자 정보 없음 - 사운드 스킵');
        return;
      }

      // 수신전화와 동일한 설정 확인 방법 사용
      final settings = await getUserNotificationSettings(currentUser.uid);
      final pushEnabled = settings?['pushEnabled'] ?? true;
      final soundEnabled = settings?['soundEnabled'] ?? true;

      debugPrint('📦 [SOUND-APPROVAL] 알림 설정:');
      debugPrint('   - pushEnabled: $pushEnabled');
      debugPrint('   - soundEnabled: $soundEnabled');

      // 푸시 알림이 꺼져있으면 사운드도 스킵
      if (!pushEnabled) {
        debugPrint('⏭️ [SOUND-APPROVAL] 푸시 알림이 비활성화됨 - 사운드 스킵');
        return;
      }

      if (!soundEnabled) {
        debugPrint('⏭️ [SOUND-APPROVAL] 사용자가 사운드를 비활성화함 - 사운드 스킵');
        return;
      }

      // 플랫폼 확인
      if (kIsWeb) {
        debugPrint('⚠️ [SOUND-APPROVAL] 웹 플랫폼 - 제한적 지원');
      }

      // AudioPlayer 생성
      audioPlayer = AudioPlayer();
      
      // 볼륨 설정 (보통 크기)
      await audioPlayer.setVolume(0.8);
      
      // 🔊 안드로이드 기본 알림음 재생
      try {
        // flutter_local_notifications 플러그인 생성
        final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
        
        // flutter_local_notifications를 사용하여 시스템 알림음 재생
        final androidPlugin = flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        
        if (androidPlugin != null) {
          // Android: 시스템 기본 알림음으로 간단한 알림 표시
          await flutterLocalNotificationsPlugin.show(
            999, // 임시 알림 ID
            '새 기기 승인 요청',
            '관리자의 승인이 필요합니다',
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'notification_sound_on_vibration_on',
                'Notifications with Sound and Vibration',
                channelDescription: 'Notifications with both sound and vibration enabled',
                importance: Importance.high,
                priority: Priority.high,
                playSound: true, // 안드로이드 기본 알림음 사용
                enableVibration: true,
              ),
            ),
          );
          debugPrint('✅ [SOUND-APPROVAL] 안드로이드 기본 알림음 재생 완료');
          
          // 1.5초 후 알림 제거
          await Future.delayed(const Duration(milliseconds: 1500));
          await flutterLocalNotificationsPlugin.cancel(999);
        } else {
          // iOS: assets 파일 재생
          debugPrint('ℹ️ [SOUND-APPROVAL] iOS 플랫폼 - assets 파일 사용');
          try {
            await audioPlayer.play(AssetSource('audio/ringtone.mp3'));
            debugPrint('✅ [SOUND-APPROVAL] iOS assets/audio/ringtone.mp3 재생 시작');
            
            // 1.5초 재생 후 중지 (짧은 알림음)
            await Future.delayed(const Duration(milliseconds: 1500));
            await audioPlayer.stop();
          } catch (e) {
            debugPrint('⚠️ [SOUND-APPROVAL] iOS assets 파일 재생 오류: $e');
          }
        }
        
        await audioPlayer.dispose();
      } catch (e) {
        debugPrint('⚠️ [SOUND-APPROVAL] 알림음 재생 오류: $e');
        await audioPlayer.dispose();
      }
    } catch (e) {
      debugPrint('❌ [SOUND-APPROVAL] 사운드 재생 오류: $e');
      if (audioPlayer != null) {
        try {
          await audioPlayer.dispose();
        } catch (_) {}
      }
    }
  }
}

/// 승인 대기 다이얼로그 위젯 (전체 화면 차단)
class _ApprovalWaitingDialog extends StatefulWidget {
  final VoidCallback onResendRequest;
  
  const _ApprovalWaitingDialog({
    required this.onResendRequest,
  });
  
  @override
  State<_ApprovalWaitingDialog> createState() => _ApprovalWaitingDialogState();
}

class _ApprovalWaitingDialogState extends State<_ApprovalWaitingDialog> {
  static const int _maxSeconds = 300; // 5분
  int _remainingSeconds = _maxSeconds;
  Timer? _timer;
  
  @override
  void initState() {
    super.initState();
    _startTimer();
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
  
  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
      }
    });
  }
  
  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
  
  @override
  Widget build(BuildContext context) {
    // 🎯 전체 화면을 덮는 방식으로 변경 (백그라운드 UI 완전 차단)
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black87, // 전체 화면을 어두운 배경으로 덮음
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 🔐 아이콘
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.devices,
                    size: 48,
                    color: Color(0xFF2196F3),
                  ),
                ),
                const SizedBox(height: 24),
                
                // 제목
                const Text(
                  '기기 승인 대기 중',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                
                // 설명
                const Text(
                  '다른 기기에서 이 기기의 로그인을\n승인해주세요.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                
                // 타이머
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        size: 20,
                        color: Color(0xFF2196F3),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(_remainingSeconds),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2196F3),
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // 로딩 인디케이터
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 24),
                
                // 재요청 버튼
                OutlinedButton.icon(
                  onPressed: widget.onResendRequest,
                  icon: const Icon(Icons.refresh),
                  label: const Text('알림 재전송'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
