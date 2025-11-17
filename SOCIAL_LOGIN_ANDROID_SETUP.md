# 소셜 로그인 Android 설정 가이드

이 문서는 MAKECALL 앱에서 4가지 소셜 로그인 (구글, 카카오, 네이버, 애플)을 Android 플랫폼에서 설정하는 방법을 안내합니다.

**참고**: 애플 로그인은 iOS 전용이므로 Android 설정이 필요 없습니다.

---

## 📋 목차

1. [구글 로그인 (Google Sign-In)](#1-구글-로그인-google-sign-in)
2. [카카오 로그인 (Kakao)](#2-카카오-로그인-kakao)
3. [네이버 로그인 (Naver)](#3-네이버-로그인-naver)
4. [AndroidManifest.xml 최종 확인](#4-androidmanifestxml-최종-확인)
5. [테스트 방법](#5-테스트-방법)

---

## 1. 구글 로그인 (Google Sign-In)

### 1.1 Firebase Console 설정

**단계 1**: Firebase Console 접속
- https://console.firebase.google.com/ 에서 프로젝트 선택

**단계 2**: Android 앱 추가/확인
- **Project Overview** → **프로젝트 설정** → **Android 앱**
- 패키지 이름: `com.makecall.app` (확인 필수)
- SHA-1 인증서 지문 등록 (필수):

```bash
# Debug SHA-1 생성
cd android
./gradlew signingReport

# 출력된 SHA-1 지문을 Firebase Console에 등록:
# Variant: debug
# Config: debug
# Store: ~/.android/debug.keystore
# Alias: androiddebugkey
# SHA-1: AA:BB:CC:DD:... (이 값을 복사)
```

**단계 3**: `google-services.json` 다운로드
- Firebase Console에서 최신 `google-services.json` 다운로드
- `android/app/google-services.json`에 배치

**단계 4**: OAuth 2.0 클라이언트 ID 확인
- **Google Cloud Console** → https://console.cloud.google.com/
- **API 및 서비스** → **사용자 인증 정보**
- **OAuth 2.0 클라이언트 ID** 확인:
  - Android 클라이언트 ID가 있어야 함
  - 패키지 이름: `com.makecall.app`
  - SHA-1 지문이 등록되어 있어야 함

### 1.2 Android 프로젝트 설정

**파일**: `android/app/build.gradle.kts`

```kotlin
dependencies {
    // ... 기존 dependencies

    // Google Play Services (구글 로그인 필수)
    implementation("com.google.android.gms:play-services-auth:21.2.0")
}
```

**확인 사항**:
- `google-services` 플러그인이 적용되어 있는지 확인
- Firebase SDK 버전이 호환되는지 확인

### 1.3 동작 테스트

```dart
// lib/services/social_login_service.dart에서 이미 구현됨
final result = await _socialLoginService.signInWithGoogle();
```

---

## 2. 카카오 로그인 (Kakao)

### 2.1 Kakao Developers Console 설정

**단계 1**: Kakao Developers 접속
- https://developers.kakao.com/ 에서 애플리케이션 생성

**단계 2**: 플랫폼 등록
- **내 애플리케이션** → 앱 선택 → **플랫폼**
- **Android 플랫폼 등록** 클릭
- 패키지 이름: `com.makecall.app`
- 키 해시 등록:

```bash
# Debug 키 해시 생성
keytool -exportcert -alias androiddebugkey -keystore ~/.android/debug.keystore | openssl sha1 -binary | openssl base64

# 비밀번호: android
# 출력된 Base64 해시를 Kakao Console에 등록
```

**단계 3**: 카카오 로그인 활성화
- **제품 설정** → **카카오 로그인** → **활성화 설정**
- 카카오 로그인 활성화: ON
- OpenID Connect 활성화: OFF (선택)

**단계 4**: 앱 키 확인
- **앱 설정** → **앱 키**
- **네이티브 앱 키** 복사 (예: `1234567890abcdef1234567890abcdef`)

### 2.2 Android 프로젝트 설정

**파일 1**: `android/app/src/main/AndroidManifest.xml`

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:name="${applicationName}"
        android:label="MAKECALL"
        android:icon="@mipmap/app_icon">
        
        <!-- 카카오 로그인 리다이렉트 Activity -->
        <activity
            android:name="com.kakao.sdk.flutter.AuthCodeCustomTabsActivity"
            android:exported="true">
            <intent-filter android:label="flutter_web_auth">
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                
                <!-- kakao${KAKAO_NATIVE_APP_KEY}://oauth -->
                <data
                    android:scheme="kakao1234567890abcdef1234567890abcdef"
                    android:host="oauth" />
            </intent-filter>
        </activity>
        
        <!-- 기존 MainActivity 등 -->
        <activity ...>
        </activity>
    </application>
    
    <!-- 카카오 SDK 쿼리 설정 (Android 11+) -->
    <queries>
        <package android:name="com.kakao.talk" />
        <package android:name="com.kakao.story" />
    </queries>
</manifest>
```

**⚠️ CRITICAL**: `android:scheme`에서 `kakao` 뒤에 **실제 네이티브 앱 키**를 붙여야 합니다!

**파일 2**: `android/app/src/main/res/values/strings.xml` (생성 필요)

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- 카카오 Native App Key -->
    <string name="kakao_app_key">1234567890abcdef1234567890abcdef</string>
</resources>
```

**파일 3**: `lib/main.dart` (이미 수정 완료)

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase 초기화
  await Firebase.initializeApp(...);
  
  // 카카오 SDK 초기화
  KakaoSdk.init(
    nativeAppKey: 'YOUR_KAKAO_NATIVE_APP_KEY', // TODO: 실제 키로 교체
    javaScriptAppKey: 'YOUR_KAKAO_JAVASCRIPT_KEY', // Web용 (선택사항)
  );
  
  runApp(const MyApp());
}
```

### 2.3 백엔드 Custom Token 생성 (필수)

카카오는 Firebase Authentication과 직접 통합되지 않으므로, 백엔드에서 Custom Token을 생성해야 합니다.

**Firebase Functions 예시**:

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');

exports.createCustomTokenForKakao = functions.https.onCall(async (data, context) => {
  const { kakaoUid, email, displayName } = data;
  
  // 카카오 UID를 Firebase UID로 변환 (prefix 추가)
  const firebaseUid = `kakao_${kakaoUid}`;
  
  try {
    // Firebase Custom Token 생성
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

**Flutter 클라이언트 호출**:

```dart
// lib/services/social_login_service.dart에서 TODO 구현 필요
final functions = FirebaseFunctions.instance;
final result = await functions.httpsCallable('createCustomTokenForKakao').call({
  'kakaoUid': user.id.toString(),
  'email': user.kakaoAccount?.email,
  'displayName': user.kakaoAccount?.profile?.nickname,
});

final customToken = result.data['customToken'];
await FirebaseAuth.instance.signInWithCustomToken(customToken);
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

**단계 3**: 환경 추가 - Android
- **서비스 환경** → **Android 앱 추가**
- **패키지 이름**: `com.makecall.app`
- **Download URL**: 앱 스토어 URL (배포 후 설정)

**단계 4**: Client ID / Client Secret 확인
- **애플리케이션 정보** → **Client ID** 복사
- **애플리케이션 정보** → **Client Secret** 복사

### 3.2 Android 프로젝트 설정

**파일 1**: `android/app/src/main/res/values/strings.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- 카카오 Native App Key -->
    <string name="kakao_app_key">1234567890abcdef1234567890abcdef</string>
    
    <!-- 네이버 로그인 -->
    <string name="naver_client_id">YOUR_NAVER_CLIENT_ID</string>
    <string name="naver_client_secret">YOUR_NAVER_CLIENT_SECRET</string>
    <string name="naver_client_name">MAKECALL</string>
</resources>
```

**파일 2**: `android/app/build.gradle.kts`

```kotlin
android {
    defaultConfig {
        // 네이버 로그인 리소스 읽기
        resValue("string", "naver_client_id", project.findProperty("NAVER_CLIENT_ID") ?: "")
        resValue("string", "naver_client_secret", project.findProperty("NAVER_CLIENT_SECRET") ?: "")
    }
}
```

### 3.3 백엔드 Custom Token 생성 (필수)

네이버도 Firebase와 직접 통합되지 않으므로 Custom Token 방식 사용:

**Firebase Functions 예시**:

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

## 4. AndroidManifest.xml 최종 확인

**완성된 AndroidManifest.xml 구조**:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- 인터넷 권한 (필수) -->
    <uses-permission android:name="android.permission.INTERNET"/>
    
    <application
        android:name="${applicationName}"
        android:label="MAKECALL"
        android:icon="@mipmap/app_icon"
        android:usesCleartextTraffic="true">
        
        <!-- 카카오 로그인 리다이렉트 Activity -->
        <activity
            android:name="com.kakao.sdk.flutter.AuthCodeCustomTabsActivity"
            android:exported="true">
            <intent-filter android:label="flutter_web_auth">
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                
                <!-- 실제 카카오 앱 키로 교체 필요 -->
                <data
                    android:scheme="kakao1234567890abcdef1234567890abcdef"
                    android:host="oauth" />
            </intent-filter>
        </activity>
        
        <!-- MainActivity -->
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            
            <!-- Deep linking 등 기존 intent-filter -->
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        
        <!-- FCM 등 기타 설정 -->
    </application>
    
    <!-- 카카오 SDK 쿼리 설정 (Android 11+) -->
    <queries>
        <package android:name="com.kakao.talk" />
        <package android:name="com.kakao.story" />
    </queries>
</manifest>
```

---

## 5. 테스트 방법

### 5.1 로컬 테스트 (Debug 빌드)

```bash
# Flutter 앱 실행
cd /home/user/flutter_app
flutter run --debug

# 또는 APK 빌드 후 설치
flutter build apk --debug
adb install build/app/outputs/flutter-apk/app-debug.apk
```

### 5.2 로그인 테스트 체크리스트

**구글 로그인**:
- [ ] 구글 계정 선택 화면 표시
- [ ] 로그인 성공 후 홈 화면 이동
- [ ] Firebase Authentication에 사용자 등록 확인

**카카오 로그인**:
- [ ] 카카오톡 앱이 설치되어 있으면 카카오톡으로 로그인
- [ ] 카카오톡이 없으면 웹뷰로 로그인
- [ ] 백엔드 Custom Token 생성 성공
- [ ] Firebase Authentication 로그인 성공

**네이버 로그인**:
- [ ] 네이버 로그인 웹뷰 표시
- [ ] 로그인 성공 후 프로필 정보 가져오기
- [ ] 백엔드 Custom Token 생성 성공
- [ ] Firebase Authentication 로그인 성공

### 5.3 디버깅 팁

**로그 확인**:
```bash
# Flutter 로그
flutter logs

# Android 로그
adb logcat | grep -E "Kakao|Naver|Google|Firebase"
```

**일반적인 오류**:

1. **카카오 로그인 실패: "Invalid redirect URI"**
   - `AndroidManifest.xml`의 `android:scheme` 확인
   - Kakao Console의 앱 키와 일치하는지 확인

2. **구글 로그인 실패: "Developer Error"**
   - SHA-1 지문이 Firebase Console에 등록되었는지 확인
   - OAuth 2.0 클라이언트 ID가 생성되었는지 확인

3. **네이버 로그인 실패: "Client ID not found"**
   - `strings.xml`의 Client ID/Secret 확인
   - Naver Console에서 Android 패키지 이름 확인

---

## 📚 참고 자료

- **Firebase Authentication**: https://firebase.google.com/docs/auth/android/start
- **Google Sign-In**: https://developers.google.com/identity/sign-in/android/start
- **Kakao SDK**: https://developers.kakao.com/docs/latest/ko/kakaologin/android
- **Naver Login**: https://developers.naver.com/docs/login/android/android.md

---

## ✅ 완료 체크리스트

프로덕션 배포 전 아래 항목들을 모두 확인하세요:

### 구글 로그인
- [ ] Firebase Console에 Android 앱 등록
- [ ] SHA-1 인증서 지문 등록 (Debug + Release)
- [ ] `google-services.json` 최신 버전 배치
- [ ] OAuth 2.0 클라이언트 ID 생성 확인

### 카카오 로그인
- [ ] Kakao Developers에 Android 플랫폼 등록
- [ ] 키 해시 등록 (Debug + Release)
- [ ] 카카오 로그인 활성화
- [ ] `AndroidManifest.xml`에 Redirect Activity 추가
- [ ] `strings.xml`에 Native App Key 설정
- [ ] 백엔드 Custom Token 생성 엔드포인트 구현

### 네이버 로그인
- [ ] Naver Developers에 애플리케이션 등록
- [ ] Android 서비스 환경 추가
- [ ] `strings.xml`에 Client ID/Secret 설정
- [ ] 백엔드 Custom Token 생성 엔드포인트 구현

### 공통
- [ ] `AndroidManifest.xml` 최종 검토
- [ ] 모든 소셜 로그인 플로우 테스트 완료
- [ ] 에러 처리 및 사용자 피드백 확인
- [ ] Firebase Console에서 사용자 인증 확인

---

**문서 버전**: 1.0  
**최종 업데이트**: 2025-01-29  
**작성자**: MAKECALL Development Team
