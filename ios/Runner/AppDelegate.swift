import UIKit
import Flutter
import FirebaseCore
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var apnsTokenCallCount = 0
  private var didFinishLaunchingCallCount = 0
  private var fcmChannel: FlutterMethodChannel?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    didFinishLaunchingCallCount += 1
    
    // Firebase 초기화
    FirebaseApp.configure()
    print("✅ Firebase 초기화 완료")
    
    // Firebase Messaging 델리게이트 설정
    Messaging.messaging().delegate = self
    
    // Flutter 플러그인 등록
    GeneratedPluginRegistrant.register(with: self)
    
    // Flutter Method Channel 설정
    let controller = window?.rootViewController as! FlutterViewController
    fcmChannel = FlutterMethodChannel(
      name: "com.makecall.app/fcm",
      binaryMessenger: controller.binaryMessenger
    )
    
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
    
    guard apnsTokenCallCount == 1 else {
      print("⚠️ APNs 중복 호출 차단 (호출 #\(apnsTokenCallCount))")
      return
    }
    
    // APNs 토큰을 Firebase Messaging에 설정
    Messaging.messaging().apnsToken = deviceToken
    print("✅ APNs 토큰 Firebase 설정 완료")
  }
  
  // APNs 토큰 수신 실패
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("❌ APNs 등록 실패: \(error.localizedDescription)")
  }
  
  // 포그라운드에서 알림 수신 - Method Channel로 직접 전달
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo
    
    print("📨 [iOS-FCM] 포그라운드 알림 수신: \(notification.request.content.title)")
    
    if let channel = fcmChannel {
      var messageData: [String: Any] = [:]
      for (key, value) in userInfo {
        if let keyString = key as? String {
          messageData[keyString] = value
        }
      }
      
      messageData["notification_title"] = notification.request.content.title
      messageData["notification_body"] = notification.request.content.body
      messageData["message_type"] = "foreground"
      
      channel.invokeMethod("handleFCMMessage", arguments: messageData) { result in
        if let error = result as? FlutterError {
          print("❌ [iOS-FCM] Flutter 전달 오류: \(error.message ?? "Unknown")")
        } else {
          print("✅ [iOS-FCM] Flutter 전달 완료")
        }
      }
    } else {
      print("❌ [iOS-FCM] Method Channel 미초기화")
    }
    
    if #available(iOS 14.0, *) {
      completionHandler([[.banner, .badge, .sound]])
    } else {
      completionHandler([[.alert, .badge, .sound]])
    }
  }
  
  // 알림 탭했을 때 - Method Channel로 직접 전달
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    
    print("📬 [iOS-FCM] 알림 탭: \(response.notification.request.content.title)")
    
    if let channel = fcmChannel {
      var messageData: [String: Any] = [:]
      for (key, value) in userInfo {
        if let keyString = key as? String {
          messageData[keyString] = value
        }
      }
      
      messageData["notification_title"] = response.notification.request.content.title
      messageData["notification_body"] = response.notification.request.content.body
      messageData["message_type"] = "notification_tap"
      
      channel.invokeMethod("handleFCMMessage", arguments: messageData) { result in
        if let error = result as? FlutterError {
          print("❌ [iOS-FCM] Flutter 전달 오류: \(error.message ?? "Unknown")")
        } else {
          print("✅ [iOS-FCM] Flutter 전달 완료")
        }
      }
    } else {
      print("❌ [iOS-FCM] Method Channel 미초기화")
    }
    
    completionHandler()
  }
}

// Firebase Messaging 델리게이트
extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    guard let fcmToken = fcmToken else { return }
    print("✅ FCM 토큰 수신: \(fcmToken.prefix(20))...")
  }
}
