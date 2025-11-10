import UIKit
import Flutter
import FirebaseCore
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
    
    // 🔥 Firebase 초기화 (FirebaseAppDelegateProxyEnabled = false이므로 수동 초기화 필요)
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
      print("✅ Firebase 초기화 완료 (Native)")
    }
    
    // Firebase Messaging 델리게이트 설정
    Messaging.messaging().delegate = self
    
    // Flutter 플러그인 등록
    GeneratedPluginRegistrant.register(with: self)
    
    // iOS 알림 설정
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
      
      let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
      UNUserNotificationCenter.current().requestAuthorization(
        options: authOptions,
        completionHandler: { _, _ in }
      )
    } else {
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
    apnsTokenCallCount += 1
    
    // 🔒 중복 호출 차단 (iOS 시스템이 2번 호출하는 버그 대응)
    guard apnsTokenCallCount == 1 else {
      print("⚠️ APNs 중복 호출 차단 (호출 #\(apnsTokenCallCount))")
      return
    }
    
    let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
    print("✅ APNs 토큰 수신: \(tokenString)")
    
    // Flutter Firebase Messaging 플러그인이 자동으로 처리
  }
  
  // APNs 토큰 수신 실패
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("❌ APNs 등록 실패: \(error.localizedDescription)")
  }
  
  // 포그라운드에서 알림 수신
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([[.banner, .badge, .sound]])
    } else {
      completionHandler([[.alert, .badge, .sound]])
    }
  }
  
  // 알림 탭했을 때
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    completionHandler()
  }
}



// Firebase Messaging 델리게이트
extension AppDelegate: MessagingDelegate {
  // FCM 토큰 수신
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    guard let fcmToken = fcmToken else { return }
    print("✅ FCM 토큰 수신: \(fcmToken.prefix(20))...")
  }
}
