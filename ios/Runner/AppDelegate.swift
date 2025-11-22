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
    
    // Naver Login SDK 초기화 (flutter_naver_login 플러그인이 자동 처리)
    // CocoaPods를 통해 NaverThirdPartyLogin이 설치되면 플러그인이 자동으로 초기화
    print("ℹ️ Naver Login SDK는 flutter_naver_login 플러그인이 자동 초기화합니다")
    
    // Flutter 플러그인 등록
    GeneratedPluginRegistrant.register(with: self)
    
    // Flutter Method Channel 설정 (FlutterViewController 직접 생성)
    if let windowScene = application.connectedScenes.first as? UIWindowScene,
       let window = windowScene.windows.first,
       let controller = window.rootViewController as? FlutterViewController {
      fcmChannel = FlutterMethodChannel(
        name: "com.makecall.app/fcm",
        binaryMessenger: controller.binaryMessenger
      )
    } else {
      // Fallback for older iOS versions
      if let controller = window?.rootViewController as? FlutterViewController {
        fcmChannel = FlutterMethodChannel(
          name: "com.makecall.app/fcm",
          binaryMessenger: controller.binaryMessenger
        )
      }
    }
    
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
  
  // 포그라운드에서 알림 수신 - Flutter Method Channel로 명시적 전달
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo
    
    #if DEBUG
    print("📨 [iOS-FCM] 포그라운드 알림: \(notification.request.content.title)")
    #endif
    
    let messageType = userInfo["type"] as? String
    let hasLinkedId = userInfo["linkedid"] != nil
    let hasCallType = userInfo["call_type"] != nil
    
    // 조건 1: 기기 승인 관련 메시지 (요청, 응답, 취소)
    let isDeviceApproval = messageType == "device_approval_request" ||
                          messageType == "device_approval_response" ||
                          messageType == "device_approval_cancelled"
    // 조건 2: 수신 전화 (linkedid + call_type 존재)
    let isIncomingCall = hasLinkedId && hasCallType
    // 조건 3: 착신전환 알림
    let isCallForward = messageType?.starts(with: "call_forward") ?? false
    
    // 수신 전화, 기기 승인, 착신전환: Flutter로 전달
    if isIncomingCall || isDeviceApproval || isCallForward {
      DispatchQueue.main.async { [weak self] in
        guard let self = self, let channel = self.fcmChannel else {
          #if DEBUG
          print("❌ [iOS-FCM] Method Channel 없음")
          #endif
          return
        }
        
        // userInfo를 String으로 변환
        var flutterData: [String: Any] = [:]
        for (key, value) in userInfo {
          if let keyString = key.base as? String {
            flutterData[keyString] = value
          }
        }
        
        #if DEBUG
        let messageType = isIncomingCall ? "수신 전화" : (isDeviceApproval ? "기기 승인" : "착신전환")
        print("🔄 [iOS-FCM] \(messageType) → Flutter")
        #endif
        
        channel.invokeMethod("onForegroundMessage", arguments: flutterData) { result in
          #if DEBUG
          if let error = result as? FlutterError {
            print("❌ [iOS-FCM] Flutter 호출 실패: \(error.message ?? "")")
          }
          #endif
        }
      }
      
      // 네이티브 알림 차단
      completionHandler([])
      return
    }
    
    // 일반 메시지
    completionHandler([.banner, .sound, .badge])
  }
  
  // 알림 탭했을 때 - Flutter Method Channel로 명시적 전달
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    
    #if DEBUG
    print("📬 [iOS-FCM-BG] 알림 탭: \(response.notification.request.content.title)")
    #endif
    
    let messageType = userInfo["type"] as? String
    let hasLinkedId = userInfo["linkedid"] != nil
    let hasCallType = userInfo["call_type"] != nil
    
    // 조건 1: 기기 승인 관련 메시지 (요청, 응답, 취소)
    let isDeviceApproval = messageType == "device_approval_request" ||
                          messageType == "device_approval_response" ||
                          messageType == "device_approval_cancelled"
    // 조건 2: 수신 전화 (linkedid + call_type 존재)
    let isIncomingCall = hasLinkedId && hasCallType
    // 조건 3: 착신전환 알림
    let isCallForward = messageType?.starts(with: "call_forward") ?? false
    
    // 기기 승인, 수신 전화, 착신전환: Flutter로 전달
    if isDeviceApproval || isIncomingCall || isCallForward {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
        guard let self = self, let channel = self.fcmChannel else {
          #if DEBUG
          print("❌ [iOS-FCM-BG] Method Channel 없음")
          #endif
          return
        }
        
        // userInfo를 String으로 변환
        var flutterData: [String: Any] = [:]
        for (key, value) in userInfo {
          if let keyString = key.base as? String {
            flutterData[keyString] = value
          }
        }
        
        flutterData["_notification_tap"] = true
        
        #if DEBUG
        print("🔄 [iOS-FCM-BG] Flutter로 전송")
        #endif
        
        channel.invokeMethod("onNotificationTap", arguments: flutterData) { result in
          #if DEBUG
          if let error = result as? FlutterError {
            print("❌ [iOS-FCM-BG] Flutter 호출 실패: \(error.message ?? "")")
          }
          #endif
        }
      }
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
