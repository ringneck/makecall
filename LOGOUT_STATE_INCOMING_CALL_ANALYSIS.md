# 🔍 로그아웃 상태 수신전화 처리 분석

## 📋 현재 상황

**문제:**
- 앱 종료 상태에서 푸시 알림 수신 ✅
- 알림 탭 → 앱 실행
- **현재 상태: 로그아웃 상태** ❌
- IncomingCallScreen 표시 불가 (AuthService.currentUser = null)

**요구사항:**
1. 로그아웃 상태에서도 수신전화 풀스크린 표시
2. 우측 상단에 닫기 버튼 추가
3. 로그인 없이 수신내역 확인 가능

---

## 🔍 현재 코드 분석

### **1. FCM 메시지 처리 흐름**

```dart
// lib/services/fcm_service.dart Line 180-189
FirebaseMessaging.onMessage.listen(_messageHandler.handleForegroundMessage);
FirebaseMessaging.onMessageOpenedApp.listen(_messageHandler.handleMessageOpenedApp);

_messaging.getInitialMessage().then((RemoteMessage? message) {
  if (message != null) {
    _messageHandler.handleMessageOpenedApp(message);
  }
});
```

**문제점:**
- `onMessageOpenedApp` → `FCMIncomingCallHandler.handleIncomingCallFCM()`
- `handleIncomingCallFCM()` → `AuthService.currentUser?.uid` 체크
- 로그아웃 상태면 `currentUser == null` → 처리 중단

---

### **2. 수신전화 화면 표시 조건**

```dart
// lib/services/fcm/fcm_incoming_call_handler.dart Line 47-80
final authService = AuthService();
final userId = authService.currentUser?.uid;

if (userId != null) {
  // 알림 설정 확인
  final settings = await _notificationService.getUserNotificationSettings(userId);
  final pushEnabled = settings?['pushEnabled'] ?? true;
  
  if (!pushEnabled) {
    return; // 알림 설정 꺼져있으면 중단
  }
}

// dcmiwsEnabled 체크
final dcmiwsEnabled = authService.currentUserModel?.dcmiwsEnabled ?? false;
```

**문제점:**
1. `userId == null` (로그아웃 상태) → 알림 설정 확인 불가
2. `currentUserModel == null` → dcmiwsEnabled 체크 불가
3. 결과: 수신전화 화면 표시 안 됨

---

### **3. IncomingCallScreen 생성**

```dart
// lib/services/fcm/fcm_incoming_call_handler.dart Line 414-438
await navigator.push(
  MaterialPageRoute(
    fullscreenDialog: true,
    settings: const RouteSettings(name: '/incoming_call'),
    builder: (context) => IncomingCallScreen(
      callerName: callerName,
      callerNumber: callerNumber,
      linkedid: linkedid,
      channel: channel,
      receiverNumber: receiverNumber,
      callType: callType,
      shouldPlaySound: soundEnabled,
      shouldVibrate: vibrationEnabled,
      onAccept: () { Navigator.of(context).pop(); },
      onReject: () { Navigator.of(context).pop(); },
    ),
  ),
);
```

**문제점:**
- `onAccept`, `onReject` 콜백이 단순히 `pop()` 만 호출
- 실제 통화 연결 로직은 IncomingCallScreen 내부에서 Firebase Auth 필요
- 로그아웃 상태에서는 통화 연결 불가

---

## ✅ 해결 방안

### **방안 1: 로그아웃 상태 전용 수신전화 화면 (권장)**

**개념:**
```
로그아웃 상태
  ↓
제한된 IncomingCallScreen 표시
  - 발신자 정보만 표시
  - 수락/거부 버튼 대신 "확인" 버튼
  - 우측 상단 닫기 버튼
  - 통화 연결 불가 (로그인 필요 안내)
```

**구현 위치:**
```dart
// lib/screens/call/incoming_call_screen_logged_out.dart (신규 생성)
class IncomingCallScreenLoggedOut extends StatelessWidget {
  final String callerName;
  final String callerNumber;
  final String receiverNumber;
  final String linkedid;
  final VoidCallback onClose;
  
  // 통화 기능 없음 - 정보 표시만
}
```

**FCM 핸들러 수정:**
```dart
// lib/services/fcm/fcm_incoming_call_handler.dart
Future<void> handleIncomingCallFCM(RemoteMessage message) async {
  final authService = AuthService();
  final isLoggedOut = authService.currentUser == null;
  
  if (isLoggedOut) {
    // 로그아웃 상태 전용 화면
    await showIncomingCallScreenLoggedOut(message);
  } else {
    // 기존 풀기능 화면
    await showIncomingCallScreen(message, ...);
  }
}
```

**장점:**
- ✅ 로그아웃 상태에서도 수신전화 확인 가능
- ✅ 통화 연결은 로그인 후에만 가능 (보안 유지)
- ✅ 우측 상단 닫기 버튼으로 화면 종료
- ✅ 수신 내역은 call_history에 기록되어 로그인 후 확인 가능

**단점:**
- ⚠️ 실시간 통화 불가 (로그인 필요)

---

### **방안 2: Firebase Anonymous Auth 자동 로그인**

**개념:**
```
앱 종료 상태
  ↓
푸시 수신 → 앱 실행
  ↓
currentUser == null 감지
  ↓
Firebase Anonymous Auth 자동 로그인
  ↓
임시 userId 생성
  ↓
IncomingCallScreen 표시 (제한된 기능)
```

**구현:**
```dart
// lib/services/fcm/fcm_incoming_call_handler.dart
Future<void> handleIncomingCallFCM(RemoteMessage message) async {
  final authService = AuthService();
  
  if (authService.currentUser == null) {
    // 익명 로그인
    await FirebaseAuth.instance.signInAnonymously();
  }
  
  // 수신전화 화면 표시
  await showIncomingCallScreen(message, ...);
}
```

**장점:**
- ✅ 기존 IncomingCallScreen 재사용 가능
- ✅ Firebase Auth 필요한 기능 사용 가능

**단점:**
- ⚠️ 익명 계정과 실제 계정 매핑 복잡
- ⚠️ 보안 이슈 (익명 계정으로 통화 연결?)
- ⚠️ call_history 연결 문제

---

### **방안 3: 수신전화 정보를 SharedPreferences에 저장**

**개념:**
```
앱 종료 상태
  ↓
푸시 수신 (백그라운드 핸들러)
  ↓
수신전화 정보를 SharedPreferences에 저장
  ↓
알림 탭 → 앱 실행
  ↓
로그인 상태 체크
  ↓
로그아웃 상태면:
  - SharedPreferences에서 수신전화 정보 읽기
  - 간단한 다이얼로그/스낵바로 표시
  - "로그인하여 수신내역 확인" 버튼
```

**구현:**
```dart
// lib/main.dart 백그라운드 핸들러
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase 초기화
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(...);
  }
  
  // 수신전화 정보 저장
  if (message.data['type'] == 'incoming_call') {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_incoming_call', jsonEncode({
      'callerName': message.data['caller_name'],
      'callerNumber': message.data['caller_num'],
      'timestamp': DateTime.now().toIso8601String(),
    }));
  }
}

// 앱 실행 후 체크
void _checkPendingIncomingCall() async {
  final prefs = await SharedPreferences.getInstance();
  final pendingCall = prefs.getString('pending_incoming_call');
  
  if (pendingCall != null) {
    final callData = jsonDecode(pendingCall);
    
    // 로그아웃 상태면 간단한 알림 표시
    if (AuthService().currentUser == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('부재중 전화'),
          content: Text('${callData['callerName']} (${callData['callerNumber']})'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('닫기'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // 로그인 화면으로 이동
                Navigator.pushNamed(context, '/login');
              },
              child: Text('로그인'),
            ),
          ],
        ),
      );
    }
    
    // 정보 삭제
    await prefs.remove('pending_incoming_call');
  }
}
```

**장점:**
- ✅ 구현 간단
- ✅ 로그인 유도 가능
- ✅ 보안 문제 없음

**단점:**
- ⚠️ 풀스크린 수신전화 화면 표시 안 됨
- ⚠️ 간단한 알림만 표시

---

## 🎯 권장 방안: **방안 1 (로그아웃 전용 화면)**

### **구현 계획:**

**1. 새 화면 생성**
```
lib/screens/call/incoming_call_screen_logged_out.dart
```

**기능:**
- 발신자 정보 표시 (이름, 번호)
- 수신 시간 표시
- 우측 상단 닫기 버튼 (✕)
- 하단 "로그인하여 통화하기" 버튼
- 통화 연결 기능 없음 (읽기 전용)

**2. FCM 핸들러 분기**
```dart
if (AuthService().currentUser == null) {
  // 로그아웃 전용 화면
  showIncomingCallScreenLoggedOut();
} else {
  // 기존 풀기능 화면
  showIncomingCallScreen();
}
```

**3. call_history 기록**
- 백엔드(Firebase Functions)에서 이미 기록됨
- 로그인 후 통화 내역에서 확인 가능

---

## 📊 비교표

| 항목 | 방안 1 (전용 화면) | 방안 2 (익명 로그인) | 방안 3 (간단 알림) |
|------|-------------------|---------------------|-------------------|
| **풀스크린 표시** | ✅ | ✅ | ❌ |
| **구현 난이도** | 중 | 중 | 하 |
| **보안** | ✅ 안전 | ⚠️ 복잡 | ✅ 안전 |
| **통화 연결** | ❌ 불가 | ⚠️ 제한적 | ❌ 불가 |
| **수신내역 확인** | ✅ 가능 | ⚠️ 복잡 | ✅ 간단 |
| **사용자 경험** | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ |

---

## 💡 결론

**권장:** 방안 1 (로그아웃 상태 전용 수신전화 화면)

**이유:**
1. ✅ 사용자 경험 최고
2. ✅ 보안 문제 없음
3. ✅ 구현 명확함
4. ✅ 로그인 유도 자연스러움

**다음 단계:**
1. `IncomingCallScreenLoggedOut` 위젯 생성
2. FCM 핸들러에 로그아웃 상태 분기 추가
3. 테스트 (로그아웃 → 앱 종료 → 푸시 수신)
