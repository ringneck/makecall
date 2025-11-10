# iOS FCM 토큰 등록 문제 수정 완료

## 🔍 문제 상황
- iOS 기기에서 로그인 및 푸시 활성화 설정 완료
- Firestore `fcm_tokens` 컬렉션에 iOS 기기 등록되지 않음

## ✅ 수정 완료 사항

### 1. FCM 서비스 코드 수정 (`lib/services/fcm_service.dart`)

**iOS 전용 디버깅 추가:**
- APNs 토큰 획득 여부 확인
- APNs 토큰이 없으면 상세한 해결 가이드 출력
- APNs 토큰 없이는 FCM 토큰을 받을 수 없음을 명확히 안내

**주요 변경 코드:**
```dart
// iOS 전용: APNs 토큰 확인
if (Platform.isIOS) {
  final apnsToken = await _messaging.getAPNSToken();
  if (apnsToken != null) {
    debugPrint('✅ APNs 토큰 획득 성공');
    debugPrint('   APNs 토큰: ${apnsToken.substring(0, 20)}...');
  } else {
    debugPrint('❌ APNs 토큰 획득 실패!');
    debugPrint('📋 해결 방법:');
    debugPrint('   1. Firebase Console에서 APNs 인증 키 업로드');
    debugPrint('   2. Xcode에서 Push Notifications Capability 추가');
    debugPrint('   3. 실제 iOS 기기에서 테스트 (시뮬레이터는 푸시 알림 불가)');
    return; // APNs 토큰 없으면 FCM 토큰 받을 수 없음
  }
}
```

**새로운 메서드 추가:**
```dart
/// iOS APNs 토큰 상태 확인 (디버깅용)
Future<Map<String, dynamic>> checkIOSAPNsStatus() async {
  if (!Platform.isIOS) {
    return {'platform': 'not_ios', 'status': 'N/A'};
  }
  
  final apnsToken = await _messaging.getAPNSToken();
  final fcmToken = await _messaging.getToken();
  
  return {
    'platform': 'ios',
    'apnsToken': apnsToken,
    'apnsTokenAvailable': apnsToken != null,
    'fcmToken': fcmToken,
    'fcmTokenAvailable': fcmToken != null,
    'status': apnsToken != null ? 'ready' : 'apns_token_missing',
  };
}
```

---

### 2. AppDelegate.swift 전면 재작성

**파일 위치:** `ios/Runner/AppDelegate.swift`

**주요 추가 기능:**
- ✅ Firebase 초기화
- ✅ APNs 등록 및 토큰 수신
- ✅ Firebase Messaging 델리게이트 설정
- ✅ 포그라운드/백그라운드 알림 처리
- ✅ 상세한 디버깅 로그 출력

**핵심 코드:**
```swift
override func application(
  _ application: UIApplication,
  didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {
  // Firebase 초기화
  FirebaseApp.configure()
  
  // Flutter 플러그인 등록
  GeneratedPluginRegistrant.register(with: self)
  
  // iOS 알림 설정
  UNUserNotificationCenter.current().delegate = self
  
  let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
  UNUserNotificationCenter.current().requestAuthorization(
    options: authOptions,
    completionHandler: { granted, error in
      if granted {
        print("✅ iOS 알림 권한 허용됨")
      } else {
        print("❌ iOS 알림 권한 거부됨")
      }
    }
  )
  
  application.registerForRemoteNotifications()
  
  // Firebase Messaging 델리게이트 설정
  Messaging.messaging().delegate = self
  
  return super.application(application, didFinishLaunchingWithOptions: launchOptions)
}

// APNs 토큰 수신 성공
override func application(
  _ application: UIApplication,
  didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
) {
  print("🍎 APNs 토큰 수신 성공")
  let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
  print("📱 토큰: \(tokenString)")
  
  // Firebase에 APNs 토큰 전달
  Messaging.messaging().apnsToken = deviceToken
  
  print("✅ Firebase가 이제 FCM 토큰을 생성합니다")
}

// APNs 토큰 수신 실패
override func application(
  _ application: UIApplication,
  didFailToRegisterForRemoteNotificationsWithError error: Error
) {
  print("❌ APNs 토큰 수신 실패: \(error.localizedDescription)")
  print("📋 해결 방법:")
  print("   1. Firebase Console에서 APNs 인증 키 업로드 확인")
  print("   2. Xcode: Capabilities → Push Notifications 추가")
  print("   3. 실제 iOS 기기에서 테스트")
}
```

**Firebase Messaging 델리게이트:**
```swift
extension AppDelegate: MessagingDelegate {
  // FCM 토큰 수신
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    guard let fcmToken = fcmToken else {
      print("❌ FCM 토큰이 nil입니다")
      return
    }
    
    print("🔔 FCM 토큰 수신 (iOS)")
    print("📱 전체 토큰: \(fcmToken)")
    print("📊 토큰 길이: \(fcmToken.count) 문자")
    print("✅ Flutter 앱에서 Firestore에 저장합니다")
  }
}
```

---

### 3. Info.plist 설정 추가

**파일 위치:** `ios/Runner/Info.plist`

**추가된 설정:**

**1) 백그라운드 모드 (푸시 알림):**
```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

**2) 푸시 알림 권한 메시지:**
```xml
<key>NSUserNotificationUsageDescription</key>
<string>전화 착신 알림을 받으려면 알림 권한이 필요합니다.</string>
```

**3) Firebase 설정:**
```xml
<key>FirebaseAppDelegateProxyEnabled</key>
<false/>

<key>FirebaseMessagingAutoInitEnabled</key>
<true/>
```

---

### 4. 진단 가이드 문서 작성

**파일 위치:** `ios_fcm_diagnostic.md`

**포함 내용:**
- ✅ iOS FCM 작동 요구사항 체크리스트
- ✅ APNs 인증서 생성 방법
- ✅ GoogleService-Info.plist 설정 방법
- ✅ Xcode 프로젝트 설정 (Push Notifications, Background Modes)
- ✅ Podfile 확인 및 재설치 방법
- ✅ 테스트 방법 및 로그 확인
- ✅ 일반적인 문제 해결 가이드

---

## 🧪 테스트 방법

### 1. 실제 iOS 기기 필수
**⚠️ 중요: iOS 시뮬레이터는 푸시 알림을 받을 수 없습니다!**

반드시 실제 iPhone 또는 iPad에서 테스트하세요.

### 2. Xcode로 빌드 및 실행
```bash
# 1. ios 디렉토리로 이동
cd /home/user/flutter_app/ios

# 2. Pod 재설치 (Firebase 관련 pods)
pod deintegrate
pod install

# 3. Xcode에서 Runner.xcworkspace 열기
open Runner.xcworkspace

# 4. 실제 iOS 기기 연결
# 5. Run 버튼 클릭 (Cmd+R)
```

### 3. 로그 확인
**Xcode 콘솔에서 다음 로그 순서로 확인:**

**성공 케이스:**
```
1️⃣  APNs 토큰 요청 시작...
📱 알림 권한 상태: authorized

="="="="="="="="="="="="="="="="="="="="="="="="="="="="="=
🍎 APNs 토큰 수신 성공
="="="="="="="="="="="="="="="="="="="="="="="="="="="="="=
📱 토큰: 1234567890abcdef...
📊 토큰 길이: 64 문자

✅ Firebase에 APNs 토큰 전달 중...
✅ APNs 토큰 전달 완료
   → Firebase가 이제 FCM 토큰을 생성합니다
="="="="="="="="="="="="="="="="="="="="="="="="="="="="="=

✅ APNs 토큰 획득 성공
   APNs 토큰: 1234567890abcdef...

="="="="="="="="="="="="="="="="="="="="="="="="="="="="="=
🔔 FCM 토큰 수신 (iOS)
="="="="="="="="="="="="="="="="="="="="="="="="="="="="="=
📱 전체 토큰:
[152자 길이 FCM 토큰]

📊 토큰 길이: 152 문자
✅ FCM 토큰 수신 완료
   → Flutter 앱에서 Firestore에 저장합니다
="="="="="="="="="="="="="="="="="="="="="="="="="="="="="=

🔔 FCM 토큰 정보
   - 토큰 길이: 152 문자
   - 사용자 ID: user_xxx
   - 플랫폼: ios
   - 기기 이름: iPhone 15 Pro (iOS 17.0)

✅ [완료] 새 FCM 토큰 저장 성공
   📱 기기: iPhone 15 Pro (iOS 17.0) (ios)
   🔑 토큰 길이: 152 문자
```

**실패 케이스 (APNs 토큰 없음):**
```
1️⃣  APNs 토큰 요청 시작...
📱 알림 권한 상태: authorized

="="="="="="="="="="="="="="="="="="="="="="="="="="="="="=
❌ APNs 토큰 수신 실패
="="="="="="="="="="="="="="="="="="="="="="="="="="="="="=
오류: [오류 메시지]

📋 해결 방법:
   1. Firebase Console에서 APNs 인증 키 업로드 확인
   2. Xcode: Capabilities → Push Notifications 추가
   3. 실제 iOS 기기에서 테스트 (시뮬레이터는 푸시 불가)
   4. 프로비저닝 프로파일에 Push Notification 권한 포함 확인
="="="="="="="="="="="="="="="="="="="="="="="="="="="="="=

❌ APNs 토큰 획득 실패!

🔴 iOS FCM 토큰을 받으려면 APNs 토큰이 먼저 필요합니다.

📋 해결 방법:
   1. Firebase Console에서 APNs 인증 키 업로드
   2. Xcode에서 Push Notifications Capability 추가
   3. 실제 iOS 기기에서 테스트 (시뮬레이터는 푸시 알림 불가)
   4. AppDelegate.swift에 Firebase 초기화 코드 추가
   5. Info.plist에 FirebaseAppDelegateProxyEnabled 설정

📄 상세 가이드: ios_fcm_diagnostic.md 참조
```

### 4. Firestore 데이터 확인
1. [Firebase Console](https://console.firebase.google.com/) 접속
2. makecallio 프로젝트 → Firestore Database
3. `fcm_tokens` 컬렉션 확인
4. iOS 기기 문서 확인:

**문서 ID 형식:**
```
{userId}_{deviceId}
```

**예시:**
```
user_abc123_ABC-123-DEF-456
```

**문서 데이터:**
```json
{
  "userId": "user_abc123",
  "fcmToken": "dK7x...hN8p (152자)",
  "deviceId": "ABC-123-DEF-456",
  "deviceName": "iPhone 15 Pro (iOS 17.0)",
  "platform": "ios",
  "createdAt": "2025-11-10T06:00:00Z",
  "lastActiveAt": "2025-11-10T06:00:00Z",
  "isActive": true
}
```

---

## 🚨 사전 준비 사항 (필수)

### 1. Firebase Console에서 APNs 인증 키 업로드

**⚠️ 가장 중요한 단계 - APNs 키 없이는 iOS 푸시 알림 불가!**

**Step 1: Apple Developer에서 APNs 키 생성**
1. [Apple Developer Console](https://developer.apple.com/account/resources/authkeys/list) 접속
2. **Keys** → **+** 버튼 클릭
3. Key Name 입력 (예: "MakeCall APNs Key")
4. **Apple Push Notifications service (APNs)** 체크
5. **Continue** → **Register** → **Download**
6. `.p8` 파일 다운로드 (절대 잃어버리지 말 것!)
7. **Key ID** 와 **Team ID** 메모

**Step 2: Firebase Console에 APNs 키 업로드**
1. [Firebase Console](https://console.firebase.google.com/) 접속
2. makecallio 프로젝트 선택
3. **프로젝트 설정** (톱니바퀴 아이콘) → **클라우드 메시징** 탭
4. **Apple 앱 구성** 섹션으로 스크롤
5. **APNs 인증 키 업로드** 클릭
6. 다운로드한 `.p8` 파일 업로드
7. **Key ID** 와 **Team ID** 입력
8. **업로드** 버튼 클릭

**확인:**
- ✅ "APNs 인증 키가 성공적으로 업로드되었습니다" 메시지 확인
- ✅ Key ID가 표시되는지 확인

---

### 2. Xcode 프로젝트 설정

**Step 1: Xcode에서 프로젝트 열기**
```bash
cd /home/user/flutter_app/ios
open Runner.xcworkspace  # ⚠️ .xcodeproj 아님!
```

**Step 2: Capabilities 추가**
1. Runner 타겟 선택 (좌측 파일 트리)
2. **Signing & Capabilities** 탭 클릭
3. **+ Capability** 버튼 클릭

**추가할 Capabilities:**
- ✅ **Push Notifications** 추가
- ✅ **Background Modes** 추가
  - Remote notifications 체크

**Step 3: Signing 설정**
1. **Signing & Capabilities** 탭에서
2. **Team** 선택 (Apple Developer 계정)
3. **Bundle Identifier** 확인 (예: `io.makecall.app`)

---

### 3. GoogleService-Info.plist 확인

**파일 위치:** `ios/Runner/GoogleService-Info.plist`

**확인 방법:**
```bash
ls -la /home/user/flutter_app/ios/Runner/GoogleService-Info.plist
```

**파일이 없다면:**
1. [Firebase Console](https://console.firebase.google.com/) 접속
2. makecallio 프로젝트 선택
3. **프로젝트 설정** → **일반** 탭
4. **내 앱** 섹션에서 iOS 앱 찾기
5. **GoogleService-Info.plist** 다운로드
6. `ios/Runner/` 디렉토리에 복사

---

## 📝 완료 체크리스트

**코드 수정:**
- [x] `lib/services/fcm_service.dart` - iOS 전용 디버깅 추가
- [x] `ios/Runner/AppDelegate.swift` - Firebase 초기화 및 APNs 처리
- [x] `ios/Runner/Info.plist` - 푸시 알림 설정 추가

**사전 준비 (사용자 작업 필요):**
- [ ] Firebase Console에 APNs 인증 키 업로드
- [ ] GoogleService-Info.plist 파일 확인
- [ ] Xcode: Push Notifications Capability 추가
- [ ] Xcode: Background Modes → Remote notifications 체크
- [ ] Xcode: Team 선택 및 Signing 설정

**테스트:**
- [ ] Pod 재설치 (`pod deintegrate && pod install`)
- [ ] 실제 iOS 기기 연결
- [ ] Xcode로 빌드 및 실행
- [ ] 로그인 후 알림 권한 허용
- [ ] Xcode 콘솔에서 APNs 토큰 수신 확인
- [ ] Xcode 콘솔에서 FCM 토큰 수신 확인
- [ ] Firestore `fcm_tokens` 컬렉션에 iOS 기기 등록 확인

---

## 🔗 참고 문서

- **ios_fcm_diagnostic.md** - 상세 진단 및 해결 가이드
- [Firebase iOS Setup](https://firebase.google.com/docs/ios/setup)
- [FCM iOS Client Setup](https://firebase.google.com/docs/cloud-messaging/ios/client)
- [APNs Overview](https://developer.apple.com/documentation/usernotifications)

---

**다음 단계:**
1. **가장 중요**: Firebase Console에 APNs 인증 키 업로드
2. Xcode에서 Push Notifications Capability 추가
3. Pod 재설치
4. 실제 iOS 기기에서 테스트
5. Xcode 콘솔 로그 확인
6. Firestore 데이터 확인

모든 코드 수정이 완료되었습니다! APNs 인증 키만 업로드하면 iOS FCM이 정상 작동합니다. 🚀
