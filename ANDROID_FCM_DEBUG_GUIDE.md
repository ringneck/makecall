# Android FCM 수신 전화 화면 미표시 문제 디버깅 가이드

## 🔍 문제 증상

**Android에서 FCM 푸시 알림은 수신되지만, 수신 전화 화면(`IncomingCallScreen`)이 표시되지 않음**

---

## 🎯 디버그 로그 확인 방법

### **1. Android Logcat 실시간 확인**

```bash
# ADB로 연결된 Android 기기의 로그 확인
adb logcat | grep -E "FCM|INCOMING|DEBUG"

# 또는 Android Studio의 Logcat 창에서 필터링
Filter: "FCM" OR "INCOMING" OR "DEBUG"
```

### **2. 기대되는 디버그 로그 출력**

#### **A. 포그라운드 FCM 수신 시**

```
📨 포그라운드 메시지: 남궁현철 01026132471
📨 메시지 데이터: {linkedid: 1762843210.1787, call_type: voice, ...}
🔍 [FCM-DEBUG] 전체 메시지 구조:
   - notification.title: 남궁현철 01026132471
   - notification.body: 새 전화 수신(01026132471)
   - data keys: [linkedid, call_type, caller_num, channel, did]
   - data[linkedid]: 1762843210.1787 (String)
   - data[call_type]: voice (String)
   - data[caller_num]: 01026132471 (String)
   - data[channel]: PJSIP/DKCT-00000460 (String)
   - data[did]:  (String)
🔍 [FCM-DEBUG] 수신 전화 조건 체크:
   - hasIncomingCallType: false (type=null)
   - hasLinkedId: true (linkedid=1762843210.1787)
   - hasCallType: true (call_type=voice)
   - 최종 조건: true
📞 [FCM] 수신 전화 감지:
   - type: null
   - linkedid: 1762843210.1787
   - call_type: voice
📞 [FCM-INCOMING] 수신 전화 FCM 메시지 처리 시작
   - Platform: Android
🔍 [FCM-INCOMING] WebSocket 연결 상태: false
⚠️ [FCM-INCOMING] WebSocket 연결 없음 - FCM으로 처리
📞 [FCM-INCOMING] _showIncomingCallScreen() 호출 시작...
🎬 [FCM-SCREEN] _showIncomingCallScreen() 시작
   - _context: 있음
   - navigatorKey.currentContext: 있음
✅ [FCM-SCREEN] Context 확인 완료 (setContext 사용)
📞 [FCM] 수신 전화 화면 표시:
   발신자: 남궁현철
   번호: 01026132471
   링크ID: 1762843210.1787
   통화타입: voice
💾 [FCM-CALLHIST] 통화 기록 생성 시작
✅ [FCM-CALLHIST] 새 통화 기록 생성 완료
✅ [FCM-INCOMING] _showIncomingCallScreen() 호출 완료
```

#### **B. 백그라운드 FCM 수신 시**

```
🔔 백그라운드 메시지: 남궁현철 01026132471
🔔 백그라운드 메시지 데이터: {linkedid: 1762843210.1787, call_type: voice, ...}
📞 [FCM-BG] 백그라운드에서 수신 전화 감지:
   - type: null
   - linkedid: 1762843210.1787
   - call_type: voice
   - caller_num: 01026132471

(사용자가 알림을 탭하면)

🔔 [FCM] 백그라운드 알림 클릭됨: 남궁현철 01026132471
🔔 [FCM] 메시지 데이터: {linkedid: 1762843210.1787, ...}
📞 [FCM] 백그라운드에서 수신 전화 화면 표시 시작...
   - type: null
   - linkedid: 1762843210.1787
   - call_type: voice
(... 이후 포그라운드와 동일한 로그 ...)
```

---

## 🔍 문제 진단 체크리스트

### **1. FCM 메시지 데이터 확인**

#### **✅ 정상 케이스**
```
🔍 [FCM-DEBUG] 전체 메시지 구조:
   - data[linkedid]: 1762843210.1787 (String) ✅
   - data[call_type]: voice (String) ✅
```

#### **❌ 문제 케이스 1: linkedid 없음**
```
🔍 [FCM-DEBUG] 전체 메시지 구조:
   - data[linkedid]: null ❌
   - data[call_type]: voice (String) ✅

🔍 [FCM-DEBUG] 수신 전화 조건 체크:
   - hasLinkedId: false ❌
   - 최종 조건: false ❌
⚠️ [FCM-DEBUG] 수신 전화 조건 불만족 - 일반 알림으로 처리
```

**해결 방법**: FCM 전송 서버에서 `linkedid` 필드를 포함하도록 수정

#### **❌ 문제 케이스 2: call_type 없음**
```
🔍 [FCM-DEBUG] 전체 메시지 구조:
   - data[linkedid]: 1762843210.1787 (String) ✅
   - data[call_type]: null ❌

🔍 [FCM-DEBUG] 수신 전화 조건 체크:
   - hasCallType: false ❌
   - 최종 조건: false ❌
```

**해결 방법**: FCM 전송 서버에서 `call_type` 필드를 포함하도록 수정

---

### **2. WebSocket 연결 상태 확인**

#### **✅ 정상 케이스 (WebSocket 비활성)**
```
🔍 [FCM-INCOMING] WebSocket 연결 상태: false ✅
⚠️ [FCM-INCOMING] WebSocket 연결 없음 - FCM으로 처리 ✅
```

#### **⚠️ WebSocket 활성 (FCM 무시)**
```
🔍 [FCM-INCOMING] WebSocket 연결 상태: true
✅ [FCM-INCOMING] WebSocket 연결 활성 - 웹소켓으로 처리 (FCM 무시)
```

**원인**: WebSocket이 이미 연결되어 있으면 FCM은 백업용으로만 동작하며 화면을 표시하지 않음

**확인 방법**: 
- WebSocket 연결을 끊어보기
- 네트워크를 비활성화하고 FCM 테스트

---

### **3. Context 확인**

#### **✅ 정상 케이스**
```
🎬 [FCM-SCREEN] _showIncomingCallScreen() 시작
   - _context: 있음 ✅
   - navigatorKey.currentContext: 있음 ✅
✅ [FCM-SCREEN] Context 확인 완료 (setContext 사용)
```

#### **❌ 문제 케이스: Context 없음**
```
🎬 [FCM-SCREEN] _showIncomingCallScreen() 시작
   - _context: 없음 ❌
   - navigatorKey.currentContext: 없음 ❌
❌ [FCM-SCREEN] BuildContext와 NavigatorKey 모두 사용 불가
💡 main.dart에서 FCMService.setContext()를 호출하거나 앱이 완전히 시작될 때까지 기다리세요
🔧 해결 방법:
   1. main.dart에서 FCMService.setContext(context) 호출 확인
   2. navigatorKey가 MaterialApp에 설정되었는지 확인
```

**해결 방법**:

1. **main.dart에서 Context 설정 확인**:
   ```dart
   @override
   Widget build(BuildContext context) {
     // Context 설정 (앱 시작 시)
     FCMService.setContext(context);
     
     return MaterialApp(
       navigatorKey: navigatorKey, // GlobalKey 설정
       // ...
     );
   }
   ```

2. **navigatorKey가 MaterialApp에 설정되었는지 확인**:
   ```dart
   // main.dart
   final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
   
   void main() {
     runApp(MyApp());
   }
   
   class MyApp extends StatelessWidget {
     @override
     Widget build(BuildContext context) {
       return MaterialApp(
         navigatorKey: navigatorKey, // ← 이 설정이 있는지 확인
         // ...
       );
     }
   }
   ```

---

## 📊 일반적인 문제 패턴 및 해결 방법

### **패턴 1: FCM 데이터 구조 문제**

| 문제 | 로그 | 해결 방법 |
|------|------|----------|
| `linkedid` 없음 | `hasLinkedId: false` | FCM 전송 서버에 `linkedid` 필드 추가 |
| `call_type` 없음 | `hasCallType: false` | FCM 전송 서버에 `call_type` 필드 추가 |
| 필드명 오타 | `data[linkeId]: ...` (오타) | 필드명 확인: `linkedid` (소문자 d) |

### **패턴 2: WebSocket 우선 처리**

| 상황 | 동작 | 해결 방법 |
|------|------|----------|
| WebSocket 활성 | FCM 무시 (정상) | WebSocket 연결 해제 후 FCM 테스트 |
| WebSocket 비활성 | FCM 처리 (정상) | 그대로 진행 |

### **패턴 3: Context 문제**

| 문제 | 로그 | 해결 방법 |
|------|------|----------|
| Context 없음 | `_context: 없음` | `FCMService.setContext(context)` 호출 |
| navigatorKey 없음 | `navigatorKey.currentContext: 없음` | `MaterialApp`에 `navigatorKey` 설정 |

---

## 🧪 테스트 시나리오

### **시나리오 1: 포그라운드 FCM 수신**

1. **앱 실행 상태 유지**
2. **WebSocket 연결 비활성화** (네트워크 끄기 or 서버 중지)
3. **FCM 푸시 전송**
4. **로그 확인**:
   - `📞 [FCM] 수신 전화 감지` 출력 확인 ✅
   - `🎬 [FCM-SCREEN] _showIncomingCallScreen() 시작` 출력 확인 ✅
   - 수신 전화 화면 표시 확인 ✅

### **시나리오 2: 백그라운드 FCM 수신**

1. **앱을 백그라운드로 전환** (홈 버튼)
2. **FCM 푸시 전송**
3. **알림바에서 알림 탭**
4. **로그 확인**:
   - `📞 [FCM-BG] 백그라운드에서 수신 전화 감지` 출력 확인 ✅
   - `🔔 [FCM] 백그라운드 알림 클릭됨` 출력 확인 ✅
   - 수신 전화 화면 표시 확인 ✅

### **시나리오 3: WebSocket 활성 시 FCM 무시**

1. **앱 실행 및 WebSocket 연결 활성화**
2. **FCM 푸시 전송**
3. **로그 확인**:
   - `✅ [FCM-INCOMING] WebSocket 연결 활성 - 웹소켓으로 처리 (FCM 무시)` ✅
   - 수신 전화 화면은 표시되지 않음 (정상) ✅
   - WebSocket을 통해 수신 전화 처리 ✅

---

## 🔧 문제 해결 단계별 가이드

### **Step 1: 로그 수집**

```bash
# Android 기기 연결 후 로그 수집
adb logcat -c  # 기존 로그 삭제
adb logcat > fcm_debug.log  # 로그 파일로 저장

# FCM 테스트 수행

# Ctrl+C로 로그 수집 중지
# fcm_debug.log 파일 확인
```

### **Step 2: 로그 분석**

```bash
# FCM 관련 로그만 필터링
cat fcm_debug.log | grep -E "FCM|INCOMING|DEBUG"

# 수신 전화 조건 체크 확인
cat fcm_debug.log | grep "수신 전화 조건 체크"

# Context 확인
cat fcm_debug.log | grep "Context 확인"
```

### **Step 3: 문제 원인 파악**

1. **FCM 데이터 문제**:
   - `hasLinkedId: false` 또는 `hasCallType: false` 확인
   - FCM 전송 서버 데이터 구조 수정

2. **WebSocket 우선 처리**:
   - `WebSocket 연결 활성` 로그 확인
   - WebSocket 비활성화 후 재테스트

3. **Context 문제**:
   - `BuildContext와 NavigatorKey 모두 사용 불가` 로그 확인
   - `main.dart` 설정 확인 및 수정

### **Step 4: 문제 해결 후 재테스트**

- 수정 사항 적용
- 앱 재시작
- FCM 푸시 재전송
- 로그 재확인

---

## 📋 체크리스트

### **배포 전 확인사항**

- [ ] FCM 메시지 데이터에 `linkedid` 포함 확인
- [ ] FCM 메시지 데이터에 `call_type` 포함 확인
- [ ] `main.dart`에 `FCMService.setContext()` 호출 확인
- [ ] `MaterialApp`에 `navigatorKey` 설정 확인
- [ ] 포그라운드 FCM 수신 테스트 완료
- [ ] 백그라운드 FCM 수신 테스트 완료
- [ ] call_history 생성 확인
- [ ] WebSocket 활성 시 FCM 무시 동작 확인

---

## 💡 추가 디버깅 팁

### **1. FCM 토큰 확인**

```dart
// FCM 토큰이 정상 생성되었는지 확인
final token = await FirebaseMessaging.instance.getToken();
print('FCM Token: $token');
```

### **2. 알림 권한 확인**

```dart
// Android 13+ 알림 권한 확인
final settings = await FirebaseMessaging.instance.requestPermission();
print('Notification Permission: ${settings.authorizationStatus}');
```

### **3. 백그라운드 핸들러 등록 확인**

```dart
// main.dart에서 확인
FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
```

---

## 📞 문의 및 지원

문제가 계속되는 경우, 다음 정보를 제공해주세요:

1. **전체 로그 파일** (`adb logcat` 출력)
2. **FCM 메시지 데이터 구조** (실제 전송되는 JSON)
3. **문제 발생 시나리오** (포그라운드/백그라운드)
4. **앱 상태** (WebSocket 연결 여부)

---

**🎯 목표**: 이 가이드를 통해 Android FCM 수신 전화 화면이 표시되지 않는 문제의 정확한 원인을 파악하고 해결할 수 있습니다!
