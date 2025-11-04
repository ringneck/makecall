import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io' show Platform;
import '../screens/call/incoming_call_screen.dart';
import 'dcmiws_service.dart';
import 'auth_service.dart';
import 'package:provider/provider.dart';

/// FCM(Firebase Cloud Messaging) 서비스
class FCMService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String? _fcmToken;
  static BuildContext? _context; // 전역 BuildContext 저장
  
  /// FCM 토큰 가져오기
  String? get fcmToken => _fcmToken;
  
  /// BuildContext 설정 (main.dart에서 호출)
  static void setContext(BuildContext context) {
    _context = context;
  }
  
  /// FCM 초기화
  Future<void> initialize(String userId) async {
    try {
      if (kDebugMode) {
        debugPrint('🔔 FCM 서비스 초기화 시작...');
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
        
        // FCM 토큰 가져오기
        _fcmToken = await _messaging.getToken();
        
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
            debugPrint('⚠️ FCM 토큰을 가져올 수 없습니다 (웹 플랫폼일 수 있음)');
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
  
  /// FCM 토큰을 Firestore에 저장
  Future<void> _saveFCMToken(String userId, String token) async {
    try {
      final deviceId = await _getDeviceId();
      final deviceName = await _getDeviceName();
      final platform = _getPlatformName();
      
      await _firestore.collection('fcm_tokens').doc(token).set({
        'userId': userId,
        'token': token,
        'deviceId': deviceId,
        'deviceName': deviceName,
        'platform': platform,
        'appVersion': '1.0.0', // TODO: 실제 앱 버전으로 변경
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastUsedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      if (kDebugMode) {
        debugPrint('✅ FCM 토큰 Firestore 저장 완료');
        debugPrint('   컬렉션: fcm_tokens');
        debugPrint('   문서 ID: ${token.substring(0, 30)}...');
        debugPrint('   사용자 ID: $userId');
        debugPrint('   기기: $deviceName ($platform)');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ FCM 토큰 저장 오류: $e');
      }
    }
  }
  
  /// 포그라운드 메시지 처리
  void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('📨 포그라운드 메시지 수신:');
      debugPrint('  제목: ${message.notification?.title}');
      debugPrint('  내용: ${message.notification?.body}');
      debugPrint('  데이터: ${message.data}');
    }
    
    // 수신 전화 타입인 경우
    if (message.data['type'] == 'incoming_call') {
      // WebSocket 연결 상태 확인 및 재연결
      _ensureWebSocketConnection();
      
      // 풀스크린 표시
      _showIncomingCallScreen(message);
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
  Future<void> deactivateToken() async {
    if (_fcmToken == null) return;
    
    try {
      await _firestore.collection('fcm_tokens').doc(_fcmToken).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      if (kDebugMode) {
        debugPrint('✅ FCM 토큰 비활성화 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ FCM 토큰 비활성화 오류: $e');
      }
    }
  }
  
  /// 기기 ID 가져오기
  Future<String> _getDeviceId() async {
    try {
      // TODO: device_info_plus 패키지를 사용하여 실제 기기 ID 가져오기
      return 'device_${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      return 'unknown_device';
    }
  }
  
  /// 기기 이름 가져오기
  Future<String> _getDeviceName() async {
    try {
      // TODO: device_info_plus 패키지를 사용하여 실제 기기 이름 가져오기
      if (kIsWeb) {
        return 'Web Browser';
      } else if (Platform.isAndroid) {
        return 'Android Device';
      } else if (Platform.isIOS) {
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
