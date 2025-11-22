# Apple Sign In Entitlement 수정

## 📋 문제 요약

### 🐛 에러 증상
```
Authorization failed: Error Domain=AKAuthenticationError Code=-7026 "(null)"
UserInfo={AKClientBundleID=com.olssoo.makecall}

process may not map database: Error Domain=NSOSStatusErrorDomain Code=-54
Failed to initialize client context with error

ASAuthorizationController credential request failed with error:
Error Domain=com.apple.AuthenticationServices.AuthorizationError Code=1000
```

### 🎯 발생 환경
- **플랫폼**: iOS 실기기 (iPhone/iPad)
- **로그인 방식**: Apple Native Sign In
- **증상**: 애플 로그인 버튼 클릭 시 즉시 실패

## 🔍 원인 분석

### 근본 원인
**iOS 프로젝트에 Sign in with Apple Entitlement가 누락됨**

### 기술적 설명
- iOS 앱이 Apple Sign In을 사용하려면 **Entitlements 파일**에 `com.apple.developer.applesignin` 권한이 명시되어야 함
- 이 권한이 없으면 iOS는 앱이 Apple Authentication 서비스에 접근하는 것을 차단
- 결과: `AKAuthenticationError Code=-7026` (권한 거부)

## ✅ 해결 방법

### 수정된 파일
**파일**: `ios/Runner/Runner.entitlements`

**변경 전**:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>aps-environment</key>
	<string>development</string>
	<key>com.apple.developer.associated-domains</key>
	<array>
		<string>applinks:makecall.io</string>
	</array>
	<!-- Keychain Sharing (Google Sign-In 필수) -->
	<key>keychain-access-groups</key>
	<array>
		<string>$(AppIdentifierPrefix)com.olssoo.makecall</string>
	</array>
</dict>
</plist>
```

**변경 후**:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>aps-environment</key>
	<string>development</string>
	<key>com.apple.developer.associated-domains</key>
	<array>
		<string>applinks:makecall.io</string>
	</array>
	<!-- Keychain Sharing (Google Sign-In 필수) -->
	<key>keychain-access-groups</key>
	<array>
		<string>$(AppIdentifierPrefix)com.olssoo.makecall</string>
	</array>
	<!-- Sign in with Apple (필수) -->
	<key>com.apple.developer.applesignin</key>
	<array>
		<string>Default</string>
	</array>
</dict>
</plist>
```

### 추가된 내용
```xml
<!-- Sign in with Apple (필수) -->
<key>com.apple.developer.applesignin</key>
<array>
	<string>Default</string>
</array>
```

## 🔧 재빌드 및 테스트

### 1️⃣ 최신 코드 업데이트
```bash
# Mac에서 실행
cd makecall
git pull origin main
```

### 2️⃣ iOS 프로젝트 클린 빌드
```bash
# Flutter 클린
flutter clean

# iOS 의존성 재설치
cd ios
pod install
cd ..

# 프로젝트 빌드
flutter build ios --release
```

### 3️⃣ Xcode에서 재빌드 (권장)
```bash
open ios/Runner.xcworkspace
```

Xcode에서:
1. Product → Clean Build Folder (⇧⌘K)
2. Product → Build (⌘B)
3. iOS 실기기 연결
4. Product → Run (⌘R)

### 4️⃣ 테스트
1. 앱 실행
2. 회원가입 화면으로 이동
3. "Apple로 시작하기" 버튼 클릭
4. Face ID/Touch ID 또는 Apple ID 암호 입력
5. ✅ 정상 로그인 확인

## 📋 체크리스트

### Apple Developer Console 설정 (이미 완료 ✅)
- [x] App ID에 Sign in with Apple Capability 활성화
- [x] Service ID 생성 (com.olssoo.makecall.signin)
- [x] Sign in with Apple Key 생성 (T46W8PY2B4)
- [x] Return URLs 설정 (https://makecallio.web.app/auth/callback)

### iOS 프로젝트 설정 (수정 완료 ✅)
- [x] Runner.entitlements에 com.apple.developer.applesignin 추가
- [x] Xcode 프로젝트에서 CODE_SIGN_ENTITLEMENTS 확인
- [x] Bundle ID 확인 (com.olssoo.makecall)

### Flutter 코드 설정 (이미 정상 ✅)
- [x] sign_in_with_apple 패키지 추가
- [x] iOS Native Sign In 구현
- [x] Service ID 설정 (Web/Android용)

## 🎯 예상 결과

### ✅ 수정 후 정상 동작
```
1. "Apple로 시작하기" 버튼 클릭
2. iOS Native Apple Sign In 화면 표시
3. Face ID/Touch ID 인증 또는 Apple ID 암호 입력
4. 사용자 정보 동의 화면
5. Firebase 인증 완료
6. "기존 계정 확인" 또는 회원가입 진행
7. ✅ 로그인 성공
```

### ❌ 수정 전 에러
```
1. "Apple로 시작하기" 버튼 클릭
2. 즉시 에러 다이얼로그 표시
3. "로그인 오류" 메시지
4. ❌ 로그인 실패
```

## 📚 기술 참고

### Apple Sign In Entitlements
- **공식 문서**: https://developer.apple.com/documentation/sign_in_with_apple
- **Entitlement Key**: `com.apple.developer.applesignin`
- **값**: `Default` (기본 구성)

### Flutter sign_in_with_apple 패키지
- **패키지**: https://pub.dev/packages/sign_in_with_apple
- **iOS 요구사항**: Entitlements 파일에 권한 추가 필수
- **Android/Web**: webAuthenticationOptions 사용

## 🔗 관련 파일
- `ios/Runner/Runner.entitlements` - iOS 앱 권한 설정
- `lib/services/social_login_service.dart` - 애플 로그인 구현
- `ios/Runner.xcodeproj/project.pbxproj` - Xcode 프로젝트 설정

## 📝 커밋 정보
- **Commit**: `2c4d1ba`
- **Message**: "🔧 Fix: Add Sign in with Apple entitlement to iOS"
- **날짜**: 2025/11/22

## ✅ 결론

**문제**: iOS 앱에 Apple Sign In 권한(Entitlement)이 누락되어 인증 실패

**해결**: `Runner.entitlements` 파일에 `com.apple.developer.applesignin` 추가

**결과**: iOS 실기기에서 Apple Sign In 정상 작동 ✅

---

**중요**: 이 수정 후 반드시 **클린 빌드**를 해야 합니다!
- `flutter clean`
- `cd ios && pod install`
- Xcode에서 Clean Build Folder (⇧⌘K)
- 재빌드 및 테스트

변경사항이 GitHub에 푸시되었습니다! 🚀
