# FCM 웹푸시 기능 테스트 가이드

## 📋 목차
1. [개요](#개요)
2. [사전 준비사항](#사전-준비사항)
3. [VAPID 키 생성 및 설정](#vapid-키-생성-및-설정)
4. [웹푸시 활성화 방법](#웹푸시-활성화-방법)
5. [테스트 방법](#테스트-방법)
6. [문제 해결](#문제-해결)
7. [기술 상세](#기술-상세)

---

## 개요

MakeCall 앱은 이제 **웹 브라우저와 macOS**에서도 Firebase Cloud Messaging (FCM)을 통한 실시간 푸시 알림을 지원합니다.

### 주요 기능
- ✅ 웹 브라우저에서 실시간 푸시 알림 수신
- ✅ macOS Flutter 앱에서 푸시 알림 지원
- ✅ 백그라운드 알림 (브라우저 최소화 상태)
- ✅ 포그라운드 알림 (앱 사용 중)
- ✅ 수신 전화, 부재중 전화 알림
- ✅ 알림 클릭 시 앱으로 자동 이동

### 지원 플랫폼
- 🌐 **웹 브라우저**: Chrome, Edge, Firefox (최신 버전)
- 🖥️ **macOS**: Flutter Desktop 앱
- 📱 **모바일**: Android, iOS (기존 지원)

---

## 사전 준비사항

### 1. Firebase 프로젝트 설정 확인
- Firebase 프로젝트: `makecallio`
- Project ID: `makecallio`
- API Key: `AIzaSyCB4mI5Kj61f6E532vg46GnmnnCfsI9XIM`

### 2. 필수 파일 확인
```bash
# 웹 관련 파일
web/firebase-messaging-sw.js          # 서비스 워커 (백그라운드 알림)
web/index.html                        # 서비스 워커 등록 스크립트

# Flutter 설정 파일
lib/firebase_options.dart             # Firebase 플랫폼별 설정
lib/services/fcm_service.dart         # FCM 서비스 로직
```

### 3. 브라우저 요구사항
- **HTTPS 필수**: 웹푸시는 보안 연결에서만 작동
- **알림 권한**: 브라우저 알림 허용 필요
- **서비스 워커 지원**: 최신 브라우저 사용

---

## VAPID 키 생성 및 설정

### ⚠️ 중요: VAPID 키 설정 필수

웹푸시 알림을 받으려면 Firebase Console에서 **VAPID 키(Web Push certificate)**를 생성하고 코드에 설정해야 합니다.

### 1. Firebase Console에서 VAPID 키 생성

1. Firebase Console 접속: https://console.firebase.google.com/
2. `makecallio` 프로젝트 선택
3. **Project Settings** (톱니바퀴 아이콘) 클릭
4. **Cloud Messaging** 탭 선택
5. **Web Push certificates** 섹션 찾기
6. **Generate key pair** 버튼 클릭
7. 생성된 **Key pair** 값 복사

### 2. VAPID 키를 코드에 적용

#### 📄 `lib/services/fcm_service.dart` 수정

```dart
// 라인 53-60 근처에서 수정
if (kIsWeb) {
  // 🔥 여기에 Firebase Console에서 생성한 VAPID 키 입력
  const vapidKey = 'YOUR_VAPID_KEY_HERE'; // ← 생성한 Key pair 값으로 교체
  
  try {
    _fcmToken = await _messaging.getToken(vapidKey: vapidKey);
    // ...
  }
}
```

#### 예시
```dart
// ❌ 잘못된 예
const vapidKey = 'YOUR_VAPID_KEY_HERE';

// ✅ 올바른 예 (실제 키로 교체)
const vapidKey = 'BHxK...생략...8qYz';  // Firebase Console에서 복사한 값
```

### 3. 서비스 워커에도 VAPID 키 적용 (선택사항)

일부 브라우저에서는 서비스 워커에도 VAPID 키 설정이 필요할 수 있습니다.

#### 📄 `web/firebase-messaging-sw.js` 수정 (필요시)

```javascript
// Firebase Messaging 인스턴스 생성 후 추가
const messaging = firebase.messaging();

// VAPID 키 설정 (선택사항)
// messaging.usePublicVapidKey('YOUR_VAPID_KEY_HERE');
```

---

## 웹푸시 활성화 방법

### 방법 1: ProfileDrawer에서 활성화 (권장)

1. Flutter 앱 실행 (웹 브라우저에서 열기)
2. 우측 상단 **프로필 아이콘** 클릭
3. **알림 설정** 섹션 찾기
4. **웹 푸시 알림 활성화** 클릭
5. 브라우저 알림 권한 허용 팝업에서 **허용** 클릭
6. "웹 푸시 알림 활성화 완료" 메시지 확인

### 방법 2: 브라우저 설정에서 직접 허용

#### Chrome/Edge
1. 주소창 왼쪽의 🔒 자물쇠 아이콘 클릭
2. **Notifications** 찾기
3. **Allow** 선택
4. 페이지 새로고침

#### Firefox
1. 주소창 왼쪽의 🔒 자물쇠 아이콘 클릭
2. **Permissions** → **Receive Notifications**
3. **Allow** 선택
4. 페이지 새로고침

---

## 테스트 방법

### 1. FCM 토큰 확인

웹푸시 활성화 후, 브라우저 개발자 도구에서 FCM 토큰을 확인할 수 있습니다.

```javascript
// 브라우저 Console에서 실행
// FCM 토큰이 로그에 출력됨
```

또는 Flutter 앱 로그 확인:
```
🔔 FCM 토큰 정보
================================================================
📱 전체 토큰:
eyJhbGc...생략...xyz
================================================================
```

### 2. Firebase Console에서 테스트 메시지 전송

1. Firebase Console → **Messaging** 메뉴
2. **Send your first message** 또는 **New campaign** 클릭
3. **Notification** 선택
4. 메시지 내용 입력:
   - **Notification title**: "테스트 알림"
   - **Notification text**: "웹푸시 테스트 메시지입니다"
5. **Send test message** 클릭
6. **Add an FCM registration token** 입력란에 위에서 확인한 토큰 붙여넣기
7. **Test** 버튼 클릭

### 3. Python 스크립트로 테스트 (고급)

#### 📄 `test_fcm_web_push.py` 생성

```python
import firebase_admin
from firebase_admin import credentials, messaging
import sys

# Firebase Admin SDK 초기화
cred = credentials.Certificate('/opt/flutter/firebase-admin-sdk.json')
firebase_admin.initialize_app(cred)

# FCM 토큰 (브라우저에서 확인한 토큰으로 교체)
fcm_token = 'YOUR_WEB_FCM_TOKEN_HERE'

if len(sys.argv) > 1:
    fcm_token = sys.argv[1]

# 메시지 구성
message = messaging.Message(
    notification=messaging.Notification(
        title='🔔 MakeCall 웹푸시 테스트',
        body='웹 브라우저에서 알림이 정상 작동합니다!',
    ),
    data={
        'type': 'test_notification',
        'timestamp': str(int(time.time())),
    },
    token=fcm_token,
    webpush=messaging.WebpushConfig(
        notification=messaging.WebpushNotification(
            icon='/icons/Icon-192.png',
            badge='/icons/Icon-192.png',
            require_interaction=True,
        ),
        fcm_options=messaging.WebpushFCMOptions(
            link='/',  # 알림 클릭 시 이동할 URL
        ),
    ),
)

# 메시지 전송
try:
    response = messaging.send(message)
    print(f'✅ 웹푸시 전송 성공: {response}')
    print(f'📱 토큰: {fcm_token[:30]}...')
except Exception as e:
    print(f'❌ 웹푸시 전송 실패: {e}')
```

#### 실행 방법
```bash
# FCM 토큰을 인자로 전달
python3 test_fcm_web_push.py "eyJhbGc...토큰...xyz"

# 또는 스크립트 내 fcm_token 변수 수정 후
python3 test_fcm_web_push.py
```

### 4. 수신 전화 알림 테스트

실제 수신 전화 시나리오 테스트:

```python
# 수신 전화 알림 메시지
message = messaging.Message(
    notification=messaging.Notification(
        title='📞 수신 전화',
        body='010-1234-5678',
    ),
    data={
        'type': 'incoming_call',
        'caller_number': '010-1234-5678',
        'caller_name': '홍길동',
        'receiver_number': '1001',
        'channel': 'SIP/1001',
        'linkedid': 'test_call_' + str(int(time.time())),
    },
    token=fcm_token,
    webpush=messaging.WebpushConfig(
        notification=messaging.WebpushNotification(
            icon='/icons/Icon-192.png',
            badge='/icons/Icon-192.png',
            require_interaction=True,
            vibrate=[200, 100, 200],  # 진동 패턴
        ),
        fcm_options=messaging.WebpushFCMOptions(
            link='/',
        ),
    ),
)
```

---

## 문제 해결

### ❌ "FCM 토큰을 가져올 수 없습니다"

**원인**: VAPID 키가 설정되지 않았거나 잘못됨

**해결**:
1. Firebase Console에서 VAPID 키 생성 확인
2. `lib/services/fcm_service.dart`의 `vapidKey` 변수 확인
3. 키 값이 정확히 복사되었는지 확인
4. Flutter 앱 재빌드 및 재시작

### ❌ "알림 권한이 거부되었습니다"

**원인**: 브라우저 알림 권한이 차단됨

**해결**:
1. 브라우저 설정 → 개인정보 보호 및 보안
2. 사이트 설정 → 알림
3. MakeCall 사이트 찾기
4. 권한을 "허용"으로 변경
5. 페이지 새로고침

### ❌ 서비스 워커 등록 실패

**원인**: HTTPS가 아니거나 서비스 워커 파일 경로 오류

**해결**:
```bash
# 서비스 워커 파일 확인
ls -la web/firebase-messaging-sw.js

# 브라우저 개발자 도구 → Application → Service Workers
# 등록된 서비스 워커 확인
```

### ❌ 백그라운드 알림이 수신되지 않음

**원인**: 서비스 워커가 제대로 등록되지 않음

**해결**:
1. 브라우저 개발자 도구 → **Application** 탭
2. **Service Workers** 섹션 확인
3. `firebase-messaging-sw.js` 등록 상태 확인
4. 등록되지 않았다면 **Unregister** 후 페이지 새로고침

### ❌ 포그라운드 알림이 표시되지 않음

**원인**: FCM 서비스가 초기화되지 않음

**해결**:
```dart
// main.dart에서 FCM 초기화 확인
await FCMService().initialize(userId);
```

---

## 기술 상세

### 아키텍처 구조

```
┌─────────────────────────────────────────┐
│         Flutter Web App (브라우저)          │
├─────────────────────────────────────────┤
│  📱 FCM Service (fcm_service.dart)      │
│    - 토큰 획득 (VAPID 키 사용)              │
│    - 포그라운드 메시지 핸들링                 │
│    - 알림 권한 요청                        │
├─────────────────────────────────────────┤
│  🔧 Service Worker                      │
│    (firebase-messaging-sw.js)           │
│    - 백그라운드 메시지 수신                  │
│    - 브라우저 알림 표시                     │
│    - 알림 클릭 이벤트 처리                   │
├─────────────────────────────────────────┤
│  🌐 Firebase Messaging SDK              │
│    (Firebase Cloud Messaging)           │
└─────────────────────────────────────────┘
         ↕️ (HTTPS + WebSocket)
┌─────────────────────────────────────────┐
│    ☁️ Firebase Cloud (FCM Server)       │
│    - 메시지 큐잉                          │
│    - 디바이스별 라우팅                     │
│    - 재시도 로직                          │
└─────────────────────────────────────────┘
```

### FCM 웹푸시 플로우

#### 1. 초기화 및 토큰 획득
```
1. 웹 앱 로드
2. Firebase SDK 초기화
3. 알림 권한 요청 (Notification.requestPermission)
4. VAPID 키로 FCM 토큰 획득
5. 토큰을 Firestore에 저장 (fcm_tokens 컬렉션)
```

#### 2. 메시지 수신 (포그라운드)
```
1. FCM 서버에서 메시지 전송
2. onMessage 이벤트 트리거
3. _handleForegroundMessage() 실행
4. 스낵바 또는 다이얼로그 표시
```

#### 3. 메시지 수신 (백그라운드)
```
1. FCM 서버에서 메시지 전송
2. 서비스 워커의 onBackgroundMessage 트리거
3. self.registration.showNotification() 실행
4. 브라우저 네이티브 알림 표시
```

#### 4. 알림 클릭 처리
```
1. 사용자가 알림 클릭
2. notificationclick 이벤트 트리거
3. clients.matchAll()로 열린 창 찾기
4. 기존 창이 있으면 포커스, 없으면 새 창 열기
```

### Firestore 데이터 구조

#### `fcm_tokens` 컬렉션
```javascript
{
  "token_id": "eyJhbGc...xyz",  // 문서 ID = FCM 토큰
  "userId": "user123",          // 사용자 ID
  "deviceId": "device_xxx",     // 디바이스 ID
  "deviceName": "Web Browser",  // 디바이스 이름
  "platform": "web",            // 플랫폼 (web, android, ios, macos)
  "appVersion": "1.0.0",        // 앱 버전
  "isActive": true,             // 활성 상태
  "createdAt": Timestamp,       // 생성 시각
  "updatedAt": Timestamp,       // 업데이트 시각
  "lastUsedAt": Timestamp       // 마지막 사용 시각
}
```

### 메시지 페이로드 구조

#### 기본 알림
```json
{
  "notification": {
    "title": "알림 제목",
    "body": "알림 내용"
  },
  "data": {
    "type": "general",
    "custom_field": "custom_value"
  },
  "webpush": {
    "notification": {
      "icon": "/icons/Icon-192.png",
      "badge": "/icons/Icon-192.png",
      "requireInteraction": true
    },
    "fcm_options": {
      "link": "/"
    }
  }
}
```

#### 수신 전화 알림
```json
{
  "notification": {
    "title": "홍길동",
    "body": "010-1234-5678"
  },
  "data": {
    "type": "incoming_call",
    "caller_name": "홍길동",
    "caller_number": "010-1234-5678",
    "receiver_number": "1001",
    "channel": "SIP/1001",
    "linkedid": "call_12345"
  },
  "webpush": {
    "notification": {
      "icon": "/icons/Icon-192.png",
      "badge": "/icons/Icon-192.png",
      "requireInteraction": true,
      "vibrate": [200, 100, 200]
    }
  }
}
```

---

## 보안 고려사항

### 1. VAPID 키 보안
- ⚠️ VAPID 키는 공개 키이므로 클라이언트 코드에 포함 가능
- ✅ 하지만 Firebase Server Key는 절대 노출 금지

### 2. HTTPS 필수
- 웹푸시는 HTTPS 환경에서만 작동
- localhost는 예외 (개발 테스트 가능)

### 3. 토큰 관리
- 토큰은 사용자별로 관리
- 로그아웃 시 토큰 비활성화 (`isActive: false`)
- 만료된 토큰은 정기적으로 정리

### 4. 권한 관리
- 알림 권한은 사용자가 직접 허용해야 함
- 강제로 알림을 보낼 수 없음
- 사용자가 언제든 권한 취소 가능

---

## 참고 자료

### 공식 문서
- [Firebase Cloud Messaging (Web)](https://firebase.google.com/docs/cloud-messaging/js/client)
- [Service Workers API](https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API)
- [Web Push Protocol](https://web.dev/push-notifications-overview/)
- [VAPID Keys](https://tools.ietf.org/html/rfc8292)

### Flutter 패키지
- [firebase_messaging](https://pub.dev/packages/firebase_messaging)
- [firebase_core](https://pub.dev/packages/firebase_core)

---

## 라이선스

이 문서는 MakeCall 프로젝트의 일부입니다.

---

**작성일**: 2024-01-XX  
**버전**: 1.0.0  
**작성자**: MakeCall Development Team
