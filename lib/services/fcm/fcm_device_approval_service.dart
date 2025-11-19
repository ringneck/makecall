import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../utils/dialog_utils.dart';
import '../database_service.dart';
import '../auth_service.dart';
import '../fcm_service.dart'; // FCMService.setCurrentDisplayedApprovalId 사용
import '../../main.dart' show navigatorKey;
import 'fcm_notification_sound_service.dart';
import 'fcm_platform_utils.dart';

/// FCM 기기 승인 서비스
/// 
/// 다중 기기 로그인 시 기기 승인 요청 및 처리를 담당합니다.
/// - 승인 요청 전송 (Cloud Functions 트리거)
/// - 승인 대기 (Firestore 스냅샷 리스너)
/// - 승인 다이얼로그 표시 및 처리
/// - 승인 응답 처리
class FCMDeviceApprovalService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseService _databaseService = DatabaseService();
  final FCMPlatformUtils _platformUtils = FCMPlatformUtils();

  // 🔒 중복 처리 방지
  static final Set<String> _processingApprovalIds = {};
  static String? _currentDisplayedApprovalId;

  // 🎨 승인 요청 정보
  String? _currentApprovalRequestId;
  String? _currentUserId;

  // BuildContext 및 콜백 참조
  static BuildContext? _context;
  static AuthService? _authService;

  /// BuildContext 설정
  static void setContext(BuildContext context) {
    _context = context;
  }

  /// AuthService 설정
  static void setAuthService(AuthService authService) {
    _authService = authService;
  }

  /// 기존 기기에 기기 승인 요청 전송 및 승인 대기
  /// 
  /// Returns: approval request ID (성공 시) 또는 null (실패 시)
  Future<String?> sendDeviceApprovalRequestAndWait({
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
      
      // 🔑 CRITICAL: 이미 승인된 활성 기기들의 토큰 조회 (새 기기 제외)
      // isApproved: true 필터로 승인 완료된 기기에게만 승인 요청을 보냄
      final existingTokens = await _firestore
          .collection('fcm_tokens')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .where('isApproved', isEqualTo: true) // 🔑 승인된 기기만
          .get();
      
      // ignore: avoid_print
      print('🔍 [FCM-APPROVAL] 전체 활성 토큰 조회 결과: ${existingTokens.docs.length}개');
      
      // 🔧 디버깅: 모든 활성 토큰 출력
      for (var doc in existingTokens.docs) {
        final data = doc.data();
        // ignore: avoid_print
        print('   📱 활성 토큰: ${data['deviceName']} (${data['deviceId']}_${data['platform']})');
        // ignore: avoid_print
        print('      - 문서 ID: ${doc.id}');
        // ignore: avoid_print
        print('      - isActive: ${data['isActive']}');
      }
      
      // 🔑 CRITICAL: Device ID + Platform 조합으로 기기 구분
      final newDeviceKey = '${newDeviceId}_$newPlatform';
      // ignore: avoid_print
      print('🆕 [FCM-APPROVAL] 새 기기 키: $newDeviceKey');
      
      // 새 기기를 제외한 기존 기기들만 필터링
      final otherDeviceTokens = existingTokens.docs
          .where((doc) {
            final data = doc.data();
            final existingDeviceKey = '${data['deviceId']}_${data['platform']}';
            final isSameDevice = existingDeviceKey == newDeviceKey;
            
            // ignore: avoid_print
            print('   🔍 비교: $existingDeviceKey == $newDeviceKey ? $isSameDevice');
            
            return !isSameDevice;
          })
          .toList();
      
      if (otherDeviceTokens.isEmpty) {
        // ignore: avoid_print
        print('✅ [FCM-APPROVAL] 다른 활성 기기 없음 - 승인 요청 불필요 (첫 로그인)');
        throw Exception('No other devices found');
      }
      
      // ignore: avoid_print
      print('📋 [FCM-APPROVAL] 다른 활성 기기 ${otherDeviceTokens.length}개 발견');
      for (var token in otherDeviceTokens) {
        final data = token.data();
        // ignore: avoid_print
        print('   ⚠️ 승인 필요: ${data['deviceName']} (${data['deviceId']}_${data['platform']})');
      }
      
      // 🔑 CRITICAL: 문서 ID를 userId_deviceId_platform 형식으로 명시
      final approvalRequestId = '${userId}_${newDeviceId}_$newPlatform';
      
      // ignore: avoid_print
      print('📝 [FCM-APPROVAL] 승인 요청 문서 ID: $approvalRequestId');
      
      // 🔧 FIX 1: 이전 승인 요청이 남아있을 수 있으므로 먼저 삭제
      try {
        final existingRequest = await _firestore
            .collection('device_approval_requests')
            .doc(approvalRequestId)
            .get();
        
        if (existingRequest.exists) {
          // ignore: avoid_print
          print('🗑️ [FCM-APPROVAL] 기존 승인 요청 발견 - 삭제 중...');
          await _firestore
              .collection('device_approval_requests')
              .doc(approvalRequestId)
              .delete();
          // ignore: avoid_print
          print('✅ [FCM-APPROVAL] 기존 승인 요청 삭제 완료');
        }
      } catch (e) {
        // ignore: avoid_print
        print('⚠️ [FCM-APPROVAL] 기존 요청 삭제 중 오류 (무시): $e');
      }
      
      // 🔧 FIX 2: 해당 사용자의 모든 승인 알림 큐 정리 (강제 클린업)
      try {
        // ignore: avoid_print
        print('🧹 [FCM-APPROVAL] 사용자의 모든 승인 알림 큐 정리 시작...');
        
        final allQueues = await _firestore
            .collection('fcm_approval_notification_queue')
            .where('userId', isEqualTo: userId)
            .get();
        
        if (allQueues.docs.isNotEmpty) {
          // ignore: avoid_print
          print('🗑️ [FCM-APPROVAL] ${allQueues.docs.length}개의 큐 삭제 중...');
          
          // 배치 삭제 (최대 500개씩)
          final batch = _firestore.batch();
          int count = 0;
          for (var doc in allQueues.docs) {
            batch.delete(doc.reference);
            count++;
            
            // Firestore 배치 제한 (500개)
            if (count >= 500) {
              await batch.commit();
              // ignore: avoid_print
              print('   ✅ 500개 배치 삭제 완료');
              count = 0;
            }
          }
          
          // 남은 문서 삭제
          if (count > 0) {
            await batch.commit();
          }
          
          // ignore: avoid_print
          print('✅ [FCM-APPROVAL] 모든 큐 ${allQueues.docs.length}개 삭제 완료');
        } else {
          // ignore: avoid_print
          print('✅ [FCM-APPROVAL] 정리할 큐 없음');
        }
      } catch (e) {
        // ignore: avoid_print
        print('⚠️ [FCM-APPROVAL] 큐 정리 중 오류 (무시): $e');
      }
      
      // Firestore에 새 승인 요청 저장 (5분 TTL)
      await _firestore.collection('device_approval_requests').doc(approvalRequestId).set({
        'userId': userId,
        'newDeviceId': newDeviceId,
        'newDeviceName': newDeviceName,
        'newPlatform': newPlatform,
        'newDeviceToken': newDeviceToken,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 5))),
      });
      
      // ignore: avoid_print
      print('✅ [FCM-APPROVAL] 승인 요청 문서 생성: $approvalRequestId');
      
      // 🎵 사용자 ringtone 정보 가져오기
      String? ringtone;
      try {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final userData = userDoc.data();
          ringtone = userData?['ringtone'] as String?;
          // ignore: avoid_print
          print('🎵 [FCM-APPROVAL] 사용자 ringtone: ${ringtone ?? "없음 (기본 벨소리 사용)"}');
        }
      } catch (e) {
        // ignore: avoid_print
        print('⚠️ [FCM-APPROVAL] ringtone 조회 실패: $e');
      }
      
      // 모든 기존 기기에 FCM 알림 큐 등록
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
            if (ringtone != null) 'ringtone': ringtone, // 🎵 ringtone 추가
          },
          'createdAt': FieldValue.serverTimestamp(),
          'processed': false,
        });
        
        // ignore: avoid_print
        print('✅ [FCM-APPROVAL] 알림 큐 등록 완료: $targetDeviceName');
      }
      
      // ignore: avoid_print
      print('✅ [FCM-APPROVAL] 모든 기존 기기에 승인 요청 큐 등록 완료');
      
      return approvalRequestId;
      
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print('❌ [FCM-APPROVAL] 승인 요청 전송 실패: $e');
      // ignore: avoid_print
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 기기 승인 대기 (Firestore 스냅샷 리스너)
  /// 
  /// Returns: true (승인됨), false (거부됨 또는 시간 초과)
  Future<bool> waitForDeviceApproval(String approvalRequestId) async {
    try {
      // ignore: avoid_print
      print('⏳ [FCM-WAIT] 기기 승인 대기 시작: $approvalRequestId');
      
      final stream = _firestore
          .collection('device_approval_requests')
          .doc(approvalRequestId)
          .snapshots();
      
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
          print('❌ [FCM-WAIT] 승인 요청 문서가 삭제됨');
          return false;
        }
        
        final data = snapshot.data();
        if (data == null) continue;
        
        final status = data['status'] as String?;
        // ignore: avoid_print
        print('📊 [FCM-WAIT] 현재 상태: $status');
        
        if (status == 'approved') {
          // ignore: avoid_print
          print('✅ [FCM-WAIT] 기기 승인됨!');
          return true;
        } else if (status == 'rejected') {
          // ignore: avoid_print
          print('❌ [FCM-WAIT] 기기 거부됨');
          return false;
        } else if (status == 'expired') {
          // ignore: avoid_print
          print('⏰ [FCM-WAIT] 승인 요청 만료됨');
          return false;
        }
        
        final now = DateTime.now();
        if (now.isAfter(timeout)) {
          // ignore: avoid_print
          print('⏰ [FCM-WAIT] 승인 대기 시간 초과 (5분)');
          return false;
        }
        
        // ignore: avoid_print
        print('⏳ [FCM-WAIT] 계속 대기 중... (${timeout.difference(now).inSeconds}초 남음)');
      }
      
      return false;
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print('❌ [FCM-WAIT] 승인 대기 오류: $e');
      // ignore: avoid_print
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  /// 기기 승인 요청 메시지 처리 (다이얼로그 표시)
  void handleDeviceApprovalRequest(RemoteMessage message) {
    // ignore: avoid_print
    print('🔔 [FCM-APPROVAL] 승인 요청 메시지 수신');
    
    final approvalRequestId = message.data['approvalRequestId'] as String?;
    final newDeviceName = message.data['newDeviceName'] ?? '알 수 없는 기기';
    final newPlatform = message.data['newPlatform'] ?? 'unknown';
    
    if (approvalRequestId == null) {
      // ignore: avoid_print
      print('❌ [FCM-APPROVAL] approvalRequestId 없음');
      return;
    }
    
    // 🔧 FIX: 현재 기기가 로그아웃 상태면 승인 요청 무시
    if (_authService == null || _authService!.currentUser == null) {
      // ignore: avoid_print
      print('⚠️ [FCM-APPROVAL] 로그아웃 상태 - 승인 요청 무시');
      // ignore: avoid_print
      print('   (로그아웃한 기기에서 푸시 수신은 정상 동작이나, 다이얼로그는 표시하지 않음)');
      return;
    }
    
    // 🔒 중복 표시 방지
    if (_currentDisplayedApprovalId == approvalRequestId) {
      // ignore: avoid_print
      print('⚠️ [FCM-APPROVAL] 이미 표시 중인 다이얼로그');
      return;
    }
    
    // 🎵 알림 사운드 및 진동 재생
    FCMNotificationSoundService.playNotificationWithVibration(duration: 3);
    
    final context = _context ?? navigatorKey.currentContext;
    if (context == null) {
      // ignore: avoid_print
      print('⏳ [FCM-APPROVAL] Context 없음 - 대기');
      _waitForContextAndShowApprovalDialog(message);
      return;
    }
    
    _currentDisplayedApprovalId = approvalRequestId;
    
    // 🔒 FCMService에도 현재 표시 중인 승인 ID 설정 (취소 메시지 처리용)
    FCMService.setCurrentDisplayedApprovalId(approvalRequestId);
    
    // ignore: avoid_print
    print('✅ [FCM-APPROVAL] 다이얼로그 표시 시작');
    
    // 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.security, color: Colors.blue, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text('🔐 새 기기 로그인 감지', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '새 기기에서 로그인을 시도하고 있습니다.',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.devices, size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(child: Text('기기: $newDeviceName', style: const TextStyle(fontSize: 12))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.phone_android, size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text('플랫폼: $newPlatform', style: const TextStyle(fontSize: 12)),
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
        ),
        actions: [
          TextButton(
            onPressed: () {
              // ignore: avoid_print
              print('🔘 [FCM-APPROVAL] 거부 버튼 클릭');
              
              if (_processingApprovalIds.contains(approvalRequestId)) {
                // ignore: avoid_print
                print('⚠️ [FCM-APPROVAL] 이미 처리 중');
                return;
              }
              _processingApprovalIds.add(approvalRequestId);
              
              if (context.mounted) {
                Navigator.of(context).pop();
                _currentDisplayedApprovalId = null;
                FCMService.setCurrentDisplayedApprovalId(null); // FCMService에도 동기화
              }
              
              _rejectDeviceApproval(approvalRequestId).whenComplete(() {
                _processingApprovalIds.remove(approvalRequestId);
              });
            },
            child: const Text('거부', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              // ignore: avoid_print
              print('🔘 [FCM-APPROVAL] 승인 버튼 클릭');
              
              if (_processingApprovalIds.contains(approvalRequestId)) {
                // ignore: avoid_print
                print('⚠️ [FCM-APPROVAL] 이미 처리 중');
                return;
              }
              _processingApprovalIds.add(approvalRequestId);
              
              if (context.mounted) {
                Navigator.of(context).pop();
                _currentDisplayedApprovalId = null;
                FCMService.setCurrentDisplayedApprovalId(null); // FCMService에도 동기화
              }
              
              _approveDeviceApproval(approvalRequestId).whenComplete(() {
                _processingApprovalIds.remove(approvalRequestId);
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('승인', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Context 대기 후 다이얼로그 표시
  Future<void> _waitForContextAndShowApprovalDialog(RemoteMessage message) async {
    // ignore: avoid_print
    print('🔄 [FCM-APPROVAL-DIALOG] Context 대기 시작');
    
    await Future.delayed(const Duration(milliseconds: 500));
    _retryShowApprovalDialog(message, 0);
  }

  /// 재시도 로직
  Future<void> _retryShowApprovalDialog(RemoteMessage message, int attempt) async {
    const maxAttempts = 50;
    
    if (attempt >= maxAttempts) {
      // ignore: avoid_print
      print('❌ [FCM-APPROVAL-DIALOG] Context 타임아웃');
      return;
    }
    
    final context = _context ?? navigatorKey.currentContext;
    
    if (context != null && context.mounted) {
      // ignore: avoid_print
      print('✅ [FCM-APPROVAL-DIALOG] Context 준비 완료 (${(attempt + 1) * 100}ms 대기)');
      handleDeviceApprovalRequest(message);
      return;
    }
    
    await Future.delayed(const Duration(milliseconds: 100));
    _retryShowApprovalDialog(message, attempt + 1);
  }

  /// 기기 승인 처리
  Future<void> _approveDeviceApproval(String approvalRequestId) async {
    try {
      debugPrint('✅ [FCM] 기기 승인 처리: $approvalRequestId');
      
      // 🔍 Step 1: 승인 요청 문서에서 기기 정보 추출
      final approvalDoc = await _firestore
          .collection('device_approval_requests')
          .doc(approvalRequestId)
          .get();
      
      if (!approvalDoc.exists) {
        debugPrint('❌ [FCM] 승인 요청 문서가 존재하지 않음');
        return;
      }
      
      final data = approvalDoc.data()!;
      final userId = data['userId'] as String?;
      final newDeviceId = data['newDeviceId'] as String?;
      final newPlatformRaw = data['newPlatform'] as String?;
      
      if (userId == null || newDeviceId == null || newPlatformRaw == null) {
        debugPrint('❌ [FCM] 승인 요청 데이터 불완전: userId=$userId, deviceId=$newDeviceId, platform=$newPlatformRaw');
        return;
      }
      
      // 🔑 CRITICAL: 플랫폼 이름을 대문자로 변환 (fcm_tokens 문서 ID 형식에 맞춤)
      // device_approval_requests: 'android', 'ios' (소문자)
      // fcm_tokens: 'Android', 'iOS' (대문자)
      String newPlatform;
      if (newPlatformRaw.toLowerCase() == 'android') {
        newPlatform = 'Android';
      } else if (newPlatformRaw.toLowerCase() == 'ios') {
        newPlatform = 'iOS';
      } else {
        newPlatform = newPlatformRaw; // web, unknown 등
      }
      
      debugPrint('📋 [FCM] 승인할 기기 정보: userId=$userId, deviceId=$newDeviceId, platform=$newPlatform (원본: $newPlatformRaw)');
      
      // 🔧 Step 2: device_approval_requests 상태 업데이트 (기존 로직)
      int retryCount = 0;
      const maxRetries = 2;
      bool success = false;
      
      while (retryCount < maxRetries && !success) {
        try {
          await _firestore.collection('device_approval_requests').doc(approvalRequestId).update({
            'status': 'approved',
            'approvedAt': FieldValue.serverTimestamp(),
          }).timeout(const Duration(seconds: 5));
          
          success = true;
          debugPrint('✅ [FCM] device_approval_requests 승인 완료');
        } catch (e) {
          retryCount++;
          if (retryCount < maxRetries) {
            await Future.delayed(const Duration(milliseconds: 500));
          } else {
            rethrow;
          }
        }
      }
      
      // 🔐 Step 3: fcm_tokens 컬렉션의 isApproved 필드 업데이트 (NEW!)
      try {
        debugPrint('🔐 [FCM] fcm_tokens 업데이트 시작...');
        
        final tokensQuery = await _firestore
            .collection('fcm_tokens')
            .where('userId', isEqualTo: userId)
            .where('deviceId', isEqualTo: newDeviceId)
            .where('platform', isEqualTo: newPlatform)
            .get()
            .timeout(const Duration(seconds: 5));
        
        if (tokensQuery.docs.isEmpty) {
          debugPrint('⚠️ [FCM] fcm_tokens에서 일치하는 토큰 없음 (이미 삭제되었거나 아직 생성 안됨)');
        } else {
          debugPrint('📋 [FCM] ${tokensQuery.docs.length}개의 토큰 문서 발견, isApproved 업데이트 중...');
          
          for (var doc in tokensQuery.docs) {
            await doc.reference.update({
              'isApproved': true,
              'approvedAt': FieldValue.serverTimestamp(),
            }).timeout(const Duration(seconds: 5));
            
            debugPrint('✅ [FCM] fcm_tokens 문서 업데이트 완료: ${doc.id}');
          }
          
          debugPrint('✅ [FCM] 모든 fcm_tokens 업데이트 완료');
        }
      } catch (e) {
        debugPrint('⚠️ [FCM] fcm_tokens 업데이트 실패 (계속 진행): $e');
        // fcm_tokens 업데이트 실패해도 승인 프로세스는 완료된 것으로 처리
      }
      
      // 🛑 Step 4: 다른 기기들에게 승인 취소 알림 전송 (NEW!)
      // (한 기기가 승인하면 다른 기기들의 승인 다이얼로그 자동 닫기)
      try {
        debugPrint('🛑 [FCM-CANCEL] 다른 기기들에게 승인 취소 알림 전송 시작...');
        
        // 승인된 새 기기 정보 (Cloud Function 호환성을 위해 필요)
        final newDeviceName = data['newDeviceName'] as String? ?? 'Unknown Device';
        final newPlatformForQueue = newPlatformRaw; // 원본 플랫폼 이름 사용 (소문자)
        
        // 현재 승인 처리 중인 기기의 deviceId와 platform 가져오기
        final currentDeviceId = await _platformUtils.getDeviceId();
        final currentPlatformRaw = _platformUtils.getPlatformName(); // 소문자: android, ios
        
        // 🔑 CRITICAL: currentPlatform도 대문자로 변환 (newPlatform과 형식 통일)
        String currentPlatform;
        if (currentPlatformRaw.toLowerCase() == 'android') {
          currentPlatform = 'Android';
        } else if (currentPlatformRaw.toLowerCase() == 'ios') {
          currentPlatform = 'iOS';
        } else {
          currentPlatform = currentPlatformRaw; // web, unknown 등
        }
        
        debugPrint('🔍 [FCM-CANCEL] 현재 승인 처리 기기: ${currentDeviceId}_$currentPlatform');
        
        // 🔑 CRITICAL: 승인된 기기들만 조회 (isApproved: true)
        // 승인 요청을 받았던 기존 기기들에게만 취소 알림을 보내야 함
        final allTokensQuery = await _firestore
            .collection('fcm_tokens')
            .where('userId', isEqualTo: userId)
            .where('isActive', isEqualTo: true)
            .where('isApproved', isEqualTo: true) // 🔑 승인된 기기만 필터링
            .get()
            .timeout(const Duration(seconds: 5));
        
        // 현재 승인 처리 기기와 새 기기를 제외한 다른 기기들 필터링
        final newDeviceKey = '${newDeviceId}_$newPlatform';
        final currentDeviceKey = '${currentDeviceId}_$currentPlatform';
        
        debugPrint('🔍 [FCM-CANCEL] 제외할 기기 키: new=$newDeviceKey, current=$currentDeviceKey');
        
        final otherDeviceTokens = allTokensQuery.docs.where((doc) {
          final data = doc.data();
          final deviceKey = '${data['deviceId']}_${data['platform']}';
          final isNewDevice = deviceKey == newDeviceKey;
          final isCurrentDevice = deviceKey == currentDeviceKey;
          final shouldExclude = isNewDevice || isCurrentDevice;
          
          debugPrint('   🔍 [FCM-CANCEL] 기기 체크: $deviceKey');
          debugPrint('      - 새 기기?: $isNewDevice');
          debugPrint('      - 승인한 기기?: $isCurrentDevice');
          debugPrint('      - 제외?: $shouldExclude');
          
          return !shouldExclude;
        }).toList();
        
        if (otherDeviceTokens.isEmpty) {
          debugPrint('✅ [FCM-CANCEL] 취소 알림을 보낼 다른 기기 없음');
        } else {
          debugPrint('📤 [FCM-CANCEL] ${otherDeviceTokens.length}개의 다른 기기에 취소 알림 전송...');
          
          // 각 기기에 취소 알림 큐 생성
          for (var tokenDoc in otherDeviceTokens) {
            final tokenData = tokenDoc.data();
            final targetToken = tokenData['fcmToken'] as String;
            final targetDeviceName = tokenData['deviceName'] as String?;
            
            await _firestore.collection('fcm_approval_notification_queue').add({
              'targetToken': targetToken,
              'targetDeviceName': targetDeviceName ?? 'Unknown Device',
              'approvalRequestId': approvalRequestId,
              'newDeviceName': newDeviceName, // Cloud Function 호환성
              'newPlatform': newPlatformForQueue, // Cloud Function 호환성
              'userId': userId,
              'message': {
                'type': 'device_approval_cancelled',
                'title': '✅ 기기 승인 완료',
                'body': '다른 기기에서 승인이 완료되었습니다.',
                'approvalRequestId': approvalRequestId,
                'action': 'approved',
              },
              'createdAt': FieldValue.serverTimestamp(),
              'processed': false,
            });
            
            debugPrint('✅ [FCM-CANCEL] 취소 알림 큐 생성: ${targetDeviceName ?? targetToken.substring(0, 20)}...');
          }
          
          debugPrint('✅ [FCM-CANCEL] 모든 취소 알림 큐 생성 완료 (${otherDeviceTokens.length}개)');
        }
      } catch (e) {
        debugPrint('⚠️ [FCM-CANCEL] 취소 알림 전송 실패 (무시): $e');
        // 취소 알림 실패해도 승인 프로세스는 완료된 것으로 처리
      }
      
    } catch (e, stackTrace) {
      debugPrint('❌ [FCM] 기기 승인 오류: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// 기기 승인 거부 처리
  Future<void> _rejectDeviceApproval(String approvalRequestId) async {
    try {
      debugPrint('❌ [FCM] 기기 승인 거부: $approvalRequestId');
      
      int retryCount = 0;
      const maxRetries = 2;
      bool success = false;
      
      while (retryCount < maxRetries && !success) {
        try {
          await _firestore.collection('device_approval_requests').doc(approvalRequestId).update({
            'status': 'rejected',
            'rejectedAt': FieldValue.serverTimestamp(),
          }).timeout(const Duration(seconds: 5));
          
          success = true;
          debugPrint('✅ [FCM] Firestore 거부 완료');
        } catch (e) {
          retryCount++;
          if (retryCount < maxRetries) {
            await Future.delayed(const Duration(milliseconds: 500));
          } else {
            rethrow;
          }
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [FCM] 기기 승인 거부 오류: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// 승인 요청 재전송
  Future<void> resendApprovalRequest(String approvalRequestId, String userId) async {
    try {
      // ignore: avoid_print
      print('🔄 [FCM-RESEND] 승인 요청 재전송 시작');
      
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
      
      final otherDeviceTokens = await _databaseService.getAllActiveFcmTokens(userId);
      final activeTokens = otherDeviceTokens.where((token) => 
        '${token.deviceId}_${token.platform}' != '${data['newDeviceId']}_${data['newPlatform']}'
      ).toList();
      
      if (activeTokens.isEmpty) {
        // ignore: avoid_print
        print('⚠️ [FCM-RESEND] 활성 기기가 없음');
        return;
      }
      
      // 🎵 사용자 ringtone 정보 가져오기
      String? ringtone;
      try {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final userData = userDoc.data();
          ringtone = userData?['ringtone'] as String?;
          // ignore: avoid_print
          print('🎵 [FCM-RESEND] 사용자 ringtone: ${ringtone ?? "없음"}');
        }
      } catch (e) {
        // ignore: avoid_print
        print('⚠️ [FCM-RESEND] ringtone 조회 실패: $e');
      }
      
      // ignore: avoid_print
      print('📤 [FCM-RESEND] ${activeTokens.length}개 기기에 알림 재전송');
      
      for (var token in activeTokens) {
        await _firestore.collection('fcm_approval_notification_queue').add({
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
            if (ringtone != null) 'ringtone': ringtone, // 🎵 ringtone 추가
          },
          'createdAt': FieldValue.serverTimestamp(),
          'processed': false,
        });
      }
      
      // ignore: avoid_print
      print('✅ [FCM-RESEND] 승인 요청 재전송 완료');
    } catch (e) {
      // ignore: avoid_print
      print('❌ [FCM-RESEND] 재전송 실패: $e');
    }
  }

  /// 승인 요청 정보 설정
  void setApprovalRequestInfo(String? requestId, String? userId) {
    _currentApprovalRequestId = requestId;
    _currentUserId = userId;
  }

  /// 승인 요청 정보 조회
  (String?, String?) getApprovalRequestInfo() {
    return (_currentApprovalRequestId, _currentUserId);
  }
}
