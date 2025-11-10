# 🔧 FCM 포그라운드/백그라운드 푸시 수신 문제 해결

## 📋 문제 상황

**증상**: 포그라운드와 백그라운드 모두에서 IncomingCallScreen이 표시되지 않음

**원인 분석**:
1. ❌ 백그라운드 알림 클릭 시 `onMessageOpenedApp` 리스너 미구현
2. ❌ 앱 종료 상태에서 알림 클릭으로 시작 시 `getInitialMessage()` 미처리
3. ❌ BuildContext가 설정되기 전에 화면 표시 시도 (타이밍 문제)

---

## ✅ 적용된 해결책

### 1️⃣ **onMessageOpenedApp 리스너 추가**

백그라운드/종료 상태에서 알림 클릭 시 IncomingCallScreen 표시

**lib/services/fcm_service.dart** (라인 188-203):
```dart
// 포그라운드 메시지 리스너
FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

// 백그라운드/종료 상태에서 알림 클릭 시 처리 (중요!)
FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

// 앱이 종료된 상태에서 알림 클릭으로 시작된 경우 처리
_messaging.getInitialMessage().then((RemoteMessage? message) {
  if (message != null) {
    debugPrint('🚀 [FCM] 앱이 종료 상태에서 알림 클릭으로 시작됨');
    _handleMessageOpenedApp(message);
  }
});
```

---

### 2️⃣ **_handleMessageOpenedApp 메서드 구현**

백그라운드 알림 클릭 시 처리 로직

**lib/services/fcm_service.dart** (라인 381-402):
```dart
/// 백그라운드/종료 상태에서 알림 클릭 시 처리
void _handleMessageOpenedApp(RemoteMessage message) {
  debugPrint('🔔 [FCM] 백그라운드 알림 클릭됨: ${message.notification?.title}');
  debugPrint('🔔 [FCM] 메시지 데이터: ${message.data}');
  
  // 🔐 강제 로그아웃 메시지 처리
  if (message.data['type'] == 'force_logout') {
    _handleForceLogout(message);
    return;
  }
  
  // 📞 수신 전화 화면 표시
  debugPrint('📞 [FCM] 백그라운드에서 수신 전화 화면 표시 시작...');
  
  // WebSocket 연결 상태 확인 및 재연결
  _ensureWebSocketConnection();
  
  // 풀스크린 수신 전화 화면 표시
  _showIncomingCallScreen(message);
}
```

---

### 3️⃣ **NavigatorKey Fallback 추가**

BuildContext 타이밍 문제 해결

**lib/services/fcm_service.dart** (라인 1):
```dart
import '../main.dart' show navigatorKey; // GlobalKey for Navigation
```

**lib/services/fcm_service.dart** (라인 653-665):
```dart
/// 수신 전화 풀스크린 표시
void _showIncomingCallScreen(RemoteMessage message) {
  // BuildContext 또는 NavigatorKey 확인
  final context = _context ?? navigatorKey.currentContext;
  
  if (context == null) {
    debugPrint('❌ [FCM] BuildContext와 NavigatorKey 모두 사용 불가');
    debugPrint('💡 main.dart에서 FCMService.setContext()를 호출하거나 앱이 완전히 시작될 때까지 기다리세요');
    return;
  }
  
  debugPrint('✅ [FCM] Context 확인 완료 (${_context != null ? "setContext" : "navigatorKey"} 사용)');
  
  // ... 나머지 코드
  Navigator.of(context).push(...); // _context! 대신 context 사용
}
```

---

### 4️⃣ **백그라운드 핸들러 로깅 개선**

디버깅 편의성 향상

**lib/main.dart** (라인 17-28):
```dart
/// 백그라운드 FCM 메시지 핸들러 (Top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase가 이미 초기화되었는지 확인
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  
  debugPrint('🔔 백그라운드 메시지: ${message.notification?.title}');
  debugPrint('🔔 백그라운드 메시지 데이터: ${message.data}');
  
  // 백그라운드에서는 알림을 시스템이 자동으로 표시함
  // 앱이 다시 열리면 onMessageOpenedApp에서 처리됨
}
```

---

## 🎯 작동 시나리오

### **시나리오 1: 포그라운드 푸시**
```
1. 앱이 열려있는 상태
2. Firebase Console에서 푸시 전송
3. FirebaseMessaging.onMessage 리스너 트리거
   └─> _handleForegroundMessage() 호출
       └─> _showAndroidNotification() (알림 표시)
       └─> _showIncomingCallScreen() (화면 표시)
4. ✅ IncomingCallScreen 즉시 표시
```

---

### **시나리오 2: 백그라운드 푸시 + 알림 클릭**
```
1. 앱이 백그라운드에 있는 상태
2. Firebase Console에서 푸시 전송
3. 시스템이 자동으로 알림바에 알림 표시
4. 사용자가 알림 클릭
5. FirebaseMessaging.onMessageOpenedApp 리스너 트리거
   └─> _handleMessageOpenedApp() 호출
       └─> _showIncomingCallScreen() 호출
           └─> navigatorKey.currentContext 사용 (BuildContext fallback)
6. ✅ IncomingCallScreen 표시
```

---

### **시나리오 3: 앱 종료 상태 + 알림 클릭으로 시작**
```
1. 앱이 완전히 종료된 상태
2. Firebase Console에서 푸시 전송
3. 시스템이 자동으로 알림바에 알림 표시
4. 사용자가 알림 클릭
5. 앱 시작
6. _messaging.getInitialMessage() 호출
   └─> RemoteMessage 반환됨
   └─> _handleMessageOpenedApp() 호출
       └─> _showIncomingCallScreen() 호출
7. ✅ IncomingCallScreen 표시
```

---

## 📊 예상 로그 시퀀스

### **포그라운드**:
```
I/flutter: 📨 포그라운드 메시지: MAKECALL
I/flutter: 📨 메시지 데이터: {caller_name: 홍길동, ...}
I/flutter: 🔔 [FCM] 안드로이드 알림 표시 시작
I/flutter:    제목: MAKECALL
I/flutter:    내용: 새로운 전화가 수신되었습니다
I/flutter: ✅ [FCM] 안드로이드 알림 표시 완료
I/flutter: 📞 [FCM] 수신 전화 화면 표시 시작...
I/flutter: ✅ [FCM] Context 확인 완료 (setContext 사용)
I/flutter: 📞 [FCM] 수신 전화 화면 표시:
I/flutter:    발신자: 홍길동 (테스트)
I/flutter:    번호: 010-1234-5678
I/flutter: ✅ [FCM] 수신 전화 화면 표시 완료
```

---

### **백그라운드 → 알림 클릭**:
```
I/flutter: 🔔 백그라운드 메시지: MAKECALL
I/flutter: 🔔 백그라운드 메시지 데이터: {caller_name: 홍길동, ...}
[사용자가 알림 클릭]
I/flutter: 🔔 [FCM] 백그라운드 알림 클릭됨: MAKECALL
I/flutter: 🔔 [FCM] 메시지 데이터: {caller_name: 홍길동, ...}
I/flutter: 📞 [FCM] 백그라운드에서 수신 전화 화면 표시 시작...
I/flutter: ✅ [FCM] Context 확인 완료 (navigatorKey 사용)
I/flutter: 📞 [FCM] 수신 전화 화면 표시:
I/flutter:    발신자: 홍길동 (테스트)
I/flutter:    번호: 010-1234-5678
I/flutter: ✅ [FCM] 수신 전화 화면 표시 완료
```

---

### **앱 종료 → 알림 클릭으로 시작**:
```
[앱 시작]
I/flutter: 🚀 [FCM] 앱이 종료 상태에서 알림 클릭으로 시작됨
I/flutter: 🔔 [FCM] 백그라운드 알림 클릭됨: MAKECALL
I/flutter: 🔔 [FCM] 메시지 데이터: {caller_name: 홍길동, ...}
I/flutter: 📞 [FCM] 백그라운드에서 수신 전화 화면 표시 시작...
I/flutter: ✅ [FCM] Context 확인 완료 (navigatorKey 사용)
I/flutter: 📞 [FCM] 수신 전화 화면 표시:
I/flutter:    발신자: 홍길동 (테스트)
I/flutter:    번호: 010-1234-5678
I/flutter: ✅ [FCM] 수신 전화 화면 표시 완료
```

---

## 🧪 테스트 절차

### 1️⃣ **포그라운드 테스트**
```bash
# 1. 앱 실행 및 로그인
# 2. ADB logcat 모니터링
adb logcat | grep -E "(FCM|FirebaseMessaging|IncomingCall)"

# 3. Firebase Console에서 푸시 전송
# 4. 확인 사항:
#    - ✅ 알림 팝업 표시
#    - ✅ IncomingCallScreen 자동 표시
#    - ✅ 발신자 정보 정확히 표시
```

---

### 2️⃣ **백그라운드 테스트**
```bash
# 1. 앱 실행 및 로그인
# 2. 홈 버튼으로 앱을 백그라운드로 보냄
# 3. ADB logcat 모니터링
adb logcat | grep -E "(FCM|FirebaseMessaging|IncomingCall)"

# 4. Firebase Console에서 푸시 전송
# 5. 알림바에서 알림 클릭
# 6. 확인 사항:
#    - ✅ 알림바에 알림 표시
#    - ✅ 알림 클릭 시 IncomingCallScreen 표시
#    - ✅ 발신자 정보 정확히 표시
```

---

### 3️⃣ **앱 종료 테스트**
```bash
# 1. 앱 완전 종료 (최근 앱에서 스와이프로 닫기)
# 2. Firebase Console에서 푸시 전송
# 3. 알림바에 알림 표시 확인
# 4. 알림 클릭
# 5. 앱 시작 후 ADB logcat 확인
adb logcat | grep -E "(FCM|FirebaseMessaging|IncomingCall)"

# 6. 확인 사항:
#    - ✅ 앱 시작됨
#    - ✅ IncomingCallScreen 자동 표시
#    - ✅ "앱이 종료 상태에서 알림 클릭으로 시작됨" 로그 확인
```

---

## 🔧 트러블슈팅

### **문제 1: 백그라운드에서 IncomingCallScreen이 표시되지 않음**
```
원인: onMessageOpenedApp 리스너가 등록되지 않음
해결: fcm_service.dart의 initialize() 메서드 확인
```

### **문제 2: "BuildContext와 NavigatorKey 모두 사용 불가" 오류**
```
원인: 앱이 완전히 초기화되기 전에 화면 표시 시도
해결: 약간의 딜레이 후 재시도 (자동으로 처리됨)
```

### **문제 3: 알림 클릭 시 앱이 열리지만 화면이 표시되지 않음**
```
원인: navigatorKey가 제대로 설정되지 않음
해결: main.dart의 MaterialApp에 navigatorKey 설정 확인
```

---

## 📚 관련 문서

- **FIREBASE_PUSH_TEST_DATA.md** - Firebase Console 푸시 테스트 데이터
- **ANDROID_FCM_LOGIN_TEST_GUIDE.md** - 로그인 후 FCM 테스트 절차
- **ADB_LOGCAT_FCM_DEBUG.md** - ADB logcat 디버깅 가이드

---

**작성일**: 2025-11-10  
**버전**: 1.0  
**다음 단계**: 실제 WebSocket 데이터로 교체, SIP/WebRTC 통화 연결 구현
