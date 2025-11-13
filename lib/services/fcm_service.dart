import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io' show Platform;
import 'dart:async'; // TimeoutException 사용을 위해 필요
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../screens/call/incoming_call_screen.dart';
import '../screens/home/main_screen.dart'; // MainScreen import 추가
import '../models/fcm_token_model.dart';
import '../main.dart' show navigatorKey; // GlobalKey for Navigation
import 'dcmiws_service.dart';
import 'auth_service.dart';
import 'database_service.dart';
import 'package:provider/provider.dart';
import '../utils/dialog_utils.dart';

/// FCM(Firebase Cloud Messaging) 서비스
/// 
/// 다중 기기 로그인 지원 기능 포함:
/// - 새 기기에서 로그인 시 기존 기기에 승인 요청
/// - FCM 메시지를 통한 기기 승인/거부 알림
/// - 여러 기기에서 동시 로그인 가능
class FCMService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseService _databaseService = DatabaseService();
  
  String? _fcmToken;
  static BuildContext? _context; // 전역 BuildContext 저장
  static Function()? _onForceLogout; // 강제 로그아웃 콜백
  
  // 🔒 중복 초기화 방지
  static bool _isInitializing = false;
  static String? _initializedUserId;
  static StreamSubscription<String>? _tokenRefreshSubscription;
  String? _lastSavedToken;
  DateTime? _lastSaveTime;
  
  // 🔒 초기화 완료를 기다리기 위한 Completer
  static Completer<void>? _initializationCompleter;
  
  // 🎨 승인 대기 다이얼로그 관련
  String? _currentApprovalRequestId;
  String? _currentUserId;
  
  /// FCM 토큰 가져오기
  String? get fcmToken => _fcmToken;
  
  /// BuildContext 설정 (main.dart에서 호출)
  static void setContext(BuildContext context) {
    _context = context;
  }
  
  /// 강제 로그아웃 콜백 설정
  static void setForceLogoutCallback(Function() callback) {
    _onForceLogout = callback;
  }
  
  /// ✅ OPTION 1: iOS Method Channel에서 호출하는 공개 메서드
  /// RemoteMessage를 받아서 포그라운드/백그라운드 핸들러로 전달
  Future<void> handleRemoteMessage(RemoteMessage message, {required bool isForeground}) async {
    // ignore: avoid_print
    print('📨 [FCM-PUBLIC] handleRemoteMessage() 호출됨');
    // ignore: avoid_print
    print('   - isForeground: $isForeground');
    // ignore: avoid_print
    print('   - messageId: ${message.messageId}');
    
    if (isForeground) {
      _handleForegroundMessage(message);
    } else {
      _handleMessageOpenedApp(message);
    }
  }
  
  /// FCM 초기화
  Future<void> initialize(String userId) async {
    try {
      // ignore: avoid_print
      print('🔔 [FCM] 초기화 시작');
      // ignore: avoid_print
      print('   User ID: $userId');
      // ignore: avoid_print
      print('   Platform: ${_getPlatformName()}');
      
      // 🔒 중복 초기화 방지 체크
      if (_isInitializing) {
        // ignore: avoid_print
        print('⏸️  [FCM] 이미 초기화 진행 중 - 완료 대기...');
        if (_initializationCompleter != null) {
          // ignore: avoid_print
          print('⏳ [FCM] 첫 번째 초기화(승인 대기 포함) 완료까지 대기합니다');
          try {
            await _initializationCompleter!.future;
            // ignore: avoid_print
            print('✅ [FCM] 첫 번째 초기화 완료됨 - 두 번째 호출 반환');
          } catch (e) {
            // ignore: avoid_print
            print('❌ [FCM] 첫 번째 초기화 실패 - 두 번째 호출도 실패');
            // ignore: avoid_print
            print('   에러: $e');
            rethrow; // 승인 실패 시 두 번째 호출도 실패해야 함
          }
        }
        return;
      }
      
      if (_initializedUserId == userId && _fcmToken != null) {
        // ignore: avoid_print
        print('✅ [FCM] 이미 동일 사용자로 초기화 완료 - 재초기화 스킵');
        // ignore: avoid_print
        print('   기존 토큰: ${_fcmToken!.substring(0, 20)}...');
        return;
      }
      
      // ignore: avoid_print
      print('🔓 [FCM] 초기화 잠금 설정');
      _isInitializing = true;
      _initializationCompleter = Completer<void>();
      
      // ✅ STEP 1: 메시지 리스너를 가장 먼저 등록! (메시지 누락 방지)
      // ignore: avoid_print
      print('📡 [FCM] 메시지 리스너 등록 시작 (최우선)');
      
      // 포그라운드 메시지 리스너
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      // ignore: avoid_print
      print('✅ [FCM] onMessage 리스너 등록 완료');
      
      // 백그라운드/종료 상태에서 알림 클릭 시 처리
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
      // ignore: avoid_print
      print('✅ [FCM] onMessageOpenedApp 리스너 등록 완료');
      
      // 앱이 종료된 상태에서 알림 클릭으로 시작된 경우 처리
      _messaging.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          // ignore: avoid_print
          print('🚀 [FCM] 앱이 종료 상태에서 알림 클릭으로 시작됨');
          _handleMessageOpenedApp(message);
        }
      });
      // ignore: avoid_print
      print('✅ [FCM] getInitialMessage 설정 완료');
      
      // ignore: avoid_print
      print('🎯 [FCM] 모든 메시지 리스너 등록 완료! 이제 토큰 생성 시작');
      
      // Android 로컬 알림 플러그인 초기화 및 알림 채널 생성
      if (Platform.isAndroid) {
        // ignore: avoid_print
        print('🤖 [FCM] Android: flutter_local_notifications 초기화 중...');
        
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
        
        // ignore: avoid_print
        print('✅ [FCM] flutter_local_notifications 초기화 완료');
        
        // 알림 채널 생성
        // ignore: avoid_print
        print('🤖 [FCM] Android: 알림 채널 생성 중...');
        
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'high_importance_channel', // id
          'High Importance Notifications', // name
          description: 'This channel is used for important notifications.',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        );
        
        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
        
        // ignore: avoid_print
        print('✅ [FCM] Android: 알림 채널 생성 완료');
      }
      
      // 알림 권한 요청
      // ignore: avoid_print
      print('📱 [FCM] 알림 권한 요청 중...');
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      
      // ignore: avoid_print
      print('✅ [FCM] 알림 권한 응답: ${settings.authorizationStatus}');
      
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        
        // FCM 토큰 가져오기
        // ignore: avoid_print
        print('🔑 [FCM] 토큰 요청 시작...');
        
        if (kIsWeb) {
          // ignore: avoid_print
          print('🌐 [FCM] 웹 플랫폼: VAPID 키 사용');
          const vapidKey = 'BM2qgTRRwT-mG4shgKLDr7CnVf5-xVs3DqNNcqY7zzHZXd5P5xWqvCLn8BxGnqJ3YKj0zcY6Kp0YwQ_Zr8vK2jM';
          _fcmToken = await _messaging.getToken(vapidKey: vapidKey);
        } else {
          // ignore: avoid_print
          print('📱 [FCM] 모바일 플랫폼: 일반 토큰 요청');
          
          // iOS 전용: APNs 토큰 확인 (재시도 로직 포함)
          if (Platform.isIOS) {
            // ignore: avoid_print
            print('🍎 [FCM] iOS: APNs 토큰 확인 중...');
            
            String? apnsToken;
            int retryCount = 0;
            const maxRetries = 5;
            
            // APNs 토큰이 준비될 때까지 재시도
            while (apnsToken == null && retryCount < maxRetries) {
              apnsToken = await _messaging.getAPNSToken();
              
              if (apnsToken == null) {
                retryCount++;
                // ignore: avoid_print
                print('⏳ [FCM] APNs 토큰 대기 중... (시도 $retryCount/$maxRetries)');
                await Future.delayed(const Duration(milliseconds: 500));
              }
            }
            
            if (apnsToken != null) {
              // ignore: avoid_print
              print('✅ [FCM] APNs 토큰 존재: ${apnsToken.substring(0, 20)}...');
            } else {
              // ignore: avoid_print
              print('❌ [FCM] APNs 토큰 없음 - FCM 토큰 생성 실패');
              // ignore: avoid_print
              print('💡 해결방법:');
              // ignore: avoid_print
              print('   1. 실제 iOS 기기에서 테스트 (시뮬레이터 X)');
              // ignore: avoid_print
              print('   2. Firebase Console에서 APNs 인증 키 업로드');
              // ignore: avoid_print
              print('   3. Xcode에서 Push Notifications Capability 추가');
              // ignore: avoid_print
              print('   4. 네트워크 연결 확인 (Wi-Fi/셀룰러)');
              // ignore: avoid_print
              print('   5. 앱을 완전히 종료하고 재시작');
              return;
            }
          }
          
          // ignore: avoid_print
          print('🔄 [FCM] getToken() 호출 중...');
          _fcmToken = await _messaging.getToken();
          // ignore: avoid_print
          print('🔄 [FCM] getToken() 완료');
        }
        
        if (_fcmToken != null) {
          // ignore: avoid_print
          print('✅ [FCM] 토큰 생성 완료!');
          // ignore: avoid_print
          print('   - 토큰 앞부분: ${_fcmToken!.substring(0, 20)}...');
          // ignore: avoid_print
          print('   - 전체 길이: ${_fcmToken!.length}자');
          // ignore: avoid_print
          print('   - 플랫폼: ${_getPlatformName()}');
          // ignore: avoid_print
          print('   - 사용자 ID: $userId');
          
          // Firestore에 토큰 저장
          // ignore: avoid_print
          print('💾 [FCM] Firestore 저장 시작...');
          await _saveFCMToken(userId, _fcmToken!);
          // ignore: avoid_print
          print('✅ [FCM] Firestore 저장 완료');
          
          // 🔒 토큰 갱신 리스너 중복 등록 방지
          if (_tokenRefreshSubscription == null) {
            // ignore: avoid_print
            print('📡 [FCM] 토큰 갱신 리스너 등록 중...');
            _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((newToken) {
              // ignore: avoid_print
              print('🔄 [FCM] 토큰 갱신 이벤트: ${newToken.substring(0, 20)}...');
              
              // 중복 저장 방지: 동일 토큰이 1분 내에 저장되었으면 스킵
              if (_lastSavedToken == newToken && 
                  _lastSaveTime != null && 
                  DateTime.now().difference(_lastSaveTime!) < const Duration(minutes: 1)) {
                // ignore: avoid_print
                print('⏭️  [FCM] 동일 토큰이 최근에 저장됨 - 중복 저장 스킵');
                return;
              }
              
              _fcmToken = newToken;
              _saveFCMToken(userId, newToken);
            });
            // ignore: avoid_print
            print('✅ [FCM] 토큰 갱신 리스너 등록 완료');
          } else {
            // ignore: avoid_print
            print('✅ [FCM] 토큰 갱신 리스너 이미 등록됨 - 스킵');
          }
          
          // ℹ️ 메시지 리스너는 이미 초기화 최상단에서 등록 완료됨
          // 백그라운드 메시지 핸들러는 main.dart에서 설정
          
        } else {
          // ignore: avoid_print
          print('❌ [FCM] 토큰 생성 실패 (null 반환)');
          // ignore: avoid_print
          print('🔍 가능한 원인:');
          // ignore: avoid_print
          print('   1. 네트워크 연결 오류');
          // ignore: avoid_print
          print('   2. Firebase 설정 오류 (GoogleService-Info.plist)');
          if (Platform.isIOS) {
            // ignore: avoid_print
            print('   3. APNs 토큰 없음 (iOS 시뮬레이터는 지원 안 됨)');
            // ignore: avoid_print
            print('   4. iOS 네트워크 권한 거부');
          }
        }
      } else {
        // ignore: avoid_print
        print('❌ [FCM] 알림 권한 거부됨: ${settings.authorizationStatus}');
      }
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print('❌ [FCM] 초기화 예외 발생: $e');
      // ignore: avoid_print
      print('Stack trace:');
      // ignore: avoid_print
      print(stackTrace);
      
      // 🔒 CRITICAL: 기기 승인 관련 오류는 반드시 상위로 전파
      final isApprovalError = e.toString().contains('Device approval') || 
                               e.toString().contains('denied') || 
                               e.toString().contains('timeout');
      
      if (isApprovalError) {
        // ignore: avoid_print
        print('🚫 [FCM] 기기 승인 실패 - 로그인 차단');
        
        // 🔒 CRITICAL: 승인 실패 시 Completer에 에러를 전달
        // 이렇게 하면 대기 중인 다른 초기화 호출들도 같은 에러를 받음
        _isInitializing = false;
        if (_initializationCompleter != null && !_initializationCompleter!.isCompleted) {
          _initializationCompleter!.completeError(e, stackTrace);
          // ignore: avoid_print
          print('🔒 [FCM] Completer에 에러 전달 완료 - 대기 중인 호출들도 실패');
        }
        
        rethrow;
      }
      
      // 일반적인 FCM 초기화 오류는 무시 (앱은 계속 실행)
      // ignore: avoid_print
      print('⚠️ [FCM] 초기화 실패했지만 앱은 계속 실행');
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
        // ignore: avoid_print
        print('✅ [FCM] 초기화 완료 - userId: $userId');
      }
    }
  }
  
  /// FCM 토큰을 Firestore에 저장 (중복 로그인 방지 포함)
  /// 
  /// ⚠️ 중요: 사용자 데이터(users 컬렉션)는 절대 삭제하지 않음!
  /// 
  /// 중복 로그인 방지 프로세스:
  /// 1. 기존 활성 토큰 조회 (fcm_tokens 컬렉션)
  /// 2. 다른 기기 감지 시 → 기존 기기에 강제 로그아웃 FCM 알림 전송
  /// 3. 기존 FCM 토큰만 비활성화 (fcm_tokens 컬렉션에서만 처리)
  /// 4. 새 FCM 토큰 저장
  /// 
  /// ✅ 보존되는 데이터:
  /// - users/{userId}: API 서버 설정, WebSocket 설정, 회사 정보, 단말번호 등 모든 사용자 데이터
  /// - my_extensions/{extensionId}: 등록된 단말번호 정보
  /// - call_forward_info/{infoId}: 착신전환 설정
  /// 
  /// ❌ 삭제되는 데이터:
  /// - fcm_tokens/{userId}_{deviceId}: 이전 기기의 FCM 토큰만 (세션 관리용)
  Future<void> _saveFCMToken(String userId, String token) async {
    try {
      // ignore: avoid_print
      print('💾 [FCM-SAVE] 토큰 저장 시작');
      
      // 🔒 중복 저장 방지: 동일 토큰이 최근 1분 내에 저장되었으면 스킵
      if (_lastSavedToken == token && 
          _lastSaveTime != null && 
          DateTime.now().difference(_lastSaveTime!) < const Duration(minutes: 1)) {
        // ignore: avoid_print
        print('⏭️  [FCM-SAVE] 동일 토큰이 최근에 저장됨 - 중복 저장 스킵');
        // ignore: avoid_print
        print('   - 마지막 저장: ${DateTime.now().difference(_lastSaveTime!).inSeconds}초 전');
        return;
      }
      
      final deviceId = await _getDeviceId();
      final deviceName = await _getDeviceName();
      final platform = _getPlatformName();
      
      // ignore: avoid_print
      print('   - Device ID: $deviceId');
      // ignore: avoid_print
      print('   - Device Name: $deviceName');
      // ignore: avoid_print
      print('   - Platform: $platform');
      
      // 1. 모든 기존 활성 토큰 조회 (다중 기기 지원)
      // ignore: avoid_print
      print('🔍 [FCM-SAVE] 모든 활성 토큰 조회 중...');
      final existingTokens = await _databaseService.getAllActiveFcmTokens(userId);
      
      // 🔑 CRITICAL: Device ID + Platform 조합으로 기기 구분
      // 같은 Device ID라도 플랫폼이 다르면 다른 기기로 취급
      final currentDeviceKey = '${deviceId}_$platform';
      
      // 🔧 FIX: 같은 기기의 기존 토큰을 먼저 비활성화 (중복 방지)
      final sameDeviceTokens = existingTokens
          .where((token) => '${token.deviceId}_${token.platform}' == currentDeviceKey)
          .toList();
      
      if (sameDeviceTokens.isNotEmpty) {
        // ignore: avoid_print
        print('🧹 [FCM-SAVE] 같은 기기의 기존 토큰 ${sameDeviceTokens.length}개 발견 - 비활성화 중...');
        for (var oldToken in sameDeviceTokens) {
          // Firestore에서 직접 비활성화
          await _firestore
              .collection('fcm_tokens')
              .where('fcmToken', isEqualTo: oldToken.fcmToken)
              .get()
              .then((snapshot) async {
            for (var doc in snapshot.docs) {
              await doc.reference.update({'isActive': false});
            }
          });
          // ignore: avoid_print
          print('   ✅ 비활성화 완료: ${oldToken.fcmToken.substring(0, 20)}...');
        }
      }
      
      // 현재 기기를 제외한 다른 기기들 필터링
      final otherDevices = existingTokens
          .where((token) => '${token.deviceId}_${token.platform}' != currentDeviceKey)
          .toList();
      
      // 🔍 플랫폼 변경 감지: 같은 Device ID지만 다른 플랫폼
      final sameDeviceIdDifferentPlatform = existingTokens
          .where((token) => token.deviceId == deviceId && token.platform != platform)
          .toList();
      
      if (sameDeviceIdDifferentPlatform.isNotEmpty) {
        // ignore: avoid_print
        print('⚠️  [FCM-SAVE] 플랫폼 변경 감지!');
        // ignore: avoid_print
        print('   - Device ID: $deviceId');
        // ignore: avoid_print
        print('   - 이전 플랫폼: ${sameDeviceIdDifferentPlatform.first.platform}');
        // ignore: avoid_print
        print('   - 새 플랫폼: $platform');
        // ignore: avoid_print
        print('   - 🚨 다른 플랫폼으로 간주하여 승인 요청 진행');
      }
      
      if (otherDevices.isNotEmpty) {
        // 다른 기기에서 로그인 감지 - 모든 기존 기기에 승인 요청 전송
        // ignore: avoid_print
        print('🔔 [FCM-SAVE] 새 기기 로그인 감지!');
        // ignore: avoid_print
        print('   - 새 기기: $deviceName ($platform)');
        // ignore: avoid_print
        print('   - Device Key: $currentDeviceKey');
        // ignore: avoid_print
        print('   - 기존 기기 ${otherDevices.length}개에 알림 전송 예정');
        
        // ✅ 승인 요청 전송 및 승인 대기
        final approvalRequestId = await _sendDeviceApprovalRequestAndWait(
          userId: userId,
          newDeviceId: deviceId,
          newDeviceName: deviceName,
          newPlatform: platform,
          newDeviceToken: token,
        );
        
        if (approvalRequestId == null) {
          // ignore: avoid_print
          print('❌ [FCM-SAVE] 승인 요청 전송 실패 - 로그인 중단');
          throw Exception('Device approval request failed');
        }
        
        // ignore: avoid_print
        print('⏳ [FCM-SAVE] 기존 기기의 승인 대기 중...');
        // ignore: avoid_print
        print('🔒 [FCM-SAVE] 중요: _waitForDeviceApproval() 호출 - 이 함수가 반환될 때까지 대기');
        
        // 🎨 승인 요청 정보 저장
        _currentApprovalRequestId = approvalRequestId;
        _currentUserId = userId;
        
        // 🎨 승인 대기 다이얼로그 표시
        _showApprovalWaitingDialog();
        
        // 승인 대기 (최대 5분)
        final approved = await _waitForDeviceApproval(approvalRequestId);
        
        // 🎨 다이얼로그 닫기
        _dismissApprovalWaitingDialog();
        
        // 🎨 승인 요청 정보 초기화
        _currentApprovalRequestId = null;
        _currentUserId = null;
        
        // ignore: avoid_print
        print('🔙 [FCM-SAVE] _waitForDeviceApproval() 반환됨: $approved');
        
        if (!approved) {
          // ignore: avoid_print
          print('❌ [FCM-SAVE] 기기 승인 거부됨 또는 시간 초과 - 로그인 중단');
          // ignore: avoid_print
          print('🚫 [FCM-SAVE] Exception 던지기: Device approval denied or timeout');
          throw Exception('Device approval denied or timeout');
        }
        
        // ignore: avoid_print
        print('✅ [FCM-SAVE] 기기 승인 완료! 로그인 진행');
        
      } else if (existingTokens.any((token) => '${token.deviceId}_${token.platform}' == currentDeviceKey)) {
        // ignore: avoid_print
        print('ℹ️ [FCM-SAVE] 동일 기기 토큰 갱신');
        // ignore: avoid_print
        print('   - Device Key: $currentDeviceKey');
      } else {
        // ignore: avoid_print
        print('ℹ️ [FCM-SAVE] 첫 로그인 (다른 활성 기기 없음)');
        // ignore: avoid_print
        print('   - Device Key: $currentDeviceKey');
      }
      
      // 2. 새 토큰 모델 생성 및 저장
      final tokenModel = FcmTokenModel(
        userId: userId,
        fcmToken: token,
        deviceId: deviceId,
        deviceName: deviceName,
        platform: platform,
        createdAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
        isActive: true,
      );
      
      // ignore: avoid_print
      print('💾 [FCM-SAVE] DatabaseService.saveFcmToken() 호출 중...');
      await _databaseService.saveFcmToken(tokenModel);
      
      // ignore: avoid_print
      print('✅ [FCM-SAVE] Firestore 저장 완료!');
      // ignore: avoid_print
      print('   - 컬렉션: fcm_tokens');
      // ignore: avoid_print
      print('   - 문서 ID: ${userId}_$deviceId');
      // ignore: avoid_print
      print('   - 기기: $deviceName ($platform)');
      
      // 🔒 저장 성공 - 추적 정보 업데이트
      _lastSavedToken = token;
      _lastSaveTime = DateTime.now();
      // ignore: avoid_print
      print('🔒 [FCM-SAVE] 중복 저장 추적 업데이트 완료');
      
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print('❌ [FCM-SAVE] 토큰 저장 오류: $e');
      // ignore: avoid_print
      print('Stack trace:');
      // ignore: avoid_print
      print(stackTrace);
      
      // 🔒 CRITICAL: 승인 관련 오류는 반드시 상위로 전파하여 로그인 차단
      if (e.toString().contains('Device approval') || 
          e.toString().contains('denied') || 
          e.toString().contains('timeout')) {
        // ignore: avoid_print
        print('🚫 [FCM-SAVE] 승인 관련 오류 감지 - 상위로 예외 전파');
        rethrow;
      }
      
      // 일반적인 토큰 저장 오류는 무시 (로그인은 계속 진행)
      // ignore: avoid_print
      print('⚠️ [FCM-SAVE] 토큰 저장 실패했지만 로그인은 허용');
    }
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
  
  /// 기존 기기에 기기 승인 요청 FCM 메시지 전송
  /// 
  /// 새 기기에서 로그인 시도 시 기존 기기에 승인 요청을 보냅니다.
  /// 기존 기기에서 승인하면 새 기기 로그인이 완료됩니다.
  /// 
  /// ✅ Firestore 트리거 방식 사용:
  /// - Flutter는 fcm_approval_notification_queue에 데이터 쓰기
  /// - Cloud Functions의 sendApprovalNotification 트리거가 자동 실행
  /// - Cloud Functions가 FCM 알림 전송 처리
  /// 
  /// Returns: approval request ID
  Future<String> _sendDeviceApprovalRequest({
    required String userId,
    required String newDeviceId,
    required String newDeviceName,
    required String newPlatform,
    required String newDeviceToken,
  }) async {
    try {
      // ignore: avoid_print
      print('📤 [FCM-APPROVAL] 기기 승인 요청 생성 시작');
      
      // 기존 활성 기기들의 토큰 조회 (새 기기 제외)
      final existingTokens = await _firestore
          .collection('fcm_tokens')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();
      
      // 🔑 CRITICAL: Device ID + Platform 조합으로 기기 구분
      // 같은 Device ID라도 플랫폼이 다르면 다른 기기로 취급
      final newDeviceKey = '${newDeviceId}_$newPlatform';
      
      // 새 기기를 제외한 기존 기기들만 필터링
      final otherDeviceTokens = existingTokens.docs
          .where((doc) {
            final data = doc.data();
            final existingDeviceKey = '${data['deviceId']}_${data['platform']}';
            return existingDeviceKey != newDeviceKey;
          })
          .toList();
      
      if (otherDeviceTokens.isEmpty) {
        // ignore: avoid_print
        print('ℹ️ [FCM-APPROVAL] 다른 활성 기기 없음 - 승인 요청 불필요');
        throw Exception('No other devices found');
      }
      
      // ignore: avoid_print
      print('📋 [FCM-APPROVAL] 다른 활성 기기 ${otherDeviceTokens.length}개 발견');
      
      // 🔑 CRITICAL: 문서 ID를 userId_deviceId_platform 형식으로 명시
      // 이렇게 하면 Firestore 보안 규칙에서 docId로 권한 체크 가능
      final approvalRequestId = '${userId}_${newDeviceId}_$newPlatform';
      
      // ignore: avoid_print
      print('📝 [FCM-APPROVAL] 승인 요청 문서 ID: $approvalRequestId');
      
      // Firestore에 승인 요청 저장 (5분 TTL) - .set()으로 명시적 ID 지정
      await _firestore.collection('device_approval_requests').doc(approvalRequestId).set({
        'userId': userId,
        'newDeviceId': newDeviceId,
        'newDeviceName': newDeviceName,
        'newPlatform': newPlatform,
        'newDeviceToken': newDeviceToken,
        'status': 'pending', // pending, approved, rejected, expired
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 5))),
      });
      
      // ignore: avoid_print
      print('✅ [FCM-APPROVAL] 승인 요청 문서 생성: $approvalRequestId');
      
      // ✅ FIXED: Firestore 트리거 방식으로 변경
      // Callable 함수 대신 fcm_approval_notification_queue에 직접 쓰기
      // Cloud Functions의 sendApprovalNotification 트리거가 자동으로 FCM 전송
      
      // 모든 기존 기기에 FCM 알림 큐 등록 (새 기기 제외)
      for (var tokenDoc in otherDeviceTokens) {
        final tokenData = tokenDoc.data();
        final targetToken = tokenData['fcmToken'] as String?;
        final targetDeviceName = tokenData['deviceName'] as String? ?? 'Unknown Device';
        
        if (targetToken == null || targetToken.isEmpty) {
          // ignore: avoid_print
          print('⚠️ [FCM-APPROVAL] FCM 토큰 없음: ${tokenDoc.id}');
          continue;
        }
        
        // ignore: avoid_print
        print('📤 [FCM-APPROVAL] 승인 요청 알림 큐 등록: $targetDeviceName');
        
        // ✅ Firestore에 직접 쓰기 → Cloud Functions 트리거 자동 실행
        await _firestore.collection('fcm_approval_notification_queue').add({
          'targetToken': targetToken,
          'targetDeviceName': targetDeviceName,
          'approvalRequestId': approvalRequestId,
          'newDeviceName': newDeviceName,
          'newPlatform': newPlatform,
          'userId': userId,
          'message': {
            'type': 'device_approval_request',
            'title': '🔐 새 기기 로그인 감지',
            'body': '$newDeviceName ($newPlatform)에서 로그인 시도',
            'approvalRequestId': approvalRequestId,
          },
          'createdAt': FieldValue.serverTimestamp(),
          'processed': false,
        });
        
        // ignore: avoid_print
        print('✅ [FCM-APPROVAL] 알림 큐 등록 완료: $targetDeviceName');
        // ignore: avoid_print
        print('   ⏳ Cloud Functions sendApprovalNotification 트리거 대기 중...');
      }
      
      // ignore: avoid_print
      print('✅ [FCM-APPROVAL] 모든 기존 기기에 승인 요청 큐 등록 완료');
      // ignore: avoid_print
      print('   📡 Cloud Functions가 FCM 알림 전송 처리합니다');
      
      // approval request ID 반환
      return approvalRequestId;
      
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print('❌ [FCM-APPROVAL] 승인 요청 전송 실패: $e');
      // ignore: avoid_print
      print('Stack trace:');
      // ignore: avoid_print
      print(stackTrace);
      rethrow;
    }
  }
  
  /// 기기 승인 대기 (폴링)
  /// 
  /// device_approval_requests 문서의 status 필드를 모니터링하여
  /// approved, rejected, 또는 expired 상태가 될 때까지 대기합니다.
  /// 
  /// Returns: true (승인됨), false (거부됨 또는 시간 초과)
  Future<bool> _waitForDeviceApproval(String approvalRequestId) async {
    try {
      // ignore: avoid_print
      print('⏳ [FCM-WAIT] 기기 승인 대기 시작: $approvalRequestId');
      // ignore: avoid_print
      print('🔒 [FCM-WAIT] 이 함수는 승인/거부/타임아웃까지 계속 대기합니다');
      
      // Firestore 스냅샷 리스너 사용 (실시간 업데이트)
      final stream = _firestore
          .collection('device_approval_requests')
          .doc(approvalRequestId)
          .snapshots();
      
      // 최대 5분 대기 (Cloud Functions에서 설정한 만료 시간과 동일)
      final timeout = DateTime.now().add(const Duration(minutes: 5));
      // ignore: avoid_print
      print('⏰ [FCM-WAIT] 타임아웃 시간: ${timeout.toString()}');
      
      int snapshotCount = 0;
      await for (var snapshot in stream) {
        snapshotCount++;
        // ignore: avoid_print
        print('📡 [FCM-WAIT] 스냅샷 수신 #$snapshotCount');
        
        if (!snapshot.exists) {
          // ignore: avoid_print
          print('❌ [FCM-WAIT] 승인 요청 문서가 삭제됨 - false 반환');
          return false;
        }
        
        final data = snapshot.data();
        if (data == null) {
          // ignore: avoid_print
          print('⚠️ [FCM-WAIT] 문서 데이터가 null - continue');
          continue;
        }
        
        final status = data['status'] as String?;
        
        // ignore: avoid_print
        print('📊 [FCM-WAIT] 현재 상태: $status (타입: ${status.runtimeType})');
        
        if (status == 'approved') {
          // ignore: avoid_print
          print('✅ [FCM-WAIT] 기기 승인됨! - true 반환');
          return true;
        } else if (status == 'rejected') {
          // ignore: avoid_print
          print('❌ [FCM-WAIT] 기기 거부됨 - false 반환');
          return false;
        } else if (status == 'expired') {
          // ignore: avoid_print
          print('⏰ [FCM-WAIT] 승인 요청 만료됨 - false 반환');
          return false;
        }
        
        // 시간 초과 체크
        final now = DateTime.now();
        if (now.isAfter(timeout)) {
          // ignore: avoid_print
          print('⏰ [FCM-WAIT] 승인 대기 시간 초과 (5분) - false 반환');
          // ignore: avoid_print
          print('   현재 시간: ${now.toString()}');
          // ignore: avoid_print
          print('   타임아웃: ${timeout.toString()}');
          return false;
        }
        
        // ignore: avoid_print
        print('⏳ [FCM-WAIT] 계속 대기 중... (남은 시간: ${timeout.difference(now).inSeconds}초)');
      }
      
      // ignore: avoid_print
      print('⚠️ [FCM-WAIT] 스트림이 비정상 종료됨 - false 반환');
      return false;
      
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print('❌ [FCM-WAIT] 승인 대기 오류: $e');
      // ignore: avoid_print
      print('Stack trace: $stackTrace');
      return false;
    }
  }
  
  /// 포그라운드 메시지 처리
  void _handleForegroundMessage(RemoteMessage message) {
    // ignore: avoid_print
    print('');
    // ignore: avoid_print
    print('═══════════════════════════════════════════════');
    // ignore: avoid_print
    print('📨 [FLUTTER-FCM] _handleForegroundMessage() 호출됨!');
    // ignore: avoid_print
    print('═══════════════════════════════════════════════');
    // ignore: avoid_print
    print('📨 포그라운드 메시지: ${message.notification?.title}');
    // ignore: avoid_print
    print('📨 메시지 데이터: ${message.data}');
    // ignore: avoid_print
    print('🔍 [FCM-DEBUG] 전체 메시지 구조:');
    // ignore: avoid_print
    print('   - messageId: ${message.messageId}');
    // ignore: avoid_print
    print('   - notification.title: ${message.notification?.title}');
    // ignore: avoid_print
    print('   - notification.body: ${message.notification?.body}');
    // ignore: avoid_print
    print('   - data keys: ${message.data.keys.toList()}');
    message.data.forEach((key, value) {
      // ignore: avoid_print
      print('   - data[$key]: $value (${value.runtimeType})');
    });
    
    // 🔐 강제 로그아웃 메시지 처리 (레거시)
    if (message.data['type'] == 'force_logout') {
      _handleForceLogout(message);
      return;
    }
    
    // 🔔 기기 승인 요청 메시지 처리
    // ✅ FIX: 포그라운드에서도 즉시 다이얼로그 표시
    if (message.data['type'] == 'device_approval_request') {
      // ignore: avoid_print
      print('🔔 [FCM] 기기 승인 요청 - 즉시 다이얼로그 표시');
      _handleDeviceApprovalRequest(message);
      return; // 알림 표시하지 않고 즉시 다이얼로그만 표시
    }
    
    // ✅ 기기 승인 응답 메시지 처리 (즉시 처리)
    if (message.data['type'] == 'device_approval_response') {
      _handleDeviceApprovalResponse(message);
      return;
    }
    
    // 📞 수신 전화 메시지 처리 (Android와 iOS 모두 지원)
    // Android: type == 'incoming_call'
    // iOS: linkedid가 있으면 수신 전화로 간주
    final hasIncomingCallType = message.data['type'] == 'incoming_call';
    final hasLinkedId = message.data['linkedid'] != null && 
                        (message.data['linkedid'] as String).isNotEmpty;
    final hasCallType = message.data['call_type'] != null;
    
    // ignore: avoid_print
    print('🔍 [FCM-DEBUG] 수신 전화 조건 체크:');
    // ignore: avoid_print
    print('   - hasIncomingCallType: $hasIncomingCallType (type=${message.data['type']})');
    // ignore: avoid_print
    print('   - hasLinkedId: $hasLinkedId (linkedid=${message.data['linkedid']})');
    // ignore: avoid_print
    print('   - hasCallType: $hasCallType (call_type=${message.data['call_type']})');
    // ignore: avoid_print
    print('   - 최종 조건: ${hasIncomingCallType || (hasLinkedId && hasCallType)}');
    
    if (hasIncomingCallType || (hasLinkedId && hasCallType)) {
      // ignore: avoid_print
      print('📞 [FCM] 수신 전화 감지:');
      // ignore: avoid_print
      print('   - type: ${message.data['type']}');
      // ignore: avoid_print
      print('   - linkedid: ${message.data['linkedid']}');
      // ignore: avoid_print
      print('   - call_type: ${message.data['call_type']}');
      _handleIncomingCallFCM(message);
      return;
    } else {
      // ignore: avoid_print
      print('⚠️ [FCM-DEBUG] 수신 전화 조건 불만족 - 일반 알림으로 처리');
    }
    
    // 📥 사용자 알림 설정 확인 (알림 표시 전 체크) - 동기 함수에서 비동기 호출 불가능하므로 주석 처리
    // 대신 _showAndroidNotification(), _showWebNotification(), _showIOSNotification() 내부에서 체크
    
    // 웹 플랫폼: 브라우저 알림 표시
    if (kIsWeb) {
      _showWebNotification(message);
    }
    
    // 안드로이드 플랫폼: 로컬 알림 표시
    if (Platform.isAndroid) {
      _showAndroidNotification(message);
    }
    
    // iOS 플랫폼: DialogUtils로 알림 표시 (네이티브 알림은 AppDelegate에서 비활성화됨)
    if (Platform.isIOS) {
      _showIOSNotification(message);
    }
  }
  
  /// 백그라운드/종료 상태에서 알림 클릭 시 처리
  /// 
  /// 사용자가 알림바에서 알림을 클릭하면 호출됩니다.
  void _handleMessageOpenedApp(RemoteMessage message) {
    // ignore: avoid_print
    print('');
    // ignore: avoid_print
    print('═══════════════════════════════════════════════');
    // ignore: avoid_print
    print('🔔 [FLUTTER-FCM] _handleMessageOpenedApp() 호출됨!');
    // ignore: avoid_print
    print('═══════════════════════════════════════════════');
    // ignore: avoid_print
    print('🔔 [FCM] 백그라운드 알림 클릭됨: ${message.notification?.title}');
    // ignore: avoid_print
    print('🔔 [FCM] 메시지 데이터: ${message.data}');
    
    // 🔐 강제 로그아웃 메시지 처리 (레거시)
    if (message.data['type'] == 'force_logout') {
      _handleForceLogout(message);
      return;
    }
    
    // 🔔 기기 승인 요청 메시지 처리 (알림 클릭 시 다이얼로그 표시)
    if (message.data['type'] == 'device_approval_request') {
      // ignore: avoid_print
      print('🔔 [FCM] 기기 승인 요청 알림 클릭 - Context 대기 후 다이얼로그 표시');
      // 🔧 FIX: iOS에서 context가 준비되지 않을 수 있으므로 대기
      _waitForContextAndShowApprovalDialog(message);
      return;
    }
    
    // ✅ 기기 승인 응답 메시지 처리
    if (message.data['type'] == 'device_approval_response') {
      _handleDeviceApprovalResponse(message);
      return;
    }
    
    // 📞 수신 전화 메시지 처리 (Android와 iOS 모두 지원)
    // Android: type == 'incoming_call'
    // iOS: linkedid가 있으면 수신 전화로 간주
    final hasIncomingCallType = message.data['type'] == 'incoming_call';
    final hasLinkedId = message.data['linkedid'] != null && 
                        (message.data['linkedid'] as String).isNotEmpty;
    final hasCallType = message.data['call_type'] != null;
    
    if (hasIncomingCallType || (hasLinkedId && hasCallType)) {
      debugPrint('📞 [FCM] 백그라운드에서 수신 전화 화면 표시 시작...');
      debugPrint('   - type: ${message.data['type']}');
      debugPrint('   - linkedid: ${message.data['linkedid']}');
      debugPrint('   - call_type: ${message.data['call_type']}');
      _waitForContextAndShowIncomingCall(message);
      return;
    }
  }
  
  /// FCM 수신 전화 메시지 처리
  /// 
  /// DCMIWS 웹소켓 연결이 중지되었을 때 FCM으로 수신전화를 처리합니다.
  Future<void> _handleIncomingCallFCM(RemoteMessage message) async {
    // ignore: avoid_print
    print('📞 [FCM-INCOMING] 수신 전화 FCM 메시지 처리 시작');
    // ignore: avoid_print
    print('   - Platform: ${Platform.isAndroid ? 'Android' : (Platform.isIOS ? 'iOS' : 'Other')}');
    // ignore: avoid_print
    print('   - Message data: ${message.data}');
    
    // WebSocket 연결 상태 확인
    try {
      final dcmiwsService = DCMIWSService();
      final isConnected = dcmiwsService.isConnected;
      // ignore: avoid_print
      print('🔍 [FCM-INCOMING] WebSocket 연결 상태: $isConnected');
      
      if (isConnected) {
        // ignore: avoid_print
        print('✅ [FCM-INCOMING] WebSocket 연결 활성 - 웹소켓으로 처리 (FCM 무시)');
        return; // WebSocket이 활성이면 FCM 무시
      }
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ [FCM-INCOMING] WebSocket 상태 확인 오류 (무시하고 계속): $e');
    }
    
    // ignore: avoid_print
    print('⚠️ [FCM-INCOMING] WebSocket 연결 없음 - FCM으로 처리');
    // ignore: avoid_print
    print('📞 [FCM-INCOMING] _showIncomingCallScreen() 호출 시작...');
    
    try {
      // 풀스크린 수신 전화 화면 표시 (통화 기록 생성 포함)
      await _showIncomingCallScreen(message);
      // ignore: avoid_print
      print('✅ [FCM-INCOMING] _showIncomingCallScreen() 호출 완료');
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print('❌ [FCM-INCOMING] _showIncomingCallScreen() 오류: $e');
      // ignore: avoid_print
      print('Stack trace: $stackTrace');
    }
  }
  
  /// Context가 준비될 때까지 대기 후 수신전화 화면 표시 (백그라운드용)
  Future<void> _waitForContextAndShowIncomingCall(RemoteMessage message) async {
    int retryCount = 0;
    const maxRetries = 30; // 3초 (100ms * 30)
    
    while (retryCount < maxRetries) {
      final context = _context ?? navigatorKey.currentContext;
      
      if (context != null) {
        debugPrint('✅ [FCM-INCOMING] Context 준비 완료 (${retryCount * 100}ms 대기)');
        
        // WebSocket 연결 상태 확인
        final dcmiwsService = DCMIWSService();
        if (dcmiwsService.isConnected) {
          debugPrint('✅ [FCM-INCOMING] WebSocket 연결 활성 - FCM 무시');
          return;
        }
        
        // 풀스크린 수신 전화 화면 표시 (통화 기록 생성 포함)
        await _showIncomingCallScreen(message);
        return;
      }
      
      debugPrint('⏳ [FCM-INCOMING] Context 대기 중... (${retryCount + 1}/$maxRetries)');
      await Future.delayed(const Duration(milliseconds: 100));
      retryCount++;
    }
    
    debugPrint('❌ [FCM-INCOMING] Context 타임아웃 (3초 대기 후에도 Context 없음)');
  }
  
  /// 🔧 NEW: Context 준비 대기 후 기기 승인 다이얼로그 표시
  Future<void> _waitForContextAndShowApprovalDialog(RemoteMessage message) async {
    // ignore: avoid_print
    print('');
    // ignore: avoid_print
    print('🔄 [FCM-APPROVAL-DIALOG] Context 대기 시작...');
    // ignore: avoid_print
    print('   🍎 iOS 알림 탭 → 앱 포그라운드 전환 대기 중...');
    
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
      // ignore: avoid_print
      print('');
      // ignore: avoid_print
      print('❌ [FCM-APPROVAL-DIALOG] Context 타임아웃!');
      // ignore: avoid_print
      print('   - 5초 대기 후에도 Context 없음');
      // ignore: avoid_print
      print('   - 앱이 백그라운드에 있거나 종료된 상태일 수 있음');
      // ignore: avoid_print
      print('💡 [FCM-APPROVAL-DIALOG] 사용자는 프로필 → 활성 세션에서 수동으로 승인 가능');
      print('');
      return;
    }
    
    final context = _context ?? navigatorKey.currentContext;
    
    // ignore: avoid_print
    print('🔍 [FCM-APPROVAL-DIALOG] 재시도 ${attempt + 1}/$maxAttempts');
    // ignore: avoid_print
    print('   - _context: ${_context != null ? "✅" : "❌"}');
    // ignore: avoid_print
    print('   - navigatorKey.currentContext: ${navigatorKey.currentContext != null ? "✅" : "❌"}');
    
    if (context != null && context.mounted) {
      // ignore: avoid_print
      print('✅ [FCM-APPROVAL-DIALOG] Context 준비 완료!');
      // ignore: avoid_print
      print('   - 대기 시간: ${(attempt + 1) * 100}ms');
      // ignore: avoid_print
      print('   - 다이얼로그 표시 시작...');
      print('');
      
      // 🔧 FIX: WidgetsBinding.addPostFrameCallback으로 안전하게 표시
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // ignore: avoid_print
        print('📲 [FCM-APPROVAL-DIALOG] PostFrameCallback 실행 - 다이얼로그 표시');
        
        // 기기 승인 요청 메시지 처리
        _handleDeviceApprovalRequest(message);
      });
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
    // ignore: avoid_print
    print('');
    // ignore: avoid_print
    print('🔔 [FCM-APPROVAL] handlePendingApprovalRequest() 호출됨 (Public)');
    // ignore: avoid_print
    print('   - 앱이 포그라운드로 돌아와서 보류 중인 승인 요청 처리');
    
    // Context 대기 후 다이얼로그 표시
    _waitForContextAndShowApprovalDialog(message);
  }
  
  /// 기기 승인 요청 메시지 처리
  /// 
  /// 새 기기에서 로그인 시도 시 기존 기기에서 승인 다이얼로그를 표시합니다.
  void _handleDeviceApprovalRequest(RemoteMessage message) {
    // ignore: avoid_print
    print('');
    // ignore: avoid_print
    print('═══════════════════════════════════════════════');
    // ignore: avoid_print
    print('🔔 [FCM-APPROVAL] _handleDeviceApprovalRequest() 호출됨');
    // ignore: avoid_print
    print('═══════════════════════════════════════════════');
    
    final approvalRequestId = message.data['approvalRequestId'] as String?;
    final newDeviceName = message.data['newDeviceName'] ?? '알 수 없는 기기';
    final newPlatform = message.data['newPlatform'] ?? 'unknown';
    
    // ignore: avoid_print
    print('📋 [FCM-APPROVAL] 메시지 데이터:');
    // ignore: avoid_print
    print('   - approvalRequestId: $approvalRequestId');
    // ignore: avoid_print
    print('   - newDeviceName: $newDeviceName');
    // ignore: avoid_print
    print('   - newPlatform: $newPlatform');
    
    if (approvalRequestId == null) {
      // ignore: avoid_print
      print('❌ [FCM-APPROVAL] approvalRequestId 없음 - 처리 중단');
      print('');
      return;
    }
    
    // 🔧 FIX: Context 즉시 확인
    final context = _context ?? navigatorKey.currentContext;
    
    // ignore: avoid_print
    print('🔍 [FCM-APPROVAL] Context 상태 확인:');
    // ignore: avoid_print
    print('   - _context: ${_context != null ? "존재" : "null"}');
    // ignore: avoid_print
    print('   - navigatorKey.currentContext: ${navigatorKey.currentContext != null ? "존재" : "null"}');
    // ignore: avoid_print
    print('   - context (final): ${context != null ? "존재" : "null"}');
    
    if (context == null) {
      // ignore: avoid_print
      print('⏳ [FCM-APPROVAL] BuildContext 없음 - Context 준비 대기 시작');
      _waitForContextAndShowApprovalDialog(message);
      return;
    }
    
    // ignore: avoid_print
    print('✅ [FCM-APPROVAL] Context 존재 - 즉시 다이얼로그 표시');
    print('');
    
    // 기기 승인 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.security, color: Colors.blue, size: 28),
            SizedBox(width: 12),
            Text('🔐 새 기기 로그인 감지'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '새 기기에서 로그인을 시도하고 있습니다.',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.devices, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '기기: $newDeviceName',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.phone_android, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        '플랫폼: $newPlatform',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '본인이 맞다면 승인 버튼을 클릭하세요.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              // ignore: avoid_print
              print('🔘 [FCM-APPROVAL] 거부 버튼 클릭됨');
              
              // 🔧 FIX: 다이얼로그를 먼저 닫고, 거부 처리는 백그라운드에서 실행
              if (context.mounted) {
                Navigator.of(context).pop();
                // ignore: avoid_print
                print('✅ [FCM-APPROVAL] 다이얼로그 즉시 닫힘');
              }
              
              // 거부 처리는 비동기로 백그라운드 실행
              _rejectDeviceApproval(approvalRequestId).then((_) {
                // ignore: avoid_print
                print('✅ [FCM-APPROVAL] 거부 처리 완료');
              }).catchError((e) {
                // ignore: avoid_print
                print('❌ [FCM-APPROVAL] 거부 처리 오류: $e');
              });
            },
            child: const Text('거부', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              // ignore: avoid_print
              print('🔘 [FCM-APPROVAL] 승인 버튼 클릭됨');
              
              // 🔧 FIX: 다이얼로그를 먼저 닫고, 승인 처리는 백그라운드에서 실행
              if (context.mounted) {
                Navigator.of(context).pop();
                // ignore: avoid_print
                print('✅ [FCM-APPROVAL] 다이얼로그 즉시 닫힘');
              }
              
              // 승인 처리는 비동기로 백그라운드 실행
              _approveDeviceApproval(approvalRequestId).then((_) {
                // ignore: avoid_print
                print('✅ [FCM-APPROVAL] 승인 처리 완료');
              }).catchError((e) {
                // ignore: avoid_print
                print('❌ [FCM-APPROVAL] 승인 처리 오류: $e');
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            child: const Text('승인', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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
        duration: const Duration(seconds: 2),
      );
    } else {
      debugPrint('❌ [FCM] 기기 승인 거부됨 - 로그인 취소');
      
      // 거부 다이얼로그
      await DialogUtils.showError(
        context,
        '$deviceName에서 거부되었습니다',
        duration: const Duration(seconds: 2),
      );
      
      // 로그아웃 처리
      if (_onForceLogout != null) {
        _onForceLogout!();
      }
    }
  }
  
  /// 기기 승인 처리
  Future<void> _approveDeviceApproval(String approvalRequestId) async {
    try {
      debugPrint('✅ [FCM] 기기 승인 처리 시작: $approvalRequestId');
      
      // 🔄 네트워크 안정화 대기 (iOS 백그라운드→포그라운드 전환 시)
      if (Platform.isIOS) {
        debugPrint('⏳ [FCM] iOS: 네트워크 안정화 대기 (2초)...');
        await Future.delayed(const Duration(seconds: 2));
      }
      
      // 🔄 재시도 로직 추가 (최대 3번)
      int retryCount = 0;
      const maxRetries = 3;
      bool success = false;
      
      while (retryCount < maxRetries && !success) {
        try {
          debugPrint('🔄 [FCM] Firestore 승인 업데이트 시도 ${retryCount + 1}/$maxRetries');
          
          // Firestore에서 승인 요청 문서 업데이트
          await _firestore.collection('device_approval_requests').doc(approvalRequestId).update({
            'status': 'approved',
            'approvedAt': FieldValue.serverTimestamp(),
          }).timeout(const Duration(seconds: 10));  // 10초 타임아웃
          
          success = true;
          debugPrint('✅ [FCM] Firestore 승인 완료');
          
        } catch (e) {
          retryCount++;
          debugPrint('⚠️  [FCM] Firestore 승인 실패 (시도 $retryCount/$maxRetries): $e');
          
          if (retryCount < maxRetries) {
            // 지수 백오프 (1초, 2초, 4초)
            final delaySeconds = retryCount * retryCount;
            debugPrint('⏳ [FCM] ${delaySeconds}초 후 재시도...');
            await Future.delayed(Duration(seconds: delaySeconds));
          } else {
            debugPrint('❌ [FCM] Firestore 승인 최종 실패');
            rethrow;
          }
        }
      }
      
      // 승인 응답 알림 전송 준비는 Cloud Functions에서 처리
      
    } catch (e, stackTrace) {
      debugPrint('❌ [FCM] 기기 승인 처리 오류: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }
  
  /// 기기 승인 거부 처리
  Future<void> _rejectDeviceApproval(String approvalRequestId) async {
    try {
      debugPrint('❌ [FCM] 기기 승인 거부 처리 시작: $approvalRequestId');
      
      // Firestore에서 승인 요청 문서 업데이트
      await _firestore.collection('device_approval_requests').doc(approvalRequestId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ [FCM] Firestore 거부 완료');
      
      // 거부 응답 알림 전송 준비는 Cloud Functions에서 처리
      
    } catch (e, stackTrace) {
      debugPrint('❌ [FCM] 기기 승인 거부 처리 오류: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }
  
  /// 안드로이드 로컬 알림 표시 (포그라운드 전용)
  Future<void> _showAndroidNotification(RemoteMessage message) async {
    if (!Platform.isAndroid) return;
    
    try {
      final title = message.notification?.title ?? message.data['title'] ?? 'MAKECALL 알림';
      final body = message.notification?.body ?? message.data['body'] ?? '새로운 알림이 있습니다.';
      
      debugPrint('🔔 [FCM] 안드로이드 알림 표시 시작');
      debugPrint('   제목: $title');
      debugPrint('   내용: $body');
      
      // 📥 사용자 알림 설정 가져오기
      String? userId;
      
      // _context가 있으면 AuthService에서 userId 가져오기
      if (_context != null) {
        try {
          final authService = Provider.of<AuthService>(_context!, listen: false);
          userId = authService.currentUser?.uid;
        } catch (e) {
          debugPrint('⚠️ [FCM-알림설정] AuthService 접근 실패: $e');
        }
      }
      
      Map<String, dynamic>? settings;
      
      if (userId != null) {
        settings = await getUserNotificationSettings(userId);
        debugPrint('📦 [FCM-알림설정] 사용자 설정: $settings');
      } else {
        debugPrint('⚠️ [FCM-알림설정] userId 없음 - 기본 설정 사용');
      }
      
      // 알림 설정 적용 (기본값: 모두 켜짐)
      final pushEnabled = settings?['pushEnabled'] ?? true;
      final soundEnabled = settings?['soundEnabled'] ?? true;
      final vibrationEnabled = settings?['vibrationEnabled'] ?? true;
      
      debugPrint('🔧 [FCM-알림설정] 적용:');
      debugPrint('   - 푸시 알림: $pushEnabled');
      debugPrint('   - 알림음: $soundEnabled');
      debugPrint('   - 진동: $vibrationEnabled');
      
      // 푸시 알림이 꺼져있으면 알림 표시 안함
      if (!pushEnabled) {
        debugPrint('⏭️ [FCM] 푸시 알림이 비활성화되어 알림 표시 건너뜀');
        return;
      }
      
      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();
      
      // 알림 상세 설정 (사용자 설정 적용)
      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'high_importance_channel', // channelId (AndroidManifest.xml과 동일)
        'High Importance Notifications', // channelName
        channelDescription: 'This channel is used for important notifications.',
        importance: Importance.high,
        priority: Priority.high,
        playSound: soundEnabled, // 🔊 사용자 설정 적용
        enableVibration: vibrationEnabled, // 📳 사용자 설정 적용
        icon: '@mipmap/ic_launcher', // 앱 아이콘 사용
      );
      
      // ✅ const 제거: androidDetails가 런타임에 계산되므로 const 사용 불가
      final NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
      );
      
      // 알림 표시
      await flutterLocalNotificationsPlugin.show(
        message.hashCode, // 고유 알림 ID (메시지마다 다름)
        title,
        body,
        notificationDetails,
      );
      
      debugPrint('✅ [FCM] 안드로이드 알림 표시 완료 (진동: $vibrationEnabled)');
      
    } catch (e) {
      debugPrint('❌ [FCM] 안드로이드 알림 표시 오류: $e');
    }
  }
  
  /// 웹 플랫폼 알림 표시
  Future<void> _showWebNotification(RemoteMessage message) async {
    if (!kIsWeb) return;
    
    try {
      final title = message.notification?.title ?? message.data['title'] ?? 'MakeCall 알림';
      final body = message.notification?.body ?? message.data['body'] ?? '새로운 알림';
      
      if (kDebugMode) {
        debugPrint('🌐 웹 알림 표시: $title - $body');
      }
      
      // 웹 알림은 서비스 워커에서 처리됨
      // 여기서는 앱 내 다이얼로그로 표시
      if (_context != null) {
        await DialogUtils.showInfo(
          _context!,
          body,
          title: title,
          duration: const Duration(seconds: 5),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 웹 알림 표시 오류: $e');
      }
    }
  }
  
  /// iOS 플랫폼 알림 표시 (DialogUtils 사용)
  Future<void> _showIOSNotification(RemoteMessage message) async {
    if (!Platform.isIOS) return;
    
    try {
      final title = message.notification?.title ?? message.data['title'] ?? 'MAKECALL 알림';
      final body = message.notification?.body ?? message.data['body'] ?? '새로운 알림이 있습니다.';
      
      debugPrint('🍎 [FCM] iOS 알림 표시 시작');
      debugPrint('   제목: $title');
      debugPrint('   내용: $body');
      
      // 📥 사용자 알림 설정 가져오기
      String? userId;
      
      // _context가 있으면 AuthService에서 userId 가져오기
      if (_context != null) {
        try {
          final authService = Provider.of<AuthService>(_context!, listen: false);
          userId = authService.currentUser?.uid;
        } catch (e) {
          debugPrint('⚠️ [FCM-알림설정-iOS] AuthService 접근 실패: $e');
        }
      }
      
      Map<String, dynamic>? settings;
      
      if (userId != null) {
        settings = await getUserNotificationSettings(userId);
        debugPrint('📦 [FCM-알림설정-iOS] 사용자 설정: $settings');
      } else {
        debugPrint('⚠️ [FCM-알림설정-iOS] userId 없음 - 기본 설정 사용');
      }
      
      // 알림 설정 적용 (기본값: 모두 켜짐)
      final pushEnabled = settings?['pushEnabled'] ?? true;
      
      debugPrint('🔧 [FCM-알림설정-iOS] 적용:');
      debugPrint('   - 푸시 알림: $pushEnabled');
      
      // 푸시 알림이 꺼져있으면 알림 표시 안함
      if (!pushEnabled) {
        debugPrint('⏭️ [FCM-iOS] 푸시 알림이 비활성화되어 알림 표시 건너뜀');
        return;
      }
      
      // _context가 있으면 DialogUtils로 알림 표시
      if (_context != null) {
        await DialogUtils.showInfo(
          _context!,
          body,
          title: title,
          duration: const Duration(seconds: 5),
        );
        debugPrint('✅ [FCM-iOS] 알림 다이얼로그 표시 완료');
      } else {
        debugPrint('⚠️ [FCM-iOS] BuildContext 없음 - 알림 표시 불가');
      }
      
    } catch (e) {
      debugPrint('❌ [FCM-iOS] 알림 표시 오류: $e');
    }
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
  
  /// 수신 전화 풀스크린 표시
  Future<void> _showIncomingCallScreen(RemoteMessage message) async {
    // ignore: avoid_print
    print('🎬 [FCM-SCREEN] _showIncomingCallScreen() 시작');
    // ignore: avoid_print
    print('   - _context: ${_context != null ? '있음' : '없음'}');
    // ignore: avoid_print
    print('   - navigatorKey.currentContext: ${navigatorKey.currentContext != null ? '있음' : '없음'}');
    
    // BuildContext 또는 NavigatorKey 확인
    final context = _context ?? navigatorKey.currentContext;
    
    if (context == null) {
      // ignore: avoid_print
      print('❌ [FCM-SCREEN] BuildContext와 NavigatorKey 모두 사용 불가');
      // ignore: avoid_print
      print('💡 main.dart에서 FCMService.setContext()를 호출하거나 앱이 완전히 시작될 때까지 기다리세요');
      // ignore: avoid_print
      print('🔧 해결 방법:');
      // ignore: avoid_print
      print('   1. main.dart에서 FCMService.setContext(context) 호출 확인');
      // ignore: avoid_print
      print('   2. navigatorKey가 MaterialApp에 설정되었는지 확인');
      return;
    }
    
    // ignore: avoid_print
    print('✅ [FCM-SCREEN] Context 확인 완료 (${_context != null ? "setContext" : "navigatorKey"} 사용)');
    
    // 📋 메시지 데이터에서 정보 추출
    // iOS와 Android 모두 지원 (caller_num, caller_name 등)
    final callerName = message.data['caller_name'] ?? 
                       message.data['callerName'] ?? 
                       message.notification?.title?.split(' ').first ?? 
                       '알 수 없음';
    
    final callerNumber = message.data['caller_num'] ?? 
                         message.data['caller_number'] ?? 
                         message.data['callerNumber'] ?? 
                         _extractPhoneNumber(message.notification?.title) ??
                         _extractPhoneNumber(message.notification?.body) ??
                         '번호 없음';
    
    final callerAvatar = message.data['caller_avatar'] ?? 
                         message.data['callerAvatar'];
    
    // 통화 관련 메타데이터
    final channel = message.data['channel'] ?? '';
    
    final linkedid = message.data['linkedid'] ?? 
                     message.data['linkedId'] ?? 
                     DateTime.now().millisecondsSinceEpoch.toString();
    
    final receiverNumber = message.data['receiver_number'] ?? 
                           message.data['receiverNumber'] ?? 
                           message.data['extension'] ??
                           message.data['did'] ??
                           '';
    
    final callType = message.data['call_type'] ?? 
                     message.data['callType'] ?? 
                     message.data['type'] ??
                     'voice'; // iOS FCM에서는 voice로 전송됨
    
    // ignore: avoid_print
    print('📞 [FCM-SCREEN] 수신 전화 데이터 추출:');
    // ignore: avoid_print
    print('   발신자: $callerName');
    // ignore: avoid_print
    print('   번호: $callerNumber');
    // ignore: avoid_print
    print('   아바타: ${callerAvatar ?? "없음"}');
    // ignore: avoid_print
    print('   채널: $channel');
    // ignore: avoid_print
    print('   링크ID: $linkedid');
    // ignore: avoid_print
    print('   수신번호: $receiverNumber');
    // ignore: avoid_print
    print('   통화타입: $callType');
    
    // 💾 통화 기록 생성 (call_history) - 네트워크 오류에도 불구하고 화면은 표시
    // ignore: avoid_print
    print('📝 [FCM-SCREEN] 통화 기록 생성 시도 중...');
    await _createCallHistory(
      callerNumber: callerNumber,
      callerName: callerName,
      receiverNumber: receiverNumber,
      linkedid: linkedid,
      channel: channel,
      callType: callType,
    );
    // ignore: avoid_print
    print('📝 [FCM-SCREEN] 통화 기록 생성 완료 (또는 실패)');
    
    print('🎬 [FCM] 수신 전화 화면 표시');
    
    // 수신 전화 화면 표시 (fullscreenDialog로 전체 화면)
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => IncomingCallScreen(
          callerName: callerName,
          callerNumber: callerNumber,
          callerAvatar: callerAvatar,
          channel: channel,
          linkedid: linkedid,
          receiverNumber: receiverNumber,
          callType: callType,
          onAccept: () async {
            debugPrint('✅ [FCM] 전화 수락: $callerName');
            Navigator.of(context).pop();
            
            // TODO: 전화 수락 로직 구현
            await DialogUtils.showSuccess(
              context,
              '전화 수락: $callerName',
              duration: const Duration(seconds: 2),
            );
          },
          onReject: () async {
            debugPrint('❌ [FCM] 전화 거절: $callerName');
            Navigator.of(context).pop();
            
            // TODO: 전화 거절 로직 구현
            await DialogUtils.showError(
              context,
              '전화 거절: $callerName',
              duration: const Duration(seconds: 2),
            );
          },
        ),
      ),
    );
    
    // ✅ 수신 알림 화면에서 "확인" 버튼 눌렀을 때 최근통화 탭으로 이동
    if (result != null && result['moveToTab'] != null) {
      final targetTabIndex = result['moveToTab'] as int;
      print('📲 [FCM] 최근통화 탭으로 이동 요청: index=$targetTabIndex');
      
      // CallTab으로 이동하기 위해 현재 route를 최근통화 탭으로 교체
      if (context.mounted) {
        // Navigator의 현재 route를 MainScreen으로 교체하되, 인자로 탭 인덱스 전달
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => MainScreen(initialTabIndex: targetTabIndex), // const 제거
          ),
        );
      }
    }
    
    print('✅ [FCM] 수신 전화 처리 완료');
  }
  
  /// 사용자 알림 설정 가져오기
  Future<Map<String, dynamic>?> getUserNotificationSettings(String userId) async {
    try {
      final doc = await _firestore
          .collection('user_notification_settings')
          .doc(userId)
          .get();
      
      if (doc.exists) {
        return doc.data();
      }
      
      // 기본 설정 반환
      return {
        'pushEnabled': true,
        'soundEnabled': true,
        'vibrationEnabled': true,
        'incomingCallNotification': true,
        'missedCallNotification': true,
        'messageNotification': true,
        'quietHoursEnabled': false,
        'quietHoursStart': '22:00',
        'quietHoursEnd': '08:00',
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 알림 설정 조회 오류: $e');
      }
      return null;
    }
  }
  
  /// 사용자 알림 설정 업데이트
  Future<void> updateNotificationSettings(
    String userId,
    Map<String, dynamic> settings,
  ) async {
    try {
      await _firestore
          .collection('user_notification_settings')
          .doc(userId)
          .set({
        ...settings,
        'userId': userId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      if (kDebugMode) {
        debugPrint('✅ 알림 설정 업데이트 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 알림 설정 업데이트 오류: $e');
      }
      rethrow;
    }
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
  Future<void> deactivateToken(String userId) async {
    if (_fcmToken == null) return;
    
    try {
      final deviceId = await _getDeviceId();
      await _databaseService.deleteFcmToken(userId, deviceId);
      debugPrint('✅ FCM 토큰 비활성화 완료');
    } catch (e) {
      debugPrint('❌ FCM 토큰 비활성화 오류: $e');
    }
  }
  
  /// 기기 ID 가져오기
  /// 
  /// FCM 토큰과 함께 사용하여 기기를 고유하게 식별합니다.
  /// 중복 로그인 방지에 사용됩니다.
  Future<String> _getDeviceId() async {
    try {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      
      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        // 웹: 브라우저 + OS 조합으로 ID 생성
        return 'web_${webInfo.browserName.name}_${webInfo.platform ?? "unknown"}';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        // Android: androidId 사용 (고유한 기기 식별자)
        return androidInfo.id; // Example: "5d513e7a5fb1e2d5"
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        // iOS: identifierForVendor 사용 (앱 삭제 시 변경됨)
        return iosInfo.identifierForVendor ?? 'ios_${DateTime.now().millisecondsSinceEpoch}';
      }
      
      // Fallback: FCM 토큰의 일부를 ID로 사용
      if (_fcmToken != null) {
        return _fcmToken!.substring(0, 50);
      }
      
      return 'unknown_device_${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      debugPrint('⚠️ 기기 ID 조회 실패: $e');
      return 'fallback_device_${DateTime.now().millisecondsSinceEpoch}';
    }
  }
  
  /// 기기 이름 가져오기
  /// 
  /// 사용자에게 표시할 기기 이름을 반환합니다.
  /// 실제 기기 모델명과 OS 버전을 포함합니다.
  Future<String> _getDeviceName() async {
    try {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      
      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        // 웹: 브라우저 이름 + OS
        final browser = webInfo.browserName.name;
        final platform = webInfo.platform ?? 'Unknown OS';
        return '$browser on $platform';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        // Android: 제조사 + 모델명
        // 예: "Samsung Galaxy S21", "Google Pixel 6"
        final manufacturer = androidInfo.manufacturer;
        final model = androidInfo.model;
        return '$manufacturer $model';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        // iOS: 모델명 + iOS 버전
        // 예: "iPhone 15 Pro", "iPad Pro"
        final model = iosInfo.utsname.machine; // 예: "iPhone14,3"
        final name = iosInfo.name; // 예: "iPhone"
        final version = iosInfo.systemVersion; // 예: "17.0"
        
        // 사용자 친화적인 모델명 변환
        final friendlyName = _getiOSFriendlyName(model);
        return '$friendlyName (iOS $version)';
      }
      
      return 'Unknown Device';
    } catch (e) {
      debugPrint('⚠️ 기기 이름 조회 실패: $e');
      
      // Fallback: 플랫폼 기본 이름
      if (kIsWeb) {
        return 'Web Browser';
      } else if (Platform.isAndroid) {
        return 'Android Device';
      } else if (Platform.isIOS) {
        return 'iOS Device';
      }
      return 'Unknown Device';
    }
  }
  
  /// iOS 기기 코드를 사용자 친화적인 이름으로 변환
  /// 
  /// 예: "iPhone14,3" → "iPhone 13 Pro Max"
  String _getiOSFriendlyName(String machineCode) {
    // 주요 iPhone 모델 매핑 (최신 모델 위주)
    final Map<String, String> iosModels = {
      // iPhone 15 시리즈
      'iPhone16,1': 'iPhone 15 Pro',
      'iPhone16,2': 'iPhone 15 Pro Max',
      'iPhone15,4': 'iPhone 15',
      'iPhone15,5': 'iPhone 15 Plus',
      
      // iPhone 14 시리즈
      'iPhone15,2': 'iPhone 14 Pro',
      'iPhone15,3': 'iPhone 14 Pro Max',
      'iPhone14,7': 'iPhone 14',
      'iPhone14,8': 'iPhone 14 Plus',
      
      // iPhone 13 시리즈
      'iPhone14,2': 'iPhone 13 Pro',
      'iPhone14,3': 'iPhone 13 Pro Max',
      'iPhone14,4': 'iPhone 13 Mini',
      'iPhone14,5': 'iPhone 13',
      
      // iPhone 12 시리즈
      'iPhone13,1': 'iPhone 12 Mini',
      'iPhone13,2': 'iPhone 12',
      'iPhone13,3': 'iPhone 12 Pro',
      'iPhone13,4': 'iPhone 12 Pro Max',
      
      // iPad 시리즈 (주요 모델)
      'iPad13,18': 'iPad Pro 12.9" (6th gen)',
      'iPad13,16': 'iPad Pro 11" (4th gen)',
      'iPad13,1': 'iPad Air (4th gen)',
      'iPad14,1': 'iPad mini (6th gen)',
    };
    
    // 매핑된 이름이 있으면 반환, 없으면 원래 코드 반환
    return iosModels[machineCode] ?? machineCode;
  }
  
  /// 플랫폼 이름 가져오기
  String _getPlatformName() {
    if (kIsWeb) {
      return 'web';
    } else if (Platform.isAndroid) {
      return 'android';
    } else if (Platform.isIOS) {
      return 'ios';
    }
    return 'unknown';
  }
  
  /// iOS APNs 토큰 상태 확인 (디버깅용)
  Future<Map<String, dynamic>> checkIOSAPNsStatus() async {
    if (!Platform.isIOS) {
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
        // ignore: avoid_print
        print('⚠️ [FCM-CALLHIST] 사용자 인증 없음 - 통화 기록 생성 스킵');
        return;
      }
      
      // ignore: avoid_print
      print('💾 [FCM-CALLHIST] 통화 기록 생성 시작');
      // ignore: avoid_print
      print('   linkedid: $linkedid');
      // ignore: avoid_print
      print('   발신자: $callerName ($callerNumber)');
      // ignore: avoid_print
      print('   수신자: $receiverNumber');
      
      // linkedid로 기존 통화 기록 확인 (중복 방지) - 타임아웃 5초
      final existingDoc = await _firestore
          .collection('call_history')
          .doc(linkedid)
          .get()
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              // ignore: avoid_print
              print('⏱️ [FCM-CALLHIST] Firestore 조회 타임아웃 (5초)');
              throw TimeoutException('Firestore get timeout');
            },
          );
      
      if (existingDoc.exists) {
        // ignore: avoid_print
        print('ℹ️ [FCM-CALLHIST] 이미 존재하는 통화 기록 (Firebase Functions에서 생성됨)');
        // ignore: avoid_print
        print('   linkedid: $linkedid');
        
        // 상태만 업데이트 (FCM 수신 확인) - 타임아웃 5초
        await _firestore.collection('call_history').doc(linkedid).update({
          'fcmReceived': true,
          'fcmReceivedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }).timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            // ignore: avoid_print
            print('⏱️ [FCM-CALLHIST] Firestore 업데이트 타임아웃 (5초)');
            throw TimeoutException('Firestore update timeout');
          },
        );
        
        // ignore: avoid_print
        print('✅ [FCM-CALLHIST] 기존 기록 업데이트 완료');
        return;
      }
      
      // 새 통화 기록 생성 (Firebase Functions에서 생성되지 않은 경우)
      // ignore: avoid_print
      print('📝 [FCM-CALLHIST] 새 통화 기록 생성');
      
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
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          // ignore: avoid_print
          print('⏱️ [FCM-CALLHIST] Firestore 생성 타임아웃 (5초)');
          throw TimeoutException('Firestore set timeout');
        },
      );
      
      // ignore: avoid_print
      print('✅ [FCM-CALLHIST] 새 통화 기록 생성 완료');
      // ignore: avoid_print
      print('   linkedid: $linkedid');
      // ignore: avoid_print
      print('   발신자: $callerName ($callerNumber)');
      // ignore: avoid_print
      print('   수신자: $receiverNumber');
      
    } on TimeoutException catch (e) {
      // ignore: avoid_print
      print('⏱️ [FCM-CALLHIST] Firestore 타임아웃: $e');
      // ignore: avoid_print
      print('   ⚠️ 네트워크 불안정 - 통화 기록 생성 실패');
      // ignore: avoid_print
      print('   ℹ️ 수신 전화 화면은 정상 표시됨');
    } on FirebaseException catch (e) {
      // ignore: avoid_print
      print('❌ [FCM-CALLHIST] Firebase 오류: ${e.code} - ${e.message}');
      // ignore: avoid_print
      print('   ⚠️ Firestore 연결 실패 - 통화 기록 생성 실패');
      // ignore: avoid_print
      print('   ℹ️ 수신 전화 화면은 정상 표시됨');
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print('❌ [FCM-CALLHIST] 통화 기록 생성 실패: $e');
      // ignore: avoid_print
      print('   Type: ${e.runtimeType}');
      // ignore: avoid_print
      print('Stack trace: $stackTrace');
    }
  }
  
  /// 승인 대기 다이얼로그 표시
  void _showApprovalWaitingDialog() {
    final context = _context ?? navigatorKey.currentContext;
    if (context == null) {
      // ignore: avoid_print
      print('⚠️ [FCM-DIALOG] Context 없음 - 다이얼로그 표시 불가');
      return;
    }
    
    // ignore: avoid_print
    print('🎨 [FCM-DIALOG] 승인 대기 다이얼로그 표시');
    
    // 🔧 키보드 숨기기
    FocusScope.of(context).unfocus();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87, // 🎨 어두운 배경으로 키패드 숨기기
      builder: (dialogContext) => PopScope(
        canPop: false, // 뒤로 가기 방지
        child: _ApprovalWaitingDialog(
          onResendRequest: () async {
            // ignore: avoid_print
            print('🔄 [FCM-DIALOG] 재요청 버튼 클릭');
            if (_currentApprovalRequestId != null && _currentUserId != null) {
              try {
                await _resendApprovalRequest(_currentApprovalRequestId!, _currentUserId!);
                
                // 사용자에게 성공 메시지 표시
                final context = _context ?? navigatorKey.currentContext;
                if (context != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ 승인 요청을 다시 전송했습니다'),
                      duration: Duration(seconds: 2),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                // ignore: avoid_print
                print('❌ [FCM-DIALOG] 재전송 오류: $e');
                
                // 사용자에게 오류 메시지 표시
                final context = _context ?? navigatorKey.currentContext;
                if (context != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ 재전송 실패: $e'),
                      duration: const Duration(seconds: 3),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            }
          },
        ),
      ),
    );
  }
  
  /// 승인 요청 재전송
  Future<void> _resendApprovalRequest(String approvalRequestId, String userId) async {
    try {
      // ignore: avoid_print
      print('');
      // ignore: avoid_print
      print('🔄 [FCM-RESEND] 승인 요청 재전송 시작');
      // ignore: avoid_print
      print('   - Approval Request ID: $approvalRequestId');
      
      // Firestore에서 승인 요청 문서 가져오기
      final approvalDoc = await _firestore
          .collection('device_approval_requests')
          .doc(approvalRequestId)
          .get();
      
      if (!approvalDoc.exists) {
        // ignore: avoid_print
        print('❌ [FCM-RESEND] 승인 요청 문서가 존재하지 않음');
        return;
      }
      
      final data = approvalDoc.data()!;
      final newDeviceName = data['newDeviceName'] as String?;
      final newPlatform = data['newPlatform'] as String?;
      
      // 기존 기기 토큰 조회
      final otherDeviceTokens = await _databaseService.getAllActiveFcmTokens(userId);
      final activeTokens = otherDeviceTokens.where((token) => 
        '${token.deviceId}_${token.platform}' != '${data['newDeviceId']}_${data['newPlatform']}'
      ).toList();
      
      if (activeTokens.isEmpty) {
        // ignore: avoid_print
        print('⚠️ [FCM-RESEND] 활성 기기가 없음');
        return;
      }
      
      // ignore: avoid_print
      print('📤 [FCM-RESEND] ${activeTokens.length}개 기기에 알림 재전송');
      
      // 알림 큐에 다시 등록
      for (var token in activeTokens) {
        // ignore: avoid_print
        print('📤 [FCM-RESEND] 알림 큐 등록 시작: ${token.deviceName}');
        // ignore: avoid_print
        print('   - Target Token: ${token.fcmToken.substring(0, 20)}...');
        // ignore: avoid_print
        print('   - New Device: $newDeviceName ($newPlatform)');
        
        final docRef = await _firestore.collection('fcm_approval_notification_queue').add({
          'targetToken': token.fcmToken,
          'targetDeviceName': token.deviceName,
          'approvalRequestId': approvalRequestId,
          'newDeviceName': newDeviceName,
          'newPlatform': newPlatform,
          'userId': userId,
          'message': {
            'type': 'device_approval_request',
            'title': '🔐 새 기기 로그인 감지',
            'body': '$newDeviceName ($newPlatform)에서 로그인 시도',
            'approvalRequestId': approvalRequestId,
          },
          'createdAt': FieldValue.serverTimestamp(),
          'processed': false,
        });
        
        // ignore: avoid_print
        print('✅ [FCM-RESEND] 알림 큐 등록 완료: ${token.deviceName}');
        // ignore: avoid_print
        print('   - Document ID: ${docRef.id}');
        // ignore: avoid_print
        print('   ⏳ Cloud Functions sendApprovalNotification 트리거 대기 중...');
      }
      
      // ignore: avoid_print
      print('✅ [FCM-RESEND] 승인 요청 재전송 완료');
      print('');
      
    } catch (e) {
      // ignore: avoid_print
      print('❌ [FCM-RESEND] 재전송 실패: $e');
    }
  }
  
  /// 승인 대기 다이얼로그 닫기
  void _dismissApprovalWaitingDialog() {
    final context = _context ?? navigatorKey.currentContext;
    if (context == null) {
      // ignore: avoid_print
      print('⚠️ [FCM-DIALOG] Context 없음 - 다이얼로그 닫기 불가');
      return;
    }
    
    // ignore: avoid_print
    print('🎨 [FCM-DIALOG] 승인 대기 다이얼로그 닫기');
    
    // 다이얼로그가 열려있는지 확인하고 닫기
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }
}

/// 승인 대기 다이얼로그 위젯
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
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
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
    );
  }
}
