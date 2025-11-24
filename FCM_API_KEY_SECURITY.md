# 🔐 FCM API Key 보안 관리

## 📋 개요

Firebase Cloud Messaging (FCM) 푸시 알림을 위해 Firebase Functions를 HTTP로 직접 호출할 때 **API Key 인증**을 사용합니다.

## 🔑 API Key 정보

### 현재 사용 중인 API Key:
- **Android/Web**: `AIzaSyCB4mI5Kj61f6E532vg46GnmnnCfsI9XIM`
- **iOS/macOS**: `AIzaSyBnZSVzdthE2oa82Vjv8Uy0Wgefx6nGAWs`

### 사용 위치:
1. **`lib/firebase_options.dart`** - 플랫폼별 Firebase 설정
2. **`android/app/google-services.json`** - Android Firebase 설정
3. **`lib/services/dcmiws_service.dart`** - FCM 푸시 전송 (HTTP 헤더)

## 🛡️ 보안 강화 방법

### 변경 전 (하드코딩):
```dart
// ❌ 하드코딩 - 보안 취약
const firebaseApiKey = 'AIzaSyCB4mI5Kj61f6E532vg46GnmnnCfsI9XIM';
```

### 변경 후 (동적 로딩):
```dart
// ✅ firebase_options.dart에서 동적으로 가져오기
final firebaseApiKey = Firebase.app().options.apiKey;
```

**장점**:
- ✅ API Key가 한 곳(`firebase_options.dart`)에서 관리됨
- ✅ 플랫폼별 자동 선택 (Android/Web/iOS)
- ✅ API Key 변경 시 한 곳만 수정하면 됨
- ✅ 버전 관리 시 보안 위험 감소

## 📍 FCM 푸시 전송 구조

### Firebase Functions HTTP 호출:

```dart
// lib/services/dcmiws_service.dart
Future<void> _sendIncomingCallFCM({...}) async {
  // Firebase Functions URL
  const functionsUrl = 
    'https://asia-northeast3-makecallio.cloudfunctions.net/sendIncomingCallNotification';
  
  // 🔐 API Key 인증 헤더
  final firebaseApiKey = Firebase.app().options.apiKey;
  
  final response = await http.post(
    Uri.parse(functionsUrl),
    headers: {
      'Content-Type': 'application/json',
      'X-Firebase-API-Key': firebaseApiKey, // 인증 헤더
    },
    body: json.encode({...}),
  );
}
```

### Firebase Functions 검증:

```javascript
// functions/index.js
exports.sendIncomingCallNotification = functions
  .region(region)
  .https.onCall(async (data, context) => {
    // Firebase SDK가 자동으로 API Key 검증
    // X-Firebase-API-Key 헤더 확인
    
    // FCM 메시지 전송
    await admin.messaging().send({...});
  });
```

## 🔧 API Key 변경 시 대응 방법

### 1. Firebase Console에서 새 API Key 확인

```
https://console.firebase.google.com/project/makecallio/settings/general
```

### 2. google-services.json 재다운로드

Firebase Console → 프로젝트 설정 → google-services.json 다운로드

### 3. firebase_options.dart 업데이트

**방법 A: FlutterFire CLI 사용 (자동)**
```bash
flutterfire configure
```

**방법 B: 수동 업데이트**
```dart
// lib/firebase_options.dart
static const FirebaseOptions android = FirebaseOptions(
  apiKey: 'NEW_API_KEY_HERE', // 새 API Key로 변경
  appId: '1:793164633643:android:efd6f648b54f7a15ccfc6e',
  // ... 나머지 동일
);

static const FirebaseOptions web = FirebaseOptions(
  apiKey: 'NEW_API_KEY_HERE', // 새 API Key로 변경
  appId: '1:793164633643:web:76f1f17cff465a5fccfc6e',
  // ... 나머지 동일
);
```

### 4. 클린 빌드 및 테스트

```bash
flutter clean
flutter pub get
flutter build apk --release
```

## 🔍 API Key 제한 설정 (권장)

Google Cloud Console에서 API Key 보안 강화:

### 1. API Key 관리 페이지

```
https://console.cloud.google.com/apis/credentials?project=makecallio
```

### 2. 애플리케이션 제한사항

- ✅ **Android 앱**: 
  - Package name: `com.olssoo.makecall_app`
  - SHA-1 지문 추가 (4개 등록됨)

- ✅ **HTTP 리퍼러**: 
  - `https://makecallio.firebaseapp.com/*`
  - `https://*.cloudfunctions.net/*`

### 3. API 제한사항

다음 API만 허용:
- Firebase Services
- Identity Toolkit API
- Token Service API
- Firebase Cloud Messaging API
- Cloud Functions API

## 📊 현재 API Key 사용 현황

| 플랫폼 | API Key | 파일 | 용도 |
|--------|---------|------|------|
| **Android** | `AIzaSyCB4...` | `google-services.json` | Firebase 초기화 |
| **Android** | `AIzaSyCB4...` | `firebase_options.dart` | Flutter 앱 설정 |
| **Android** | `AIzaSyCB4...` | `dcmiws_service.dart` | FCM HTTP 호출 인증 |
| **Web** | `AIzaSyCB4...` | `firebase_options.dart` | Flutter 웹 앱 설정 |
| **iOS** | `AIzaSyBnZ...` | `firebase_options.dart` | Flutter iOS 앱 설정 |
| **macOS** | `AIzaSyBnZ...` | `firebase_options.dart` | Flutter macOS 앱 설정 |

## 🚨 보안 주의사항

### ✅ 안전한 사용 방법:
1. API Key를 `firebase_options.dart`에서 동적으로 가져오기
2. Google Cloud Console에서 API Key 제한 설정
3. 민감한 작업은 Firebase Functions에서 처리
4. API Key를 `.gitignore`에 추가 (선택)

### ❌ 피해야 할 사항:
1. API Key를 소스코드에 하드코딩
2. API Key를 public repository에 노출
3. 제한 없이 API Key 사용
4. 서버 측 인증 없이 클라이언트만 검증

## 🔗 관련 문서

- [Firebase API Key 보안](https://firebase.google.com/docs/projects/api-keys)
- [Google Cloud API Key 관리](https://cloud.google.com/docs/authentication/api-keys)
- [FCM HTTP v1 API](https://firebase.google.com/docs/cloud-messaging/send-message)

## 📝 변경 이력

- **2025-11-23**: API Key 동적 로딩으로 변경
  - `dcmiws_service.dart`에서 하드코딩 제거
  - `firebase_options.dart`에서 자동으로 가져오도록 개선
  - 플랫폼별 API Key 자동 선택 지원
