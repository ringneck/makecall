# FCM 기기 승인 푸시 시스템 진단 보고서

## 날짜: 2025-11-22

## 🔍 진단 요청
새 기기 승인 요청 푸시가 iOS 기기로 전송되지 않는 문제 조사

## 📊 시스템 상태 확인

### 1. FCM 토큰 상태
```
사용자: 00UZFjXMjnSj0ThUnGlgkn8cgVy2

iOS 기기:
  - deviceName: iPhone 15 Pro (iOS 26.1)
  - isActive: true
  - isApproved: true
  - FCM Token: dM5Eudma0EG0rIzkB-LSKR:APA91bE...

Web 기기:
  - deviceName: chrome on MacIntel
  - isActive: true (타임아웃 후 false였으나 수동 복구)
  - isApproved: true (수동 승인)
  - FCM Token: cKD90Ly1Vf0ctcL00vSn6u:APA91bE...
```

### 2. 승인 요청 상태
```
device_approval_requests:
  - approvalRequestId: 00UZFjXMjnSj0ThUnGlgkn8cgVy2_web_chrome_MacIntel_web
  - status: pending → approved (수동 처리)
  - newDeviceName: chrome on MacIntel
  - newPlatform: web
  - createdAt: 2025-11-22 15:50:38
  - expiresAt: 2025-11-22 15:55:38 (5분 타임아웃)
```

### 3. FCM 알림 큐
```
fcm_approval_notification_queue:
  - 5개의 알림 대기 중
  - 모두 FCM 전송 실패 상태
  - errorCode: messaging/mismatched-credential
  - error: Permission 'cloudmessaging.messages.create' denied
```

## 🚨 문제 발견

### 핵심 문제: FCM 푸시 전송 권한 부족

**에러 메시지:**
```json
{
  "errorCode": "messaging/mismatched-credential",
  "error": "Permission 'cloudmessaging.messages.create' denied on resource '//cloudresourcemanager.googleapis.com/projects/makecallio' (or it may not exist)."
}
```

### 문제 플로우

1. ✅ Web에서 로그인 시도
2. ✅ iOS 기기가 활성 상태 확인됨
3. ✅ 승인 요청 생성 (device_approval_requests)
4. ✅ 알림 큐 추가 (fcm_approval_notification_queue)
5. ❌ **FCM 푸시 전송 실패** (권한 오류)
6. ❌ iOS 기기에 승인 요청 알림 미도착
7. ⏳ Web 기기는 5분간 승인 대기
8. ⏰ 타임아웃 발생
9. 🚪 Web 로그아웃 (isActive: false)
10. 🔧 수동 승인 처리 (isApproved: true)
11. ⚠️ isActive 복구 누락 → 로그인 불가

## 🔧 해결 방법

### 1. FCM 권한 추가 (근본 해결)

**Google Cloud Console IAM:**
- URL: https://console.cloud.google.com/iam-admin/iam?project=makecallio
- 서비스 계정: `firebase-adminsdk-xxxxx@makecallio.iam.gserviceaccount.com`
- 필요한 역할: `Firebase Cloud Messaging Admin` 또는 `Cloud Messaging Admin`

### 2. 수동 승인 시 체크리스트

완전한 수동 승인 처리:
```python
# 1. FCM 토큰 활성화 및 승인
db.collection('fcm_tokens').document(token_id).update({
    'isActive': True,      # ← 중요! 타임아웃 시 비활성화됨
    'isApproved': True,
})

# 2. 승인 요청 상태 변경
db.collection('device_approval_requests').document(token_id).update({
    'status': 'approved'
})
```

## 📋 코드 로직 검증

### 승인 대기 타임아웃 처리 (정상 작동 확인)

**파일:** `lib/services/fcm/fcm_device_approval_service.dart`
```dart
Future<bool> waitForDeviceApproval(String approvalRequestId) async {
  final timeout = DateTime.now().add(const Duration(minutes: 5));
  
  await for (var snapshot in stream) {
    // 승인 상태 체크
    if (status == 'approved') return true;
    if (status == 'rejected') return false;
    if (status == 'expired') return false;
    
    // 타임아웃 체크
    if (DateTime.now().isAfter(timeout)) {
      print('⏰ [FCM-WAIT] 승인 대기 시간 초과 (5분)');
      return false;  // ✅ 정상 작동
    }
  }
}
```

**파일:** `lib/services/fcm_service.dart`
```dart
// 승인 대기 실패 시 예외 발생
final approved = await _approvalService.waitForDeviceApproval(approvalRequestId);

if (!approved) {
  throw Exception('Device approval denied or timeout');  // ✅ 정상 작동
}
```

**파일:** `lib/services/auth_service.dart`
```dart
try {
  await fcmService.initialize(credential.user!.uid);
} catch (e, stackTrace) {
  // 기기 승인 관련 오류는 로그인 차단
  if (e.toString().contains('Device approval') || 
      e.toString().contains('denied') || 
      e.toString().contains('timeout')) {
    
    print('🚫 [AUTH] 기기 승인 실패 - 로그인 취소');
    await _auth.signOut();  // ✅ 정상 작동 (FCM 토큰 비활성화됨)
    rethrow;  // ✅ UI에 에러 전파
  }
}
```

## ✅ 검증 결과

### 정상 작동하는 부분
1. ✅ 승인 요청 생성 로직
2. ✅ 알림 큐 추가 로직
3. ✅ 승인 대기 타임아웃 처리
4. ✅ 타임아웃 시 로그아웃 처리
5. ✅ FCM 토큰 비활성화 처리
6. ✅ 예외 전파 및 UI 에러 처리

### 실패하는 부분
1. ❌ FCM 푸시 전송 (권한 부족)
   - 원인: Firebase Admin SDK 서비스 계정 권한 부족
   - 해결: Google Cloud IAM에서 FCM Admin 역할 추가

## 🎯 결론

**코드 로직은 정상 작동합니다.**

승인 요청 푸시가 전송되지 않는 이유는:
- Firebase Admin SDK 서비스 계정에 FCM 메시지 전송 권한이 없기 때문
- Cloud Functions 또는 백엔드 서비스가 `messaging/mismatched-credential` 에러로 푸시 전송 실패

**해결책:**
1. Google Cloud Console에서 서비스 계정에 FCM Admin 역할 추가
2. 또는 Firebase Admin SDK 키 재생성 후 재업로드

## 📝 추가 발견 사항

### 타임아웃 후 수동 승인 시 주의사항

타임아웃 발생 시:
1. Web 앱이 자동으로 로그아웃됨 (`isActive: false`)
2. 수동으로 `isApproved: true`만 설정하면 로그인 불가
3. **반드시 `isActive: true`도 함께 설정해야 함**

### 권장 수동 승인 프로세스

```python
# 완전한 승인 처리
web_token_id = 'userId_deviceId_platform'

db.collection('fcm_tokens').document(web_token_id).update({
    'isActive': True,      # 타임아웃으로 비활성화된 경우 복구
    'isApproved': True,
})

db.collection('device_approval_requests').document(web_token_id).update({
    'status': 'approved'
})
```

## 🔗 관련 파일

- `lib/services/fcm/fcm_device_approval_service.dart` - 승인 요청 및 대기 로직
- `lib/services/fcm_service.dart` - FCM 초기화 및 토큰 관리
- `lib/services/auth_service.dart` - 로그인 및 FCM 초기화 통합
- `lib/services/fcm/fcm_token_manager.dart` - FCM 토큰 저장 및 관리
- `scripts/check_firestore_state.py` - Firestore 상태 확인 스크립트
- `scripts/cleanup_test_data.py` - 테스트 데이터 정리 스크립트

## 🚀 다음 단계

1. Google Cloud Console에서 FCM 권한 추가
2. 승인 요청 푸시 재테스트
3. 정상 작동 확인
4. 문서 업데이트

---

**진단 완료 일시:** 2025-11-22 16:00 UTC
**진단자:** AI Flutter Development Assistant
