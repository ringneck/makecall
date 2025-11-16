# 🔐 Firebase reCAPTCHA 설정 가이드

## 문제 상황
```
Password reset request norman@olssoo.com with empty reCAPTCHA token
```

이 경고는 Firebase가 비밀번호 재설정 요청을 받았지만 reCAPTCHA 토큰이 없어서 **이메일 발송이 차단**되었을 가능성을 의미합니다.

## 해결 방법 1: Firebase Console에서 reCAPTCHA 비활성화 (개발용)

### 단계:
1. Firebase Console: https://console.firebase.google.com/
2. 프로젝트 선택: **makecallio**
3. **Authentication** → **Settings** 탭
4. **Email Enumeration Protection** 섹션 찾기
5. "Enable Email Enumeration Protection" **비활성화**

또는:

3. **Authentication** → **Sign-in method** 탭
4. **Advanced** 섹션 → **Manage bot protection**
5. "reCAPTCHA Enterprise" **비활성화** (개발 중)

### ⚠️ 주의사항
- 개발/테스트 환경에서만 비활성화
- 프로덕션에서는 reCAPTCHA 활성화 필요

## 해결 방법 2: SHA-1/SHA-256 인증서 등록 (권장)

Android 앱에서 reCAPTCHA 작동을 위해 필요합니다.

### SHA-1/SHA-256 인증서 확인:
```bash
# Debug 키스토어 (개발용)
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# Release 키스토어 (프로덕션용)
keytool -list -v -keystore /home/user/flutter_app/android/release-key.jks -alias release
```

### Firebase Console에 등록:
1. Firebase Console → Project Settings (⚙️)
2. **Android 앱** 선택
3. **SHA certificate fingerprints** 섹션
4. **Add fingerprint** 클릭
5. SHA-1과 SHA-256 모두 등록

### 중요:
- Debug 키 (개발): 반드시 등록
- Release 키 (프로덕션): 배포 전 등록 필수

## 해결 방법 3: App Check 설정 (선택사항)

App Check는 Firebase의 추가 보안 계층입니다.

### 1. Firebase Console 설정:
```
1. Firebase Console → App Check
2. Android 앱 등록
3. "Debug provider" 활성화 (개발용)
4. Debug token 생성 및 등록
```

### 2. Flutter 패키지 추가:
```yaml
dependencies:
  firebase_app_check: ^0.2.1+7
```

### 3. 코드 초기화:
```dart
import 'package:firebase_app_check/firebase_app_check.dart';

await Firebase.initializeApp();
await FirebaseAppCheck.instance.activate(
  // 개발용
  androidProvider: AndroidProvider.debug,
  // 프로덕션용
  // androidProvider: AndroidProvider.playIntegrity,
);
```

## 테스트 순서

### ✅ 1단계: SHA 인증서 등록 (가장 중요!)
```bash
# SHA-1, SHA-256 확인
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# Firebase Console에 등록
# → Project Settings → Android app → Add fingerprint
```

### ✅ 2단계: 앱 재빌드 및 테스트
```bash
# Clean build
flutter clean
flutter pub get
flutter run
```

### ✅ 3단계: 비밀번호 재설정 재시도
- 이메일 입력 → 재설정 이메일 보내기
- 로그 확인: "empty reCAPTCHA token" 경고 사라짐

### ✅ 4단계: 이메일 확인
- 받은 편지함 확인 (5-10분 대기)
- 스팸함 확인

## Firebase Console 확인사항

### Authentication → Settings
- ✅ Email/Password 활성화 확인
- ✅ Email Enumeration Protection 설정 확인

### Project Settings → Android app
- ✅ SHA-1 인증서 등록 확인
- ✅ SHA-256 인증서 등록 확인
- ✅ google-services.json 최신 버전 확인

### Authentication → Templates
- ✅ 비밀번호 재설정 템플릿 활성화 확인
- ✅ 발신자 이메일 설정 확인

## 프로덕션 배포 시 필수사항

### 1. Release 키스토어 SHA 등록
```bash
keytool -list -v -keystore android/release-key.jks -alias release
```

### 2. reCAPTCHA Enterprise 활성화
- Firebase Console → Authentication → Sign-in method
- Advanced → Manage bot protection
- reCAPTCHA Enterprise 활성화

### 3. App Check 활성화
- Firebase Console → App Check
- Play Integrity provider 사용
- 모든 서비스에 적용

## 빠른 해결 (개발 환경)

가장 빠른 해결 방법:

1. **SHA-1 인증서 등록** (5분)
   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```
   → Firebase Console에 복사/붙여넣기

2. **앱 재시작**
   ```bash
   flutter run
   ```

3. **비밀번호 재설정 재시도**

4. **로그 확인**
   - "empty reCAPTCHA token" 경고 사라짐 확인

## 문제 지속 시

### Firebase Console → Authentication → Templates
- "비밀번호 재설정" 템플릿 클릭
- "보낸 편지함" 또는 "Email delivery" 탭 확인
- 발송 실패 원인 확인 가능

### Firebase Support
- Firebase Console → ⚙️ → Support
- 티켓 생성: "Password reset emails not being sent"
- 프로젝트 ID: makecallio
- 로그 첨부
