# Android용 Apple 로그인 설정 가이드

## 📋 현재 Apple Developer 설정 정보

### App ID
- **Primary App ID**: `MAKECALL (2W96U5V89C.com.olssoo.makecall)`
- **Bundle ID**: `com.olssoo.makecall`

### Service ID (Services ID)
- **Service ID**: `com.olssoo.makecall.signin`
- **Enabled Services**: Sign In with Apple

### Web Authentication
- **Domains**: 
  - `makecallio.firebaseapp.com`
  - `makecallio.web.app`
- **Return URLs**:
  - `https://makecallio.firebaseapp.com/auth/callback`
  - `https://makecallio.web.app/auth/callback`

### Sign In with Apple Key
- **Key Name**: Sign in with Apple Key
- **Key ID**: `T46W8PY2B4`
- **Created**: 2025/11/22 09:11 am by nam koong hyun cheol

---

## 🔥 Firebase Console 설정 (필수)

### 1단계: Firebase Console 접속
1. Firebase Console 접속: https://console.firebase.google.com/
2. 프로젝트 선택: **makecallio**
3. **Authentication** → **Sign-in method** 탭 이동

### 2단계: Apple 로그인 제공업체 활성화
1. **Apple** 제공업체 찾기
2. **사용 설정** 토글 ON
3. 다음 정보 입력:

#### 필수 정보 입력:
```
서비스 ID: com.olssoo.makecall.signin

OAuth 코드 흐름 구성 (선택사항):
- Apple 팀 ID: 2W96U5V89C
- 키 ID: T46W8PY2B4
- 비공개 키: (Apple Developer Console에서 다운로드한 .p8 파일 내용)
```

#### 비공개 키 다운로드 방법:
1. Apple Developer Console: https://developer.apple.com/account/resources/authkeys/list
2. **Sign in with Apple Key** (Key ID: T46W8PY2B4) 선택
3. **Download** 버튼 클릭 → `AuthKey_T46W8PY2B4.p8` 파일 다운로드
4. 텍스트 에디터로 열어서 전체 내용 복사
5. Firebase Console의 **비공개 키** 필드에 붙여넣기

### 3단계: OAuth Redirect URI 확인
Firebase Console의 Apple 설정 하단에 표시되는 **OAuth 리디렉션 URI**를 확인하고, Apple Developer Console의 **Return URLs**에 등록되어 있는지 확인:

예상 URI:
```
https://makecallio.firebaseapp.com/__/auth/handler
```

**⚠️ 중요**: 이 URI가 Apple Developer Console의 **Return URLs**에 없으면 추가해야 합니다!

---

## 🔧 Flutter 코드 수정 (이미 적용됨)

현재 `social_login_service.dart`에 Android 지원이 이미 구현되어 있습니다:

```dart
// Android & Web: Web-based authentication
await SignInWithApple.getAppleIDCredential(
  scopes: [
    AppleIDAuthorizationScopes.email,
    AppleIDAuthorizationScopes.fullName,
  ],
  webAuthenticationOptions: WebAuthenticationOptions(
    clientId: 'com.olssoo.makecall.signin',  // Service ID
    redirectUri: Uri.parse('https://makecallio.web.app/auth/callback'),
  ),
);
```

---

## 🎯 Android에서 Apple 로그인 작동 원리

1. **사용자가 "Apple로 로그인" 버튼 클릭**
2. **Android WebView 또는 Chrome Custom Tabs 열림**
3. **Apple 로그인 웹 페이지 표시** (appleid.apple.com)
4. **사용자 Apple ID로 인증**
5. **Redirect URI로 리디렉션** (`https://makecallio.web.app/auth/callback`)
6. **identityToken 및 authorizationCode 수신**
7. **Firebase Authentication으로 로그인**

---

## ✅ 설정 체크리스트

### Apple Developer Console
- [x] App ID 생성 및 Sign In with Apple 활성화
- [x] Service ID 생성 (`com.olssoo.makecall.signin`)
- [x] Web Authentication 도메인 설정
- [x] Return URLs 등록
- [x] Sign In with Apple Key 생성 (Key ID: T46W8PY2B4)

### Firebase Console (확인 필요)
- [ ] Apple 로그인 제공업체 활성화
- [ ] Service ID 입력: `com.olssoo.makecall.signin`
- [ ] Apple 팀 ID 입력: `2W96U5V89C`
- [ ] Key ID 입력: `T46W8PY2B4`
- [ ] 비공개 키 (.p8 파일) 업로드
- [ ] OAuth Redirect URI가 Apple Developer Console Return URLs에 등록됨

### Flutter 앱
- [x] `sign_in_with_apple` 패키지 추가
- [x] `social_login_service.dart`에 Android 지원 코드 구현
- [x] Service ID 및 Redirect URI 설정

---

## 🚨 문제 해결

### 문제 1: "Apple 로그인이 작동하지 않습니다"
**원인**: Firebase Console에 Apple 제공업체가 활성화되지 않았거나 설정이 잘못됨

**해결**:
1. Firebase Console → Authentication → Sign-in method
2. Apple 제공업체 확인
3. 위의 필수 정보가 모두 입력되어 있는지 확인

### 문제 2: "Redirect URI mismatch" 오류
**원인**: Apple Developer Console의 Return URLs와 Firebase Redirect URI가 일치하지 않음

**해결**:
1. Firebase Console의 Apple 설정에서 **OAuth 리디렉션 URI** 확인
2. Apple Developer Console → Service ID → Web Authentication
3. Firebase의 OAuth URI를 Return URLs에 추가

### 문제 3: "Invalid client" 오류
**원인**: Service ID 또는 Key 설정이 잘못됨

**해결**:
1. Firebase Console의 Service ID가 `com.olssoo.makecall.signin`인지 확인
2. Key ID가 `T46W8PY2B4`인지 확인
3. 비공개 키 (.p8) 파일 내용이 정확히 복사되었는지 확인

---

## 📚 참고 자료

- [Firebase - Android에서 Apple로 인증](https://firebase.google.com/docs/auth/android/apple?hl=ko)
- [Apple - Sign in with Apple 구성](https://developer.apple.com/sign-in-with-apple/get-started/)
- [sign_in_with_apple 패키지](https://pub.dev/packages/sign_in_with_apple)

---

## 🎯 다음 단계

1. ✅ **비공개 키 (.p8) 파일 다운로드**
   - Apple Developer Console에서 Key ID `T46W8PY2B4` 다운로드
   
2. ✅ **Firebase Console에서 Apple 로그인 설정**
   - 위의 정보 입력
   - 비공개 키 업로드
   
3. ✅ **OAuth Redirect URI 확인 및 등록**
   - Firebase에서 제공하는 URI를 Apple Developer Console에 추가
   
4. ✅ **Android 앱 테스트**
   - Debug APK 빌드
   - Android 기기에서 Apple 로그인 테스트

