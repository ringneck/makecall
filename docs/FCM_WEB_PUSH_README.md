# FCM 웹푸시 기능 구현 완료 ✅

## 📋 구현 개요

MakeCall 앱에 **FCM 웹푸시 알림 기능**이 성공적으로 추가되었습니다. 이제 웹 브라우저와 macOS에서도 실시간 푸시 알림을 받을 수 있습니다!

---

## 🎯 구현된 기능

### ✅ 완료된 작업

1. **Firebase Messaging Service Worker 생성**
   - 📄 `web/firebase-messaging-sw.js`
   - 백그라운드 알림 수신 처리
   - 알림 클릭 이벤트 핸들링

2. **FCM 서비스 웹 플랫폼 지원 추가**
   - 📄 `lib/services/fcm_service.dart`
   - VAPID 키 기반 토큰 획득
   - 웹 포그라운드 메시지 핸들러
   - 플랫폼별 초기화 로직

3. **웹 알림 권한 요청 UI**
   - 📄 `lib/widgets/profile_drawer.dart`
   - ProfileDrawer에 "알림 설정" 섹션 추가
   - "웹 푸시 알림 활성화" 버튼
   - "웹 푸시 정보" 안내 다이얼로그

4. **서비스 워커 등록**
   - 📄 `web/index.html`
   - Flutter Service Worker 등록
   - Firebase Messaging Service Worker 등록

5. **테스트 문서 작성**
   - 📄 `docs/FCM_WEB_PUSH_GUIDE.md` - 상세 가이드
   - 📄 `docs/FCM_WEB_PUSH_QUICKSTART.md` - 빠른 시작
   - 📄 `docs/FCM_WEB_PUSH_README.md` - 이 파일

---

## 🚀 빠른 시작 (5분)

### Step 1: VAPID 키 생성

1. Firebase Console: https://console.firebase.google.com/
2. Project Settings → Cloud Messaging
3. Web Push certificates → Generate key pair
4. 생성된 키 복사

### Step 2: VAPID 키 적용

```dart
// lib/services/fcm_service.dart (라인 53-60 근처)
if (kIsWeb) {
  const vapidKey = 'BHxK...여기에_복사한_키_붙여넣기...8qYz';
  // ...
}
```

### Step 3: 앱 재빌드

```bash
cd /home/user/flutter_app
flutter build web --release
python3 -m http.server 5060 --directory build/web --bind 0.0.0.0
```

### Step 4: 웹푸시 활성화

1. 브라우저에서 앱 열기
2. 프로필 → 알림 설정 → 웹 푸시 알림 활성화
3. 브라우저 알림 권한 허용
4. ✅ 완료!

---

## 📁 변경된 파일 목록

### 새로 생성된 파일

```
web/firebase-messaging-sw.js          # 서비스 워커
docs/FCM_WEB_PUSH_GUIDE.md           # 상세 가이드 (10KB+)
docs/FCM_WEB_PUSH_QUICKSTART.md      # 빠른 시작 가이드
docs/FCM_WEB_PUSH_README.md          # 이 파일
```

### 수정된 파일

```
lib/services/fcm_service.dart         # 웹 플랫폼 지원 추가
lib/widgets/profile_drawer.dart       # 알림 설정 UI 추가
web/index.html                        # 서비스 워커 등록
```

---

## 🔍 주요 변경 사항

### 1. FCM Service (fcm_service.dart)

**추가된 기능:**
- ✅ 웹 플랫폼 감지 (`kIsWeb`)
- ✅ VAPID 키 기반 토큰 획득
- ✅ 웹 포그라운드 메시지 핸들러
- ✅ 웹 알림 표시 (SnackBar)
- ✅ 플랫폼별 로깅

**코드 예시:**
```dart
// 웹 플랫폼: VAPID 키 사용
if (kIsWeb) {
  const vapidKey = 'YOUR_VAPID_KEY_HERE';
  try {
    _fcmToken = await _messaging.getToken(vapidKey: vapidKey);
  } catch (e) {
    // VAPID 키 없이 시도 (fallback)
    _fcmToken = await _messaging.getToken();
  }
}

// 웹 알림 표시
void _showWebNotification(RemoteMessage message) {
  if (!kIsWeb) return;
  // SnackBar로 알림 표시
}
```

### 2. Profile Drawer (profile_drawer.dart)

**추가된 UI:**
- 🔔 **알림 설정** 섹션
- 📱 **웹 푸시 알림 활성화** 버튼
- ℹ️ **웹 푸시 정보** 안내

**새 메서드:**
```dart
Future<void> _requestWebPushPermission(BuildContext context)
void _showWebPushInfo(BuildContext context)
```

### 3. Service Worker (firebase-messaging-sw.js)

**구현된 기능:**
- ✅ Firebase SDK 로드 (10.7.0)
- ✅ Firebase 초기화
- ✅ 백그라운드 메시지 핸들러
- ✅ 알림 표시 (`showNotification`)
- ✅ 알림 클릭 이벤트 처리
- ✅ 앱 포커스 또는 새 창 열기

### 4. Index.html

**서비스 워커 등록:**
```javascript
// Flutter Service Worker
navigator.serviceWorker.register('flutter_service_worker.js');

// Firebase Messaging Service Worker
navigator.serviceWorker.register('firebase-messaging-sw.js');
```

---

## 🧪 테스트 방법

### 방법 1: Firebase Console에서 테스트

1. Firebase Console → Messaging
2. "Send test message" 클릭
3. FCM 토큰 입력 (브라우저 콘솔에서 복사)
4. "Test" 버튼 클릭
5. 알림 수신 확인

### 방법 2: Python 스크립트로 테스트

```python
import firebase_admin
from firebase_admin import credentials, messaging

# Firebase Admin SDK 초기화
cred = credentials.Certificate('/opt/flutter/firebase-admin-sdk.json')
firebase_admin.initialize_app(cred)

# 테스트 메시지 전송
message = messaging.Message(
    notification=messaging.Notification(
        title='테스트 알림',
        body='웹푸시 테스트입니다!',
    ),
    token='YOUR_WEB_FCM_TOKEN',
    webpush=messaging.WebpushConfig(
        notification=messaging.WebpushNotification(
            icon='/icons/Icon-192.png',
        ),
    ),
)

response = messaging.send(message)
print(f'✅ 전송 완료: {response}')
```

---

## ⚠️ 중요 사항

### VAPID 키 설정 필수

웹푸시를 사용하려면 **반드시** VAPID 키를 설정해야 합니다:

1. Firebase Console에서 키 생성
2. `fcm_service.dart`의 `vapidKey` 변수에 적용
3. 앱 재빌드

**VAPID 키 없이는 웹 FCM 토큰을 획득할 수 없습니다!**

### HTTPS 필수

- 웹푸시는 HTTPS 환경에서만 작동
- localhost는 예외 (개발 테스트 가능)
- 배포 시 HTTPS 인증서 필요

### 브라우저 지원

✅ **지원:**
- Chrome (Desktop, Android)
- Edge (Desktop)
- Firefox (Desktop, Android)
- Safari 16.4+ (macOS, iOS)

❌ **미지원:**
- Internet Explorer
- 오래된 브라우저 버전

---

## 📊 Firestore 데이터 구조

### `fcm_tokens` 컬렉션

```javascript
{
  "token_id": "eyJhbGc...xyz",  // 문서 ID = FCM 토큰
  "userId": "user123",
  "deviceId": "device_xxx",
  "deviceName": "Web Browser",  // 또는 "Chrome on Windows"
  "platform": "web",            // web, android, ios, macos
  "appVersion": "1.0.0",
  "isActive": true,
  "createdAt": Timestamp,
  "updatedAt": Timestamp,
  "lastUsedAt": Timestamp
}
```

---

## 🔧 문제 해결

### ❌ "FCM 토큰을 가져올 수 없습니다"

**원인**: VAPID 키 미설정 또는 오류

**해결**:
1. Firebase Console → Cloud Messaging → Web Push certificates
2. Key pair 생성 및 복사
3. `fcm_service.dart`에 적용
4. 앱 재빌드

### ❌ "알림 권한이 거부되었습니다"

**원인**: 브라우저 알림 권한 차단

**해결**:
1. 브라우저 주소창 왼쪽 자물쇠 아이콘 클릭
2. "알림" 권한을 "허용"으로 변경
3. 페이지 새로고침

### ❌ 서비스 워커 등록 실패

**원인**: HTTPS가 아니거나 파일 경로 오류

**해결**:
```bash
# 서비스 워커 파일 확인
ls -la web/firebase-messaging-sw.js

# 브라우저 개발자 도구 → Application → Service Workers 확인
```

---

## 📚 상세 문서

- 📖 **상세 가이드**: [FCM_WEB_PUSH_GUIDE.md](./FCM_WEB_PUSH_GUIDE.md)
- 🚀 **빠른 시작**: [FCM_WEB_PUSH_QUICKSTART.md](./FCM_WEB_PUSH_QUICKSTART.md)

---

## 🎉 테스트 현황

### ✅ 완료된 테스트

- [x] Flutter 앱 빌드 성공
- [x] 서비스 워커 파일 생성 확인
- [x] FCM 서비스 로직 구현 확인
- [x] ProfileDrawer UI 추가 확인
- [x] 코드 분석 통과 (no errors)

### ⏳ 사용자 테스트 필요

- [ ] VAPID 키 생성 및 적용
- [ ] 브라우저에서 알림 권한 허용
- [ ] FCM 토큰 획득 확인
- [ ] Firebase Console에서 테스트 메시지 전송
- [ ] 포그라운드 알림 수신 확인
- [ ] 백그라운드 알림 수신 확인
- [ ] 알림 클릭 동작 확인

---

## 📱 Preview URL

**Flutter 앱 (웹푸시 지원)**:
https://5060-ijpqhzty575rh093zweuw-5185f4aa.sandbox.novita.ai

---

## 📝 다음 단계

1. **VAPID 키 설정**
   - Firebase Console에서 키 생성
   - `fcm_service.dart`에 적용
   - 앱 재빌드

2. **웹푸시 활성화 테스트**
   - 브라우저에서 앱 열기
   - ProfileDrawer → 알림 설정
   - 웹 푸시 활성화

3. **알림 수신 테스트**
   - Firebase Console에서 테스트 메시지 전송
   - 포그라운드/백그라운드 알림 확인

4. **실전 테스트**
   - 실제 수신 전화 알림 테스트
   - 부재중 전화 알림 테스트
   - 다양한 브라우저에서 테스트

---

## 📧 지원

문제가 발생하면:
1. 상세 가이드 문서 확인
2. 브라우저 개발자 도구 콘솔 확인
3. Flutter 앱 로그 확인

---

**작성일**: 2024-01-XX  
**버전**: 1.0.0  
**상태**: ✅ 구현 완료, 테스트 대기 중
