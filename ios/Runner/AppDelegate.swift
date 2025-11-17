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
  
  // 포그라운드에서 알림 수신 - Flutter Method Channel로 명시적 전달
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo
    
    print("📨 [iOS-FCM] 포그라운드 알림 수신: \(notification.request.content.title)")
    print("📨 [iOS-FCM] userInfo: \(userInfo)")
    
    // 🔧 FIX: 모든 FCM 메시지를 Flutter로 전달 (기기 승인 + 수신 전화 + 착신전환)
    let messageType = userInfo["type"] as? String
    let hasLinkedId = userInfo["linkedid"] != nil
    let hasCallType = userInfo["call_type"] != nil
    
    // 조건 1: 기기 승인 요청
    let isDeviceApproval = messageType == "device_approval_request"
    // 조건 2: 수신 전화 (linkedid + call_type 존재)
    let isIncomingCall = hasLinkedId && hasCallType
    // 조건 3: 착신전환 알림
    let isCallForward = messageType?.starts(with: "call_forward") ?? false
    
    if isDeviceApproval {
      print("🔔 [iOS-FCM] 기기 승인 요청 감지 - Flutter로 전달")
    } else if isIncomingCall {
      print("📞 [iOS-FCM] 수신 전화 감지 - Flutter로 전달")
      print("   - linkedid: \(userInfo["linkedid"] ?? "없음")")
      print("   - call_type: \(userInfo["call_type"] ?? "없음")")
      print("   - caller_num: \(userInfo["caller_num"] ?? "없음")")
    } else if isCallForward {
      print("📲 [iOS-FCM] 착신전환 알림 감지 - Flutter로 전달")
      print("   - type: \(messageType ?? "없음")")
      print("   - extensionNumber: \(userInfo["extensionNumber"] ?? "없음")")
    }
    
    // ✅ 기기 승인, 수신 전화는 Flutter로만 전달 (네이티브 알림 차단)
    // ✅ 착신전환은 네이티브 알림으로 표시 (사운드 포함)
    if isDeviceApproval || isIncomingCall {
      // 기기 승인 + 수신 전화: Flutter로 전달, 네이티브 알림 차단
      DispatchQueue.main.async { [weak self] in
        guard let self = self, let channel = self.fcmChannel else {
          print("❌ [iOS-FCM] Method Channel이 없음")
          return
        }
        
        // userInfo를 String으로 변환
        var flutterData: [String: Any] = [:]
        for (key, value) in userInfo {
          if let keyString = key.base as? String {
            flutterData[keyString] = value
          }
        }
        
        print("🔄 [iOS-FCM] Flutter로 전송할 데이터 keys: \(flutterData.keys.sorted())")
        
        channel.invokeMethod("onForegroundMessage", arguments: flutterData) { result in
          if let error = result as? FlutterError {
            print("❌ [iOS-FCM] Flutter 호출 실패: \(error.message ?? "알 수 없는 오류")")
          } else {
            print("✅ [iOS-FCM] Flutter 호출 성공")
          }
        }
      }
      
      // 네이티브 알림 차단
      completionHandler([])
      print("✅ [iOS-FCM] Flutter 전달 완료, 네이티브 알림 차단됨")
      return
    } else if isCallForward {
      // 착신전환: Flutter로 전달 + 네이티브 알림 표시 (사운드 포함)
      DispatchQueue.main.async { [weak self] in
        guard let self = self, let channel = self.fcmChannel else {
          print("❌ [iOS-FCM] Method Channel이 없음")
          return
        }
        
        // userInfo를 String으로 변환
        var flutterData: [String: Any] = [:]
        for (key, value) in userInfo {
          if let keyString = key.base as? String {
            flutterData[keyString] = value
          }
        }
        
        print("🔄 [iOS-FCM] 착신전환 - Flutter로 전송")
        
        channel.invokeMethod("onForegroundMessage", arguments: flutterData) { result in
          if let error = result as? FlutterError {
            print("❌ [iOS-FCM] Flutter 호출 실패: \(error.message ?? "알 수 없는 오류")")
          } else {
            print("✅ [iOS-FCM] Flutter 호출 성공")
          }
        }
      }
      
      // 🔔 네이티브 알림 표시 (사운드 + 배너)
      completionHandler([.banner, .sound, .badge])
      print("✅ [iOS-FCM] 착신전환 - 네이티브 알림 표시 (사운드 포함)")
      return
    }
    
    // 일반 메시지는 Firebase SDK에 처리 위임
    print("ℹ️ [iOS-FCM] 일반 메시지 - Firebase SDK 기본 동작 사용")
    completionHandler([.banner, .sound, .badge])
  }
  
  // 알림 탭했을 때 - Flutter Method Channel로 명시적 전달
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    
    print("📬 [iOS-FCM] 백그라운드 알림 탭: \(response.notification.request.content.title)")
    print("📬 [iOS-FCM] userInfo: \(userInfo)")
    
    // 🔧 FIX: 포그라운드와 동일하게 수신 전화 + 착신전환도 Method Channel로 전달
    let messageType = userInfo["type"] as? String
    let hasLinkedId = userInfo["linkedid"] != nil
    let hasCallType = userInfo["call_type"] != nil
    
    // 조건 1: 기기 승인 요청
    let isDeviceApproval = messageType == "device_approval_request"
    // 조건 2: 수신 전화 (linkedid + call_type 존재)
    let isIncomingCall = hasLinkedId && hasCallType
    // 조건 3: 착신전환 알림
    let isCallForward = messageType?.starts(with: "call_forward") ?? false
    
    if isDeviceApproval {
      print("🔔 [iOS-FCM-BG] 기기 승인 요청 알림 탭 - Flutter로 전달")
    } else if isIncomingCall {
      print("📞 [iOS-FCM-BG] 수신 전화 알림 탭 - Flutter로 전달")
      print("   - linkedid: \(userInfo["linkedid"] ?? "없음")")
      print("   - call_type: \(userInfo["call_type"] ?? "없음")")
      print("   - caller_num: \(userInfo["caller_num"] ?? "없음")")
    } else if isCallForward {
      print("📲 [iOS-FCM-BG] 착신전환 알림 탭 - Flutter로 전달")
      print("   - type: \(messageType ?? "없음")")
      print("   - extensionNumber: \(userInfo["extensionNumber"] ?? "없음")")
    }
    
    // ✅ 기기 승인, 수신 전화, 착신전환일 때 Flutter로 전달
    if isDeviceApproval || isIncomingCall || isCallForward {
      // 약간의 딜레이를 주어 Flutter가 준비될 시간 확보
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
        guard let self = self, let channel = self.fcmChannel else {
          print("❌ [iOS-FCM-BG] Method Channel이 없음")
          return
        }
        
        // userInfo를 String으로 변환
        var flutterData: [String: Any] = [:]
        for (key, value) in userInfo {
          if let keyString = key.base as? String {
            flutterData[keyString] = value
          }
        }
        
        // 백그라운드 알림 탭임을 표시
        flutterData["_notification_tap"] = true
        
        print("🔄 [iOS-FCM-BG] Flutter로 전송할 데이터 keys: \(flutterData.keys.sorted())")
        
        channel.invokeMethod("onNotificationTap", arguments: flutterData) { result in
          if let error = result as? FlutterError {
            print("❌ [iOS-FCM-BG] Flutter 호출 실패: \(error.message ?? "알 수 없는 오류")")
          } else {
            print("✅ [iOS-FCM-BG] Flutter 호출 성공")
          }
        }
      }
    } else {
      print("ℹ️ [iOS-FCM-BG] 일반 메시지 (기기 승인/수신 전화/착신전환 아님) - Firebase SDK 기본 동작 사용")
      // Firebase SDK의 기본 동작 (FirebaseMessaging.onMessageOpenedApp)
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
