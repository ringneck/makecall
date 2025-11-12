# Firebase Cloud Functions for MAKECALL App
## 고급 웹푸시 알림 시스템

이 문서는 MAKECALL 앱의 Firebase Cloud Functions 설정 및 배포 가이드입니다.

---

## 📋 목차

1. [기능 개요](#기능-개요)
2. [사전 요구사항](#사전-요구사항)
3. [설치 및 배포](#설치-및-배포)
4. [함수 상세 설명](#함수-상세-설명)
5. [Firestore 컬렉션 구조](#firestore-컬렉션-구조)
6. [클라이언트 통합](#클라이언트-통합)
7. [테스트 및 모니터링](#테스트-및-모니터링)
8. [문제 해결](#문제-해결)

---

## 🎯 기능 개요

### 1. **기존 함수 (유지)**
- ✅ `sendForceLogoutNotification` - 중복 로그인 시 강제 로그아웃 알림
- ✅ `remoteLogout` - 원격 기기 로그아웃
- ✅ `cleanupExpiredTokens` - 만료된 FCM 토큰 자동 정리 (스케줄)

### 2. **신규 고급 푸시 기능**
- 🆕 `sendIncomingCallNotification` - 실시간 착신 전화 알림
- 🆕 `sendCallStatusNotification` - 통화 상태 변경 알림
- 🆕 `sendGroupMessage` - 그룹 메시지 브로드캐스트
- 🆕 `processScheduledNotifications` - 예약 알림 자동 처리 (스케줄)
- 🆕 `sendCustomNotification` - 사용자 지정 알림 전송
- 🆕 `subscribeWebPush` - 웹푸시 구독 관리
- 🆕 `getNotificationStats` - 알림 통계 API
- 🆕 `validateAllTokens` - FCM 토큰 유효성 일괄 검사
- 🆕 `manualCleanupTokens` - 수동 토큰 정리

---

## 🔧 사전 요구사항

### 1. Firebase 프로젝트 설정
```bash
# Firebase CLI 설치
npm install -g firebase-tools

# Firebase 로그인
firebase login

# 프로젝트 초기화 (이미 완료된 경우 스킵)
firebase init functions
```

### 2. Node.js 환경
- **Node.js 버전**: 22 (package.json에 지정됨)
- **NPM 패키지**: 자동 설치됨

### 3. Firebase 프로젝트 권한
- **Firebase Admin SDK** 활성화
- **Cloud Firestore** 활성화
- **Firebase Cloud Messaging (FCM)** 활성화
- **Cloud Scheduler** 활성화 (스케줄 함수용)

---

## 🚀 설치 및 배포

### 1. 의존성 설치
```bash
cd functions
npm install
```

### 2. ESLint 검사 (선택사항)
```bash
npm run lint
```

### 3. Functions 배포
```bash
# 모든 함수 배포
firebase deploy --only functions

# 특정 함수만 배포
firebase deploy --only functions:sendIncomingCallNotification

# 여러 함수 배포
firebase deploy --only functions:sendIncomingCallNotification,functions:sendCallStatusNotification
```

### 4. 배포 확인
```bash
# 배포된 함수 목록 확인
firebase functions:list

# 로그 확인
firebase functions:log
```

---

## 📚 함수 상세 설명

### 1. `sendForceLogoutNotification` (Firestore Trigger)
**트리거**: `fcm_force_logout_queue/{queueId}` 문서 생성 시  
**용도**: 중복 로그인 감지 시 기존 기기에 강제 로그아웃 알림 전송

**Firestore 문서 구조** (`fcm_force_logout_queue`):
```javascript
{
  targetToken: "FCM_TOKEN_STRING",
  newDeviceName: "Galaxy S23",
  newPlatform: "android",
  message: {
    title: "새로운 기기에서 로그인",
    body: "Galaxy S23에서 로그인되어 이 기기는 로그아웃됩니다."
  },
  processed: false,
  createdAt: Timestamp
}
```

**자동 처리**:
- ✅ 메시지 전송 후 `processed: true` 업데이트
- ✅ 무효한 토큰 자동 삭제
- ✅ 에러 정보 저장

---

### 2. `remoteLogout` (Callable Function)
**호출 방법**: Flutter 클라이언트에서 `FirebaseFunctions.instance.httpsCallable('remoteLogout')`

**요청 파라미터**:
```dart
{
  "targetDeviceId": "device_12345",
  "targetUserId": "user_abc123"
}
```

**응답**:
```dart
{
  "success": true,
  "message": "원격 로그아웃이 완료되었습니다.",
  "deviceName": "iPhone 14 Pro"
}
```

**권한 확인**: 본인의 기기만 로그아웃 가능

---

### 3. `cleanupExpiredTokens` (Scheduled Function)
**스케줄**: 매일 자정 (KST)  
**용도**: 30일 이상 사용되지 않은 FCM 토큰 자동 삭제

**설정 확인**:
```bash
# Firebase Console > Cloud Scheduler
# Schedule: 0 0 * * *
# Timezone: Asia/Seoul
```

**수동 실행**:
```dart
// Flutter에서 수동 실행
FirebaseFunctions.instance.httpsCallable('manualCleanupTokens').call();
```

---

### 4. `sendIncomingCallNotification` (Firestore Trigger) 🆕
**트리거**: `incoming_calls/{callId}` 문서 생성 시  
**용도**: 착신 전화 실시간 알림

**Firestore 문서 구조** (`incoming_calls`):
```javascript
{
  userId: "user_abc123",
  callerNumber: "010-1234-5678",
  callerName: "홍길동",
  extension: "8001",
  timestamp: Timestamp
}
```

**웹푸시 특징**:
- 🔔 높은 우선순위 (Urgency: high)
- 📳 진동 패턴: [200, 100, 200]
- 🎬 액션 버튼: "응답", "거부"
- 🔒 requireInteraction: true (사용자 조작 필수)

---

### 5. `sendCallStatusNotification` (Firestore Trigger) 🆕
**트리거**: `call_history/{historyId}` 문서 업데이트 시  
**용도**: 통화 종료, 부재중 전화 알림

**감지 상태 변경**:
- `status: "ended"` - 통화 종료
- `status: "missed"` - 부재중 전화

---

### 6. `sendGroupMessage` (Callable Function) 🆕
**호출 방법**:
```dart
final result = await FirebaseFunctions.instance
    .httpsCallable('sendGroupMessage')
    .call({
      'userIds': ['user1', 'user2', 'user3'],
      'title': '공지사항',
      'body': '중요한 공지가 있습니다.',
      'data': {
        'type': 'announcement',
        'priority': 'high'
      }
    });
```

**응답**:
```dart
{
  "success": true,
  "successCount": 8,
  "failureCount": 0,
  "totalTokens": 8
}
```

---

### 7. `processScheduledNotifications` (Scheduled Function) 🆕
**스케줄**: 매분 실행 (`* * * * *`)  
**용도**: 예약 알림 자동 처리

**Firestore 문서 구조** (`scheduled_notifications`):
```javascript
{
  userId: "user_abc123",
  title: "회의 알림",
  body: "30분 후 회의가 있습니다.",
  scheduledAt: Timestamp, // 전송 예정 시각
  processed: false,
  data: {
    type: "meeting_reminder",
    meetingId: "meeting_123"
  }
}
```

**자동 처리**:
- ✅ `scheduledAt <= now` && `processed == false` 조건 확인
- ✅ 알림 전송 후 `processed: true` 업데이트
- ✅ 전송 시각 기록 (`sentAt`)

---

### 8. `sendCustomNotification` (Callable Function) 🆕
**호출 방법**:
```dart
final result = await FirebaseFunctions.instance
    .httpsCallable('sendCustomNotification')
    .call({
      'userId': 'user_abc123',
      'title': '새로운 메시지',
      'body': '홍길동님이 메시지를 보냈습니다.',
      'priority': 'high',
      'data': {
        'messageId': 'msg_123',
        'senderId': 'user_xyz'
      },
      'webpush': {
        'icon': '/icons/message_icon.png',
        'requireInteraction': true,
        'vibrate': [200, 100, 200]
      }
    });
```

**우선순위**:
- `"high"` - 즉시 전달 (배터리 절약 모드에서도 전달)
- `"normal"` - 일반 전달

---

### 9. `subscribeWebPush` (Callable Function) 🆕
**용도**: 웹 브라우저 FCM 토큰 등록

**호출 방법**:
```dart
await FirebaseFunctions.instance
    .httpsCallable('subscribeWebPush')
    .call({
      'fcmToken': 'WEB_FCM_TOKEN',
      'deviceId': 'browser_12345',
      'deviceName': 'Chrome on Windows'
    });
```

---

### 10. `getNotificationStats` (HTTP Function) 🆕
**엔드포인트**: `https://asia-east1-YOUR_PROJECT.cloudfunctions.net/getNotificationStats`

**응답 예시**:
```json
{
  "activeTokens": 156,
  "processedLogouts": 42,
  "pendingScheduledNotifications": 8,
  "timestamp": "2025-01-07T10:30:00Z"
}
```

**사용 예**:
```bash
curl https://asia-east1-YOUR_PROJECT.cloudfunctions.net/getNotificationStats
```

---

### 11. `validateAllTokens` (Callable Function) 🆕
**용도**: 모든 FCM 토큰 유효성 일괄 검사 및 무효 토큰 삭제

**호출 방법**:
```dart
final result = await FirebaseFunctions.instance
    .httpsCallable('validateAllTokens')
    .call();

print('유효: ${result.data['validCount']}');
print('무효: ${result.data['invalidCount']}');
print('삭제: ${result.data['deletedCount']}');
```

---

## 🗄️ Firestore 컬렉션 구조

### 1. `fcm_tokens` (FCM 토큰 저장)
```javascript
{
  userId: "user_abc123",
  fcmToken: "FCM_TOKEN_STRING",
  deviceId: "device_12345",
  deviceName: "Galaxy S23",
  platform: "android" | "ios" | "web",
  createdAt: Timestamp,
  lastActiveAt: Timestamp
}
```

### 2. `fcm_force_logout_queue` (강제 로그아웃 큐)
```javascript
{
  targetToken: "FCM_TOKEN_STRING",
  newDeviceName: "iPhone 14",
  newPlatform: "ios",
  message: {
    title: "새로운 기기에서 로그인",
    body: "..."
  },
  processed: false,
  sentAt: Timestamp | null,
  error: string | null
}
```

### 3. `incoming_calls` (착신 전화)
```javascript
{
  userId: "user_abc123",
  callerNumber: "010-1234-5678",
  callerName: "홍길동",
  extension: "8001",
  timestamp: Timestamp
}
```

### 4. `call_history` (통화 내역)
```javascript
{
  userId: "user_abc123",
  phoneNumber: "010-1234-5678",
  status: "ringing" | "answered" | "ended" | "missed",
  duration: 120, // seconds
  timestamp: Timestamp
}
```

### 5. `scheduled_notifications` (예약 알림)
```javascript
{
  userId: "user_abc123",
  title: "회의 알림",
  body: "30분 후 회의가 있습니다.",
  scheduledAt: Timestamp,
  processed: false,
  sentAt: Timestamp | null,
  data: {
    type: "meeting_reminder",
    meetingId: "meeting_123"
  }
}
```

---

## 📱 클라이언트 통합

### Flutter 클라이언트 설정

#### 1. Firebase Functions 초기화
```dart
import 'package:cloud_functions/cloud_functions.dart';

final functions = FirebaseFunctions.instanceFor(region: 'asia-east1');
```

#### 2. Callable Functions 호출
```dart
// 원격 로그아웃
Future<void> remoteLogoutDevice(String deviceId) async {
  try {
    final result = await functions.httpsCallable('remoteLogout').call({
      'targetDeviceId': deviceId,
      'targetUserId': currentUserId,
    });
    
    if (result.data['success']) {
      print('로그아웃 성공: ${result.data['deviceName']}');
    }
  } catch (e) {
    print('원격 로그아웃 실패: $e');
  }
}

// 그룹 메시지 전송
Future<void> sendGroupNotification(List<String> userIds, String title, String body) async {
  try {
    final result = await functions.httpsCallable('sendGroupMessage').call({
      'userIds': userIds,
      'title': title,
      'body': body,
      'data': {'type': 'announcement'},
    });
    
    print('전송 성공: ${result.data['successCount']}개');
  } catch (e) {
    print('그룹 메시지 전송 실패: $e');
  }
}

// 예약 알림 생성
Future<void> scheduleNotification(DateTime scheduledTime, String title, String body) async {
  await FirebaseFirestore.instance.collection('scheduled_notifications').add({
    'userId': currentUserId,
    'title': title,
    'body': body,
    'scheduledAt': Timestamp.fromDate(scheduledTime),
    'processed': false,
    'data': {'type': 'reminder'},
  });
}
```

#### 3. FCM 메시지 수신 처리
```dart
FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  print('메시지 수신: ${message.notification?.title}');
  
  final type = message.data['type'];
  
  switch (type) {
    case 'force_logout':
      // 강제 로그아웃 처리
      handleForceLogout(message.data);
      break;
    case 'incoming_call':
      // 착신 전화 UI 표시
      showIncomingCallDialog(message.data);
      break;
    case 'call_status_update':
      // 통화 상태 업데이트
      updateCallStatus(message.data);
      break;
    case 'group_message':
      // 그룹 메시지 표시
      showGroupMessage(message.data);
      break;
    case 'custom_notification':
      // 커스텀 알림 처리
      handleCustomNotification(message.data);
      break;
  }
});
```

---

## 🧪 테스트 및 모니터링

### 1. 로컬 테스트 (Emulator)
```bash
# Firebase Emulator 시작
firebase emulators:start

# 특정 함수만 테스트
firebase emulators:start --only functions
```

### 2. 로그 확인
```bash
# 실시간 로그 스트리밍
firebase functions:log --only sendIncomingCallNotification

# 최근 로그 확인
firebase functions:log --limit 100
```

### 3. Firebase Console 모니터링
- **Functions 대시보드**: https://console.firebase.google.com/project/YOUR_PROJECT/functions
- **Cloud Scheduler**: https://console.cloud.google.com/cloudscheduler
- **메트릭 확인**:
  - 실행 횟수
  - 평균 실행 시간
  - 오류율
  - 메모리 사용량

### 4. 알림 통계 확인
```bash
# HTTP 엔드포인트 호출
curl https://asia-east1-YOUR_PROJECT.cloudfunctions.net/getNotificationStats
```

---

## 🐛 문제 해결

### 1. 함수 배포 실패
```bash
# 오류 확인
firebase deploy --only functions --debug

# Node.js 버전 확인
node --version  # v22.x.x 필요

# 의존성 재설치
cd functions
rm -rf node_modules package-lock.json
npm install
```

### 2. FCM 토큰 무효화
**증상**: "messaging/invalid-registration-token" 오류

**해결**:
- ✅ 자동 처리: `sendForceLogoutNotification`에서 자동 삭제
- ✅ 수동 처리: `validateAllTokens` 함수 호출

### 3. 스케줄 함수 미실행
**확인사항**:
- Cloud Scheduler 활성화 여부
- 타임존 설정 (Asia/Seoul)
- IAM 권한 설정

**수동 트리거**:
```bash
# Firebase Console > Cloud Scheduler
# 해당 스케줄 선택 > "지금 실행" 클릭
```

### 4. 웹푸시 미수신
**체크리스트**:
- ✅ 웹앱에서 FCM 토큰 등록 확인
- ✅ HTTPS 환경 (localhost 제외)
- ✅ 브라우저 알림 권한 허용
- ✅ Service Worker 등록 확인

### 5. 메시지 전송 실패
**로그 확인**:
```bash
firebase functions:log --only sendIncomingCallNotification
```

**일반적인 원인**:
- 무효한 FCM 토큰
- Firestore 권한 문제
- 네트워크 타임아웃

---

## 📊 성능 최적화

### 1. 배치 처리
- 500개 단위로 메시지 전송
- Firestore 배치 쓰기 사용

### 2. 에러 핸들링
- 무효한 토큰 자동 제거
- 재시도 로직 구현

### 3. 메모리 최적화
- 대용량 데이터 스트림 처리
- 불필요한 변수 제거

---

## 🔐 보안 권장사항

### 1. Firestore Security Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // FCM 토큰: 본인만 읽기/쓰기
    match /fcm_tokens/{tokenId} {
      allow read, write: if request.auth != null && 
                           tokenId.matches(request.auth.uid + '_.*');
    }
    
    // 강제 로그아웃 큐: 시스템만 쓰기
    match /fcm_force_logout_queue/{queueId} {
      allow read: if false;
      allow write: if false;
    }
    
    // 예약 알림: 본인만 읽기/쓰기
    match /scheduled_notifications/{notifId} {
      allow read, write: if request.auth != null && 
                           resource.data.userId == request.auth.uid;
    }
  }
}
```

### 2. Callable Functions 권한
- ✅ 모든 Callable Functions는 인증 확인 필수
- ✅ `remoteLogout`: 본인 기기만 로그아웃 가능
- ✅ `sendGroupMessage`: 발신자 검증

---

## 📚 참고 자료

### Firebase 공식 문서
- [Firebase Cloud Functions](https://firebase.google.com/docs/functions)
- [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging)
- [Cloud Scheduler](https://cloud.google.com/scheduler/docs)

### 추가 리소스
- [FCM 웹푸시 가이드](https://firebase.google.com/docs/cloud-messaging/js/client)
- [Callable Functions 보안](https://firebase.google.com/docs/functions/callable)

---

## 📞 지원

문제가 발생하거나 질문이 있으시면:
- **이메일**: help@makecall.io
- **GitHub Issues**: https://github.com/ringneck/makecall/issues

---

**마지막 업데이트**: 2025-01-07  
**Functions 버전**: 2.0.0  
**Node.js 버전**: 22
