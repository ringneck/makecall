import UIKit
import Flutter
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    print("")
    print(String(repeating: "=", count: 80))
    print("🚀 AppDelegate.application() 실행 시작")
    print(String(repeating: "=", count: 80))
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
    print("✅ AppDelegate.application() 실행 완료")
    print(String(repeating: "=", count: 80))
    print("")
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // APNs 토큰 수신 성공
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
    
    // ⚠️ Flutter 플러그인이 자동으로 APNs 토큰을 Firebase에 전달
    // Native에서 Messaging.messaging().apnsToken을 설정하면
    // Firebase 초기화 전에 호출되어 중복 초기화 오류 발생
    // Messaging.messaging().apnsToken = deviceToken ← 제거됨
    
    print("📱 Flutter Firebase Messaging 플러그인이 자동으로 처리합니다")
    print("   → APNs 토큰을 Firebase에 자동 전달")
    print("   → FCM 토큰 자동 생성")
    print(String(repeating: "=", count: 60))
    print("")
    
    // Flutter 플러그인이 처리할 수 있도록 super 호출
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
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
