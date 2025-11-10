import UIKit
import Flutter
import Firebase
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Firebase 초기화
    FirebaseApp.configure()
    
    // Flutter 플러그인 등록
    GeneratedPluginRegistrant.register(with: self)
    
    // iOS 알림 설정
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
      
      let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
      UNUserNotificationCenter.current().requestAuthorization(
        options: authOptions,
        completionHandler: { granted, error in
          if granted {
            print("✅ iOS 알림 권한 허용됨")
          } else {
            print("❌ iOS 알림 권한 거부됨: \(error?.localizedDescription ?? "unknown")")
          }
        }
      )
    } else {
      // iOS 9 이하
      let settings: UIUserNotificationSettings =
        UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
      application.registerUserNotificationSettings(settings)
    }
    
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
    print("")
    print("="*60)
    print("🍎 APNs 토큰 수신 성공")
    print("="*60)
    let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
    print("📱 토큰: \(tokenString)")
    print("📊 토큰 길이: \(tokenString.count) 문자")
    print("")
    print("✅ Firebase에 APNs 토큰 전달 중...")
    
    // Firebase에 APNs 토큰 전달
    Messaging.messaging().apnsToken = deviceToken
    
    print("✅ APNs 토큰 전달 완료")
    print("   → Firebase가 이제 FCM 토큰을 생성합니다")
    print("="*60)
    print("")
  }
  
  // APNs 토큰 수신 실패
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("")
    print("="*60)
    print("❌ APNs 토큰 수신 실패")
    print("="*60)
    print("오류: \(error.localizedDescription)")
    print("")
    print("📋 해결 방법:")
    print("   1. Firebase Console에서 APNs 인증 키 업로드 확인")
    print("   2. Xcode: Capabilities → Push Notifications 추가")
    print("   3. 실제 iOS 기기에서 테스트 (시뮬레이터는 푸시 불가)")
    print("   4. 프로비저닝 프로파일에 Push Notification 권한 포함 확인")
    print("="*60)
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

// Firebase Messaging 델리게이트
extension AppDelegate: MessagingDelegate {
  // FCM 토큰 수신
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    guard let fcmToken = fcmToken else {
      print("❌ FCM 토큰이 nil입니다")
      return
    }
    
    print("")
    print("="*60)
    print("🔔 FCM 토큰 수신 (iOS)")
    print("="*60)
    print("📱 전체 토큰:")
    print(fcmToken)
    print("")
    print("📊 토큰 길이: \(fcmToken.count) 문자")
    print("✅ FCM 토큰 수신 완료")
    print("   → Flutter 앱에서 Firestore에 저장합니다")
    print("="*60)
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
