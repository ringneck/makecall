# 착신전환 설정 변경 푸시 알림 기능

## 📋 개요

착신전환 설정이 변경될 때 **현재 기기를 제외한 모든 활성 기기**에 푸시 알림을 자동으로 전송하는 기능입니다.

사용자가 여러 기기에서 로그인한 경우, 한 기기에서 착신전환 설정을 변경하면 다른 모든 기기에 실시간 알림이 전송됩니다.

## 🚀 기능

### 1. 착신전환 설정 활성화
- **알림 제목**: "착신전환 설정"
- **알림 내용**: "착신전환 사용이 설정되었습니다."
- **전송 대상**: 현재 기기를 제외한 모든 활성 기기

### 2. 착신전환 해제
- **알림 제목**: "착신전환 해제"
- **알림 내용**: "착신전환 사용이 해제되었습니다."
- **전송 대상**: 현재 기기를 제외한 모든 활성 기기

### 3. 착신전환 번호 변경
- **알림 제목**: "착신전환 번호 변경"
- **알림 내용**: "착신전환 번호가 변경되었습니다. {전화번호}"
- **전송 대상**: 현재 기기를 제외한 모든 활성 기기

## 📂 주요 파일

### Flutter 앱 (클라이언트)

#### 1. `lib/services/fcm/fcm_call_forward_service.dart`
착신전환 푸시 알림 서비스의 핵심 로직

```dart
class FCMCallForwardService {
  // 착신전환 설정 활성화 알림
  Future<void> sendCallForwardEnabledNotification({
    required String userId,
    required String extensionNumber,
  })

  // 착신전환 해제 알림
  Future<void> sendCallForwardDisabledNotification({
    required String userId,
    required String extensionNumber,
  })

  // 착신전환 번호 변경 알림
  Future<void> sendCallForwardNumberChangedNotification({
    required String userId,
    required String extensionNumber,
    required String newNumber,
  })
}
```

#### 2. `lib/widgets/call_forward_settings_card.dart`
착신전환 설정 위젯에 푸시 알림 통합

**주요 변경사항**:
- `_toggleCallForward()`: 착신전환 활성화/해제 시 푸시 알림 전송
- `_updateDestination()`: 착신번호 변경 시 푸시 알림 전송

### Firebase Cloud Functions (서버)

#### `functions/index.js` - `sendCallForwardNotification`
Firestore `fcm_notifications` 컬렉션을 감시하여 자동으로 FCM 푸시 알림 전송

**트리거**: `onCreate` 이벤트 (새 문서 생성 시)

**처리 흐름**:
1. Firestore에서 알림 데이터 읽기
2. FCM 메시지 구성 (제목, 내용, 데이터)
3. FCM API를 통해 푸시 알림 전송
4. 전송 상태 업데이트 (sent/failed)
5. 무효 토큰 자동 정리

## 🔄 동작 흐름

```
┌─────────────────────┐
│   사용자 (기기 A)    │
│  착신전환 설정 변경   │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────────────────────┐
│  FCMCallForwardService              │
│  1. 현재 기기 정보 가져오기          │
│  2. 모든 활성 FCM 토큰 조회          │
│  3. 현재 기기 제외하고 필터링        │
└──────────┬──────────────────────────┘
           │
           ▼
┌─────────────────────────────────────┐
│  Firestore (fcm_notifications)      │
│  알림 데이터 저장                   │
│  - fcmToken                         │
│  - deviceId, deviceName, platform   │
│  - notification (title, body, data) │
└──────────┬──────────────────────────┘
           │
           ▼
┌─────────────────────────────────────┐
│  Cloud Functions                    │
│  sendCallForwardNotification        │
│  1. onCreate 트리거 감지            │
│  2. FCM 메시지 구성                 │
│  3. admin.messaging().send()        │
│  4. 전송 상태 업데이트              │
└──────────┬──────────────────────────┘
           │
           ▼
┌─────────────────────┐
│  기기 B, C, D...    │
│  푸시 알림 수신     │
└─────────────────────┘
```

## 🔧 설정 방법

### 1. Firebase Functions 배포

```bash
cd functions
firebase deploy --only functions:sendCallForwardNotification
```

### 2. Firestore 보안 규칙 (선택사항)

`fcm_notifications` 컬렉션에 대한 보안 규칙 설정:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // FCM 알림 컬렉션
    match /fcm_notifications/{notificationId} {
      // 인증된 사용자만 자신의 알림 생성 가능
      allow create: if request.auth != null 
                    && request.resource.data.userId == request.auth.uid;
      
      // 읽기는 자신의 알림만
      allow read: if request.auth != null 
                   && resource.data.userId == request.auth.uid;
      
      // Functions가 업데이트 가능하도록 (서버 사이드)
      allow update: if true;
    }
  }
}
```

### 3. Android 알림 채널 설정 (이미 구성됨)

착신전환 알림은 `call_forward_channel`을 사용합니다.

**채널 속성**:
- **ID**: `call_forward_channel`
- **이름**: "Call Forward Notifications"
- **중요도**: HIGH
- **소리**: 기본 알림음
- **진동**: 활성화

## 📊 Firestore 데이터 구조

### `fcm_notifications` 컬렉션

```javascript
{
  userId: "user123",                    // 사용자 ID
  fcmToken: "eAbCd...",                 // 대상 기기 FCM 토큰
  deviceId: "device456",                // 기기 고유 ID
  deviceName: "Galaxy S21",             // 기기 이름
  platform: "android",                  // 플랫폼 (android/ios/web)
  notification: {
    notification: {
      title: "착신전환 설정",          // 알림 제목
      body: "착신전환 사용이 설정되었습니다."  // 알림 내용
    },
    data: {
      type: "call_forward_enabled",    // 알림 타입
      extensionNumber: "1001",         // 내선번호
      timestamp: "2024-01-15T10:30:00Z"  // 타임스탬프
    }
  },
  status: "sent",                      // 상태 (pending/sent/failed)
  createdAt: Timestamp,                // 생성 시간
  sentAt: Timestamp                    // 전송 시간
}
```

## 🧪 테스트 방법

### 1. 로컬 테스트

1. **여러 기기에서 로그인**:
   - 기기 A: Android 에뮬레이터
   - 기기 B: iOS 시뮬레이터
   - 기기 C: Web 브라우저

2. **착신전환 설정 변경** (기기 A):
   - 착신전환 활성화 → 기기 B, C에 알림 수신
   - 착신번호 변경 → 기기 B, C에 알림 수신
   - 착신전환 해제 → 기기 B, C에 알림 수신

3. **로그 확인**:
   ```bash
   # Flutter 앱 로그
   flutter logs

   # Cloud Functions 로그
   firebase functions:log --only sendCallForwardNotification
   ```

### 2. Firebase Console에서 확인

**Firestore Database**:
1. `fcm_notifications` 컬렉션 확인
2. 새 문서가 생성되는지 확인
3. `status` 필드가 `sent`로 업데이트되는지 확인

**Cloud Functions**:
1. Functions 대시보드 → `sendCallForwardNotification` 클릭
2. 로그 탭에서 실행 기록 확인
3. 성공/실패 여부 확인

## 🐛 문제 해결

### 1. 알림이 전송되지 않음

**원인**: Cloud Functions가 배포되지 않음
```bash
cd functions
firebase deploy --only functions:sendCallForwardNotification
```

**원인**: FCM 토큰이 만료됨
- 앱을 재시작하여 새 토큰 생성
- Firestore `fcm_tokens` 컬렉션 확인

### 2. 현재 기기에도 알림이 옴

**원인**: 기기 ID 또는 플랫폼 정보가 올바르지 않음
- `FCMPlatformUtils.getDeviceId()` 확인
- `fcm_tokens` 컬렉션에서 `deviceId`와 `platform` 필드 확인

### 3. Cloud Functions 오류

**로그 확인**:
```bash
firebase functions:log --only sendCallForwardNotification
```

**일반적인 오류**:
- `messaging/registration-token-not-registered`: 무효 토큰 (자동 정리됨)
- `messaging/invalid-argument`: FCM 메시지 형식 오류
- Firestore 권한 오류: 보안 규칙 확인

## 📈 모니터링

### Cloud Functions 메트릭

Firebase Console → Functions → `sendCallForwardNotification`에서 확인:
- **실행 횟수**: 알림 전송 건수
- **실행 시간**: 평균 처리 시간
- **오류 비율**: 실패한 알림 비율

### Firestore 데이터

```javascript
// 실패한 알림 조회
fcm_notifications
  .where('status', '==', 'failed')
  .orderBy('createdAt', 'desc')
  .limit(10)
```

## 🔐 보안 고려사항

1. **인증된 사용자만 알림 생성**: `userId` 검증
2. **현재 기기 제외**: Device ID + Platform 조합으로 구분
3. **무효 토큰 자동 정리**: `registration-token-not-registered` 오류 처리
4. **Firestore 보안 규칙**: 사용자별 데이터 접근 제어

## 📝 향후 개선 사항

- [ ] 알림 우선순위 설정 (긴급/일반)
- [ ] 알림 배치 전송 (여러 변경사항 묶어서 전송)
- [ ] 알림 히스토리 UI (사용자가 받은 알림 목록)
- [ ] 알림 설정 (착신전환 알림 끄기 옵션)
- [ ] 푸시 알림 재시도 로직 (실패 시 재전송)

## 📞 문의

문제가 발생하거나 개선 제안이 있으시면 이슈를 등록해주세요.
