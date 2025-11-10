# Firebase Functions 푸시 알림 시스템 검증 가이드

> **작성일**: 2025년  
> **대상**: MAKECALL 앱 개발자 및 운영자  
> **목적**: Firebase Functions를 통한 푸시 알림 시스템의 데이터베이스 저장 및 동작 검증  
> **지원 플랫폼**: Android, iOS, Web

---

## 📋 목차

1. [시스템 개요](#1-시스템-개요)
2. [데이터베이스 구조](#2-데이터베이스-구조)
3. [FCM 토큰 저장 검증](#3-fcm-토큰-저장-검증)
4. [플랫폼별 구성](#4-플랫폼별-구성)
5. [Firebase Functions 동작 검증](#5-firebase-functions-동작-검증)
6. [플랫폼별 실제 테스트](#6-플랫폼별-실제-테스트)
7. [수신 전화 테스트](#7-수신-전화-테스트)
8. [문제 해결](#8-문제-해결)

---

## 1. 시스템 개요

### 1.1 아키텍처

```
Flutter 앱 (FCMService)
    ↓
Firestore DB (fcm_tokens 컬렉션)
    ↓
Firebase Functions (index.js)
    ↓
FCM 푸시 알림 전송
    ↓
┌─────────────────────────────────────┐
│  Android: Firebase Cloud Messaging  │
│  iOS: Apple Push Notification (APNs)│
│  Web: Service Worker (Background)   │
└─────────────────────────────────────┘
```

### 1.2 주요 컴포넌트

| 컴포넌트 | 파일 경로 | 역할 |
|---------|----------|------|
| FCM Service | `lib/services/fcm_service.dart` | FCM 토큰 생성 및 등록 |
| Database Service | `lib/services/database_service.dart` | Firestore 데이터 관리 |
| Firebase Functions | `functions/index.js` | 서버 측 푸시 알림 처리 |
| FCM Token Model | `lib/models/fcm_token_model.dart` | FCM 토큰 데이터 모델 |
| Web Service Worker | `web/firebase-messaging-sw.js` | 웹 백그라운드 알림 처리 |

### 1.3 플랫폼별 지원 현황

| 플랫폼 | FCM 토큰 생성 | 포그라운드 알림 | 백그라운드 알림 | 중복 로그인 방지 |
|--------|--------------|----------------|----------------|-----------------|
| **Android** | ✅ 자동 생성 | ✅ 지원 | ✅ 지원 | ✅ 지원 |
| **iOS** | ✅ 자동 생성 | ✅ 지원 | ✅ 지원 | ✅ 지원 |
| **Web** | ✅ 활성화됨 (VAPID 키 교체 필요) | ✅ 지원 | ✅ Service Worker | ✅ 지원 |

**✅ 웹 플랫폼 활성화 상태**:
- 웹 FCM 코드가 이미 활성화되어 있습니다
- **필수 작업**: `fcm_service.dart`의 `vapidKey` 값을 실제 Firebase VAPID 키로 교체
- VAPID 키 생성 및 교체 방법은 Section 4.3 참조
- 키 교체 후 즉시 웹 푸시 알림 사용 가능

---

## 2. 데이터베이스 구조

### 2.1 fcm_tokens 컬렉션

**경로**: `Firestore > fcm_tokens`

**문서 ID 형식**: `{userId}_{deviceId}`

**필드 구조**:

| 필드 | 타입 | 설명 | 예시 |
|-----|------|------|------|
| `userId` | string | Firebase 사용자 UID | `"abc123xyz"` |
| `fcmToken` | string | FCM 등록 토큰 (152자) | `"fGHI...xyz"` |
| `deviceId` | string | 기기 고유 식별자 | `"5d513e7a5fb1e2d5"` (Android)<br>`"iPhone14,3"` (iOS)<br>`"web_chrome_Windows"` (Web) |
| `deviceName` | string | 사용자 친화적 기기 이름 | `"Samsung Galaxy S21"`<br>`"iPhone 13 Pro (iOS 17.0)"`<br>`"Chrome on Windows"` |
| `platform` | string | 플랫폼 타입 | `"android"`, `"ios"`, `"web"` |
| `createdAt` | Timestamp | 토큰 생성 시간 | `2025-01-15 10:30:00` |
| `lastActiveAt` | Timestamp | 마지막 활동 시간 | `2025-01-15 15:45:00` |
| `isActive` | boolean | 활성 상태 | `true` / `false` |

**플랫폼별 deviceId 형식**:

- **Android**: `androidInfo.id` (예: `"5d513e7a5fb1e2d5"`)
- **iOS**: `iosInfo.identifierForVendor` (예: `"iPhone14,3"`)
- **Web**: `web_{browserName}_{platform}` (예: `"web_chrome_Windows"`)

**예시 문서**:

```json
{
  "userId": "user_abc123",
  "fcmToken": "fGHI1234567890abcdefXYZ...(152자)",
  "deviceId": "5d513e7a5fb1e2d5",
  "deviceName": "Samsung Galaxy S21",
  "platform": "android",
  "createdAt": Timestamp(1705300200),
  "lastActiveAt": Timestamp(1705319100),
  "isActive": true
}
```

### 2.2 fcm_force_logout_queue 컬렉션

**경로**: `Firestore > fcm_force_logout_queue`

**용도**: 중복 로그인 방지 - 강제 로그아웃 FCM 메시지 전송 큐

**필드 구조**:

| 필드 | 타입 | 설명 |
|-----|------|------|
| `targetToken` | string | 로그아웃할 기기의 FCM 토큰 |
| `newDeviceName` | string | 새로 로그인한 기기 이름 |
| `newPlatform` | string | 새로 로그인한 플랫폼 |
| `message.type` | string | `"force_logout"` |
| `message.title` | string | `"다른 기기에서 로그인됨"` |
| `message.body` | string | 알림 메시지 |
| `createdAt` | Timestamp | 큐 생성 시간 |
| `processed` | boolean | 처리 완료 여부 |
| `sentAt` | Timestamp | FCM 전송 완료 시간 (처리 후) |
| `response` | string | FCM 응답 ID (처리 후) |

### 2.3 incoming_calls 컬렉션

**경로**: `Firestore > incoming_calls`

**용도**: 수신 전화 알림 트리거

**필드 구조**:

| 필드 | 타입 | 설명 |
|-----|------|------|
| `userId` | string | 수신자 사용자 ID |
| `callerNumber` | string | 발신 전화번호 |
| `callerName` | string | 발신자 이름 (옵션) |
| `extension` | string | 수신 단말번호 |

---

## 3. FCM 토큰 저장 검증

### 3.1 앱 실행 시 자동 토큰 등록

**프로세스**:

1. 앱 로그인 시 `FCMService.initialize(userId)` 자동 호출
2. FCM 토큰 생성 및 Firestore 저장
3. 콘솔에 토큰 정보 출력

**검증 방법**:

#### Step 1: Flutter 앱 로그 확인

앱 실행 후 콘솔에서 다음 로그 확인:

**Android/iOS 플랫폼**:
```
============================================================
🔔 FCM 토큰 정보
============================================================
📱 전체 토큰:
fGHI1234567890abcdefXYZ...(152자)

📋 요약 정보:
  - 토큰 길이: 152 문자
  - 사용자 ID: user_abc123
  - 플랫폼: android
  - 기기 이름: Samsung Galaxy S21

💡 복사해서 테스트에 사용하세요:
   Firebase Console → Messaging → Send test message
   또는: python3 docs/fcm_testing/send_fcm_test_message.py
============================================================
```

**Web 플랫폼 (VAPID 키 미설정)**:
```
⚠️  웹 플랫폼에서는 FCM이 비활성화되어 있습니다
   💡 중복 로그인 방지 기능은 모바일 앱에서만 사용 가능합니다
   💡 웹에서 FCM을 사용하려면 Firebase Console에서 VAPID 키를 설정하세요
```

#### Step 2: Firestore 콘솔 확인

1. Firebase Console 접속
2. **Firestore Database** 메뉴 선택
3. **fcm_tokens** 컬렉션 선택
4. 문서 ID가 `{userId}_{deviceId}` 형식인지 확인
5. 모든 필드 값이 올바른지 확인:
   - ✅ `fcmToken`: 152자 길이의 문자열
   - ✅ `deviceName`: 실제 기기 이름
   - ✅ `platform`: `android`, `ios`, `web` 중 하나
   - ✅ `isActive`: `true`
   - ✅ `createdAt`, `lastActiveAt`: 최근 시간

**플랫폼별 예상 결과**:

**Android**:
```
문서 ID: user_abc123_5d513e7a5fb1e2d5

필드:
  userId: "user_abc123"
  fcmToken: "fGHI1234567890abcdefXYZ..."
  deviceId: "5d513e7a5fb1e2d5"
  deviceName: "Samsung Galaxy S21"
  platform: "android"
  createdAt: 2025-01-15 10:30:00
  lastActiveAt: 2025-01-15 10:30:00
  isActive: true
```

**iOS**:
```
문서 ID: user_abc123_iPhone14,3

필드:
  userId: "user_abc123"
  fcmToken: "cDEF9876543210fedcbaABC..."
  deviceId: "iPhone14,3"
  deviceName: "iPhone 13 Pro (iOS 17.0)"
  platform: "ios"
  createdAt: 2025-01-15 11:00:00
  lastActiveAt: 2025-01-15 11:00:00
  isActive: true
```

**Web** (VAPID 키 설정 후):
```
문서 ID: user_abc123_web_chrome_Windows

필드:
  userId: "user_abc123"
  fcmToken: "bZXC5432109876zyxwvuABC..."
  deviceId: "web_chrome_Windows"
  deviceName: "Chrome on Windows"
  platform: "web"
  createdAt: 2025-01-15 12:00:00
  lastActiveAt: 2025-01-15 12:00:00
  isActive: true
```

### 3.2 중복 로그인 시 토큰 관리 검증

**시나리오**: 동일 사용자가 다른 기기에서 로그인

**검증 방법**:

#### Step 1: 첫 번째 기기에서 로그인

1. 기기 A (Android)에서 앱 로그인
2. Firestore에서 `fcm_tokens/{userId}_{deviceId_A}` 문서 생성 확인
3. `isActive: true` 확인

#### Step 2: 두 번째 기기에서 로그인

1. 기기 B (iOS)에서 동일 계정 로그인
2. Flutter 콘솔에서 중복 로그인 감지 로그 확인:

```
======================================================================
🔐 [중복 로그인 방지] FCM 토큰 저장 프로세스
======================================================================
   📱 사용자 ID: user_abc123
   📱 새 기기: iPhone 13 Pro (iOS 17.0) (ios)
   📱 기기 ID: iPhone14,3

🚨 [중복 로그인 감지]
   🔴 기존 기기: Samsung Galaxy S21 (android)
   🔴 기존 기기 ID: 5d513e7a5fb1e2d5
   🔴 기존 토큰: fGHI1234567890abcdefXYZ...

   ⚙️  중복 로그인 방지 동작:
   1️⃣  기존 기기에 강제 로그아웃 FCM 알림 전송
   2️⃣  기존 FCM 토큰만 비활성화 (fcm_tokens 컬렉션)
   3️⃣  사용자 데이터는 보존 (users 컬렉션 유지)

   ✅ 기존 기기에 강제 로그아웃 알림 전송 완료
   ✅ 기존 FCM 토큰 비활성화됨
   ✅ 사용자 데이터는 온전히 보존됨

✅ [완료] 새 FCM 토큰 저장 성공
   📱 기기: iPhone 13 Pro (iOS 17.0) (ios)
   🔑 토큰 길이: 152 문자
======================================================================
```

#### Step 3: Firestore 변경 사항 확인

1. **fcm_tokens 컬렉션**:
   - 기존 문서: `user_abc123_5d513e7a5fb1e2d5` → `isActive: false` 로 변경
   - 신규 문서: `user_abc123_iPhone14,3` → `isActive: true` 로 생성

2. **fcm_force_logout_queue 컬렉션**:
   - 신규 문서 생성 확인
   - `targetToken`: 기기 A의 FCM 토큰
   - `processed: false` (Firebase Functions 처리 대기)

3. **Firebase Functions 로그 확인**:
   - Firebase Console → **Functions** → **Logs** 메뉴
   - `sendForceLogoutNotification` 함수 실행 로그 확인:

```
============================================================
📤 강제 로그아웃 FCM 메시지 전송 시작
============================================================
Target Token: fGHI1234567890...
New Device: iPhone 13 Pro (iOS 17.0) (ios)
✅ FCM 메시지 전송 성공: projects/.../messages/0:1705300200123456
✅ 강제 로그아웃 알림 전송 완료
============================================================
```

4. **fcm_force_logout_queue 문서 업데이트 확인**:
   - `processed: true`
   - `sentAt`: Timestamp 값 존재
   - `response`: FCM 메시지 ID 값 존재

#### Step 4: 기기 A에서 강제 로그아웃 확인

기기 A (Android)에서 다이얼로그 표시 확인:

```
⚠️ 다른 기기에서 로그인됨

iPhone 13 Pro (iOS 17.0)에서 로그인되어 현재 세션이 종료됩니다.

ℹ️ 본인이 아닌 경우 비밀번호를 변경하세요.

[확인] 버튼 → 자동 로그아웃
```

---

## 4. 플랫폼별 구성

### 4.1 Android 플랫폼

**필수 파일**:
- `android/app/google-services.json` - Firebase 구성 파일

**Firebase 초기화**:
- `lib/firebase_options.dart`의 `android` 설정 사용
- 앱 시작 시 자동 초기화

**알림 권한**:
- Android 13+ (API 33+): 런타임 알림 권한 요청 필요
- Android 12 이하: 자동 허용

**FCM 토큰 생성**:
```dart
// FCMService에서 자동 처리
final token = await FirebaseMessaging.instance.getToken();
// Android: 152자 길이의 FCM 토큰 생성됨
```

**알림 채널**:
```kotlin
// Android는 알림 채널(Notification Channel) 사용
// 높은 우선순위 알림: "default" 채널
```

### 4.2 iOS 플랫폼

**필수 설정**:
- Apple Developer 계정에서 APNs 인증 키 또는 인증서 설정
- Firebase Console에 APNs 키 업로드
- `ios/Runner/Info.plist` 권한 설정

**Firebase 초기화**:
- `lib/firebase_options.dart`의 `ios` 설정 사용
- `iosBundleId: com.olssoo.makecall`

**알림 권한**:
```dart
// FCMService에서 자동 처리
NotificationSettings settings = await messaging.requestPermission(
  alert: true,
  badge: true,
  sound: true,
);
```

**FCM 토큰 생성**:
```dart
// APNs 토큰 → FCM 토큰 자동 변환
final token = await FirebaseMessaging.instance.getToken();
// iOS: 152자 길이의 FCM 토큰 생성됨
```

**백그라운드 처리**:
```dart
// main.dart에서 백그라운드 핸들러 등록
FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
```

### 4.3 Web 플랫폼

**✅ 현재 상태**: Web FCM 활성화됨 (VAPID 키 교체만 필요)

**Web FCM 완전 활성화 방법**:

#### Step 1: Firebase Console에서 VAPID 키 생성

1. Firebase Console 접속: https://console.firebase.google.com
2. MAKECALL 프로젝트 선택
3. 프로젝트 설정 (톱니바퀴 아이콘) 클릭
4. **클라우드 메시징** 탭 선택
5. **웹 구성** 섹션으로 스크롤
6. **웹 푸시 인증서** 탭 선택
7. **키 쌍 생성** 버튼 클릭 (또는 기존 키 확인)
8. 생성된 키 쌍 복사

**예시**:
```
키 쌍: BM2qgTRRwT-mG4shgKLDr7CnVf5-xVs3DqNNcqY7zzHZXd5P5xWqvCLn8BxGnqJ3YKj0zcY6Kp0YwQ_Zr8vK2jM
```

**⚠️ 주의**: 
- VAPID 키는 88자 길이의 Base64 인코딩된 공개 키입니다
- 키는 보안 키가 아니므로 소스 코드에 포함해도 안전합니다
- 한 번 생성하면 프로젝트에서 계속 사용할 수 있습니다

#### Step 2: Flutter 코드에 VAPID 키 교체

**파일**: `lib/services/fcm_service.dart`

**현재 코드 (Line 73)**:
```dart
const vapidKey = 'BM2qgTRRwT-mG4shgKLDr7CnVf5-xVs3DqNNcqY7zzHZXd5P5xWqvCLn8BxGnqJ3YKj0zcY6Kp0YwQ_Zr8vK2jM';
```

**수정 방법**:
1. `lib/services/fcm_service.dart` 파일 열기
2. 73번째 줄 찾기: `const vapidKey = '...'`
3. 작은따옴표 안의 값을 Firebase Console에서 복사한 VAPID 키로 교체
4. 파일 저장

**수정 예시**:
```dart
// 웹 플랫폼에서 FCM을 사용하려면 VAPID 키가 필요합니다
// 
// VAPID 키 생성 방법:
// 1. Firebase Console (https://console.firebase.google.com)
// 2. 프로젝트 선택 → 프로젝트 설정 (톱니바퀴 아이콘)
// 3. 클라우드 메시징 탭 선택
// 4. 웹 구성 섹션으로 스크롤
// 5. 웹 푸시 인증서 탭에서 "키 쌍 생성" 버튼 클릭
// 6. 생성된 키 쌍을 아래 vapidKey 변수에 입력
// 
// 예시: 'BPv3xX9QR5aY...Wz8kL9mN0o' (88자 길이)
const vapidKey = 'YOUR_ACTUAL_VAPID_KEY_FROM_FIREBASE_CONSOLE'; // ← 여기를 실제 키로 교체
```

**✅ 웹 FCM 코드 구조 (이미 구현됨)**:
```dart
if (kIsWeb) {
  // 웹 플랫폼: VAPID 키로 FCM 토큰 생성
  const vapidKey = 'YOUR_VAPID_KEY'; // ← 교체 필요
  _fcmToken = await _messaging.getToken(vapidKey: vapidKey);
} else {
  // 모바일 플랫폼: 일반 FCM 토큰 생성
  _fcmToken = await _messaging.getToken();
}
```

#### Step 3: 앱 재빌드 및 실행

**VAPID 키 교체 후 반드시 재빌드 필요**:

```bash
# 개발 서버 종료 (실행 중인 경우)
# Ctrl+C 또는 프로세스 종료

# Flutter 웹 앱 재빌드
cd /home/user/flutter_app
flutter clean
flutter pub get
flutter build web --release

# 웹 서버 실행
cd build/web
python3 -m http.server 5060
```

**브라우저 접속**:
```
http://localhost:5060
```

#### Step 4: 웹 FCM 토큰 생성 확인

**브라우저 개발자 도구 → Console 확인**:

```
🔔 FCM 서비스 초기화 시작...
   플랫폼: web

📱 알림 권한 상태: AuthorizationStatus.authorized

============================================================
🔔 FCM 토큰 정보
============================================================
📱 전체 토큰:
bZXC5432109876zyxwvutsrqponmlkjihgfedcbaABCDEFGHIJKLMN...(152자)

📋 요약 정보:
  - 토큰 길이: 152 문자
  - 사용자 ID: user_abc123
  - 플랫폼: web
  - 기기 이름: Chrome on Windows
============================================================
```

**✅ 성공 확인**:
- FCM 토큰이 152자 길이로 생성됨
- 플랫폼이 "web"으로 표시됨
- Firestore `fcm_tokens` 컬렉션에 문서 생성됨

#### Step 5: Service Worker 등록 확인

**브라우저 개발자 도구 → Application → Service Workers**:

```
✅ flutter_service_worker.js - Active
✅ firebase-messaging-sw.js - Active
```

**Console 로그 확인**:
```
✅ Flutter Service Worker 등록 완료: https://localhost:5060/
✅ Firebase Messaging Service Worker 등록 완료: https://localhost:5060/
```

**⚠️ Service Worker 파일 내용 (자동 설정됨)**:
- **파일**: `web/firebase-messaging-sw.js`
- **Firebase Config**: 이미 올바르게 구성되어 있음 (프로젝트: makecallio)
- **백그라운드 핸들러**: 이미 구현되어 있음

#### Step 6: 웹 알림 권한 확인

**자동 권한 요청**:
- 앱 실행 시 브라우저가 자동으로 알림 권한 요청
- "허용" 버튼 클릭

**브라우저별 권한 다이얼로그**:
```
Chrome: "localhost에서 알림을 표시하려고 합니다" [차단] [허용]
Firefox: "localhost에서 알림을 보내도 되겠습니까?" [허용 안 함] [허용]
Safari: "localhost에서 알림을 보내려고 합니다" [허용 안 함] [허용]
```

**권한 상태 수동 확인**:
```javascript
// 브라우저 개발자 도구 → Console
Notification.permission
// "granted" (허용됨), "denied" (거부됨), "default" (미설정)
```

**권한 재설정 방법**:
- **Chrome**: 주소창 왼쪽 아이콘 → 사이트 설정 → 알림 → 허용
- **Firefox**: 주소창 왼쪽 아이콘 → 권한 → 알림 → 허용
- **Safari**: Safari 메뉴 → 환경설정 → 웹사이트 → 알림 → localhost 허용

#### Step 7: 웹 푸시 알림 테스트

**Python 스크립트로 테스트**:
```bash
python3 docs/fcm_testing/send_fcm_test_message.py
```

**웹 브라우저에서 알림 확인**:
```
포그라운드 (탭 활성화):
  ✅ 앱 내 스낵바 표시
  ✅ 수신 전화 풀스크린 화면

백그라운드 (탭 비활성화):
  ✅ 브라우저 시스템 알림 표시
  ✅ [열기] [닫기] 액션 버튼 (Chrome/Edge)
  ✅ 알림 클릭 → 탭 활성화
```

**✅ 웹 FCM 완전 활성화 완료!**

---

## 5. Firebase Functions 동작 검증

### 5.1 배포 확인

#### Step 1: Firebase Console 확인

1. Firebase Console → **Functions** 메뉴
2. 다음 함수들이 배포되어 있는지 확인:

| 함수 이름 | 트리거 타입 | 리전 | 상태 |
|----------|-----------|------|------|
| `sendForceLogoutNotification` | Firestore onCreate | asia-east1 | ✅ 활성 |
| `sendIncomingCallNotification` | Firestore onCreate | asia-east1 | ✅ 활성 |
| `sendCallStatusNotification` | Firestore onUpdate | asia-east1 | ✅ 활성 |
| `remoteLogout` | Callable Function | asia-east1 | ✅ 활성 |
| `cleanupExpiredTokens` | Callable Function | asia-east1 | ✅ 활성 |
| `sendGroupMessage` | Callable Function | asia-east1 | ✅ 활성 |
| `sendCustomNotification` | Callable Function | asia-east1 | ✅ 활성 |

### 5.2 강제 로그아웃 함수 테스트

#### 수동 트리거 방법

Firestore에 직접 문서 추가:

1. Firestore Console → **fcm_force_logout_queue** 컬렉션
2. **문서 추가** 버튼 클릭
3. 다음 필드 입력:

```json
{
  "targetToken": "테스트할_FCM_토큰_152자",
  "newDeviceName": "Test Device",
  "newPlatform": "android",
  "message": {
    "type": "force_logout",
    "title": "다른 기기에서 로그인됨",
    "body": "Test Device에서 로그인되어 현재 세션이 종료됩니다."
  },
  "createdAt": "현재시간 (Timestamp)",
  "processed": false
}
```

4. **저장** 버튼 클릭
5. 약 3-5초 후 Firebase Functions 로그 확인
6. 문서의 `processed` 필드가 `true`로 변경되었는지 확인

### 5.3 수신 전화 알림 함수 테스트

#### 수동 트리거 방법

1. Firestore Console → **incoming_calls** 컬렉션
2. **문서 추가** 버튼 클릭
3. 다음 필드 입력:

```json
{
  "userId": "테스트할_사용자_ID",
  "callerNumber": "010-1234-5678",
  "callerName": "테스트 발신자",
  "extension": "1010"
}
```

4. **저장** 버튼 클릭
5. Firebase Functions 로그 확인:

```
============================================================
📞 착신 전화 알림 전송
============================================================
User ID: user_abc123
Caller: 010-1234-5678
Extension: 1010
발견된 활성 기기: 1개
✅ 알림 전송 완료 - 성공: 1, 실패: 0
============================================================
```

6. 앱에서 푸시 알림 수신 확인

---

## 6. 플랫폼별 실제 테스트

### 6.1 Android 플랫폼 테스트

#### 테스트 환경 준비

**필수 조건**:
- ✅ Android 기기 또는 에뮬레이터 (Android 5.0 이상)
- ✅ Google Play Services 설치됨
- ✅ 인터넷 연결 (Wi-Fi 또는 모바일 데이터)
- ✅ 앱 알림 권한 허용됨

**알림 권한 확인**:
```
설정 → 앱 → MAKECALL → 알림 → 허용
```

#### Step 1: FCM 토큰 생성 및 저장 확인

**앱 실행**:
```bash
# Android 기기 연결 확인
adb devices

# 앱 실행 (디버그 모드)
flutter run -d <device-id>
```

**콘솔 로그 확인**:
```
🔔 FCM 서비스 초기화 시작...
   플랫폼: android

📱 알림 권한 상태: AuthorizationStatus.authorized

============================================================
🔔 FCM 토큰 정보
============================================================
📱 전체 토큰:
fGHI1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOP...(152자)

📋 요약 정보:
  - 토큰 길이: 152 문자
  - 사용자 ID: user_abc123
  - 플랫폼: android
  - 기기 이름: Samsung Galaxy S21
============================================================

🔐 [DatabaseService] FCM 토큰 저장 시작
   userId: user_abc123
   deviceId: 5d513e7a5fb1e2d5
   platform: android
   기존 활성 토큰 수: 0

✅ [DatabaseService] FCM 토큰 저장 완료 (문서 ID: user_abc123_5d513e7a5fb1e2d5)
```

**Firestore 확인**:
1. Firebase Console → Firestore Database
2. `fcm_tokens` 컬렉션 선택
3. 문서 ID: `user_abc123_5d513e7a5fb1e2d5` 확인

#### Step 2: Python 스크립트로 테스트 알림 전송

**스크립트 실행**:
```bash
cd /home/user/flutter_app
python3 docs/fcm_testing/send_fcm_test_message.py
```

**실행 화면**:
```
============================================================
🔔 FCM 테스트 메시지 발송
============================================================

📱 활성 FCM 토큰 조회 중...
✅ 1개의 활성 토큰 발견

1. 사용자: user_abc123
   기기: Samsung Galaxy S21 (android)
   토큰: user_abc123_5d513e7...

메시지 타입을 선택하세요:
1. 기본 테스트 알림
2. 수신 전화 알림
3. 부재중 전화 알림
4. 새 메시지 알림
5. 모든 타입 순차 발송

선택 (1-5, Enter=1): 2

📤 Samsung Galaxy S21로 메시지 발송 중...

📨 incoming_call 메시지 발송 중...
✅ 메시지 발송 성공: projects/makecallio/messages/0:1705300200123456
✅ incoming_call 발송 완료

============================================================
🎉 테스트 완료!
============================================================

💡 팁:
- 기기에서 알림을 확인하세요
- Firestore의 notification_logs 컬렉션에서 로그를 확인할 수 있습니다
- 앱의 알림 설정이 활성화되어 있는지 확인하세요
```

#### Step 3: Android 기기에서 알림 확인

**포그라운드 상태 (앱 실행 중)**:
```
✅ 앱 내 스낵바 표시:
   제목: 김철수
   내용: 010-1234-5678
   
✅ 수신 전화 풀스크린 화면 표시
   - 발신자 정보
   - 응답/거절 버튼
```

**백그라운드 상태 (앱 최소화)**:
```
✅ Android 알림 트레이에 알림 표시:
   [앱 아이콘]
   김철수
   010-1234-5678
   
✅ 알림 탭 → 앱 포그라운드로 전환
✅ 수신 전화 풀스크린 화면 표시
```

**앱 종료 상태**:
```
✅ Android 알림 트레이에 알림 표시
✅ 알림 탭 → 앱 자동 실행
✅ 백그라운드 핸들러 실행:

콘솔 로그:
🔔 백그라운드 메시지 수신:
  제목: 김철수
  내용: 010-1234-5678
  데이터: {type: incoming_call, caller_name: 김철수, ...}
  메시지 타입: incoming_call
```

#### Step 4: Firebase Functions 로그 확인

Firebase Console → Functions → Logs:
```
============================================================
📞 착신 전화 알림 전송
============================================================
User ID: user_abc123
Caller: 010-1234-5678
Extension: 1010
발견된 활성 기기: 1개
✅ 알림 전송 완료 - 성공: 1, 실패: 0
============================================================
```

### 6.2 iOS 플랫폼 테스트

#### 테스트 환경 준비

**필수 조건**:
- ✅ iOS 기기 (iOS 13.0 이상) 또는 시뮬레이터
- ✅ Apple Developer 계정
- ✅ APNs 인증 키 또는 인증서 설정
- ✅ Firebase Console에 APNs 키 업로드
- ✅ 앱 알림 권한 허용됨

**⚠️ 중요**: iOS 시뮬레이터는 푸시 알림을 지원하지 않습니다. 실제 iOS 기기에서 테스트해야 합니다.

**알림 권한 확인**:
```
설정 → 알림 → MAKECALL → 알림 허용
```

#### Step 1: FCM 토큰 생성 및 저장 확인

**앱 실행**:
```bash
# iOS 기기 연결 확인
flutter devices

# 앱 실행 (디버그 모드)
flutter run -d <ios-device-id>
```

**콘솔 로그 확인**:
```
🔔 FCM 서비스 초기화 시작...
   플랫폼: ios

📱 알림 권한 상태: AuthorizationStatus.authorized

============================================================
🔔 FCM 토큰 정보
============================================================
📱 전체 토큰:
cDEF9876543210fedcbazyxwvutsrqponmlkjihgfedcbaABCDEFG...(152자)

📋 요약 정보:
  - 토큰 길이: 152 문자
  - 사용자 ID: user_abc123
  - 플랫폼: ios
  - 기기 이름: iPhone 13 Pro (iOS 17.0)
============================================================

🔐 [DatabaseService] FCM 토큰 저장 시작
   userId: user_abc123
   deviceId: iPhone14,3
   platform: ios

✅ [DatabaseService] FCM 토큰 저장 완료 (문서 ID: user_abc123_iPhone14,3)
```

**Firestore 확인**:
1. Firebase Console → Firestore Database
2. `fcm_tokens` 컬렉션 선택
3. 문서 ID: `user_abc123_iPhone14,3` 확인

#### Step 2: Python 스크립트로 테스트 알림 전송

**스크립트 실행**:
```bash
python3 docs/fcm_testing/send_fcm_test_message.py
```

**실행 화면**:
```
============================================================
🔔 FCM 테스트 메시지 발송
============================================================

📱 활성 FCM 토큰 조회 중...
✅ 1개의 활성 토큰 발견

1. 사용자: user_abc123
   기기: iPhone 13 Pro (iOS 17.0) (ios)
   토큰: user_abc123_iPhone14,3...

메시지 타입을 선택하세요:
1. 기본 테스트 알림
2. 수신 전화 알림
3. 부재중 전화 알림
4. 새 메시지 알림
5. 모든 타입 순차 발송

선택 (1-5, Enter=1): 2

📤 iPhone 13 Pro (iOS 17.0)로 메시지 발송 중...

✅ 메시지 발송 성공: projects/makecallio/messages/0:1705300250789012
✅ incoming_call 발송 완료
```

#### Step 3: iOS 기기에서 알림 확인

**포그라운드 상태 (앱 실행 중)**:
```
✅ 앱 내 스낵바 표시:
   제목: 김철수
   내용: 010-1234-5678
   
✅ 수신 전화 풀스크린 화면 표시
   - 발신자 정보
   - 응답/거절 버튼
```

**백그라운드 상태 (앱 최소화)**:
```
✅ iOS 알림 배너 표시 (화면 상단):
   [MAKECALL]
   김철수
   010-1234-5678
   
✅ 알림 탭 → 앱 포그라운드로 전환
✅ 수신 전화 풀스크린 화면 표시
```

**앱 종료 상태**:
```
✅ iOS 알림 배너 표시
✅ 알림 탭 → 앱 자동 실행
✅ 백그라운드 핸들러 실행:

콘솔 로그:
🔔 백그라운드 메시지 수신:
  제목: 김철수
  내용: 010-1234-5678
  데이터: {type: incoming_call, caller_name: 김철수, ...}
  메시지 타입: incoming_call
```

**iOS 특수 기능**:
```
✅ Lock Screen (잠금 화면)에서도 알림 표시
✅ Notification Center (알림 센터)에 알림 누적
✅ Badge (앱 아이콘 배지) 카운트 업데이트
✅ Sound (알림음) 재생
```

### 6.3 Web 플랫폼 테스트

#### 테스트 환경 준비

**필수 조건**:
- ✅ 최신 브라우저 (Chrome 67+, Firefox 62+, Safari 16+)
- ✅ HTTPS 연결 (localhost는 HTTP 허용)
- ✅ VAPID 키 설정 완료 (Section 4.3 참조)
- ✅ Service Worker 등록 완료
- ✅ 브라우저 알림 권한 허용

**✅ 현재 상태**: Web FCM 활성화됨 (VAPID 키 교체 후 테스트 가능)

**참고**: 코드에는 예시 VAPID 키가 포함되어 있습니다. 실제 Firebase Console에서 생성한 키로 교체 후 테스트를 진행하세요 (Section 4.3 참조).

#### Step 1: Flutter Web 앱 실행

**개발 서버 실행**:
```bash
cd /home/user/flutter_app
flutter run -d chrome --web-port=5060
```

**또는 빌드 후 서버 실행**:
```bash
flutter build web --release
cd build/web
python3 -m http.server 5060
```

**브라우저 접속**:
```
http://localhost:5060
또는
https://your-domain.com
```

#### Step 2: Service Worker 등록 확인

**브라우저 개발자 도구 → Console**:
```javascript
// Service Worker 등록 상태 확인
navigator.serviceWorker.getRegistrations().then(registrations => {
  console.log('등록된 Service Workers:', registrations);
});

// 예상 출력:
✅ Flutter Service Worker 등록 완료: https://localhost:5060/
✅ Firebase Messaging Service Worker 등록 완료: https://localhost:5060/
```

**브라우저 개발자 도구 → Application → Service Workers**:
```
✅ flutter_service_worker.js - Active
✅ firebase-messaging-sw.js - Active
```

#### Step 3: 알림 권한 확인 및 요청

**브라우저 개발자 도구 → Console**:
```javascript
// 현재 알림 권한 확인
console.log('알림 권한:', Notification.permission);
// 예상 출력: "default", "granted", "denied"

// 권한 요청 (필요 시)
if (Notification.permission === 'default') {
  Notification.requestPermission().then(permission => {
    console.log('알림 권한 결과:', permission);
  });
}
```

**브라우저 UI에서 권한 허용**:
```
Chrome: 주소창 왼쪽 아이콘 → 알림 허용
Firefox: 주소창 팝업 → 알림 허용
Safari: 환경설정 → 웹사이트 → 알림 → 허용
```

#### Step 4: FCM 토큰 생성 확인 (VAPID 키 설정 후)

**Flutter 앱 콘솔 로그**:
```
🔔 FCM 서비스 초기화 시작...
   플랫폼: web

============================================================
🔔 FCM 토큰 정보
============================================================
📱 전체 토큰:
bZXC5432109876zyxwvutsrqponmlkjihgfedcbaABCDEFGHIJKLMN...(152자)

📋 요약 정보:
  - 토큰 길이: 152 문자
  - 사용자 ID: user_abc123
  - 플랫폼: web
  - 기기 이름: Chrome on Windows
============================================================
```

**Firestore 확인**:
```
문서 ID: user_abc123_web_chrome_Windows

필드:
  userId: "user_abc123"
  fcmToken: "bZXC5432109876..."
  deviceId: "web_chrome_Windows"
  deviceName: "Chrome on Windows"
  platform: "web"
  isActive: true
```

#### Step 5: Web 푸시 알림 테스트

**Python 스크립트로 알림 전송**:
```bash
python3 docs/fcm_testing/send_fcm_test_message.py
```

**포그라운드 상태 (브라우저 탭 활성화)**:
```
✅ 앱 내 스낵바 표시:
   제목: 김철수
   내용: 010-1234-5678
   
✅ 수신 전화 풀스크린 화면 표시
```

**백그라운드 상태 (브라우저 탭 비활성화 또는 최소화)**:
```
✅ 브라우저 알림 표시:
   [MAKECALL 아이콘]
   김철수
   010-1234-5678
   [열기] [닫기]
   
✅ [열기] 버튼 클릭 → 브라우저 탭 활성화
✅ 수신 전화 풀스크린 화면 표시
```

**Service Worker 콘솔 로그**:

**브라우저 개발자 도구 → Application → Service Workers → firebase-messaging-sw.js 콘솔**:
```
[firebase-messaging-sw.js] 백그라운드 메시지 수신: {
  notification: {
    title: "김철수",
    body: "010-1234-5678"
  },
  data: {
    type: "incoming_call",
    caller_name: "김철수",
    caller_number: "010-1234-5678"
  }
}
```

#### Step 6: 브라우저별 알림 동작 확인

**Chrome (Windows/Mac/Linux)**:
```
✅ 시스템 알림으로 표시
✅ 알림 액션 버튼 지원 (열기/닫기)
✅ 알림 클릭 시 탭 활성화
✅ 알림 음향 재생
```

**Firefox (Windows/Mac/Linux)**:
```
✅ 시스템 알림으로 표시
✅ 알림 클릭 시 탭 활성화
✅ 알림 음향 재생
```

**Safari (Mac)**:
```
✅ macOS 알림 센터에 표시
✅ 알림 클릭 시 Safari 활성화
⚠️  알림 액션 버튼 미지원
```

**Edge (Windows)**:
```
✅ Windows 알림 센터에 표시
✅ 알림 액션 버튼 지원
✅ 알림 클릭 시 탭 활성화
```

### 6.4 플랫폼 간 중복 로그인 테스트

#### 시나리오: Android → iOS → Web 순차 로그인

**Step 1: Android 기기에서 로그인**
```
✅ FCM 토큰 생성: user_abc123_5d513e7a5fb1e2d5
✅ isActive: true
```

**Step 2: iOS 기기에서 동일 계정 로그인**
```
🚨 중복 로그인 감지
✅ Android 기기에 강제 로그아웃 알림 전송
✅ Android FCM 토큰 isActive: false로 변경
✅ iOS FCM 토큰 생성: user_abc123_iPhone14,3
✅ iOS isActive: true
```

**Android 기기 화면**:
```
[다이얼로그 표시]
⚠️ 다른 기기에서 로그인됨

iPhone 13 Pro (iOS 17.0)에서 로그인되어
현재 세션이 종료됩니다.

ℹ️ 본인이 아닌 경우 비밀번호를 변경하세요.

[확인] → 자동 로그아웃
```

**Step 3: Web 브라우저에서 동일 계정 로그인**
```
🚨 중복 로그인 감지
✅ iOS 기기에 강제 로그아웃 알림 전송
✅ iOS FCM 토큰 isActive: false로 변경
✅ Web FCM 토큰 생성: user_abc123_web_chrome_Windows
✅ Web isActive: true
```

**iOS 기기 화면**:
```
[iOS 알림 배너 표시]
다른 기기에서 로그인됨
Chrome on Windows에서 로그인되어
현재 세션이 종료됩니다.

[탭] → 앱 실행 → 자동 로그아웃
```

**최종 Firestore 상태**:
```
fcm_tokens 컬렉션:
├─ user_abc123_5d513e7a5fb1e2d5 (Android)
│  └─ isActive: false
├─ user_abc123_iPhone14,3 (iOS)
│  └─ isActive: false
└─ user_abc123_web_chrome_Windows (Web)
   └─ isActive: true
```

---

## 7. 수신 전화 테스트

### 7.1 전제 조건

1. ✅ FCM 토큰이 Firestore에 저장되어 있어야 함
2. ✅ 앱이 포그라운드 또는 백그라운드에서 실행 중
3. ✅ Firebase Functions가 정상 배포되어 있어야 함
4. ✅ 앱에서 알림 권한이 허용되어 있어야 함

### 7.2 테스트 시나리오 A: Firestore 직접 테스트

**목적**: Firebase Functions만 격리하여 테스트

**절차**:

#### Step 1: 사용자 ID 및 FCM 토큰 확인

1. 앱 실행 후 콘솔에서 사용자 ID 복사
2. Firestore → **fcm_tokens** 컬렉션에서 해당 사용자의 `fcmToken` 복사

#### Step 2: Firestore에 수신 전화 문서 추가

1. Firestore Console → **incoming_calls** 컬렉션
2. **문서 추가** 클릭
3. 필드 입력:

```json
{
  "userId": "복사한_사용자_ID",
  "callerNumber": "010-9876-5432",
  "callerName": "홍길동",
  "extension": "1020"
}
```

4. **저장** 클릭

#### Step 3: 플랫폼별 푸시 알림 수신 확인

**Android**:
```
포그라운드:
  ✅ 앱 내 스낵바: "홍길동님의 전화"
  ✅ 수신 전화 풀스크린 화면

백그라운드:
  ✅ Android 알림 트레이: "📞 착신 전화 / 홍길동님의 전화"
  ✅ 탭 → 앱 활성화 → 풀스크린 화면

종료 상태:
  ✅ Android 알림 트레이 표시
  ✅ 탭 → 앱 자동 실행 → 풀스크린 화면
```

**iOS**:
```
포그라운드:
  ✅ 앱 내 스낵바: "홍길동님의 전화"
  ✅ 수신 전화 풀스크린 화면

백그라운드:
  ✅ iOS 알림 배너: "📞 착신 전화 / 홍길동님의 전화"
  ✅ 탭 → 앱 활성화 → 풀스크린 화면

종료 상태:
  ✅ iOS 알림 배너 표시
  ✅ 탭 → 앱 자동 실행 → 풀스크린 화면
```

**Web** (VAPID 키 설정 후):
```
포그라운드:
  ✅ 앱 내 스낵바: "홍길동님의 전화"
  ✅ 수신 전화 풀스크린 화면

백그라운드:
  ✅ 브라우저 알림: "📞 착신 전화 / 홍길동님의 전화"
  ✅ [열기] 버튼 → 탭 활성화 → 풀스크린 화면

브라우저 종료:
  ✅ 시스템 알림 표시 (Service Worker)
  ✅ 알림 클릭 → 브라우저 및 앱 실행
```

#### Step 4: Firebase Functions 로그 확인

Firebase Console → Functions → Logs:

```
============================================================
📞 착신 전화 알림 전송
============================================================
User ID: user_abc123
Caller: 010-9876-5432
Extension: 1020
발견된 활성 기기: 1개

멀티캐스트 메시지 전송:
  - Android: High Priority, Channel ID: incoming_calls
  - iOS: APNs Priority 10, Sound: default
  - Web: Urgency: high, Actions: [응답, 거부]

✅ 알림 전송 완료 - 성공: 1, 실패: 0
============================================================
```

### 7.3 테스트 시나리오 B: 실제 통화 시스템 연동 테스트

**목적**: DCMIWS 서버에서 실제 수신 전화 발생 시 테스트

**전제 조건**:
- DCMIWS 서버 연결 필요
- 실제 전화 발신 필요 (외부 전화기 또는 다른 단말)

**절차**:

#### Step 1: DCMIWS 서버 연결 확인

앱 내에서:
1. 설정 → 서버 설정 확인
2. WebSocket 연결 상태 확인 (녹색 아이콘)

#### Step 2: 실제 전화 걸기

1. 외부 전화기에서 등록된 단말번호로 전화 걸기
2. DCMIWS 서버가 수신 전화 이벤트 감지
3. Flutter 앱의 WebSocket 리스너가 이벤트 수신
4. `incoming_calls` 컬렉션에 문서 자동 생성
5. Firebase Functions 트리거 실행
6. FCM 푸시 알림 전송

#### Step 3: 검증 포인트

1. **Firestore 문서 생성 확인**:
   - `incoming_calls` 컬렉션에 신규 문서 생성됨
   
2. **Firebase Functions 로그 확인**:
   - `sendIncomingCallNotification` 함수 실행 로그 존재
   
3. **푸시 알림 수신 확인**:
   - 앱에서 수신 전화 화면 표시
   - 통화 응답/거절 버튼 동작 확인

### 7.4 예상 결과

**정상 동작 시**:

```
✅ Firestore에 incoming_calls 문서 생성됨
✅ Firebase Functions 로그에 전송 성공 기록됨
✅ 앱에서 푸시 알림 수신됨
✅ 수신 전화 화면(IncomingCallScreen) 표시됨
```

**오류 발생 시**:

| 증상 | 원인 | 해결 방법 |
|-----|------|---------|
| 푸시 알림 수신 안 됨 | FCM 토큰 미등록 | 앱 재로그인 → 토큰 재등록 |
| Firebase Functions 미실행 | 함수 배포 실패 | `firebase deploy --only functions` 재배포 |
| 활성 기기 0개 로그 | `fcm_tokens` 컬렉션 비어있음 | 앱 재실행 → 토큰 등록 확인 |
| FCM 전송 실패 | 유효하지 않은 토큰 | 토큰 삭제 → 앱 재로그인 |
| Web 알림 안 됨 | VAPID 키 미설정 | Section 4.3 참조하여 VAPID 키 설정 |
| Service Worker 미등록 | 브라우저 캐시 문제 | 하드 리프레시 (Ctrl+Shift+R) |

---

## 8. 문제 해결

### 8.1 FCM 토큰이 저장되지 않음

**증상**:
- Firestore `fcm_tokens` 컬렉션이 비어있음
- 콘솔에 FCM 토큰 정보가 출력되지 않음

**원인 및 해결 방법**:

#### 원인 1: 웹 플랫폼에서 실행 중 (VAPID 키 미설정)

웹 플랫폼은 VAPID 키 설정이 필요하여 기본적으로 비활성화되어 있습니다.

**확인 방법**:
```
콘솔 로그:
⚠️  웹 플랫폼에서는 FCM이 비활성화되어 있습니다
   💡 중복 로그인 방지 기능은 모바일 앱에서만 사용 가능합니다
   💡 웹에서 FCM을 사용하려면 Firebase Console에서 VAPID 키를 설정하세요
```

**해결 방법**:
- Android 또는 iOS 기기에서 앱 실행
- 또는 Section 4.3 참조하여 VAPID 키 설정

#### 원인 2: 알림 권한 거부

**확인 방법**:
```
콘솔 로그:
❌ 알림 권한이 거부되었습니다
```

**해결 방법**:

**Android**:
```
설정 → 앱 → MAKECALL → 알림 → 허용
```

**iOS**:
```
설정 → 알림 → MAKECALL → 알림 허용
```

**Web**:
```
Chrome: 주소창 아이콘 → 사이트 설정 → 알림 허용
Firefox: 주소창 아이콘 → 권한 → 알림 허용
Safari: 환경설정 → 웹사이트 → 알림 → 허용
```

#### 원인 3: Firebase 초기화 실패

**확인 방법**:
```
콘솔 로그:
❌ FCM 초기화 오류: ...
```

**해결 방법**:

**Android**:
1. `google-services.json` 파일이 `android/app/` 경로에 있는지 확인
2. `pubspec.yaml`에 Firebase 패키지가 올바르게 추가되었는지 확인
3. 앱 재빌드 및 재실행:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

**iOS**:
1. Firebase Console에 APNs 키가 업로드되었는지 확인
2. `ios/Runner/Info.plist` 권한 설정 확인
3. 앱 재빌드 및 재실행

**Web**:
1. `web/firebase-messaging-sw.js` 파일 존재 확인
2. Firebase 구성이 올바른지 확인
3. VAPID 키 설정 (Section 4.3)

### 8.2 Firebase Functions가 실행되지 않음

**증상**:
- Firestore에 문서는 추가되지만 FCM 알림이 전송되지 않음
- Functions 로그에 실행 기록이 없음

**원인 및 해결 방법**:

#### 원인 1: Functions 미배포

**확인 방법**:
- Firebase Console → Functions 메뉴에 함수 목록이 비어있음

**해결 방법**:
```bash
cd functions
npm install
firebase deploy --only functions
```

**배포 확인**:
```bash
firebase functions:list
```

#### 원인 2: 리전 불일치

**확인 방법**:
- Firestore 데이터베이스 리전: `asia-east1`
- Functions 배포 리전: 다른 리전

**해결 방법**:
- `functions/index.js` 파일의 모든 함수 `region` 옵션을 `"asia-east1"`로 설정 (이미 설정되어 있음)

#### 원인 3: 권한 부족

**확인 방법**:
- Functions 로그에 권한 오류 메시지 존재

**해결 방법**:
- Firebase Console → 프로젝트 설정 → 서비스 계정
- Firebase Admin SDK 권한 확인
- 필요 시 새 서비스 계정 키 생성

### 8.3 푸시 알림이 수신되지 않음

**증상**:
- Functions 로그에는 전송 성공 기록이 있지만 앱에서 알림 미수신

**플랫폼별 해결 방법**:

#### Android

**원인 1: 앱이 종료된 상태**
```
해결 방법:
- 앱을 백그라운드 상태로 전환 (홈 버튼)
- 또는 앱 재실행
```

**원인 2: 배터리 최적화**
```
해결 방법:
설정 → 배터리 → 배터리 최적화 → MAKECALL → 최적화 안 함
```

**원인 3: 알림 채널 차단**
```
해결 방법:
설정 → 앱 → MAKECALL → 알림 → 채널별 알림 확인
```

#### iOS

**원인 1: 앱이 완전 종료됨**
```
해결 방법:
- iOS는 앱 강제 종료 시 푸시 알림 수신 제한
- 홈 버튼으로 백그라운드 전환 권장
```

**원인 2: Do Not Disturb 모드**
```
해결 방법:
제어 센터 → 방해 금지 모드 비활성화
```

**원인 3: APNs 인증 문제**
```
해결 방법:
Firebase Console → 프로젝트 설정 → 클라우드 메시징
→ Apple 앱 구성 → APNs 인증 키 재업로드
```

#### Web

**원인 1: Service Worker 미등록**
```
확인:
브라우저 개발자 도구 → Application → Service Workers

해결 방법:
- 하드 리프레시: Ctrl+Shift+R (Windows/Linux) 또는 Cmd+Shift+R (Mac)
- 브라우저 캐시 삭제
```

**원인 2: VAPID 키 미설정**
```
확인:
콘솔 로그에 "VAPID 키가 필요합니다" 메시지

해결 방법:
Section 4.3 참조하여 VAPID 키 설정
```

**원인 3: HTTPS 미사용**
```
확인:
브라우저 주소창에 http:// 표시

해결 방법:
- localhost는 HTTP 허용
- 프로덕션 환경은 HTTPS 필수
```

### 8.4 강제 로그아웃이 동작하지 않음

**증상**:
- 다른 기기에서 로그인해도 기존 기기가 로그아웃되지 않음

**원인 및 해결 방법**:

#### 원인 1: fcm_force_logout_queue 문서 미생성

**확인 방법**:
- Firestore → `fcm_force_logout_queue` 컬렉션 확인

**해결 방법**:
- Flutter 콘솔 로그 확인
- `_sendForceLogoutNotification` 함수 실행 여부 확인
- Firestore 쓰기 권한 확인

#### 원인 2: Functions 트리거 실패

**확인 방법**:
- `fcm_force_logout_queue` 문서의 `processed` 필드가 `false`로 유지됨

**해결 방법**:
- Firebase Functions 로그 확인
- `sendForceLogoutNotification` 함수 오류 메시지 확인
- Functions 재배포

### 8.5 Web Service Worker 문제

**증상**:
- 웹에서 백그라운드 알림이 수신되지 않음
- Service Worker 등록 실패

**원인 및 해결 방법**:

#### 원인 1: Service Worker 파일 경로 오류

**확인 방법**:
```
브라우저 개발자 도구 → Console:
❌ Service Worker registration failed
```

**해결 방법**:
```
파일 확인:
- web/firebase-messaging-sw.js 존재 확인
- 파일 이름 철자 확인
```

#### 원인 2: Firebase 버전 불일치

**확인 방법**:
```
web/firebase-messaging-sw.js:
importScripts('https://www.gstatic.com/firebasejs/10.7.0/...');
```

**해결 방법**:
```
Firebase SDK 버전을 pubspec.yaml의 firebase_core 버전과 일치시키기
(현재: 10.7.0 사용 중)
```

#### 원인 3: CORS 오류

**확인 방법**:
```
브라우저 개발자 도구 → Console:
❌ Access to fetch ... has been blocked by CORS policy
```

**해결 방법**:
```
- 개발: localhost 사용 (CORS 제한 없음)
- 프로덕션: 적절한 CORS 헤더 설정
```

### 8.6 유용한 디버깅 명령어

#### Firestore 데이터 조회 (Firebase CLI)

```bash
# fcm_tokens 컬렉션 전체 조회
firebase firestore:query "fcm_tokens"

# 특정 사용자의 토큰 조회
firebase firestore:query "fcm_tokens" --where "userId==user_abc123"

# 활성 토큰만 조회
firebase firestore:query "fcm_tokens" --where "isActive==true"

# 플랫폼별 토큰 조회
firebase firestore:query "fcm_tokens" --where "platform==android"
firebase firestore:query "fcm_tokens" --where "platform==ios"
firebase firestore:query "fcm_tokens" --where "platform==web"
```

#### Firebase Functions 로그 실시간 확인

```bash
# 전체 Functions 로그 스트리밍
firebase functions:log

# 특정 함수 로그만 확인
firebase functions:log --only sendForceLogoutNotification
firebase functions:log --only sendIncomingCallNotification

# 특정 기간의 로그 확인
firebase functions:log --since "1h"
firebase functions:log --since "1d"
```

#### FCM 토큰 직접 테스트

**Python 스크립트 사용**:
```bash
# 테스트 알림 전송
python3 docs/fcm_testing/send_fcm_test_message.py

# Firebase Admin SDK 경로 확인
ls -la /opt/flutter/firebase-admin-sdk.json
```

**cURL 사용** (직접 FCM API 호출):
```bash
# Access Token 생성
python3 docs/fcm_testing/get_access_token.py

# FCM API 호출
docs/fcm_testing/send_fcm_curl.sh <FCM_TOKEN> <ACCESS_TOKEN>
```

#### Web Service Worker 디버깅

**Chrome**:
```
chrome://serviceworker-internals/

Actions:
- Unregister: Service Worker 등록 해제
- Start: Service Worker 수동 시작
- Inspect: DevTools로 디버깅
```

**Firefox**:
```
about:debugging#/runtime/this-firefox

Actions:
- Service Workers 목록 확인
- 등록 해제 버튼
- 검사 버튼 (DevTools)
```

#### 플랫폼별 로그 확인

**Android**:
```bash
# Logcat 실시간 로그
adb logcat -s flutter

# FCM 관련 로그만 필터링
adb logcat | grep FCM
```

**iOS**:
```bash
# iOS 시뮬레이터 로그
xcrun simctl spawn booted log stream --level debug | grep FCM

# 실제 기기 로그
idevicesyslog | grep FCM
```

**Web**:
```javascript
// 브라우저 콘솔에서 Service Worker 로그 확인
navigator.serviceWorker.ready.then(registration => {
  console.log('Service Worker:', registration);
});

// FCM 토큰 확인
firebase.messaging().getToken().then(token => {
  console.log('FCM Token:', token);
});
```

---

## 9. 체크리스트

### 9.1 초기 설정 체크리스트

- [ ] Firebase 프로젝트 생성 완료
- [ ] **Android**: `google-services.json` 파일이 `android/app/` 경로에 존재
- [ ] **iOS**: APNs 인증 키가 Firebase Console에 업로드됨
- [ ] **Web**: VAPID 키 생성 및 코드에 적용됨 (옵션)
- [ ] `pubspec.yaml`에 Firebase 패키지 추가됨
- [ ] Firebase Functions 배포 완료 (`firebase deploy --only functions`)
- [ ] Firestore Database 생성 완료
- [ ] Firestore 보안 규칙 설정 완료

### 9.2 플랫폼별 FCM 토큰 검증 체크리스트

**Android**:
- [ ] 앱 실행 시 콘솔에 FCM 토큰 정보 출력됨
- [ ] Firestore `fcm_tokens` 컬렉션에 문서 생성됨
- [ ] 문서 ID: `{userId}_{androidId}` 형식
- [ ] `platform: "android"` 확인
- [ ] `deviceName`: 실제 기기 모델명 확인
- [ ] `isActive: true` 확인

**iOS**:
- [ ] 앱 실행 시 콘솔에 FCM 토큰 정보 출력됨
- [ ] Firestore `fcm_tokens` 컬렉션에 문서 생성됨
- [ ] 문서 ID: `{userId}_{iOSDeviceId}` 형식
- [ ] `platform: "ios"` 확인
- [ ] `deviceName`: iOS 버전 포함 확인
- [ ] `isActive: true` 확인

**Web** (VAPID 키 설정 후):
- [ ] 브라우저 알림 권한 허용됨
- [ ] Service Worker 등록 완료
- [ ] 앱 실행 시 콘솔에 FCM 토큰 정보 출력됨
- [ ] Firestore `fcm_tokens` 컬렉션에 문서 생성됨
- [ ] 문서 ID: `{userId}_web_{browser}_{os}` 형식
- [ ] `platform: "web"` 확인
- [ ] `isActive: true` 확인

### 9.3 중복 로그인 방지 체크리스트

- [ ] 두 번째 기기 로그인 시 중복 로그인 감지 로그 출력됨
- [ ] `fcm_force_logout_queue` 컬렉션에 문서 추가됨
- [ ] Firebase Functions 로그에 `sendForceLogoutNotification` 실행 기록 존재
- [ ] 기존 기기의 `fcm_tokens` 문서 `isActive`가 `false`로 변경됨
- [ ] 기존 기기에서 강제 로그아웃 다이얼로그/알림 표시됨
- [ ] 새 기기의 FCM 토큰만 `isActive: true`로 유지됨

### 9.4 플랫폼별 푸시 알림 수신 체크리스트

**Android**:
- [ ] Firestore `incoming_calls` 문서 추가 시 푸시 알림 수신됨
- [ ] 포그라운드: 앱 내 스낵바 + 풀스크린 화면
- [ ] 백그라운드: 시스템 알림 트레이 표시
- [ ] 종료 상태: 알림 탭 시 앱 자동 실행
- [ ] Firebase Functions 로그에 전송 성공 기록 존재

**iOS**:
- [ ] Firestore `incoming_calls` 문서 추가 시 푸시 알림 수신됨
- [ ] 포그라운드: 앱 내 스낵바 + 풀스크린 화면
- [ ] 백그라운드: iOS 알림 배너 표시
- [ ] 종료 상태: 알림 탭 시 앱 자동 실행
- [ ] 잠금 화면에서도 알림 표시됨
- [ ] Firebase Functions 로그에 전송 성공 기록 존재

**Web** (VAPID 키 설정 후):
- [ ] Firestore `incoming_calls` 문서 추가 시 푸시 알림 수신됨
- [ ] 포그라운드: 앱 내 스낵바 + 풀스크린 화면
- [ ] 백그라운드: 브라우저 알림 표시 (Service Worker)
- [ ] 알림 클릭 시 탭 활성화
- [ ] 알림 액션 버튼 동작 확인 (Chrome/Edge)
- [ ] Firebase Functions 로그에 전송 성공 기록 존재

---

## 10. 참고 자료

### 10.1 코드 파일 경로

| 컴포넌트 | 파일 경로 |
|---------|----------|
| FCM Service | `lib/services/fcm_service.dart` |
| Database Service | `lib/services/database_service.dart` |
| Firebase Functions | `functions/index.js` |
| FCM Token Model | `lib/models/fcm_token_model.dart` |
| Firebase Options | `lib/firebase_options.dart` |
| Web Service Worker | `web/firebase-messaging-sw.js` |
| Web Manifest | `web/manifest.json` |
| Web Index HTML | `web/index.html` |
| Incoming Call Screen | `lib/screens/call/incoming_call_screen.dart` |
| Main (Background Handler) | `lib/main.dart` |

### 10.2 Firestore 컬렉션 경로

| 컬렉션 | 경로 | 용도 |
|-------|------|------|
| FCM Tokens | `fcm_tokens` | FCM 토큰 저장 |
| Force Logout Queue | `fcm_force_logout_queue` | 강제 로그아웃 큐 |
| Incoming Calls | `incoming_calls` | 수신 전화 알림 트리거 |
| Call History | `call_history` | 통화 기록 |
| Scheduled Notifications | `scheduled_notifications` | 예약 알림 |
| Notification Logs | `notification_logs` | 알림 전송 로그 (옵션) |

### 10.3 Firebase Functions 목록

| 함수 | 트리거 | 설명 |
|-----|-------|------|
| `sendForceLogoutNotification` | Firestore onCreate | 중복 로그인 방지 알림 전송 |
| `sendIncomingCallNotification` | Firestore onCreate | 수신 전화 알림 전송 (멀티캐스트) |
| `sendCallStatusNotification` | Firestore onUpdate | 통화 상태 변경 알림 |
| `remoteLogout` | Callable | 원격 로그아웃 |
| `cleanupExpiredTokens` | Callable | 만료 토큰 정리 |
| `sendGroupMessage` | Callable | 그룹 메시지 전송 |
| `sendCustomNotification` | Callable | 사용자 지정 알림 전송 |
| `processScheduledNotifications` | Callable | 예약 알림 처리 |
| `subscribeWebPush` | Callable | 웹푸시 구독 등록 |
| `validateAllTokens` | Callable | 전체 토큰 유효성 검사 |

### 10.4 테스트 스크립트

| 스크립트 | 경로 | 용도 |
|---------|------|------|
| FCM 테스트 메시지 | `docs/fcm_testing/send_fcm_test_message.py` | 대화형 알림 테스트 |
| Access Token 생성 | `docs/fcm_testing/get_access_token.py` | FCM API 인증 토큰 생성 |
| cURL 예시 | `docs/fcm_testing/fcm_curl_examples.sh` | cURL 명령어 예시 |
| FCM cURL 전송 | `docs/fcm_testing/send_fcm_curl.sh` | cURL로 직접 전송 |

### 10.5 플랫폼별 Firebase SDK 버전

| 플랫폼 | SDK | 버전 |
|--------|-----|------|
| Flutter | firebase_core | 3.6.0 |
| Flutter | firebase_messaging | 15.1.3 |
| Flutter | cloud_firestore | 5.4.3 |
| Web | Firebase JS SDK | 10.7.0 |
| Functions | Firebase Admin SDK | Node.js v2 |

---

## 11. 버전 정보

| 항목 | 버전 |
|-----|------|
| Flutter | 3.35.4 |
| Dart | 3.9.2 |
| Firebase Core | 3.6.0 |
| Firebase Messaging | 15.1.3 |
| Cloud Firestore | 5.4.3 |
| Firebase JS SDK (Web) | 10.7.0 |
| Firebase Functions | Node.js v2 |
| 문서 버전 | 2.0.0 (플랫폼별 테스트 포함) |
| 작성일 | 2025-01-15 |
| 마지막 업데이트 | 2025-01-15 |

---

**문서 작성자**: MAKECALL 개발팀  
**마지막 업데이트**: 2025-01-15  
**문서 버전**: 2.0.0 (Android, iOS, Web 플랫폼별 실제 테스트 예시 포함)
