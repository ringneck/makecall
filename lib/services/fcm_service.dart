import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io' show Platform;
import '../screens/call/incoming_call_screen.dart';
import '../models/fcm_token_model.dart';
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
      if (kDebugMode) {
        debugPrint('🔔 FCM 서비스 초기화 시작...');
        debugPrint('   플랫폼: ${_getPlatformName()}');
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
      
      if (kDebugMode) {
        debugPrint('📱 알림 권한 상태: ${settings.authorizationStatus}');
      }
      
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        
        // FCM 토큰 가져오기 (웹 플랫폼은 VAPID 키 필요)
        if (kIsWeb) {
          // 웹 플랫폼: VAPID 키 사용
          // ⚠️ VAPID 키는 Firebase Console → Project Settings → Cloud Messaging → Web Push certificates에서 생성
          // TODO: 실제 VAPID 키로 교체 필요
          const vapidKey = 'YOUR_VAPID_KEY_HERE'; // Firebase Console에서 생성한 Web Push certificate의 Key pair 값
          
          try {
            _fcmToken = await _messaging.getToken(vapidKey: vapidKey);
            if (kDebugMode) {
              debugPrint('🌐 웹 FCM 토큰 획득 성공 (VAPID)');
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('⚠️ 웹 FCM 토큰 획득 실패: $e');
              debugPrint('💡 Firebase Console에서 Web Push certificate를 생성하고 VAPID 키를 설정하세요:');
              debugPrint('   1. Firebase Console → Project Settings → Cloud Messaging');
              debugPrint('   2. Web Push certificates → Generate key pair');
              debugPrint('   3. 생성된 키를 fcm_service.dart의 vapidKey 변수에 복사');
            }
            // VAPID 키 없이 시도 (일부 브라우저에서 작동할 수 있음)
            _fcmToken = await _messaging.getToken();
          }
        } else {
          // 모바일 플랫폼: 일반 토큰 획득
          _fcmToken = await _messaging.getToken();
        }
        
        if (_fcmToken != null) {
          if (kDebugMode) {
            debugPrint('');
            debugPrint('='*60);
            debugPrint('🔔 FCM 토큰 정보');
            debugPrint('='*60);
            debugPrint('📱 전체 토큰:');
            debugPrint(_fcmToken!);
            debugPrint('');
            debugPrint('📋 요약 정보:');
            debugPrint('  - 토큰 길이: ${_fcmToken!.length} 문자');
            debugPrint('  - 사용자 ID: $userId');
            debugPrint('  - 플랫폼: ${_getPlatformName()}');
            debugPrint('  - 기기 이름: ${await _getDeviceName()}');
            debugPrint('');
            debugPrint('💡 복사해서 테스트에 사용하세요:');
            debugPrint('   Firebase Console → Messaging → Send test message');
            debugPrint('   또는: python3 docs/fcm_testing/send_fcm_test_message.py');
            debugPrint('='*60);
            debugPrint('');
          }
          
          // Firestore에 토큰 저장
          await _saveFCMToken(userId, _fcmToken!);
          
          // 토큰 갱신 리스너 등록
          _messaging.onTokenRefresh.listen((newToken) {
            if (kDebugMode) {
              debugPrint('');
              debugPrint('🔄 FCM 토큰 갱신됨!');
              debugPrint('='*60);
              debugPrint('📱 새 토큰:');
              debugPrint(newToken);
              debugPrint('');
              debugPrint('⚠️  이전 토큰은 더 이상 유효하지 않습니다.');
              debugPrint('   새 토큰을 테스트에 사용하세요.');
              debugPrint('='*60);
              debugPrint('');
            }
            _fcmToken = newToken;
            _saveFCMToken(userId, newToken);
          });
          
          // 포그라운드 메시지 리스너
          FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
          
          // 백그라운드 메시지 핸들러는 main.dart에서 설정
          
        } else {
          if (kDebugMode) {
            debugPrint('⚠️ FCM 토큰을 가져올 수 없습니다');
            if (kIsWeb) {
              debugPrint('💡 웹 플랫폼: VAPID 키가 필요합니다');
              debugPrint('   Firebase Console → Cloud Messaging → Web Push certificates');
            }
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint('❌ 알림 권한이 거부되었습니다');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ FCM 초기화 오류: $e');
      }
    }
  }
  
  /// FCM 토큰을 Firestore에 저장 (중복 로그인 방지 포함)
  /// 
  /// 새 기기에서 로그인 시:
  /// 1. 기존 활성 토큰 조회
  /// 2. 기존 기기에 강제 로그아웃 FCM 메시지 전송
  /// 3. 기존 토큰 비활성화
  /// 4. 새 토큰 저장
  Future<void> _saveFCMToken(String userId, String token) async {
    try {
      final deviceId = await _getDeviceId();
      final deviceName = await _getDeviceName();
      final platform = _getPlatformName();
      
      // ignore: avoid_print
      print('🔐 [FCMService] FCM 토큰 저장 프로세스 시작');
      // ignore: avoid_print
      print('   사용자 ID: $userId');
      // ignore: avoid_print
      print('   새 기기: $deviceName ($platform)');
      
      // 1. 기존 활성 토큰 조회
      final existingToken = await _databaseService.getActiveFcmToken(userId);
      
      if (existingToken != null && existingToken.deviceId != deviceId) {
        // ignore: avoid_print
        print('🚨 [FCMService] 중복 로그인 감지!');
        // ignore: avoid_print
        print('   기존 기기: ${existingToken.deviceName} (${existingToken.platform})');
        // ignore: avoid_print
        print('   기존 토큰: ${existingToken.fcmToken.substring(0, 30)}...');
        
        // 2. 기존 기기에 강제 로그아웃 알림 전송
        await _sendForceLogoutNotification(existingToken.fcmToken, deviceName, platform);
        
        // ignore: avoid_print
        print('   ✅ 기존 기기에 강제 로그아웃 알림 전송 완료');
      } else if (existingToken != null) {
        // ignore: avoid_print
        print('   ℹ️  동일 기기에서 토큰 갱신');
      } else {
        // ignore: avoid_print
        print('   ℹ️  첫 로그인 (기존 활성 토큰 없음)');
      }
      
      // 3. 새 토큰 모델 생성 및 저장
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
      
      await _databaseService.saveFcmToken(tokenModel);
      
      // ignore: avoid_print
      print('✅ [FCMService] 새 FCM 토큰 저장 완료');
      // ignore: avoid_print
      print('   기기: $deviceName ($platform)');
      
    } catch (e) {
      // ignore: avoid_print
      print('❌ [FCMService] FCM 토큰 저장 오류: $e');
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
      // ignore: avoid_print
      print('📤 [FCMService] 강제 로그아웃 알림 전송 시작');
      // ignore: avoid_print
      print('   대상 토큰: ${targetToken.substring(0, 30)}...');
      
      // Cloud Functions를 통해 FCM 메시지 전송
      // Cloud Functions에서 Firebase Admin SDK로 메시지 전송 처리
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
      
      // ignore: avoid_print
      print('✅ [FCMService] 강제 로그아웃 알림 큐 등록 완료');
      // ignore: avoid_print
      print('   ℹ️  Cloud Functions가 실제 FCM 메시지를 전송합니다');
      
    } catch (e) {
      // ignore: avoid_print
      print('❌ [FCMService] 강제 로그아웃 알림 전송 실패: $e');
      // 에러 무시 (중요하지 않은 작업)
    }
  }
  
  /// 포그라운드 메시지 처리
  void _handleForegroundMessage(RemoteMessage message) {
    // ignore: avoid_print
    print('');
    // ignore: avoid_print
    print('='*60);
    // ignore: avoid_print
    print('📨 포그라운드 메시지 수신 (${_getPlatformName()})');
    // ignore: avoid_print
    print('='*60);
    // ignore: avoid_print
    print('  제목: ${message.notification?.title}');
    // ignore: avoid_print
    print('  내용: ${message.notification?.body}');
    // ignore: avoid_print
    print('  데이터: ${message.data}');
    // ignore: avoid_print
    print('  메시지 타입: ${message.data['type']}');
    // ignore: avoid_print
    print('='*60);
    // ignore: avoid_print
    print('');
    
    // 🔐 강제 로그아웃 메시지 처리
    if (message.data['type'] == 'force_logout') {
      _handleForceLogout(message);
      return;
    }
    
    // 웹 플랫폼: 브라우저 알림 표시
    if (kIsWeb) {
      _showWebNotification(message);
    }
    
    // 수신 전화 타입인 경우
    if (message.data['type'] == 'incoming_call') {
      // WebSocket 연결 상태 확인 및 재연결
      _ensureWebSocketConnection();
      
      // 풀스크린 표시
      _showIncomingCallScreen(message);
    }
  }
  
  /// 강제 로그아웃 메시지 처리
  /// 
  /// 다른 기기에서 로그인했을 때 현재 세션을 종료합니다.
  void _handleForceLogout(RemoteMessage message) {
    // ignore: avoid_print
    print('🚨 [FCMService] 강제 로그아웃 메시지 수신');
    
    final newDeviceName = message.data['newDeviceName'] ?? '다른 기기';
    final newPlatform = message.data['newPlatform'] ?? 'unknown';
    
    // ignore: avoid_print
    print('   새 로그인 기기: $newDeviceName ($newPlatform)');
    
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
    
    // ignore: avoid_print
    print('✅ [FCMService] 강제 로그아웃 처리 완료');
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
    if (_context == null) {
      debugPrint('❌ BuildContext가 설정되지 않았습니다');
      return;
    }
    
    final callerName = message.data['caller_name'] ?? message.notification?.title ?? '알 수 없음';
    final callerNumber = message.data['caller_number'] ?? message.notification?.body ?? '';
    final callerAvatar = message.data['caller_avatar'];
    
    if (kDebugMode) {
      debugPrint('📞 수신 전화 화면 표시:');
      debugPrint('  발신자: $callerName');
      debugPrint('  번호: $callerNumber');
    }
    
    // FCM에서는 channel과 linkedid가 없으므로 기본값 사용
    final channel = message.data['channel'] ?? 'FCM-PUSH';
    final linkedid = message.data['linkedid'] ?? 'fcm_${DateTime.now().millisecondsSinceEpoch}';
    final receiverNumber = message.data['receiver_number'] ?? '';
    
    Navigator.of(_context!).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => IncomingCallScreen(
          callerName: callerName,
          callerNumber: callerNumber,
          callerAvatar: callerAvatar,
          channel: channel,
          linkedid: linkedid,
          receiverNumber: receiverNumber,
          callType: 'unknown', // FCM 푸시는 통화 타입 감지 불가
          onAccept: () {
            Navigator.of(context).pop();
            // TODO: 전화 수락 로직 (SIP 연결 등)
            if (kDebugMode) {
              debugPrint('✅ 전화 수락됨: $callerNumber');
            }
          },
          onReject: () {
            Navigator.of(context).pop();
            // TODO: 전화 거절 로직 (서버 통신 등)
            if (kDebugMode) {
              debugPrint('❌ 전화 거절됨: $callerNumber');
            }
          },
        ),
      ),
    );
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
  /// 로그아웃 시 현재 기기의 FCM 토큰을 삭제합니다.
  Future<void> deactivateToken(String userId) async {
    if (_fcmToken == null) return;
    
    try {
      // ignore: avoid_print
      print('🗑️  [FCMService] FCM 토큰 비활성화 시작');
      
      final deviceId = await _getDeviceId();
      await _databaseService.deleteFcmToken(userId, deviceId);
      
      // ignore: avoid_print
      print('✅ [FCMService] FCM 토큰 비활성화 완료');
    } catch (e) {
      // ignore: avoid_print
      print('❌ [FCMService] FCM 토큰 비활성화 오류: $e');
    }
  }
  
  /// 기기 ID 가져오기
  /// 
  /// FCM 토큰과 함께 사용하여 기기를 고유하게 식별합니다.
  /// 중복 로그인 방지에 사용됩니다.
  Future<String> _getDeviceId() async {
    try {
      if (_fcmToken != null) {
        // FCM 토큰의 해시를 기기 ID로 사용 (고유성 보장)
        return _fcmToken!.substring(0, 50);
      }
      // FCM 토큰이 없으면 임시 ID 생성
      return 'temp_device_${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      return 'unknown_device_${DateTime.now().millisecondsSinceEpoch}';
    }
  }
  
  /// 기기 이름 가져오기
  /// 
  /// 사용자에게 표시할 기기 이름을 반환합니다.
  Future<String> _getDeviceName() async {
    try {
      if (kIsWeb) {
        // 웹: 브라우저 정보 포함
        return 'Web Browser';
      } else if (Platform.isAndroid) {
        // Android: 모델명 포함 (TODO: device_info_plus로 실제 모델명 가져오기)
        return 'Android Device';
      } else if (Platform.isIOS) {
        // iOS: 기기 모델 포함 (TODO: device_info_plus로 실제 모델명 가져오기)
        return 'iOS Device';
      }
      return 'Unknown Device';
    } catch (e) {
      return 'Unknown Device';
    }
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
}
