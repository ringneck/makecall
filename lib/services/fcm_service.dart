import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../screens/call/incoming_call_screen.dart';
import '../models/fcm_token_model.dart';
import '../main.dart' show navigatorKey; // GlobalKey for Navigation
import 'dcmiws_service.dart';
import 'auth_service.dart';
import 'database_service.dart';
import 'package:provider/provider.dart';

/// FCM(Firebase Cloud Messaging) 서비스
/// 
/// 중복 로그인 방지 기능 포함:
/// - 새 기기에서 로그인 시 이전 세션 강제 로그아웃
/// - FCM 메시지를 통한 세션 만료 알림
/// - 한 사용자당 하나의 활성 세션만 유지
class FCMService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseService _databaseService = DatabaseService();
  
  String? _fcmToken;
  static BuildContext? _context; // 전역 BuildContext 저장
  static Function()? _onForceLogout; // 강제 로그아웃 콜백
  
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
  
  /// FCM 초기화
  Future<void> initialize(String userId) async {
    try {
      // ignore: avoid_print
      print('🔔 [FCM] 초기화 시작');
      // ignore: avoid_print
      print('   User ID: $userId');
      // ignore: avoid_print
      print('   Platform: ${_getPlatformName()}');
      
      // Android 알림 채널 생성
      if (Platform.isAndroid) {
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
        
        final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
            FlutterLocalNotificationsPlugin();
        
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
          
          // 토큰 갱신 리스너 등록
          _messaging.onTokenRefresh.listen((newToken) {
            debugPrint('🔄 FCM 토큰 갱신: ${newToken.substring(0, 20)}...');
            _fcmToken = newToken;
            _saveFCMToken(userId, newToken);
          });
          
          // 포그라운드 메시지 리스너
          FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
          
          // 백그라운드/종료 상태에서 알림 클릭 시 처리 (중요!)
          FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
          
          // 앱이 종료된 상태에서 알림 클릭으로 시작된 경우 처리
          _messaging.getInitialMessage().then((RemoteMessage? message) {
            if (message != null) {
              debugPrint('🚀 [FCM] 앱이 종료 상태에서 알림 클릭으로 시작됨');
              _handleMessageOpenedApp(message);
            }
          });
          
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
      
      final deviceId = await _getDeviceId();
      final deviceName = await _getDeviceName();
      final platform = _getPlatformName();
      
      // ignore: avoid_print
      print('   - Device ID: $deviceId');
      // ignore: avoid_print
      print('   - Device Name: $deviceName');
      // ignore: avoid_print
      print('   - Platform: $platform');
      
      // 1. 기존 활성 토큰 조회 (fcm_tokens 컬렉션에서만)
      // ignore: avoid_print
      print('🔍 [FCM-SAVE] 기존 토큰 조회 중...');
      final existingToken = await _databaseService.getActiveFcmToken(userId);
      
      if (existingToken != null && existingToken.deviceId != deviceId) {
        // 다른 기기에서 로그인 감지 - 기존 기기에 강제 로그아웃 알림 전송
        // ignore: avoid_print
        print('🚨 [FCM-SAVE] 중복 로그인 감지: ${existingToken.deviceName} → $deviceName');
        await _sendForceLogoutNotification(existingToken.fcmToken, deviceName, platform);
      } else if (existingToken != null) {
        // ignore: avoid_print
        print('ℹ️ [FCM-SAVE] 동일 기기 토큰 갱신');
      } else {
        // ignore: avoid_print
        print('ℹ️ [FCM-SAVE] 첫 로그인');
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
      
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print('❌ [FCM-SAVE] 토큰 저장 오류: $e');
      // ignore: avoid_print
      print('Stack trace:');
      // ignore: avoid_print
      print(stackTrace);
    }
  }
  
  /// 기존 기기에 강제 로그아웃 FCM 메시지 전송
  /// 
  /// @param targetToken 대상 기기의 FCM 토큰
  /// @param newDeviceName 새로 로그인한 기기 이름
  /// @param newPlatform 새로 로그인한 플랫폼
  Future<void> _sendForceLogoutNotification(
    String targetToken,
    String newDeviceName,
    String newPlatform,
  ) async {
    try {
      await _firestore.collection('fcm_force_logout_queue').add({
        'targetToken': targetToken,
        'newDeviceName': newDeviceName,
        'newPlatform': newPlatform,
        'message': {
          'type': 'force_logout',
          'title': '다른 기기에서 로그인됨',
          'body': '$newDeviceName에서 로그인되어 현재 세션이 종료됩니다.',
        },
        'createdAt': FieldValue.serverTimestamp(),
        'processed': false,
      });
      
      debugPrint('✅ 강제 로그아웃 알림 큐 등록 완료');
    } catch (e) {
      debugPrint('❌ 강제 로그아웃 알림 전송 실패: $e');
    }
  }
  
  /// 포그라운드 메시지 처리
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📨 포그라운드 메시지: ${message.notification?.title}');
    debugPrint('📨 메시지 데이터: ${message.data}');
    
    // 🔐 강제 로그아웃 메시지 처리
    if (message.data['type'] == 'force_logout') {
      _handleForceLogout(message);
      return;
    }
    
    // 웹 플랫폼: 브라우저 알림 표시
    if (kIsWeb) {
      _showWebNotification(message);
    }
    
    // 안드로이드 플랫폼: 로컬 알림 표시
    if (Platform.isAndroid) {
      _showAndroidNotification(message);
    }
    
    // 📞 모든 푸시 메시지에 대해 수신 전화 화면 표시
    // (나중에 type 조건 추가 가능: type == 'incoming_call')
    debugPrint('📞 [FCM] 수신 전화 화면 표시 시작...');
    
    // WebSocket 연결 상태 확인 및 재연결
    _ensureWebSocketConnection();
    
    // 풀스크린 수신 전화 화면 표시
    _showIncomingCallScreen(message);
  }
  
  /// 백그라운드/종료 상태에서 알림 클릭 시 처리
  /// 
  /// 사용자가 알림바에서 알림을 클릭하면 호출됩니다.
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('🔔 [FCM] 백그라운드 알림 클릭됨: ${message.notification?.title}');
    debugPrint('🔔 [FCM] 메시지 데이터: ${message.data}');
    
    // 🔐 강제 로그아웃 메시지 처리
    if (message.data['type'] == 'force_logout') {
      _handleForceLogout(message);
      return;
    }
    
    // 📞 수신 전화 화면 표시
    debugPrint('📞 [FCM] 백그라운드에서 수신 전화 화면 표시 시작...');
    
    // WebSocket 연결 상태 확인 및 재연결
    _ensureWebSocketConnection();
    
    // 풀스크린 수신 전화 화면 표시
    _showIncomingCallScreen(message);
  }
  
  /// 강제 로그아웃 메시지 처리
  /// 
  /// 다른 기기에서 로그인했을 때 현재 세션을 종료합니다.
  void _handleForceLogout(RemoteMessage message) {
    debugPrint('🚨 강제 로그아웃 메시지 수신');
    
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
  
  /// 안드로이드 로컬 알림 표시 (포그라운드 전용)
  Future<void> _showAndroidNotification(RemoteMessage message) async {
    if (!Platform.isAndroid) return;
    
    try {
      final title = message.notification?.title ?? message.data['title'] ?? 'MAKECALL 알림';
      final body = message.notification?.body ?? message.data['body'] ?? '새로운 알림이 있습니다.';
      
      if (kDebugMode) {
        debugPrint('🔔 [FCM] 안드로이드 알림 표시 시작');
        debugPrint('   제목: $title');
        debugPrint('   내용: $body');
      }
      
      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();
      
      // 알림 상세 설정
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'high_importance_channel', // channelId (AndroidManifest.xml과 동일)
        'High Importance Notifications', // channelName
        channelDescription: 'This channel is used for important notifications.',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher', // 앱 아이콘 사용
      );
      
      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
      );
      
      // 알림 표시
      await flutterLocalNotificationsPlugin.show(
        message.hashCode, // 고유 알림 ID (메시지마다 다름)
        title,
        body,
        notificationDetails,
      );
      
      if (kDebugMode) {
        debugPrint('✅ [FCM] 안드로이드 알림 표시 완료');
      }
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [FCM] 안드로이드 알림 표시 오류: $e');
      }
    }
  }
  
  /// 웹 플랫폼 알림 표시
  void _showWebNotification(RemoteMessage message) {
    if (!kIsWeb) return;
    
    try {
      final title = message.notification?.title ?? message.data['title'] ?? 'MakeCall 알림';
      final body = message.notification?.body ?? message.data['body'] ?? '새로운 알림';
      
      if (kDebugMode) {
        debugPrint('🌐 웹 알림 표시: $title - $body');
      }
      
      // 웹 알림은 서비스 워커에서 처리됨
      // 여기서는 앱 내 스낵바나 다이얼로그로 표시 가능
      if (_context != null) {
        ScaffoldMessenger.of(_context!).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(body, style: const TextStyle(fontSize: 12)),
              ],
            ),
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: '확인',
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 웹 알림 표시 오류: $e');
      }
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
      
      // user_model에서 serverAddress 가져오기
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      
      if (userData == null) return;
      
      final serverAddress = userData['serverAddress'] as String?;
      final serverPort = userData['serverPort'] as int? ?? 7099;
      final useSSL = userData['serverSSL'] as bool? ?? false;
      
      if (serverAddress == null || serverAddress.isEmpty) {
        if (kDebugMode) {
          debugPrint('⚠️  서버 주소가 설정되지 않았습니다');
        }
        return;
      }
      
      // WebSocket 재연결
      final success = await dcmiwsService.connect(
        serverAddress: serverAddress,
        port: serverPort,
        useSSL: useSSL,
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
  void _showIncomingCallScreen(RemoteMessage message) {
    // BuildContext 또는 NavigatorKey 확인
    final context = _context ?? navigatorKey.currentContext;
    
    if (context == null) {
      debugPrint('❌ [FCM] BuildContext와 NavigatorKey 모두 사용 불가');
      debugPrint('💡 main.dart에서 FCMService.setContext()를 호출하거나 앱이 완전히 시작될 때까지 기다리세요');
      return;
    }
    
    debugPrint('✅ [FCM] Context 확인 완료 (${_context != null ? "setContext" : "navigatorKey"} 사용)');
    
    // 📋 메시지 데이터에서 정보 추출 (없으면 임시 WebSocket 데이터 사용)
    final callerName = message.data['caller_name'] ?? 
                       message.data['callerName'] ?? 
                       message.notification?.title ?? 
                       '홍길동 (테스트)'; // 임시 WebSocket 데이터
    
    final callerNumber = message.data['caller_number'] ?? 
                         message.data['callerNumber'] ?? 
                         message.notification?.body ?? 
                         '010-1234-5678'; // 임시 WebSocket 데이터
    
    final callerAvatar = message.data['caller_avatar'] ?? 
                         message.data['callerAvatar'];
    
    // 통화 관련 메타데이터 (임시 WebSocket 데이터)
    final channel = message.data['channel'] ?? 
                    'SIP/1001-00000123'; // 임시 WebSocket 채널 데이터
    
    final linkedid = message.data['linkedid'] ?? 
                     message.data['linkedId'] ?? 
                     '1731254400.123'; // 임시 WebSocket linkedid
    
    final receiverNumber = message.data['receiver_number'] ?? 
                           message.data['receiverNumber'] ?? 
                           message.data['extension'] ?? 
                           '1001'; // 임시 내선번호 (WebSocket)
    
    final callType = message.data['call_type'] ?? 
                     message.data['callType'] ?? 
                     'external'; // 임시 통화 타입 (WebSocket)
    
    if (kDebugMode) {
      debugPrint('📞 [FCM] 수신 전화 화면 표시:');
      debugPrint('   발신자: $callerName');
      debugPrint('   번호: $callerNumber');
      debugPrint('   아바타: ${callerAvatar ?? "없음"}');
      debugPrint('   채널: $channel');
      debugPrint('   링크ID: $linkedid');
      debugPrint('   수신번호: $receiverNumber');
      debugPrint('   통화타입: $callType');
    }
    
    // 수신 전화 화면 표시 (fullscreenDialog로 전체 화면)
    Navigator.of(context).push(
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
          onAccept: () {
            if (kDebugMode) {
              debugPrint('✅ [FCM] 전화 수락됨');
              debugPrint('   발신자: $callerName ($callerNumber)');
              debugPrint('   링크ID: $linkedid');
            }
            
            Navigator.of(context).pop();
            
            // TODO: 전화 수락 로직 구현
            // 1. SIP 연결 시작
            // 2. WebSocket으로 서버에 수락 알림
            // 3. 통화 화면으로 전환
            
            // 임시: 스낵바로 알림
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('📞 전화 수락: $callerName'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          },
          onReject: () {
            if (kDebugMode) {
              debugPrint('❌ [FCM] 전화 거절됨');
              debugPrint('   발신자: $callerName ($callerNumber)');
              debugPrint('   링크ID: $linkedid');
            }
            
            Navigator.of(context).pop();
            
            // TODO: 전화 거절 로직 구현
            // 1. WebSocket으로 서버에 거절 알림
            // 2. 통화 로그에 부재중 전화 기록
            
            // 임시: 스낵바로 알림
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('📵 전화 거절: $callerName'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
      ),
    );
    
    if (kDebugMode) {
      debugPrint('✅ [FCM] 수신 전화 화면 표시 완료');
    }
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
}
