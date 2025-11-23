# 🍎 Apple 로그인 Android 수정사항

## 📋 문제 설명

### 증상
Android에서 Apple 로그인 시 사용자 인증 후 마지막 페이지에서 오류 발생:
```
Unable to process request due to missing initial state. 
This may happen if browser sessionStorage is inaccessible or accidentally cleared.
```

### 원인
- Android WebView에서 `signInWithRedirect` 방식 사용
- Firebase OAuth 리다이렉트 페이지에서 sessionStorage 접근 불가
- WebView 환경에서 브라우저 세션 관리 문제

## ✅ 해결 방법

### Kakao 로그인과 동일한 방식 적용
Firebase Custom Token 방식으로 전환하여 WebView OAuth 리다이렉트 문제 우회

### 주요 변경사항

#### 1. Firebase Functions에 Apple Custom Token 생성 함수 추가

**파일**: `functions/index.js`

```javascript
/**
 * 🍎 Apple 로그인을 위한 Firebase Custom Token 생성
 *
 * Apple Sign In 인증 정보를 받아서 Firebase Custom Token을 생성합니다.
 * Android에서 WebView OAuth 리다이렉트 문제를 우회하기 위한 방법입니다.
 */
exports.createCustomTokenForApple = functions
    .region(region)
    .https.onCall(async (data, context) => {
      try {
        const {appleUid, email, displayName, identityToken} = data;

        if (!appleUid || !identityToken) {
          throw new functions.https.HttpsError(
              "invalid-argument",
              "appleUid and identityToken are required",
          );
        }

        const firebaseUid = `apple_${appleUid}`;

        // Custom Token 생성
        const customToken = await admin.auth().createCustomToken(firebaseUid, {
          provider: "apple.com",
          email: email || null,
          name: displayName || "Apple User",
        });

        return {customToken};
      } catch (error) {
        throw new functions.https.HttpsError(
            "internal",
            `Failed to create custom token: ${error.message}`,
        );
      }
    });
```

#### 2. Flutter Apple 로그인 로직 수정

**파일**: `lib/services/social_login_service.dart`

**변경 전 (OAuth Provider 방식)**:
```dart
final oAuthProvider = OAuthProvider('apple.com');
final firebaseCredential = oAuthProvider.credential(
  idToken: identityToken,
  accessToken: authorizationCode,
);
final userCredential = await _auth.signInWithCredential(firebaseCredential);
```

**변경 후 (Custom Token 방식)**:
```dart
// Apple Identity Token에서 User ID 추출
final appleUid = _extractAppleUidFromToken(identityToken);

// Firebase Functions를 통해 Custom Token 생성
final functions = FirebaseFunctions.instanceFor(region: 'asia-northeast3');
final callable = functions.httpsCallable('createCustomTokenForApple');

final response = await callable.call({
  'appleUid': appleUid,
  'email': email,
  'displayName': displayName,
  'identityToken': identityToken,
});

final customToken = response.data['customToken'] as String;

// Custom Token으로 Firebase 로그인
final userCredential = await _auth.signInWithCustomToken(customToken);
```

#### 3. JWT 파싱 헬퍼 함수 추가

Apple Identity Token (JWT)에서 User ID를 추출하는 함수:

```dart
/// JWT에서 Apple User ID 추출
String? _extractAppleUidFromToken(String identityToken) {
  try {
    // JWT 구조: header.payload.signature
    final parts = identityToken.split('.');
    if (parts.length != 3) return null;

    // Payload 파트 추출 및 Base64 디코딩
    String payload = parts[1];
    
    // Base64 URL-safe 패딩 추가
    switch (payload.length % 4) {
      case 2: payload += '=='; break;
      case 3: payload += '='; break;
    }

    // Base64 URL-safe 디코딩
    final normalized = payload.replaceAll('-', '+').replaceAll('_', '/');
    final decoded = utf8.decode(base64.decode(normalized));
    
    // JSON 파싱 및 'sub' claim 추출
    final Map<String, dynamic> json = jsonDecode(decoded);
    return json['sub'] as String?;
  } catch (e) {
    return null;
  }
}
```

## 🚀 배포 방법

### 1. Firebase Functions 배포

**방법 1: Firebase CLI 사용 (추천)**
```bash
cd functions
firebase deploy --only functions:createCustomTokenForApple
```

**방법 2: 전체 Functions 재배포**
```bash
cd functions
npm run deploy
```

### 2. Flutter 앱 빌드

```bash
# Web 빌드 (테스트용)
flutter build web --release

# Android APK 빌드
flutter build apk --release

# Android App Bundle 빌드 (Google Play 배포용)
flutter build appbundle --release
```

## 📊 동작 흐름

### Before (실패하는 방식)
```
1. Apple Sign In 인증 (WebView)
2. identityToken 받기
3. OAuthProvider로 Firebase Credential 생성
4. signInWithCredential 시도
   → ❌ sessionStorage 오류 발생
```

### After (수정된 방식)
```
1. Apple Sign In 인증 (WebView)
2. identityToken 받기
3. JWT에서 Apple UID 추출
4. Firebase Functions 호출
   → createCustomTokenForApple
   → Custom Token 생성
5. Custom Token으로 Firebase 로그인
   → ✅ 성공!
```

## 🔍 테스트 방법

### Android에서 테스트
1. APK 빌드 후 Android 기기에 설치
2. Apple 로그인 버튼 클릭
3. Apple 인증 화면에서 로그인
4. 정상적으로 앱으로 돌아와서 로그인 완료 확인

### 예상 결과
- ✅ sessionStorage 오류 없이 정상 로그인
- ✅ 사용자 정보 정상 표시
- ✅ Firebase Authentication에 사용자 생성 확인

## 📌 주의사항

1. **Firebase Functions 배포 필수**
   - `createCustomTokenForApple` 함수가 배포되어 있어야 작동
   - 배포 후 5-10분 대기 (Functions 활성화 시간)

2. **리전 설정 확인**
   - Functions 리전: `asia-northeast3` (서울)
   - Flutter 코드의 리전 설정 일치 필요

3. **Apple Developer 설정**
   - Service ID, Redirect URI 설정 유지
   - 기존 OAuth 설정 그대로 유지

4. **플랫폼별 동작**
   - iOS: Native Apple Sign In (변경 없음)
   - Android: Custom Token 방식 (새로 적용)
   - Web: Custom Token 방식 (새로 적용)

## 🔗 관련 문서

- [Kakao 로그인 수정사항](./functions/KAKAO_LOGIN_FIX.md)
- [Firebase Functions 배포 가이드](./functions/DEPLOYMENT_GUIDE.md)
- [Firebase Custom Token 문서](https://firebase.google.com/docs/auth/admin/create-custom-tokens)

## 📝 변경 이력

- **2025-11-23**: Apple 로그인 Custom Token 방식 적용
  - Android sessionStorage 오류 해결
  - JWT 파싱 헬퍼 함수 추가
  - Firebase Functions에 createCustomTokenForApple 추가
