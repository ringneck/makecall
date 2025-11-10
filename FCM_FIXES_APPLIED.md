# FCM iOS 통합 수정 완료

## 🎯 중요 업데이트 (2024-11-10)

**"No app has been configured yet" 오류의 근본 원인 2가지를 모두 해결했습니다!**

### 문제 1: Flutter 레이어
`firebase_options.dart` 파일의 iOS 설정이 **Android 값**을 사용하고 있었습니다.

### 문제 2: Native 레이어 (더 치명적!)
`Info.plist`에서 `FirebaseAppDelegateProxyEnabled = false`로 설정했지만, **AppDelegate에서 수동으로 Firebase를 초기화하지 않았습니다**. 

이로 인해 Native 레이어에서 Firebase가 전혀 초기화되지 않았고, Flutter의 Firebase 플러그인들이 작동하지 않았습니다.

## 🔴 해결된 문제들

### 1. ❌ "Could not locate configuration file: 'GoogleService-Info.plist'" 오류
**원인**: GoogleService-Info.plist 파일이 Xcode 프로젝트에 등록되지 않음

**해결**:
- GoogleService-Info.plist를 Xcode 프로젝트에 올바르게 등록
- PBXFileReference 섹션에 파일 참조 추가
- PBXBuildFile 섹션에 빌드 파일 추가
- PBXGroup (Runner) 섹션에 파일 추가
- PBXResourcesBuildPhase 섹션에 리소스로 추가

**파일 위치**:
- `ios/Runner/GoogleService-Info.plist` (871 bytes) ✅
- `ios/GoogleService-Info.plist` (871 bytes, 백업용) ✅

### 2. ❌ "유효한 'aps-environment' 인타이틀먼트 문자열을 찾을 수 없습니다" APNs 오류
**원인**: APNs Push 알림을 위한 entitlements 설정 누락

**해결**:
- `ios/Runner/Runner.entitlements` 파일 생성
- `aps-environment` 키를 `development` 값으로 설정
- Xcode 프로젝트에 entitlements 파일 등록
- 모든 빌드 구성(Debug/Release/Profile)에 `CODE_SIGN_ENTITLEMENTS` 설정 추가

**생성된 파일**: `ios/Runner/Runner.entitlements` ✅
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
</dict>
</plist>
```

### 3. ❌ "No app has been configured yet" Firebase 초기화 오류

#### 원인 1: Flutter 레이어
`firebase_options.dart`에 iOS API Key와 App ID가 잘못 설정됨 (Android 값 사용)

**해결 (Flutter)**:
- `lib/firebase_options.dart` 파일에서 iOS 설정 수정
- iOS apiKey: `AIzaSyBnZSVzdthE2oa82Vjv8Uy0Wgefx6nGAWs` (GoogleService-Info.plist와 일치)
- iOS appId: `1:793164633643:ios:1e2ec90f03abf1abccfc6e` (올바른 iOS App ID)
- macOS 설정도 동일하게 수정 ✅

**수정 전 (잘못된 값)**:
```dart
static const FirebaseOptions ios = FirebaseOptions(
  apiKey: 'AIzaSyCB4mI5Kj61f6E532vg46GnmnnCfsI9XIM',  // ❌ Android 키
  appId: '1:793164633643:ios:c2f267d67b908274ccfc6e',  // ❌ 잘못된 ID
  ...
);
```

**수정 후 (올바른 값)**:
```dart
static const FirebaseOptions ios = FirebaseOptions(
  apiKey: 'AIzaSyBnZSVzdthE2oa82Vjv8Uy0Wgefx6nGAWs',  // ✅ iOS 키
  appId: '1:793164633643:ios:1e2ec90f03abf1abccfc6e',  // ✅ 올바른 iOS ID
  ...
);
```

#### 원인 2: Native 레이어 (더 치명적!)
`Info.plist`에서 `FirebaseAppDelegateProxyEnabled = false`로 설정했지만, **AppDelegate에서 Firebase를 수동으로 초기화하지 않음**

**해결 (Native)**:
- `ios/Runner/AppDelegate.swift`에 Firebase 수동 초기화 추가
- `FirebaseCore` 모듈 import
- `didFinishLaunchingWithOptions`에서 `FirebaseApp.configure()` 호출
- `Messaging.messaging().delegate = self` 설정

**추가된 코드**:
```swift
import FirebaseCore  // ✅ 추가
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 🔥 Firebase 수동 초기화 (필수!)
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
      print("✅ Firebase 초기화 완료 (Native)")
    }
    
    // Firebase Messaging 델리게이트 설정
    Messaging.messaging().delegate = self
    
    // ... 나머지 코드
  }
}
```

**중요**: `FirebaseAppDelegateProxyEnabled = false`일 때는 **반드시** AppDelegate에서 수동 초기화 필요!

---

---

## 📋 변경된 파일들

### 1. `ios/Runner/AppDelegate.swift` (Native Firebase 초기화 추가)
- `import FirebaseCore` 추가
- `FirebaseApp.configure()` 호출
- `Messaging.messaging().delegate = self` 설정

### 2. `lib/firebase_options.dart` (Flutter Firebase 설정 수정)
- iOS apiKey 수정: `AIzaSyBnZSVzdthE2oa82Vjv8Uy0Wgefx6nGAWs`
- iOS appId 수정: `1:793164633643:ios:1e2ec90f03abf1abccfc6e`

### 3. `ios/Runner.xcodeproj/project.pbxproj` 수정 사항:

1. **PBXFileReference 섹션** (line 63-64):
```
97C147031CF9000F007C117E /* GoogleService-Info.plist */
97C147041CF9000F007C117F /* Runner.entitlements */
```

2. **PBXBuildFile 섹션** (line 19):
```
97C147021CF9000F007C117F /* GoogleService-Info.plist in Resources */
```

3. **PBXResourcesBuildPhase 섹션** (line 269):
```
97C147021CF9000F007C117F /* GoogleService-Info.plist in Resources */
```

4. **PBXGroup (Runner) 섹션**:
```
children = (
    ...
    97C147031CF9000F007C117E /* GoogleService-Info.plist */,
    97C147041CF9000F007C117F /* Runner.entitlements */,
    ...
)
```

5. **XCBuildConfiguration (Debug/Release/Profile)** - 3개 설정 모두:
```
CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;
```

---

## 🧪 테스트 방법

### 1. Xcode 프로젝트 열기
```bash
open ios/Runner.xcworkspace
```

### 2. 확인 사항
- ✅ Xcode가 오류 없이 열림
- ✅ Project Navigator에서 GoogleService-Info.plist 표시됨
- ✅ Project Navigator에서 Runner.entitlements 표시됨
- ✅ Build Settings → Signing → Code Signing Entitlements = Runner/Runner.entitlements

### 3. 빌드 및 실행 (실제 iOS 디바이스 필요)
```bash
# Clean build
cd ios && rm -rf build Pods && pod install && cd ..

# Run on device
flutter run --release
```

### 4. 예상 로그 (Native + Flutter)
```
✅ Firebase 초기화 완료 (Native)        ← 🆕 AppDelegate에서 출력
✅ APNs 토큰 수신: [token]
🔔 [FCM] 초기화 시작
   User ID: [userId]
   Platform: Mobile
📱 [FCM] 알림 권한 요청 중...
✅ [FCM] 알림 권한 응답: AuthorizationStatus.authorized
🔑 [FCM] 토큰 요청 시작...
🍎 [FCM] iOS: APNs 토큰 확인 중...
✅ [FCM] APNs 토큰 존재: [token]...
🔄 [FCM] getToken() 호출 중...
✅ [FCM] 토큰 생성 완료!
💾 [FCM-SAVE] 토큰 저장 시작
✅ [FCM-SAVE] Firestore 저장 완료!
✅ FCM 토큰 수신: [token]...           ← 🆕 Native 델리게이트에서 출력
```

### 5. Firebase Console 확인
1. Firebase Console → Firestore Database
2. `fcm_tokens` 컬렉션 확인
3. 사용자 디바이스의 FCM 토큰 문서 확인

---

## 🚨 주의사항

### Production 빌드 시
`Runner.entitlements` 파일의 `aps-environment` 값을 변경해야 합니다:

```xml
<!-- Development (TestFlight, 개발 중) -->
<key>aps-environment</key>
<string>development</string>

<!-- Production (App Store 릴리스) -->
<key>aps-environment</key>
<string>production</string>
```

또는 Xcode에서 자동 관리:
1. Xcode → Runner target → Signing & Capabilities
2. "+ Capability" 클릭
3. "Push Notifications" 추가
4. 자동으로 aps-environment가 관리됨

### Apple Developer 계정 설정
실제 디바이스에서 테스트하려면:
1. Apple Developer 계정 필요 (유료 또는 무료)
2. Xcode → Signing & Capabilities → Team 선택
3. Bundle Identifier: `com.olssoo.makecall`
4. Provisioning Profile 자동 생성됨

---

## 📊 Git 커밋 히스토리

```
16dcc0d - CRITICAL FIX: Add Firebase manual initialization in AppDelegate (가장 중요!)
f27933e - docs: Update FCM fixes with firebase_options.dart correction details
224729b - CRITICAL FIX: Correct iOS Firebase configuration (API key and App ID)
0be6d23 - docs: Add FCM iOS integration fixes documentation
015c25b - Fix: Add GoogleService-Info.plist and APNs entitlements to Xcode project
9a5132c - CRITICAL FIX: Restore corrupted Xcode project.pbxproj
```

---

## ✅ 완료 체크리스트

- [x] GoogleService-Info.plist Xcode 프로젝트 등록
- [x] Runner.entitlements 생성 및 등록
- [x] CODE_SIGN_ENTITLEMENTS 설정 추가 (Debug/Release/Profile)
- [x] firebase_options.dart iOS 설정 수정 (올바른 API Key와 App ID)
- [x] **AppDelegate.swift Firebase 수동 초기화 추가 (가장 중요!)** 🔥
- [x] Git 커밋 및 GitHub 푸시
- [x] 문서 작성

---

## 📝 다음 단계

1. **Xcode 열기**: `open ios/Runner.xcworkspace`
2. **실제 iOS 디바이스 연결**
3. **Team 선택** (Signing & Capabilities)
4. **앱 빌드 및 실행**
5. **로그 확인** (FCM 초기화 및 토큰 생성)
6. **Firebase Console 확인** (fcm_tokens 컬렉션)

문제가 발생하면 콘솔 로그를 공유해주세요! 🚀
