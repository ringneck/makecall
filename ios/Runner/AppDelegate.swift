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
    
    // 🔥 Firebase 초기화 (반드시 가장 먼저!)
    FirebaseApp.configure()
    print("✅ Firebase 초기화 완료 (Native)")
    
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
    
    // 🔥 CRITICAL: APNs 토큰을 Firebase Messaging에 수동으로 설정
    Messaging.messaging().apnsToken = deviceToken
    print("✅ APNs 토큰을 Firebase Messaging에 설정 완료")
  }
  
  // APNs 토큰 수신 실패
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("❌ APNs 등록 실패: \(error.localizedDescription)")
  }
  
  // 🔥 CRITICAL: 원격 알림 수신 핸들러 (Firebase Messaging Plugin 필수!)
  // 이 메서드가 없으면 Flutter의 FirebaseMessaging.onMessage가 트리거되지 않음
  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    print("📲 [REMOTE] 원격 알림 수신 (didReceiveRemoteNotification)")
    print("   - UserInfo: \(userInfo)")
    
    // 앱 상태 확인
    let appState = application.applicationState
    switch appState {
    case .active:
      print("   - 앱 상태: 포그라운드 (Active)")
    case .inactive:
      print("   - 앱 상태: 비활성 (Inactive)")
    case .background:
      print("   - 앱 상태: 백그라운드 (Background)")
    @unknown default:
      print("   - 앱 상태: 알 수 없음")
    }
    
    // ✅ Firebase Messaging Plugin에 메시지 전달
    // 이 호출이 Flutter의 FirebaseMessaging.onMessage를 트리거함
    Messaging.messaging().appDidReceiveMessage(userInfo)
    print("✅ [REMOTE] Firebase Messaging Plugin으로 전달 완료")
    
    completionHandler(.newData)
  }
  
  // 포그라운드에서 알림 수신
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo
    
    print("📨 [FOREGROUND-UNNotification] 포그라운드 알림 수신")
    print("   - Title: \(notification.request.content.title)")
    print("   - Body: \(notification.request.content.body)")
    print("   - UserInfo: \(userInfo)")
    
    // ✅ Firebase Messaging Plugin에 메시지 전달
    // 주의: didReceiveRemoteNotification이 이미 호출되었을 수 있으므로
    // 여기서는 UI 표시만 담당
    print("🔄 [FOREGROUND-UNNotification] Firebase Messaging Plugin 전달")
    Messaging.messaging().appDidReceiveMessage(userInfo)
    print("✅ [FOREGROUND-UNNotification] 전달 완료")
    
    // 포그라운드에서도 알림 배너 표시
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
    let userInfo = response.notification.request.content.userInfo
    
    print("📬 [NOTIFICATION-TAP] 알림 탭됨")
    print("   - Title: \(response.notification.request.content.title)")
    print("   - Body: \(response.notification.request.content.body)")
    print("   - UserInfo: \(userInfo)")
    
    // ✅ Firebase Messaging Plugin에 메시지 전달
    // 이 호출이 Flutter의 FirebaseMessaging.onMessageOpenedApp을 트리거함
    print("🔄 [NOTIFICATION-TAP] Firebase Messaging Plugin 전달")
    Messaging.messaging().appDidReceiveMessage(userInfo)
    print("✅ [NOTIFICATION-TAP] 전달 완료")
    
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
