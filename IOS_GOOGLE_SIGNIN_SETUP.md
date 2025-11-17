# iOS Google Sign-In 설정 가이드

## 🚨 현재 에러
```
{error: invalid_request, error_description: iOS bundleId validation failed.}
```

## 📋 에러 원인
Firebase Console에서 iOS 앱에 대한 OAuth 2.0 클라이언트가 올바르게 설정되지 않았습니다.

## ✅ 해결 방법

### 1️⃣ Firebase Console에서 iOS 앱 설정 확인

1. **Firebase Console 접속**
   - https://console.firebase.google.com/
   - 프로젝트: `makecallio`

2. **iOS 앱 등록 확인**
   - 왼쪽 메뉴: ⚙️ **프로젝트 설정**
   - **일반** 탭
   - **내 앱** 섹션에서 iOS 앱 확인
   - **Bundle ID**: `com.olssoo.makecall` (필수)

3. **GoogleService-Info.plist 다시 다운로드 (선택사항)**
   - iOS 앱 설정에서 **GoogleService-Info.plist 다운로드**
   - 다운로드한 파일로 `ios/Runner/GoogleService-Info.plist` 교체

---

### 2️⃣ Google Cloud Console에서 OAuth 2.0 설정

**중요: 이 단계가 가장 핵심입니다!**

1. **Google Cloud Console 접속**
   - https://console.cloud.google.com/
   - 프로젝트: `makecallio`

2. **API 및 서비스 > 사용자 인증 정보**
   - 왼쪽 메뉴: **API 및 서비스** > **사용자 인증 정보**

3. **iOS용 OAuth 2.0 클라이언트 ID 생성 확인**
   
   **A. 기존 iOS 클라이언트 확인:**
   - **OAuth 2.0 클라이언트 ID** 목록에서 iOS 타입 클라이언트 찾기
   - **Bundle ID**: `com.olssoo.makecall`이 설정되어 있는지 확인
   
   **B. iOS 클라이언트가 없는 경우 생성:**
   ```
   1. "+ 사용자 인증 정보 만들기" 클릭
   2. "OAuth 클라이언트 ID" 선택
   3. 애플리케이션 유형: "iOS"
   4. 이름: "iOS client (auto created by Google Service)"
   5. 번들 ID: com.olssoo.makecall
   6. "만들기" 클릭
   ```

4. **생성된 클라이언트 ID 확인**
   - 형식: `{숫자}-{문자열}.apps.googleusercontent.com`
   - 예: `793164633643-urj0qb989v8l2bggj6h025plnbbshfg5.apps.googleusercontent.com`
   - 이 값이 `Info.plist`의 `GIDClientID`와 일치해야 함

---

### 3️⃣ 웹용 OAuth 클라이언트 확인 (Web에서 Google 로그인 시 필요)

1. **웹 클라이언트 ID 확인**
   - Google Cloud Console > API 및 서비스 > 사용자 인증 정보
   - **웹 애플리케이션** 타입 클라이언트 찾기

2. **승인된 JavaScript 원본 추가 (Web 전용)**
   ```
   http://localhost
   http://localhost:5060
   https://your-app-domain.com
   ```

3. **승인된 리디렉션 URI 추가 (Web 전용)**
   ```
   http://localhost
   http://localhost:5060/__/auth/handler
   https://your-app-domain.com/__/auth/handler
   ```

---

### 4️⃣ firebase_options.dart에 웹 클라이언트 ID 추가

현재 `lib/firebase_options.dart` 파일을 확인하세요:

```dart
static const FirebaseOptions web = FirebaseOptions(
  apiKey: 'AIzaSyBnZSVzdthE2oa82Vjv8Uy0Wgefx6nGAWs',
  appId: '1:793164633643:web:b16982bf72c4c9c6ccfc6e',
  messagingSenderId: '793164633643',
  projectId: 'makecallio',
  authDomain: 'makecallio.firebaseapp.com',
  storageBucket: 'makecallio.firebasestorage.app',
  
  // ⚠️ 이 값이 누락되어 있다면 추가 필요
  // Google Cloud Console에서 "웹 클라이언트" OAuth 2.0 클라이언트 ID
  // iosClientId: '793164633643-xxx.apps.googleusercontent.com',  // 웹에서 iOS OAuth 사용 시
);

static const FirebaseOptions ios = FirebaseOptions(
  apiKey: 'AIzaSyBnZSVzdthE2oa82Vjv8Uy0Wgefx6nGAWs',
  appId: '1:793164633643:ios:1e2ec90f03abf1abccfc6e',
  messagingSenderId: '793164633643',
  projectId: 'makecallio',
  storageBucket: 'makecallio.firebasestorage.app',
  
  // ✅ iOS용 클라이언트 ID (이미 설정됨)
  iosClientId: '793164633643-urj0qb989v8l2bggj6h025plnbbshfg5.apps.googleusercontent.com',
  iosBundleId: 'com.olssoo.makecall',
);
```

---

## 🔍 현재 설정 요약

### ✅ 올바르게 설정된 항목
- iOS Bundle ID: `com.olssoo.makecall` (GoogleService-Info.plist, project.pbxproj 일치)
- Info.plist GIDClientID: `793164633643-urj0qb989v8l2bggj6h025plnbbshfg5.apps.googleusercontent.com`
- REVERSED_CLIENT_ID URL Scheme: 설정됨

### ⚠️ 확인 필요한 항목
- [ ] Google Cloud Console에 iOS용 OAuth 2.0 클라이언트 ID 생성 여부
- [ ] Bundle ID `com.olssoo.makecall`로 OAuth 클라이언트 등록 여부
- [ ] firebase_options.dart의 iosClientId 값 일치 여부

---

## 🎯 테스트 방법

1. **Firebase Console & Google Cloud Console 설정 완료**
2. **앱 재빌드**
   ```bash
   flutter clean
   cd ios && pod install && cd ..
   flutter run -d [iOS-device-id]
   ```
3. **Google 로그인 테스트**
   - 로그인 화면에서 Google 버튼 클릭
   - Google 계정 선택
   - ✅ 성공적으로 로그인되어야 함

---

## 📚 추가 참고 자료

### Firebase 공식 문서
- [iOS 앱에 Firebase 추가](https://firebase.google.com/docs/ios/setup)
- [Google Sign-In for iOS](https://firebase.google.com/docs/auth/ios/google-signin)

### Google Sign-In 패키지 문서
- [google_sign_in Flutter 패키지](https://pub.dev/packages/google_sign_in)
- [iOS 설정 가이드](https://pub.dev/packages/google_sign_in#ios-integration)

---

## 💡 자주 발생하는 문제

### 1. "iOS bundleId validation failed"
- **원인**: OAuth 클라이언트의 Bundle ID가 앱의 Bundle ID와 불일치
- **해결**: Google Cloud Console에서 iOS OAuth 클라이언트 Bundle ID 확인

### 2. "No active configuration"
- **원인**: Info.plist에 GIDClientID 누락
- **해결**: ✅ 이미 해결됨 (Info.plist에 GIDClientID 추가됨)

### 3. 로그인 후 앱으로 돌아오지 않음
- **원인**: URL Scheme (REVERSED_CLIENT_ID) 누락
- **해결**: ✅ 이미 설정됨 (Info.plist CFBundleURLSchemes)

---

## 🚀 다음 단계

1. **Firebase Console에서 iOS 앱 설정 확인**
2. **Google Cloud Console에서 iOS OAuth 클라이언트 생성/확인**
3. **앱 재빌드 및 테스트**

설정 완료 후에도 문제가 지속되면 추가 지원이 필요합니다.
