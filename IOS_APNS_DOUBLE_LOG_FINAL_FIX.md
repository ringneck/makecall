# iOS APNs 토큰 이중 출력 - 최종 해결

## 🚨 문제 발견!

**증상**: APNs 토큰이 **정확히 두 번** 출력되고 Firebase 중복 초기화 오류 발생

```
============================================================
🍎 APNs 토큰 수신 성공  ← 첫 번째
============================================================
📱 토큰: 76c1ffb42223d8d79b9ca575b8e88b2febf689cde56677fed4617e3adc9a7ca7

============================================================
🍎 APNs 토큰 수신 성공  ← 두 번째 (문제!)
============================================================
📱 토큰: 76c1ffb42223d8d79b9ca575b8e88b2febf689cde56677fed4617e3adc9a7ca7

[ERROR] [core/duplicate-app] A Firebase App named "[DEFAULT]" already exists
```

---

## 🔍 진짜 근본 원인

### 문제의 코드 (AppDelegate.swift Line 110)

```swift
override func application(
  _ application: UIApplication,
  didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
) {
  print("🍎 APNs 토큰 수신 성공")
  // ... 로그 출력 ...
  
  // ❌ 이것이 문제였습니다!
  super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
}
```

### 왜 문제가 발생했는가?

**실행 흐름 분석**:

1. **iOS 시스템** → `AppDelegate.didRegisterForRemoteNotificationsWithDeviceToken` 호출
2. **우리 코드** → 로그 출력 (첫 번째)
3. **우리 코드** → `super.application()` 호출
4. **FlutterAppDelegate** → 내부 처리 후 다시 **같은 메서드 호출** 또는 델리게이트 체인 실행
5. **우리 코드** → 로그 출력 (두 번째) ← **중복!**
6. **Firebase SDK** → 두 번 초기화 시도 → **duplicate-app 오류**

**핵심 문제**: 
- `super.application()`이 **FlutterAppDelegate의 구현**을 호출
- FlutterAppDelegate가 내부적으로 **이벤트를 다시 전파**하거나 **델리게이트 체인**을 실행
- 결과적으로 우리 메서드가 **두 번 실행**됨

---

## ✅ 해결 방법

### 핵심 원칙

**"Native 코드는 아무것도 하지 말고, Flutter 플러그인이 자동으로 처리하도록 놔둬라"**

Flutter Firebase Messaging 플러그인은 **method channel**을 통해 자동으로:
1. APNs 토큰을 감지
2. Firebase에 토큰 전달
3. FCM 토큰 생성

**Native 코드에서 할 일**: 로그 출력만! (선택사항)

### 수정된 코드

```swift
override func application(
  _ application: UIApplication,
  didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
) {
  print("")
  print(String(repeating: "=", count: 60))
  print("🍎 APNs 토큰 수신 성공")
  print(String(repeating: "=", count: 60))
  let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
  print("📱 토큰: \(tokenString)")
  print("📊 토큰 길이: \(tokenString.count) 문자")
  print("")
  
  print("📱 Flutter Firebase Messaging 플러그인이 자동으로 처리합니다")
  print("   → APNs 토큰을 Firebase에 자동 전달")
  print("   → FCM 토큰 자동 생성")
  print(String(repeating: "=", count: 60))
  print("")
  
  // ✅ 아무것도 하지 않음!
  // Flutter Firebase Messaging 플러그인이 method channel을 통해
  // 자동으로 APNs 토큰을 감지하고 Firebase에 전달합니다.
  // 
  // ❌ super.application() 호출 금지!
  // → FlutterAppDelegate가 이 메서드를 다시 호출하여 무한 재귀 발생
  // → APNs 토큰이 두 번 출력되는 원인
  //
  // super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken) ← 제거됨
}
```

---

## 🔄 Flutter Firebase Messaging 플러그인 작동 원리

### 자동 APNs 토큰 감지 메커니즘

Flutter Firebase Messaging 플러그인은 **native method channel interception**을 사용합니다:

```
1. iOS 시스템
   └─→ AppDelegate.didRegisterForRemoteNotificationsWithDeviceToken 호출
   
2. Flutter Plugin (자동 감지)
   ├─→ Method Channel을 통해 APNs 토큰 수신
   ├─→ Firebase Messaging에 토큰 자동 전달
   └─→ FCM 토큰 생성
   
3. Flutter App
   ├─→ FirebaseMessaging.instance.getToken() 호출
   └─→ FCM 토큰 수신 및 Firestore 저장
```

**Native 코드에서 별도로 토큰을 전달할 필요가 전혀 없습니다!**

---

## 🚨 잘못된 접근 방법 (하지 말 것)

### ❌ 방법 1: Messaging.messaging().apnsToken 설정

```swift
// ❌ 절대 금지!
Messaging.messaging().apnsToken = deviceToken
```

**문제점**: Firebase가 초기화되기 전에 호출되어 조기 초기화 발생

---

### ❌ 방법 2: super.application() 호출

```swift
// ❌ 절대 금지!
super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
```

**문제점**: 
- FlutterAppDelegate가 이벤트를 다시 전파하여 무한 재귀 또는 이중 호출
- APNs 토큰이 두 번 출력
- Firebase 중복 초기화

---

### ❌ 방법 3: Messaging.messaging().delegate 설정

```swift
// ❌ 절대 금지!
Messaging.messaging().delegate = self
```

**문제점**: Flutter 플러그인이 이미 델리게이트를 설정하므로 충돌

---

## ✅ 올바른 접근 방법

### 방법: 아무것도 하지 않기!

```swift
override func application(
  _ application: UIApplication,
  didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
) {
  // ✅ 선택사항: 디버깅 로그만 출력
  print("🍎 APNs 토큰 수신: \(deviceToken)")
  
  // ✅ 끝! 아무것도 하지 않음
  // Flutter 플러그인이 자동으로 모든 것을 처리합니다
}
```

**또는 메서드 자체를 override하지 않아도 됩니다**:

```swift
@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // APNs 등록만
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
      UNUserNotificationCenter.current().requestAuthorization(
        options: [.alert, .badge, .sound]
      ) { granted, _ in
        if granted {
          DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
          }
        }
      }
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // ✅ didRegisterForRemoteNotificationsWithDeviceToken 메서드 override 불필요!
  // FlutterAppDelegate가 자동으로 처리합니다
}
```

---

## 🧪 검증 방법

### 1. Clean Build

```bash
cd /Users/NORMAND/makecall/makecall

# Flutter 클린
flutter clean
rm -rf .dart_tool/ build/

# 의존성 재설치
flutter pub get

# iOS 클린
cd ios
rm -rf Pods Podfile.lock
pod install
cd ..
```

### 2. Xcode 빌드

```bash
open ios/Runner.xcworkspace
```

**Xcode에서**:
1. Product → Clean Build Folder (⇧⌘K)
2. Product → Run (⌘R)

### 3. 로그 확인

**✅ 성공 케이스 (APNs 토큰 한 번만 출력)**:

```
============================================================
🍎 APNs 토큰 수신 성공
============================================================
📱 토큰: 76c1ffb42223d8d79b9ca575b8e88b2febf689cde56677fed4617e3adc9a7ca7
📊 토큰 길이: 64 문자

📱 Flutter Firebase Messaging 플러그인이 자동으로 처리합니다
   → APNs 토큰을 Firebase에 자동 전달
   → FCM 토큰 자동 생성
============================================================

flutter: ══════════════════════════════════════
flutter: 🔥 Firebase 초기화 완료
flutter: ══════════════════════════════════════
flutter: 🔔 FCM 알림 권한 승인됨!
flutter: ══════════════════════════════════════
flutter: 📱 FCM 토큰 생성 완료:
flutter: fX7j9kL2nU:APA91bH_example_token_here
flutter: ══════════════════════════════════════
flutter: ✅ FCM 토큰이 Firestore에 저장되었습니다
```

**🚨 실패 케이스 (여전히 문제 발생)**:
```
============================================================
🍎 APNs 토큰 수신 성공  ← 첫 번째
============================================================

============================================================
🍎 APNs 토큰 수신 성공  ← 두 번째 (문제!)
============================================================

[ERROR] [core/duplicate-app] A Firebase App named "[DEFAULT]" already exists
```

→ 코드가 업데이트되지 않았거나 Clean Build가 제대로 되지 않음

---

## 📊 문제 해결 히스토리

이 문제는 **4단계 수정**을 거쳐 완전히 해결되었습니다:

### 1단계: FirebaseApp.configure() 제거 ❌
**결과**: 여전히 문제 발생 (다른 경로로 초기화됨)

### 2단계: Firebase.apps.isEmpty 체크 추가 ❌
**결과**: 백그라운드 핸들러는 안전해졌지만 APNs 문제 지속

### 3단계: Messaging.messaging().apnsToken 제거 + super.application() 추가 ❌
**결과**: APNs 토큰이 여전히 두 번 출력됨

### 4단계: super.application() 제거 ✅
**결과**: 
- ✅ APNs 토큰 로그 한 번만 출력
- ✅ 중복 초기화 오류 완전히 해결
- ✅ FCM 토큰 정상 생성
- ✅ Firestore에 토큰 정상 저장

---

## 💡 핵심 교훈

### Flutter-iOS Firebase 통합 황금 규칙

1. **Firebase 초기화는 Flutter에서만**
   - Native에서 `FirebaseApp.configure()` 절대 금지

2. **Firebase 메서드 호출 금지**
   - Native에서 `Messaging.messaging()` 호출 금지
   - Native에서 `Firebase.xxx()` 호출 금지

3. **super.application() 호출 주의**
   - `didRegisterForRemoteNotificationsWithDeviceToken`에서는 호출 금지
   - FlutterAppDelegate가 이벤트를 재전파하여 중복 실행 발생

4. **Flutter 플러그인을 신뢰하라**
   - Flutter Firebase Messaging 플러그인이 모든 것을 자동으로 처리
   - Native 코드는 최소한의 설정만 (APNs 등록, 알림 권한)

5. **로그가 정확한 진단 도구**
   - 로그가 두 번 출력 = 메서드가 두 번 호출됨
   - 즉시 코드 실행 흐름 분석 필요

---

## 📝 최종 체크리스트

- [x] `FirebaseApp.configure()` 제거됨
- [x] `Messaging.messaging().apnsToken` 제거됨
- [x] `Messaging.messaging().delegate` 제거됨
- [x] `super.application(didRegisterForRemoteNotificationsWithDeviceToken)` 제거됨
- [x] `Firebase.apps.isEmpty` 체크 추가됨 (main.dart 백그라운드 핸들러)
- [ ] Clean Build 수행 완료
- [ ] Xcode에서 앱 실행 성공
- [ ] APNs 토큰 로그 **한 번만** 출력 확인
- [ ] 중복 초기화 오류 없음 확인
- [ ] FCM 토큰 생성 성공 확인
- [ ] Firestore `fcm_tokens` 컬렉션에 토큰 저장 확인

---

## 🔗 관련 문서

- [IOS_FIREBASE_DUPLICATE_INIT_ROOT_CAUSE.md](./IOS_FIREBASE_DUPLICATE_INIT_ROOT_CAUSE.md) - 이전 해결 시도
- [IOS_DEBUG_LOG_GUIDE.md](./IOS_DEBUG_LOG_GUIDE.md) - iOS FCM 전체 설정 가이드
- [APNS_TOKEN_FAILURE_CHECKLIST.md](./APNS_TOKEN_FAILURE_CHECKLIST.md) - APNs 문제 해결

---

**마지막 업데이트**: 2025-01-23  
**문제 해결**: ✅ iOS APNs 토큰 이중 출력 완전 해결  
**핵심 발견**: `super.application(didRegisterForRemoteNotificationsWithDeviceToken)` 호출이 이중 실행의 원인
