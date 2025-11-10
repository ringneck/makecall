# iOS FCM 토큰 등록 문제 진단 및 해결

## 🔍 문제 증상
- iOS 기기에서 로그인 및 푸시 활성화 설정 완료
- Firestore `fcm_tokens` 컬렉션에 iOS 기기가 등록되지 않음

---

## 📋 iOS FCM 작동 요구사항 체크리스트

### 1. APNs (Apple Push Notification service) 인증서
iOS에서 FCM이 작동하려면 APNs 인증서가 필수입니다.

**확인 방법:**
1. [Firebase Console](https://console.firebase.google.com/) 접속
2. makecallio 프로젝트 선택
3. **프로젝트 설정** (톱니바퀴 아이콘) → **클라우드 메시징** 탭
4. **Apple 앱 구성** 섹션 확인

**필요한 것:**
- ✅ **APNs 인증 키** (.p8 파일) 또는
- ✅ **APNs 인증서** (.p12 파일)

**APNs 키 생성 방법:**
1. [Apple Developer Console](https://developer.apple.com/account/resources/authkeys/list) 접속
2. **Keys** → **+** 버튼 클릭
3. Key Name 입력 (예: "MakeCall APNs Key")
4. **Apple Push Notifications service (APNs)** 체크
5. **Continue** → **Register** → **Download**
6. 다운로드한 `.p8` 파일을 Firebase Console에 업로드
7. Key ID와 Team ID도 함께 입력

---

### 2. GoogleService-Info.plist 파일
iOS 앱에 Firebase 설정 파일이 있어야 합니다.

**파일 위치:**
```
/home/user/flutter_app/ios/Runner/GoogleService-Info.plist
```

**확인 명령:**
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

### 3. Xcode 프로젝트 설정

**Runner.xcworkspace에서 확인:**
1. Xcode에서 `ios/Runner.xcworkspace` 열기 (`.xcodeproj` 아님!)
2. Runner 타겟 선택
3. **Signing & Capabilities** 탭

**필수 Capabilities:**
- ✅ **Push Notifications** - 푸시 알림 수신
- ✅ **Background Modes** - 백그라운드 알림 처리
  - Remote notifications 체크

**추가 방법:**
1. **+ Capability** 버튼 클릭
2. "Push Notifications" 검색 후 추가
3. "Background Modes" 검색 후 추가
4. Background Modes에서 "Remote notifications" 체크

---

### 4. Podfile 확인
Firebase 관련 pods가 설치되어 있어야 합니다.

**파일 위치:** `/home/user/flutter_app/ios/Podfile`

**필수 내용 확인:**
```ruby
# Uncomment this line if you're using Swift or would like to use dynamic frameworks
# use_frameworks!

# Flutter Firebase 플러그인이 자동으로 추가하는 pods:
# - Firebase/CoreOnly
# - Firebase/Messaging
# - GoogleUtilities

# iOS 최소 버전 (Firebase는 iOS 13.0 이상 필요)
platform :ios, '13.0'
```

**Pod 재설치:**
```bash
cd /home/user/flutter_app/ios
pod deintegrate
pod install
```

---

### 5. Info.plist 권한 설정
알림 권한 요청 메시지가 필요합니다.

**파일 위치:** `/home/user/flutter_app/ios/Runner/Info.plist`

**추가해야 할 내용:**
```xml
<!-- Firebase 설정 -->
<key>FirebaseAppDelegateProxyEnabled</key>
<false/>

<!-- 푸시 알림 권한 요청 메시지 -->
<key>NSUserNotificationUsageDescription</key>
<string>전화 착신 알림을 받으려면 알림 권한이 필요합니다.</string>

<!-- 백그라운드 모드 -->
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

---

## 🔧 코드 수정 사항

### 1. FCM 서비스 iOS 디버깅 강화

현재 `fcm_service.dart`의 `initialize()` 메서드에 iOS 전용 디버깅을 추가합니다.

**수정 위치:** `/home/user/flutter_app/lib/services/fcm_service.dart`

**43번째 줄 `initialize()` 메서드 시작 부분:**

```dart
Future<void> initialize(String userId) async {
  try {
    if (kDebugMode) {
      debugPrint('🔔 FCM 서비스 초기화 시작...');
      debugPrint('   플랫폼: ${_getPlatformName()}');
      
      // iOS 전용 추가 디버깅
      if (Platform.isIOS) {
        debugPrint('');
        debugPrint('='*60);
        debugPrint('🍎 iOS FCM 초기화 상세 정보');
        debugPrint('='*60);
        debugPrint('1️⃣  APNs 토큰 요청 시작...');
      }
    }
    
    // 알림 권한 요청
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    
    if (kDebugMode) {
      debugPrint('📱 알림 권한 상태: ${settings.authorizationStatus}');
      
      // iOS 전용: APNs 토큰 확인
      if (Platform.isIOS) {
        final apnsToken = await _messaging.getAPNSToken();
        if (apnsToken != null) {
          debugPrint('✅ APNs 토큰 획득 성공');
          debugPrint('   APNs 토큰: ${apnsToken.substring(0, 20)}...');
        } else {
          debugPrint('');
          debugPrint('❌ APNs 토큰 획득 실패!');
          debugPrint('');
          debugPrint('🔴 iOS FCM 토큰을 받으려면 APNs 토큰이 먼저 필요합니다.');
          debugPrint('');
          debugPrint('📋 해결 방법:');
          debugPrint('   1. Firebase Console에서 APNs 인증 키 업로드');
          debugPrint('   2. Xcode에서 Push Notifications Capability 추가');
          debugPrint('   3. 실제 iOS 기기에서 테스트 (시뮬레이터는 푸시 알림 불가)');
          debugPrint('   4. Info.plist에 FirebaseAppDelegateProxyEnabled 설정');
          debugPrint('');
          return; // APNs 토큰 없으면 FCM 토큰 받을 수 없음
        }
      }
    }
```

---

### 2. iOS APNs 토큰 확인 메서드 추가

**추가 위치:** `fcm_service.dart` 파일 끝부분 (887번째 줄 이후)

```dart
/// iOS APNs 토큰 상태 확인 (디버깅용)
Future<Map<String, dynamic>> checkIOSAPNsStatus() async {
  if (!Platform.isIOS) {
    return {'platform': 'not_ios', 'status': 'N/A'};
  }
  
  try {
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
  } catch (e) {
    return {
      'platform': 'ios',
      'status': 'error',
      'error': e.toString(),
    };
  }
}
```

---

### 3. AppDelegate.swift 수정 (중요!)

iOS에서 FCM이 작동하려면 `AppDelegate.swift`를 수정해야 합니다.

**파일 위치:** `/home/user/flutter_app/ios/Runner/AppDelegate.swift`

**전체 내용을 다음으로 교체:**

```swift
import UIKit
import Flutter
import Firebase

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Firebase 초기화
    FirebaseApp.configure()
    
    // Flutter 플러그인 등록
    GeneratedPluginRegistrant.register(with: self)
    
    // iOS 13 이상: APNs 등록
    if #available(iOS 13.0, *) {
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
    } else {
      // iOS 12 이하
      let settings: UIUserNotificationSettings =
        UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
      application.registerUserNotificationSettings(settings)
    }
    
    application.registerForRemoteNotifications()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // APNs 토큰 수신 성공
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    print("🍎 APNs 토큰 수신 성공")
    print("   토큰: \\(deviceToken.map { String(format: \"%02x\", $0) }.joined())")
    
    // Firebase에 APNs 토큰 전달
    Messaging.messaging().apnsToken = deviceToken
  }
  
  // APNs 토큰 수신 실패
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("❌ APNs 토큰 수신 실패: \\(error.localizedDescription)")
  }
  
  // 포그라운드에서 알림 수신
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo
    print("📨 포그라운드 알림 수신: \\(userInfo)")
    
    // iOS 14 이상
    if #available(iOS 14.0, *) {
      completionHandler([[.banner, .badge, .sound]])
    } else {
      // iOS 13
      completionHandler([[.alert, .badge, .sound]])
    }
  }
  
  // 알림 탭했을 때
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    print("👆 알림 탭됨: \\(userInfo)")
    
    completionHandler()
  }
}
```

---

## 🧪 테스트 방법

### 1. 실제 iOS 기기에서 테스트
**⚠️ 중요: iOS 시뮬레이터는 푸시 알림을 받을 수 없습니다!**

실제 iPhone 또는 iPad에서 테스트해야 합니다.

### 2. Xcode 콘솔 로그 확인
1. Xcode에서 `ios/Runner.xcworkspace` 열기
2. 실제 iOS 기기 연결
3. Run 버튼 클릭 (Cmd+R)
4. 로그인 후 푸시 권한 허용
5. Xcode 콘솔에서 다음 로그 확인:

**성공 시 로그:**
```
🍎 APNs 토큰 수신 성공
   토큰: 1234567890abcdef...
✅ iOS 알림 권한 허용됨
🔔 FCM 서비스 초기화 시작...
   플랫폼: ios
📱 알림 권한 상태: authorized
✅ APNs 토큰 획득 성공
   APNs 토큰: 1234567890abcdef...
🔔 FCM 토큰 정보
   - 토큰 길이: 152 문자
   - 사용자 ID: user_xxx
   - 플랫폼: ios
   - 기기 이름: iPhone 15 Pro (iOS 17.0)
✅ 완료 새 FCM 토큰 저장 성공
```

**실패 시 로그:**
```
❌ APNs 토큰 수신 실패: [오류 메시지]
❌ APNs 토큰 획득 실패!
🔴 iOS FCM 토큰을 받으려면 APNs 토큰이 먼저 필요합니다.
```

### 3. Firestore 데이터 확인
1. [Firebase Console](https://console.firebase.google.com/) 접속
2. makecallio 프로젝트 → **Firestore Database**
3. `fcm_tokens` 컬렉션 확인
4. iOS 기기 문서 확인:

**문서 ID 형식:**
```
{userId}_ios_{identifierForVendor}
```

**문서 데이터:**
```json
{
  "userId": "user_xxx",
  "fcmToken": "152자 길이 토큰",
  "deviceId": "ios_ABC123...",
  "deviceName": "iPhone 15 Pro (iOS 17.0)",
  "platform": "ios",
  "createdAt": "2025-11-10T05:30:00Z",
  "lastActiveAt": "2025-11-10T05:30:00Z",
  "isActive": true
}
```

---

## 🚨 일반적인 문제 및 해결

### 문제 1: APNs 토큰을 받을 수 없음
**증상:**
```
❌ APNs 토큰 획득 실패!
```

**해결 방법:**
1. ✅ Firebase Console에 APNs 인증 키 업로드 확인
2. ✅ Xcode: Push Notifications Capability 추가
3. ✅ Xcode: Background Modes → Remote notifications 체크
4. ✅ 실제 iOS 기기에서 테스트 (시뮬레이터 X)
5. ✅ 앱 재빌드 및 재설치

### 문제 2: FCM 토큰은 받았지만 Firestore에 저장 안됨
**증상:**
```
🔔 FCM 토큰 정보
   - 토큰 길이: 152 문자
❌ [FCMService] FCM 토큰 저장 오류: ...
```

**해결 방법:**
1. ✅ Firestore 보안 규칙 확인 (읽기/쓰기 권한)
2. ✅ 네트워크 연결 확인
3. ✅ Firebase Admin SDK 권한 확인
4. ✅ Xcode 콘솔에서 상세 오류 메시지 확인

### 문제 3: 알림 권한 denied
**증상:**
```
📱 알림 권한 상태: denied
❌ 알림 권한이 거부되었습니다
```

**해결 방법:**
1. iOS 설정 → MakeCall 앱 → 알림 → **허용** 선택
2. 앱 재시작
3. 로그인 다시 시도

### 문제 4: identifierForVendor가 nil
**증상:**
```
⚠️  [FCMService] 기기 ID 조회 실패
```

**해결 방법:**
- iOS에서 `identifierForVendor`는 앱 삭제 시 변경됩니다
- 코드에 fallback 로직이 있어 자동으로 처리됩니다
- 문제가 계속되면 앱 재설치

---

## 📝 체크리스트

**배포 전 확인:**
- [ ] Firebase Console에 APNs 인증 키 업로드
- [ ] GoogleService-Info.plist 파일 존재
- [ ] Xcode: Push Notifications Capability 추가
- [ ] Xcode: Background Modes → Remote notifications 체크
- [ ] AppDelegate.swift 수정 완료
- [ ] Info.plist에 권한 메시지 추가
- [ ] Pod install 완료

**테스트 시 확인:**
- [ ] 실제 iOS 기기 사용 (시뮬레이터 X)
- [ ] 알림 권한 허용
- [ ] Xcode 콘솔에서 APNs 토큰 수신 확인
- [ ] Xcode 콘솔에서 FCM 토큰 수신 확인
- [ ] Firestore에 fcm_tokens 문서 생성 확인
- [ ] 테스트 푸시 알림 전송 및 수신 확인

---

## 🔗 참고 자료

- [Firebase iOS Setup](https://firebase.google.com/docs/ios/setup)
- [FCM iOS Client Setup](https://firebase.google.com/docs/cloud-messaging/ios/client)
- [APNs Overview](https://developer.apple.com/documentation/usernotifications)
- [Flutter Firebase Messaging](https://firebase.flutter.dev/docs/messaging/overview/)

---

**다음 단계:**
1. 위 체크리스트 항목 확인
2. 누락된 설정 추가
3. 실제 iOS 기기에서 테스트
4. Xcode 콘솔 로그 확인
5. Firestore 데이터 확인
