import UIKit
import Flutter
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate {
  // 🔍 호출 카운터 (고급 디버깅)
  private var apnsTokenCallCount = 0
  private var didFinishLaunchingCallCount = 0
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    didFinishLaunchingCallCount += 1
    
    print("")
    print(String(repeating: "=", count: 80))
    print("🚀 [NATIVE-001] AppDelegate.didFinishLaunching 실행 시작")
    print("📊 호출 횟수: \(didFinishLaunchingCallCount)")
    print("📊 Thread: \(Thread.current)")
    print("📊 Timestamp: \(Date())")
    print(String(repeating: "=", count: 80))
    print("")
    
    // 🔍 호출 스택 추적 (고급 디버깅)
    print("🔍 [NATIVE-002] 호출 스택 추적:")
    Thread.callStackSymbols.prefix(10).forEach { symbol in
      print("   \(symbol)")
    }
    print("")
    
    // 환경 정보 출력
    printEnvironmentInfo()
    
    // ⚠️ Firebase 초기화는 Flutter에서 처리 (main.dart)
    // Native에서 초기화하면 중복 초기화 오류 발생
    // FirebaseApp.configure() ← 제거됨
    
    // Flutter 플러그인 등록
    print("📱 Flutter 플러그인 등록 중...")
    GeneratedPluginRegistrant.register(with: self)
    print("✅ Flutter 플러그인 등록 완료")
    print("")
    
    // iOS 알림 설정
    print("🔔 iOS 알림 권한 요청 중...")
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
      
      let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
      UNUserNotificationCenter.current().requestAuthorization(
        options: authOptions,
        completionHandler: { granted, error in
          print("")
          print(String(repeating: "=", count: 60))
          if granted {
            print("✅ iOS 알림 권한 허용됨")
          } else {
            print("❌ iOS 알림 권한 거부됨")
            if let error = error {
              print("   오류: \(error.localizedDescription)")
            }
          }
          print(String(repeating: "=", count: 60))
          print("")
        }
      )
    } else {
      // iOS 9 이하
      print("⚠️ iOS 9 이하 버전 감지")
      let settings: UIUserNotificationSettings =
        UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
      application.registerUserNotificationSettings(settings)
    }
    print("✅ 알림 권한 요청 완료")
    print("")
    
    print("🍎 APNs 원격 알림 등록 시작...")
    application.registerForRemoteNotifications()
    print("✅ APNs 등록 요청 전송 완료")
    print("   → didRegisterForRemoteNotificationsWithDeviceToken() 또는")
    print("   → didFailToRegisterForRemoteNotificationsWithError() 호출 대기 중...")
    print("")
    
    // ⚠️ Firebase Messaging 델리게이트는 Flutter 플러그인이 자동 설정
    // Native에서 설정하면 Flutter 초기화 전이라 문제 발생 가능
    // Messaging.messaging().delegate = self ← 제거됨 (Flutter가 처리)
    print("📱 Firebase Messaging은 Flutter 플러그인이 자동 초기화합니다")
    print("")
    
    print(String(repeating: "=", count: 80))
    print("✅ [NATIVE-FINISH] AppDelegate.didFinishLaunching 실행 완료")
    print("📊 호출 횟수: \(didFinishLaunchingCallCount)")
    print("")
    print("🔍 [NATIVE-SUPER] super.application() 호출 예정...")
    print(String(repeating: "=", count: 80))
    print("")
    
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    
    print("")
    print(String(repeating: "=", count: 80))
    print("✅ [NATIVE-COMPLETE] super.application() 반환 완료")
    print("📊 결과: \(result)")
    print(String(repeating: "=", count: 80))
    print("")
    
    return result
  }
  
  // APNs 토큰 수신 성공
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    apnsTokenCallCount += 1
    
    print("")
    print(String(repeating: "=", count: 80))
    print("🍎 [NATIVE-APNS-001] APNs 토큰 수신 - 호출 #\(apnsTokenCallCount)")
    print("📊 Thread: \(Thread.current)")
    print("📊 Timestamp: \(Date())")
    print("📊 DispatchQueue: \(DispatchQueue.currentLabel)")
    print(String(repeating: "=", count: 80))
    
    // 🔍 호출 스택 추적 (고급 디버깅 - 누가 이 메서드를 호출했는지 확인)
    print("")
    print("🔍 [NATIVE-APNS-002] 호출 스택 추적 (첫 15개):")
    Thread.callStackSymbols.prefix(15).enumerated().forEach { index, symbol in
      print("   [\(index)] \(symbol)")
    }
    print("")
    
    let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
    print("📱 [NATIVE-APNS-003] 토큰 정보:")
    print("   - 토큰: \(tokenString)")
    print("   - 길이: \(tokenString.count) 문자")
    print("   - 바이트: \(deviceToken.count) bytes")
    print("")
    
    // ⚠️ 중복 호출 경고
    if apnsTokenCallCount > 1 {
      print("⚠️⚠️⚠️  [NATIVE-APNS-WARNING] ⚠️⚠️⚠️")
      print("🚨 중복 호출 감지! 이 메서드가 \(apnsTokenCallCount)번 호출되었습니다!")
      print("🚨 APNs 토큰은 앱 생명주기 동안 한 번만 수신되어야 합니다!")
      print("🚨 호출 스택을 확인하여 중복 호출 원인을 파악하세요!")
      print("⚠️⚠️⚠️  [NATIVE-APNS-WARNING] ⚠️⚠️⚠️")
      print("")
    }
    
    // 🔍 Firebase 상태 확인 (고급 디버깅)
    print("🔍 [NATIVE-APNS-004] 현재 상태 체크:")
    print("   - 이 메서드는 override 되었습니까? YES")
    print("   - super.application() 호출 예정? NO (의도적으로 제거됨)")
    print("   - Flutter 플러그인 자동 감지 예상: YES")
    print("")
    
    print("📱 [NATIVE-APNS-005] Flutter Firebase Messaging 플러그인이 자동으로 처리합니다")
    print("   → APNs 토큰을 Firebase에 자동 전달")
    print("   → FCM 토큰 자동 생성")
    print(String(repeating: "=", count: 80))
    print("")
    
    // ✅ 아무것도 하지 않음!
    // Flutter Firebase Messaging 플러그인이 method channel을 통해
    // 자동으로 APNs 토큰을 감지하고 Firebase에 전달합니다.
    // 
    // ❌ super.application() 호출 금지!
    // ❌ Messaging.messaging().apnsToken 설정 금지!
    // 
    // 모든 처리는 Flutter 플러그인이 자동으로 수행합니다.
    
    print("✅ [NATIVE-APNS-006] 메서드 종료 - 아무 작업도 수행하지 않음")
    print("${'=' * 80}\n")
  }
  
  // APNs 토큰 수신 실패
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("")
    print(String(repeating: "=", count: 60))
    print("❌ APNs 토큰 수신 실패")
    print(String(repeating: "=", count: 60))
    print("오류: \(error.localizedDescription)")
    print("")
    print("📋 해결 방법:")
    print("   1. Firebase Console에서 APNs 인증 키 업로드 확인")
    print("   2. Xcode: Capabilities → Push Notifications 추가")
    print("   3. 실제 iOS 기기에서 테스트 (시뮬레이터는 푸시 불가)")
    print("   4. 프로비저닝 프로파일에 Push Notification 권한 포함 확인")
    print(String(repeating: "=", count: 60))
    print("")
  }
  
  // 포그라운드에서 알림 수신
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo
    
    print("")
    print("📨 포그라운드 알림 수신")
    print("   제목: \(notification.request.content.title)")
    print("   내용: \(notification.request.content.body)")
    print("   데이터: \(userInfo)")
    
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
    print("")
    print("👆 알림 탭됨")
    print("   데이터: \(userInfo)")
    
    completionHandler()
  }
}

// 🔧 DispatchQueue 헬퍼
extension DispatchQueue {
  static var currentLabel: String {
    return String(cString: __dispatch_queue_get_label(nil), encoding: .utf8) ?? "Unknown Queue"
  }
}

// 🔧 앱 시작 시 환경 정보 출력
extension AppDelegate {
  func printEnvironmentInfo() {
    print("")
    print(String(repeating: "=", count: 80))
    print("📊 iOS 환경 정보")
    print(String(repeating: "=", count: 80))
    print("iOS 버전: \(UIDevice.current.systemVersion)")
    print("기기 모델: \(UIDevice.current.model)")
    print("기기 이름: \(UIDevice.current.name)")
    
    #if targetEnvironment(simulator)
    print("⚠️ 실행 환경: iOS 시뮬레이터")
    print("   → 시뮬레이터는 APNs를 지원하지 않습니다!")
    print("   → 실제 iOS 기기에서 테스트하세요.")
    #else
    print("✅ 실행 환경: 실제 iOS 기기")
    print("   → APNs 토큰 획득 가능")
    #endif
    
    print(String(repeating: "=", count: 80))
    print("")
  }
}

// Firebase Messaging 델리게이트
extension AppDelegate: MessagingDelegate {
  // FCM 토큰 수신
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    guard let fcmToken = fcmToken else {
      print("❌ FCM 토큰이 nil입니다")
      return
    }
    
    print("")
    print(String(repeating: "=", count: 60))
    print("🔔 FCM 토큰 수신 (iOS)")
    print(String(repeating: "=", count: 60))
    print("📱 전체 토큰:")
    print(fcmToken)
    print("")
    print("📊 토큰 길이: \(fcmToken.count) 문자")
    print("✅ FCM 토큰 수신 완료")
    print("   → Flutter 앱에서 Firestore에 저장합니다")
    print(String(repeating: "=", count: 60))
    print("")
    
    // Flutter 채널로 토큰 전달 (선택사항)
    let tokenDict = ["token": fcmToken]
    NotificationCenter.default.post(
      name: NSNotification.Name("FCMToken"),
      object: nil,
      userInfo: tokenDict
    )
  }
}
