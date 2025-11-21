# Android Apple Sign In 설정 가이드

## ❌ 현재 문제
Android에서 Apple 로그인 시 `identityToken`과 `authorizationCode`가 null로 반환됨

## 🔑 필수 설정 단계

### 1. Apple Developer Console 설정
https://developer.apple.com/account/resources/identifiers/list/serviceId

#### Step 1: Services ID 생성
1. **Identifier**: `com.olssoo.makecall.signin` (코드에서 사용 중)
2. **Description**: "MAKECALL Apple Sign In"
3. **Sign in with Apple** 활성화

#### Step 2: Return URLs 설정
Services ID 편집 → "Sign in with Apple" Configure 클릭:

**Return URLs (Redirect URIs) - 두 개 모두 추가 필수:**
```
https://makecallio.web.app/auth/callback
https://makecallio.firebaseapp.com/auth/callback
```

**Domains (Web Domain):**
```
makecallio.web.app
makecallio.firebaseapp.com
```

**⚠️ 중요:** Firebase Hosting의 두 도메인 모두 추가해야 함!

### 2. Firebase Console 설정
https://console.firebase.google.com/project/makecall-e81bb/authentication/providers

#### Apple 제공업체 활성화
1. Authentication → Sign-in method → Apple
2. **Enable** 체크
3. **Services ID**: `com.olssoo.makecall.signin`
4. **팀 ID**: Apple Developer Console에서 확인
5. **키 ID**: Apple Developer Console에서 생성
6. **비공개 키**: .p8 파일 내용 업로드

### 3. 코드 확인 (이미 올바름)

#### social_login_service.dart
```dart
webAuthenticationOptions: WebAuthenticationOptions(
  clientId: 'com.olssoo.makecall.signin',  // ✅ Services ID
  redirectUri: Uri.parse('https://makecallio.web.app/auth/callback'),  // ✅ Return URL
),
```

## 🧪 테스트 방법

### 디버그 로그 확인
Android 디바이스 연결 후:
```bash
adb logcat | grep -E "Apple|identityToken|authorizationCode"
```

**정상 로그:**
```
🍎 [Apple] 로그인 시작
   플랫폼: Android (webAuthenticationOptions 사용)
✅ [Apple] Apple 인증 정보 수신 완료
   - identityToken: 있음 (1234자)
   - authorizationCode: 있음 (567자)
```

**에러 로그:**
```
❌ [Apple] identityToken이 null입니다
Apple 로그인 인증 정보를 받지 못했습니다.
```

## 🔧 문제 해결

### Case 1: identityToken/authorizationCode가 null
**원인:** Apple Developer Console의 Return URLs 미설정
**해결:** Services ID에 Firebase 도메인 추가

### Case 2: "Invalid client_id"
**원인:** Services ID가 코드와 불일치
**해결:** Firebase Console과 코드의 Services ID 확인

### Case 3: "Redirect URI mismatch"
**원인:** Return URL이 코드와 불일치
**해결:** Apple Console에 정확한 Firebase URL 추가

## 📱 최종 확인 사항

- [ ] Apple Developer Console에서 Services ID 생성 완료
- [ ] Return URLs에 Firebase 도메인 2개 추가 완료
- [ ] Firebase Console에서 Apple 제공업체 활성화 완료
- [ ] Services ID가 `com.olssoo.makecall.signin`로 일치
- [ ] Redirect URI가 `https://makecallio.web.app/auth/callback`로 일치
- [ ] Android 빌드 및 테스트

## 🌐 참고 링크

- [Apple Sign In 공식 문서](https://developer.apple.com/sign-in-with-apple/)
- [Firebase Apple 인증 가이드](https://firebase.google.com/docs/auth/android/apple)
- [sign_in_with_apple 패키지](https://pub.dev/packages/sign_in_with_apple)
