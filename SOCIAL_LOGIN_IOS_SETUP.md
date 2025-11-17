# 소셜 로그인 iOS 설정 가이드

이 문서는 MAKECALL 앱에서 4가지 소셜 로그인 (구글, 카카오, 네이버, 애플)을 iOS 플랫폼에서 설정하는 방법을 안내합니다.

**🎯 구현 상태**: `ios/Runner/Info.plist`에 URL Schemes 및 LSApplicationQueriesSchemes 설정 완료  
**📦 Bundle ID**: `com.olssoo.makecall` (⚠️ 문서의 `com.makecall.app`과 다름 - 실제 Bundle ID 기준으로 설정됨)

---

## 🚀 빠른 확인 (Quick Check)

`ios/Runner/Info.plist` 파일에 다음 설정이 완료되어 있습니다:

**✅ CFBundleURLTypes (URL Schemes)**:
- 🔵 **Google Sign-In**: `com.googleusercontent.apps.793164633643-urj0qb989v8l2bggj6h025plnbbshfg5`
- 🟡 **Kakao Login**: `kakao737f26c4d0d81077b35b8f0313ec3536`
- 🟢 **Naver Login**: `naverWl4fP6XbiTRQQMpbC5a9`

**✅ LSApplicationQueriesSchemes (앱 전환)**:
- 카카오톡: `kakaokompassauth`, `kakaolink`, `kakao737f26c4d0d81077b35b8f0313ec3536`
- 네이버: `naversearchapp`, `naversearchthirdlogin`, `navercafe`

**다음 단계**:
1. ✅ Info.plist URL Schemes 설정 완료
2. 🔄 각 소셜 로그인 플랫폼에서 iOS 앱 등록 필요 (아래 섹션 참조)
3. 🔄 실제 기기/시뮬레이터에서 소셜 로그인 테스트

---

## 📋 목차

1. [구글 로그인 (Google Sign-In)](#1-구글-로그인-google-sign-in)
2. [카카오 로그인 (Kakao)](#2-카카오-로그인-kakao)
3. [네이버 로그인 (Naver)](#3-네이버-로그인-naver)
4. [애플 로그인 (Sign in with Apple)](#4-애플-로그인-sign-in-with-apple)
5. [Info.plist 최종 확인](#5-infoplist-최종-확인)
6. [테스트 방법](#6-테스트-방법)

---

## 1. 구글 로그인 (Google Sign-In)

### 1.1 Firebase Console 설정

**단계 1**: Firebase Console 접속
- https://console.firebase.google.com/ 에서 프로젝트 선택

**단계 2**: iOS 앱 추가/확인
- **Project Overview** → **프로젝트 설정** → **iOS 앱**
- Bundle ID: `com.olssoo.makecall` (⚠️ 실제 프로젝트 Bundle ID)
- App Store ID: (선택사항, 배포 후 입력)

**단계 3**: `GoogleService-Info.plist` 다운로드
- Firebase Console에서 최신 `GoogleService-Info.plist` 다운로드
- Xcode에서 `ios/Runner/GoogleService-Info.plist`에 추가
  - Xcode에서 **Runner** 프로젝트 선택
  - **File** → **Add Files to "Runner"**
  - `GoogleService-Info.plist` 선택
  - **"Copy items if needed"** 체크
  - **"Add to targets: Runner"** 체크

**단계 4**: OAuth 2.0 클라이언트 ID 확인
- **Google Cloud Console** → https://console.cloud.google.com/
- **API 및 서비스** → **사용자 인증 정보**
- **iOS OAuth 클라이언트 ID** 확인:
  - Bundle ID: `com.olssoo.makecall` (⚠️ 실제 Bundle ID)
  - iOS URL Scheme 자동 생성됨: `com.googleusercontent.apps.793164633643-urj0qb989v8l2bggj6h025plnbbshfg5`

### 1.2 Xcode 프로젝트 설정

**파일**: `ios/Runner/Info.plist`

```xml
<dict>
    <!-- 기존 설정 ... -->
    
    <!-- 구글 로그인 URL Scheme -->
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <!-- GoogleService-Info.plist의 REVERSED_CLIENT_ID 값 -->
                <string>com.googleusercontent.apps.1234567890-abcdefghijklmnopqrstuvwxyz</string>
            </array>
        </dict>
    </array>
</dict>
```

**⚠️ CRITICAL**: `REVERSED_CLIENT_ID` 값은 `GoogleService-Info.plist`에서 확인하세요!

**Podfile 확인**:

`ios/Podfile`에 Google Sign-In pod이 자동으로 추가됩니다:

```ruby
# ios/Podfile
target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
  
  # Google Sign-In은 Flutter 패키지에서 자동 추가됨
end
```

**Pod 설치**:

```bash
cd ios
pod install
```

---

## 2. 카카오 로그인 (Kakao)

### 2.1 Kakao Developers Console 설정

**단계 1**: Kakao Developers 접속
- https://developers.kakao.com/ 에서 애플리케이션 생성

**단계 2**: 플랫폼 등록
- **내 애플리케이션** → 앱 선택 → **플랫폼**
- **iOS 플랫폼 등록** 클릭
- Bundle ID: `com.olssoo.makecall` (⚠️ 실제 Bundle ID)
- 팀 ID: Apple Developer 계정의 Team ID (10자리 영문/숫자)

**단계 3**: 카카오 로그인 활성화
- **제품 설정** → **카카오 로그인** → **활성화 설정**
- 카카오 로그인 활성화: ON
- OpenID Connect 활성화: OFF (선택)

**단계 4**: 앱 키 확인
- **앱 설정** → **앱 키**
- **네이티브 앱 키** 복사: `737f26c4d0d81077b35b8f0313ec3536` (✅ 실제 적용된 키)

### 2.2 Xcode 프로젝트 설정

**파일**: `ios/Runner/Info.plist`

```xml
<dict>
    <!-- 기존 설정 ... -->
    
    <!-- ✅ 카카오 URL Scheme (Info.plist에 이미 설정됨) -->
    <key>CFBundleURLTypes</key>
    <array>
        <!-- 구글 로그인 URL Scheme -->
        <dict>...</dict>
        
        <!-- 🟡 카카오 로그인 URL Scheme -->
        <dict>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <!-- ✅ 실제 적용된 값: kakao + 737f26c4d0d81077b35b8f0313ec3536 -->
                <string>kakao737f26c4d0d81077b35b8f0313ec3536</string>
            </array>
        </dict>
    </array>
    
    <!-- ✅ 카카오톡 앱 연동 (Info.plist에 이미 설정됨) -->
    <key>LSApplicationQueriesSchemes</key>
    <array>
        <string>kakaokompassauth</string>
        <string>kakaolink</string>
        <string>kakao737f26c4d0d81077b35b8f0313ec3536</string>
    </array>
</dict>
```

**✅ 설정 완료**: 위 설정은 이미 `ios/Runner/Info.plist`에 적용되어 있습니다.

### 2.3 AppDelegate 설정 (선택사항)

카카오 SDK가 자동으로 URL Scheme 처리를 하므로, 추가 코드는 필요하지 않습니다.

### 2.4 백엔드 Custom Token 생성 (필수)

카카오는 Firebase Authentication과 직접 통합되지 않으므로, 백엔드에서 Custom Token을 생성해야 합니다.

**Firebase Functions 예시** (Android 설정 가이드와 동일):

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');

exports.createCustomTokenForKakao = functions.https.onCall(async (data, context) => {
  const { kakaoUid, email, displayName } = data;
  
  const firebaseUid = `kakao_${kakaoUid}`;
  
  try {
    const customToken = await admin.auth().createCustomToken(firebaseUid, {
      provider: 'kakao',
      email: email,
      name: displayName,
    });
    
    return { customToken };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});
```

---

## 3. 네이버 로그인 (Naver)

### 3.1 Naver Developers Console 설정

**단계 1**: 네이버 개발자 센터 접속
- https://developers.naver.com/apps/#/register 에서 애플리케이션 등록

**단계 2**: API 설정
- **애플리케이션 이름**: MAKECALL
- **사용 API**: 네아로 (네이버 아이디로 로그인)
- **제공 정보**: 이메일, 닉네임, 프로필 이미지

**단계 3**: 환경 추가 - iOS
- **서비스 환경** → **iOS 앱 추가**
- **URL Scheme**: `naverWl4fP6XbiTRQQMpbC5a9` (✅ Client ID 기반으로 설정됨)
- **Bundle ID**: `com.olssoo.makecall` (⚠️ 실제 Bundle ID)

**단계 4**: Client ID / Client Secret 확인
- **애플리케이션 정보** → **Client ID**: `Wl4fP6XbiTRQQMpbC5a9` (✅ 실제 적용된 값)
- **애플리케이션 정보** → **Client Secret**: `gr2MvANyr8` (✅ 실제 적용된 값)

### 3.2 Xcode 프로젝트 설정

**파일**: `ios/Runner/Info.plist`

```xml
<dict>
    <!-- 기존 설정 ... -->
    
    <!-- ⚠️ 네이버 SDK Info.plist 설정 (필요 시 추가) -->
    <!-- flutter_naver_login 2.1.1은 Info.plist 키 불필요, main.dart에서 초기화 -->
    
    <!-- ✅ 네이버 URL Scheme (Info.plist에 이미 설정됨) -->
    <key>CFBundleURLTypes</key>
    <array>
        <!-- 구글, 카카오 등 기존 URL Schemes ... -->
        
        <!-- 🟢 네이버 로그인 URL Scheme -->
        <dict>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <!-- ✅ 실제 적용된 값: naver + Client ID -->
                <string>naverWl4fP6XbiTRQQMpbC5a9</string>
            </array>
        </dict>
    </array>
    
    <!-- ✅ 네이버 앱 연동 (Info.plist에 이미 설정됨) -->
    <key>LSApplicationQueriesSchemes</key>
    <array>
        <!-- 카카오 schemes ... -->
        <string>naversearchapp</string>
        <string>naversearchthirdlogin</string>
        <string>navercafe</string>
    </array>
</dict>
```

**✅ 설정 완료**: 위 설정은 이미 `ios/Runner/Info.plist`에 적용되어 있습니다.

**📝 참고**: `flutter_naver_login` 2.1.1 버전은 `NaverConsumerKey`, `NaverConsumerSecret` 등의 Info.plist 키를 사용하지 않습니다. 대신 `lib/main.dart`에서 직접 초기화합니다.

### 3.3 백엔드 Custom Token 생성 (필수)

네이버도 Firebase와 직접 통합되지 않으므로 Custom Token 방식 사용:

```javascript
exports.createCustomTokenForNaver = functions.https.onCall(async (data, context) => {
  const { naverId, email, nickname } = data;
  
  const firebaseUid = `naver_${naverId}`;
  
  try {
    const customToken = await admin.auth().createCustomToken(firebaseUid, {
      provider: 'naver',
      email: email,
      name: nickname,
    });
    
    return { customToken };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});
```

---

## 4. 애플 로그인 (Sign in with Apple)

### 4.1 Apple Developer 설정

**단계 1**: Apple Developer 계정
- https://developer.apple.com/account/ 접속
- Apple Developer Program 가입 필요 (연간 $99)

**단계 2**: App ID 설정
- **Certificates, Identifiers & Profiles** → **Identifiers**
- App ID 선택: `com.makecall.app`
- **Capabilities** → **Sign in with Apple** 활성화

**단계 3**: 서비스 ID 생성 (Web Auth용, 선택사항)
- **Identifiers** → **+** → **Services IDs**
- Description: MAKECALL Web
- Identifier: `com.makecall.app.web`

### 4.2 Firebase Console 설정

**단계 1**: Firebase Console 접속
- https://console.firebase.google.com/ → 프로젝트 선택

**단계 2**: Apple 로그인 제공업체 활성화
- **Authentication** → **Sign-in method**
- **Apple** 제공업체 클릭 → **사용 설정**
- 서비스 ID (선택사항): `com.makecall.app.web`

### 4.3 Xcode 프로젝트 설정

**단계 1**: Signing & Capabilities 설정

Xcode에서:
1. **Runner** 프로젝트 선택
2. **Signing & Capabilities** 탭
3. **+ Capability** 클릭
4. **Sign in with Apple** 추가

**단계 2**: Entitlements 자동 생성 확인

`ios/Runner/Runner.entitlements` 파일이 자동 생성됩니다:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.applesignin</key>
    <array>
        <string>Default</string>
    </array>
</dict>
</plist>
```

### 4.4 Flutter 구현 (이미 완료)

`lib/services/social_login_service.dart`에 애플 로그인이 이미 구현되어 있습니다:

```dart
Future<SocialLoginResult> signInWithApple() async {
  // iOS 플랫폼에서만 동작
  final appleCredential = await SignInWithApple.getAppleIDCredential(...);
  final oauthCredential = OAuthProvider("apple.com").credential(...);
  final userCredential = await FirebaseAuth.instance.signInWithCredential(oauthCredential);
  // ...
}
```

---

## 5. Info.plist 최종 확인

**완성된 Info.plist 구조**:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- 기본 앱 정보 -->
    <key>CFBundleDisplayName</key>
    <string>MAKECALL</string>
    
    <key>CFBundleIdentifier</key>
    <string>com.makecall.app</string>
    
    <!-- URL Schemes (구글, 카카오, 네이버) -->
    <key>CFBundleURLTypes</key>
    <array>
        <!-- 구글 로그인 -->
        <dict>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>com.googleusercontent.apps.1234567890-abcdefg</string>
            </array>
        </dict>
        
        <!-- 카카오 로그인 -->
        <dict>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>kakao1234567890abcdef1234567890abcdef</string>
            </array>
        </dict>
        
        <!-- 네이버 로그인 -->
        <dict>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>naverlogin</string>
            </array>
        </dict>
    </array>
    
    <!-- 앱 연동 쿼리 (LSApplicationQueriesSchemes) -->
    <key>LSApplicationQueriesSchemes</key>
    <array>
        <!-- 카카오 -->
        <string>kakaokompassauth</string>
        <string>kakaolink</string>
        <string>kakaoplus</string>
        
        <!-- 네이버 -->
        <string>naversearchapp</string>
        <string>naversearchthirdlogin</string>
    </array>
    
    <!-- 카카오 Native App Key -->
    <key>KAKAO_APP_KEY</key>
    <string>1234567890abcdef1234567890abcdef</string>
    
    <!-- 네이버 Client 정보 -->
    <key>NaverConsumerKey</key>
    <string>YOUR_NAVER_CLIENT_ID</string>
    
    <key>NaverConsumerSecret</key>
    <string>YOUR_NAVER_CLIENT_SECRET</string>
    
    <key>NaverServiceAppName</key>
    <string>MAKECALL</string>
    
    <key>NaverServiceAppUrlScheme</key>
    <string>naverlogin</string>
    
    <!-- 기타 설정들 ... -->
</dict>
</plist>
```

---

## 6. 테스트 방법

### 6.1 시뮬레이터 테스트

```bash
# iOS 시뮬레이터 실행
cd /home/user/flutter_app
flutter run -d ios

# 또는 특정 시뮬레이터 지정
flutter run -d "iPhone 15 Pro"
```

**⚠️ 참고**: 
- **애플 로그인**은 **실제 기기**에서만 테스트 가능 (시뮬레이터 불가)
- 구글, 카카오, 네이버는 시뮬레이터에서 테스트 가능

### 6.2 실제 기기 테스트

**요구사항**:
- Apple Developer 계정
- Provisioning Profile 설정
- 실제 iOS 기기 (iPhone/iPad)

**테스트 절차**:

```bash
# 1. 기기 연결 확인
flutter devices

# 2. 실제 기기에 설치
flutter run --release -d [DEVICE_ID]

# 3. 또는 IPA 빌드
flutter build ipa
# Xcode에서 Archive → Distribute App → Development
```

### 6.3 로그인 테스트 체크리스트

**구글 로그인**:
- [ ] 구글 계정 선택 화면 표시
- [ ] 로그인 성공 후 홈 화면 이동
- [ ] Firebase Authentication에 사용자 등록 확인

**카카오 로그인**:
- [ ] 카카오톡 앱이 설치되어 있으면 카카오톡으로 로그인
- [ ] 카카오톡이 없으면 Safari 웹뷰로 로그인
- [ ] 백엔드 Custom Token 생성 성공
- [ ] Firebase Authentication 로그인 성공

**네이버 로그인**:
- [ ] 네이버 로그인 Safari 웹뷰 표시
- [ ] 로그인 성공 후 프로필 정보 가져오기
- [ ] 백엔드 Custom Token 생성 성공
- [ ] Firebase Authentication 로그인 성공

**애플 로그인** (실제 기기 필수):
- [ ] Face ID / Touch ID 인증 화면 표시
- [ ] 애플 계정 선택 (이름/이메일 공유 선택)
- [ ] Firebase Authentication 직접 로그인 성공
- [ ] 사용자 정보 정상 저장 확인

### 6.4 디버깅 팁

**Xcode 콘솔 로그**:

```bash
# Flutter 로그 확인
flutter logs

# Xcode에서 직접 실행 시 Console 확인
# Window → Devices and Simulators → Device → View Device Logs
```

**일반적인 오류**:

1. **구글 로그인 실패: "Error 10"**
   - `GoogleService-Info.plist`가 제대로 추가되지 않음
   - Bundle ID 불일치
   - URL Scheme 오류 (`REVERSED_CLIENT_ID` 확인)

2. **카카오 로그인 실패: "Invalid redirect URI"**
   - `Info.plist`의 URL Scheme 확인
   - Kakao Console의 iOS Bundle ID 확인
   - Team ID 일치 여부 확인

3. **네이버 로그인 실패: "Client authentication failed"**
   - `Info.plist`의 Client ID/Secret 확인
   - URL Scheme 설정 확인

4. **애플 로그인 실패: "Sign in with Apple not enabled"**
   - Xcode의 Signing & Capabilities 확인
   - Apple Developer에서 App ID의 Sign in with Apple 활성화 확인
   - Provisioning Profile 재생성

---

## 📚 참고 자료

- **Firebase Authentication**: https://firebase.google.com/docs/auth/ios/start
- **Google Sign-In iOS**: https://developers.google.com/identity/sign-in/ios/start
- **Kakao SDK iOS**: https://developers.kakao.com/docs/latest/ko/kakaologin/ios
- **Naver Login iOS**: https://developers.naver.com/docs/login/ios/ios.md
- **Sign in with Apple**: https://developer.apple.com/documentation/sign_in_with_apple

---

## ✅ 완료 체크리스트

프로덕션 배포 전 아래 항목들을 모두 확인하세요:

### 구글 로그인
- [ ] Firebase Console에 iOS 앱 등록
- [ ] `GoogleService-Info.plist` 최신 버전 추가
- [ ] `Info.plist`에 URL Scheme 추가 (REVERSED_CLIENT_ID)
- [ ] Pod 설치 완료

### 카카오 로그인
- [ ] Kakao Developers에 iOS 플랫폼 등록
- [ ] Bundle ID 및 Team ID 등록
- [ ] 카카오 로그인 활성화
- [ ] `Info.plist`에 KAKAO_APP_KEY 설정
- [ ] `Info.plist`에 URL Scheme 추가
- [ ] `LSApplicationQueriesSchemes`에 카카오 schemes 추가
- [ ] 백엔드 Custom Token 생성 엔드포인트 구현

### 네이버 로그인
- [ ] Naver Developers에 애플리케이션 등록
- [ ] iOS 서비스 환경 추가
- [ ] `Info.plist`에 NaverConsumerKey/Secret 설정
- [ ] `Info.plist`에 URL Scheme 추가
- [ ] `LSApplicationQueriesSchemes`에 네이버 schemes 추가
- [ ] 백엔드 Custom Token 생성 엔드포인트 구현

### 애플 로그인
- [ ] Apple Developer에서 App ID의 Sign in with Apple 활성화
- [ ] Xcode에서 Sign in with Apple Capability 추가
- [ ] Runner.entitlements 자동 생성 확인
- [ ] Firebase Console에서 Apple 로그인 제공업체 활성화

### 공통
- [ ] `Info.plist` 최종 검토
- [ ] 모든 소셜 로그인 플로우 테스트 완료 (실제 기기 필수)
- [ ] 에러 처리 및 사용자 피드백 확인
- [ ] Firebase Console에서 사용자 인증 확인

---

**문서 버전**: 1.0  
**최종 업데이트**: 2025-01-29  
**작성자**: MAKECALL Development Team
