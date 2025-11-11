# iOS FCM 수신 전화 화면 미표시 문제 해결 가이드

## 🔍 문제 분석

### **증상**
iOS에서 FCM 푸시 알림은 정상 수신되지만, 수신 전화 화면(`IncomingCallScreen`)이 표시되지 않음

### **사용자 로그 분석**
```
📬 [NOTIFICATION] 알림 탭됨
   - Title: 남궁현철 01026132471
   - Body: 새 전화 수신(01026132471)
   - UserInfo: [
       AnyHashable("call_type"): voice,      // ✅ 있음
       AnyHashable("linkedid"): 1762843210.1787,  // ✅ 있음
       AnyHashable("channel"): PJSIP/DKCT-00000460,
       AnyHashable("caller_num"): ,          // 빈 값
       AnyHashable("did"): ,                  // 빈 값
       // ❌ 'type' 필드가 없음!
     ]
```

### **근본 원인**
iOS FCM 데이터 구조와 Android FCM 데이터 구조가 다름:

| 필드 | Android FCM | iOS FCM | 비고 |
|------|------------|---------|------|
| `type` | ✅ `'incoming_call'` | ❌ **없음** | 핵심 문제 |
| `linkedid` | ✅ 있음 | ✅ 있음 | 통화 고유 ID |
| `call_type` | ✅ 있음 | ✅ `'voice'` | 통화 유형 |
| `caller_number` | ✅ 있음 | ❌ `caller_num` | 필드명 다름 |

**기존 코드**는 `type == 'incoming_call'`만 체크하므로 iOS에서 동작하지 않음:
```dart
// ❌ iOS에서 실패하는 기존 코드
if (message.data['type'] == 'incoming_call') {
  _handleIncomingCallFCM(message);  // iOS는 type이 없어서 실행 안 됨!
}
```

---

## ✅ 해결 방법

### **1. iOS와 Android 모두 지원하는 조건 추가**

```dart
// ✅ iOS와 Android 모두 동작하는 수정 코드
final hasIncomingCallType = message.data['type'] == 'incoming_call';  // Android
final hasLinkedId = message.data['linkedid'] != null &&               // iOS
                    (message.data['linkedid'] as String).isNotEmpty;
final hasCallType = message.data['call_type'] != null;                // iOS

if (hasIncomingCallType || (hasLinkedId && hasCallType)) {
  // Android: type == 'incoming_call' 조건 만족
  // iOS: linkedid + call_type 조건 만족
  _handleIncomingCallFCM(message);
}
```

### **2. 수정된 메서드**

#### **A. _handleForegroundMessage() - 포그라운드 메시지 처리**
```dart
void _handleForegroundMessage(RemoteMessage message) {
  // ... 기존 force_logout, device_approval 처리 ...
  
  // 📞 수신 전화 메시지 처리 (Android와 iOS 모두 지원)
  final hasIncomingCallType = message.data['type'] == 'incoming_call';
  final hasLinkedId = message.data['linkedid'] != null && 
                      (message.data['linkedid'] as String).isNotEmpty;
  final hasCallType = message.data['call_type'] != null;
  
  if (hasIncomingCallType || (hasLinkedId && hasCallType)) {
    debugPrint('📞 [FCM] 수신 전화 감지:');
    debugPrint('   - type: ${message.data['type']}');
    debugPrint('   - linkedid: ${message.data['linkedid']}');
    debugPrint('   - call_type: ${message.data['call_type']}');
    _handleIncomingCallFCM(message);
    return;
  }
}
```

#### **B. _handleMessageOpenedApp() - 백그라운드 알림 클릭 처리**
```dart
void _handleMessageOpenedApp(RemoteMessage message) {
  // ... 기존 force_logout, device_approval 처리 ...
  
  // 📞 수신 전화 메시지 처리 (Android와 iOS 모두 지원)
  final hasIncomingCallType = message.data['type'] == 'incoming_call';
  final hasLinkedId = message.data['linkedid'] != null && 
                      (message.data['linkedid'] as String).isNotEmpty;
  final hasCallType = message.data['call_type'] != null;
  
  if (hasIncomingCallType || (hasLinkedId && hasCallType)) {
    debugPrint('📞 [FCM] 백그라운드에서 수신 전화 화면 표시 시작...');
    debugPrint('   - type: ${message.data['type']}');
    debugPrint('   - linkedid: ${message.data['linkedid']}');
    debugPrint('   - call_type: ${message.data['call_type']}');
    _waitForContextAndShowIncomingCall(message);
    return;
  }
}
```

---

## 🎯 동작 흐름

### **Android FCM 수신 시**
```
1. FCM 메시지 수신
   ↓
2. message.data['type'] == 'incoming_call' ✅
   ↓
3. _handleIncomingCallFCM() 호출
   ↓
4. _showIncomingCallScreen() 호출
   ↓
5. call_history 생성 + 화면 표시 ✅
```

### **iOS FCM 수신 시**
```
1. FCM 메시지 수신
   ↓
2. message.data['type'] == 'incoming_call' ❌ (type 필드 없음)
   BUT linkedid + call_type 존재 ✅
   ↓
3. _handleIncomingCallFCM() 호출
   ↓
4. _showIncomingCallScreen() 호출
   ↓
5. call_history 생성 + 화면 표시 ✅
```

---

## 📱 테스트 방법

### **1. iOS 실제 기기 테스트**
```bash
# iOS 앱 빌드
cd /home/user/flutter_app
flutter build ios --release

# Xcode에서 실제 기기에 설치
open ios/Runner.xcworkspace
```

### **2. FCM 푸시 테스트**
실제 PBX에서 전화 수신 시:
```
1. iOS 기기에서 앱 실행 (포그라운드)
2. 전화 수신
3. FCM 푸시 도착
4. ✅ 수신 전화 화면 자동 표시 확인
5. ✅ Call History에 통화 기록 생성 확인
```

### **3. 백그라운드 테스트**
```
1. iOS 기기에서 앱을 백그라운드로 전환
2. 전화 수신
3. FCM 알림 탭
4. ✅ 수신 전화 화면 자동 표시 확인
5. ✅ Call History에 통화 기록 생성 확인
```

---

## 🔍 디버그 로그 확인

수정 후 iOS에서 다음 로그가 출력되어야 함:

### **포그라운드 수신 시**
```
📨 포그라운드 메시지: 남궁현철 01026132471
📨 메시지 데이터: {linkedid: 1762843210.1787, call_type: voice, ...}
📞 [FCM] 수신 전화 감지:
   - type: null
   - linkedid: 1762843210.1787
   - call_type: voice
📞 [FCM-INCOMING] 수신 전화 FCM 메시지 처리
⚠️ [FCM-INCOMING] WebSocket 연결 없음 - FCM으로 처리
✅ [FCM] Context 확인 완료
📞 [FCM] 수신 전화 화면 표시:
   발신자: 남궁현철
   번호: 01026132471
   링크ID: 1762843210.1787
   통화타입: voice
💾 [FCM-CALLHIST] 통화 기록 생성 시작
✅ [FCM-CALLHIST] 새 통화 기록 생성 완료
```

### **백그라운드 알림 클릭 시**
```
🔔 [FCM] 백그라운드 알림 클릭됨: 남궁현철 01026132471
🔔 [FCM] 메시지 데이터: {linkedid: 1762843210.1787, call_type: voice, ...}
📞 [FCM] 백그라운드에서 수신 전화 화면 표시 시작...
   - type: null
   - linkedid: 1762843210.1787
   - call_type: voice
✅ [FCM] Context 확인 완료
📞 [FCM] 수신 전화 화면 표시:
   (... 동일한 로그 ...)
```

---

## 📊 변경 사항 요약

| 항목 | 변경 전 | 변경 후 |
|------|--------|--------|
| **Android 지원** | ✅ 동작 | ✅ 동작 (변경 없음) |
| **iOS 지원** | ❌ 화면 미표시 | ✅ **화면 정상 표시** |
| **조건 체크** | `type == 'incoming_call'` | `type OR (linkedid + call_type)` |
| **디버그 로그** | 최소한 | 상세 로그 추가 |
| **call_history** | 생성 안 됨 | ✅ 정상 생성 |

---

## ✅ 완료 체크리스트

배포 전 확인사항:

- [x] `_handleForegroundMessage()` 수정 완료
- [x] `_handleMessageOpenedApp()` 수정 완료
- [x] Flutter analyze 통과 (에러 없음)
- [x] GitHub 커밋 및 푸시 완료
- [ ] iOS 실제 기기 테스트 (사용자 수행 필요)
- [ ] 포그라운드 수신 테스트
- [ ] 백그라운드 알림 클릭 테스트
- [ ] call_history 생성 확인

---

## 🚀 배포

```bash
# GitHub에서 최신 코드 받기
git pull origin main

# iOS 앱 빌드
flutter build ios --release

# Xcode에서 실제 기기에 설치 및 테스트
open ios/Runner.xcworkspace
```

---

## 📝 참고사항

### **Android APK는 이미 배포 완료**
- arm64-v8a: 21MB
- armeabi-v7a: 19MB
- x86_64: 22MB

### **iOS 빌드 필요**
현재 Android APK만 빌드되었으므로, iOS 테스트를 위해서는 별도로 iOS 앱을 빌드해야 합니다.

### **FCM 데이터 표준화 권장**
향후 iOS와 Android FCM 데이터 구조를 통일하면 더 간단한 조건문으로 처리 가능:
```json
{
  "type": "incoming_call",      // 모든 플랫폼에 추가
  "linkedid": "...",
  "call_type": "voice",
  "caller_number": "...",        // iOS도 caller_number로 통일
}
```
