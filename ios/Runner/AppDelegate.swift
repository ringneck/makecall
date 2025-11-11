import UIKit
import Flutter
import FirebaseCore
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate {
  // 🔍 호출 카운터 (고급 디버깅)
  private var apnsTokenCallCount = 0
  private var didFinishLaunchingCallCount = 0
  
  // ✅ Flutter Method Channel for FCM
  private var fcmChannel: FlutterMethodChannel?
  
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
    
    // ✅ OPTION 1: Flutter Method Channel 설정
    let controller = window?.rootViewController as! FlutterViewController
    fcmChannel = FlutterMethodChannel(
      name: "com.makecall.app/fcm",
      binaryMessenger: controller.binaryMessenger
    )
    print("✅ [METHOD-CHANNEL] FCM Method Channel 생성 완료")
    
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
  
  // 🔥 원격 알림 수신 핸들러 (Option 2용 - 호출되지 않음)
  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    print("📲 [REMOTE] 원격 알림 수신 (didReceiveRemoteNotification)")
    print("   ⚠️ 이 메서드는 iOS에서 호출하지 않음 - UNNotification만 사용됨")
    print("   - UserInfo: \(userInfo)")
    
    // Firebase Messaging Plugin 전달 (동작 안 함)
    Messaging.messaging().appDidReceiveMessage(userInfo)
    
    completionHandler(.newData)
  }
  
  // ✅ OPTION 1: 포그라운드에서 알림 수신 - Method Channel로 직접 전달
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo
    
    print("")
    print("═══════════════════════════════════════════════")
    print("📨 [OPTION-1] 포그라운드 알림 수신 (UNNotification)")
    print("═══════════════════════════════════════════════")
    print("   - Title: \(notification.request.content.title)")
    print("   - Body: \(notification.request.content.body)")
    print("   - UserInfo keys: \(userInfo.keys)")
    
    // ✅ Option 1: Flutter Method Channel로 직접 전달
    if let channel = fcmChannel {
      print("🔄 [OPTION-1] Flutter Method Channel 호출 시작")
      
      // UserInfo를 String Dictionary로 변환
      var messageData: [String: Any] = [:]
      for (key, value) in userInfo {
        if let keyString = key as? String {
          messageData[keyString] = value
        }
      }
      
      // Notification 정보 추가
      messageData["notification_title"] = notification.request.content.title
      messageData["notification_body"] = notification.request.content.body
      messageData["message_type"] = "foreground"
      
      print("   - 전달할 데이터: \(messageData.keys)")
      
      // Flutter Method Channel 호출
      channel.invokeMethod("handleFCMMessage", arguments: messageData) { result in
        if let error = result as? FlutterError {
          print("❌ [OPTION-1] Flutter Method Channel 오류: \(error.message ?? "Unknown")")
        } else {
          print("✅ [OPTION-1] Flutter Method Channel 호출 완료")
        }
      }
    } else {
      print("❌ [OPTION-1] Method Channel이 초기화되지 않음!")
    }
    
    // 포그라운드에서도 알림 배너 표시
    if #available(iOS 14.0, *) {
      completionHandler([[.banner, .badge, .sound]])
    } else {
      completionHandler([[.alert, .badge, .sound]])
    }
  }
  
  // ✅ OPTION 1: 알림 탭했을 때 - Method Channel로 직접 전달
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    
    print("")
    print("═══════════════════════════════════════════════")
    print("📬 [OPTION-1] 알림 탭됨 (UNNotification)")
    print("═══════════════════════════════════════════════")
    print("   - Title: \(response.notification.request.content.title)")
    print("   - Body: \(response.notification.request.content.body)")
    print("   - UserInfo keys: \(userInfo.keys)")
    
    // ✅ Option 1: Flutter Method Channel로 직접 전달
    if let channel = fcmChannel {
      print("🔄 [OPTION-1] Flutter Method Channel 호출 시작")
      
      // UserInfo를 String Dictionary로 변환
      var messageData: [String: Any] = [:]
      for (key, value) in userInfo {
        if let keyString = key as? String {
          messageData[keyString] = value
        }
      }
      
      // Notification 정보 추가
      messageData["notification_title"] = response.notification.request.content.title
      messageData["notification_body"] = response.notification.request.content.body
      messageData["message_type"] = "notification_tap"
      
      print("   - 전달할 데이터: \(messageData.keys)")
      
      // Flutter Method Channel 호출
      channel.invokeMethod("handleFCMMessage", arguments: messageData) { result in
        if let error = result as? FlutterError {
          print("❌ [OPTION-1] Flutter Method Channel 오류: \(error.message ?? "Unknown")")
        } else {
          print("✅ [OPTION-1] Flutter Method Channel 호출 완료")
        }
      }
    } else {
      print("❌ [OPTION-1] Method Channel이 초기화되지 않음!")
    }
    
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
