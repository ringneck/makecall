# 📞 수신 전화 푸시 메시지 가이드

## 📋 목차
1. [메시지 형식 개요](#메시지-형식-개요)
2. [iOS APN 형식](#ios-apn-형식)
3. [필수 데이터 필드](#필수-데이터-필드)
4. [Flutter 처리 흐름](#flutter-처리-흐름)
5. [테스트 예제](#테스트-예제)

---

## 메시지 형식 개요

iOS 포그라운드 상태에서 수신 전화 푸시를 받으려면 다음 조건을 만족해야 합니다:

### ✅ 수신 전화 감지 조건

```dart
// 조건 1: type == 'incoming_call' (선택)
final hasIncomingCallType = message.data['type'] == 'incoming_call';

// 조건 2: linkedid와 call_type이 모두 있음 (필수)
final hasLinkedId = message.data['linkedid'] != null && 
                    (message.data['linkedid'] as String).isNotEmpty;
final hasCallType = message.data['call_type'] != null;

// 최종: 둘 중 하나라도 만족하면 수신 전화로 처리
if (hasIncomingCallType || (hasLinkedId && hasCallType)) {
  _handleIncomingCallFCM(message);
}
```

---

## iOS APN 형식

### 완전한 메시지 예제

```json
{
  "to": "FCM_TOKEN_HERE",
  "notification": {
    "title": "남궁현철 01026132471",
    "body": "새 전화 수신(01026132471)"
  },
  "data": {
    "linkedid": "1762843210.1787",
    "call_type": "external",
    "caller_num": "01026132471",
    "caller_name": "남궁현철",
    "channel": "PJSIP/DKCT-00000460",
    "receiverNumber": "07045144801",
    "timestamp": "2025-11-13T23:01:21.330122"
  },
  "apns": {
    "payload": {
      "aps": {
        "alert": {
          "title": "남궁현철 01026132471",
          "body": "새 전화 수신(01026132471)"
        },
        "sound": "default",
        "badge": 1,
        "content-available": 1,
        "mutable-content": 1,
        "category": "CALL_CATEGORY",
        "thread-id": "incoming_call"
      }
    }
  }
}
```

---

## 필수 데이터 필드

### 1️⃣ 통화 식별 정보 (필수)

| 필드 | 타입 | 설명 | 예제 |
|------|------|------|------|
| `linkedid` | String | 통화 고유 ID (Asterisk Linked ID) | `"1762843210.1787"` |
| `call_type` | String | 통화 타입 | `"external"`, `"voice"`, `"video"` |

**중요:** 이 두 필드가 모두 있어야 수신 전화로 감지됩니다!

---

### 2️⃣ 발신자 정보 (필수)

| 필드 | 타입 | 설명 | 예제 | 기본값 |
|------|------|------|------|--------|
| `caller_num` | String | 발신 전화번호 | `"01026132471"` | `"번호 없음"` |
| `caller_name` | String | 발신자 이름 | `"남궁현철"` | `"알 수 없음"` |
| `caller_avatar` | String | 프로필 이미지 URL | `"https://..."` | `null` |

**필드명 호환:**
- `caller_num`, `caller_number`, `callerNumber` 모두 지원
- `caller_name`, `callerName` 모두 지원
- `caller_avatar`, `callerAvatar` 모두 지원

---

### 3️⃣ 수신자 정보 (선택)

| 필드 | 타입 | 설명 | 예제 | 기본값 |
|------|------|------|------|--------|
| `receiverNumber` | String | 수신 전화번호 (내선/DID) | `"07045144801"` | `""` |
| `receiver_number` | String | 대체 필드명 | `"07045144801"` | `""` |
| `extension` | String | 내선번호 | `"1001"` | `""` |
| `did` | String | DID 번호 | `"070-1234-5678"` | `""` |

**우선순위:**
```dart
receiverNumber > receiver_number > extension > did
```

---

### 4️⃣ Asterisk 정보 (선택)

| 필드 | 타입 | 설명 | 예제 |
|------|------|------|------|
| `channel` | String | Asterisk 채널 정보 | `"PJSIP/DKCT-00000460"` |
| `timestamp` | String | 메시지 타임스탬프 | `"2025-11-13T23:01:21.330122"` |

---

## Flutter 처리 흐름

### iOS Native → Flutter 전달 흐름

```
1. iOS Native (AppDelegate.swift)
   ├─ userNotificationCenter.willPresent
   ├─ userInfo 수신
   ├─ 조건 체크:
   │  ├─ type == "device_approval_request" → 기기 승인
   │  └─ linkedid && call_type → 수신 전화 ✅
   └─ DispatchQueue.main.async
      └─ fcmChannel.invokeMethod("onForegroundMessage", arguments: data)

2. Flutter (main.dart)
   ├─ _handleIOSForegroundMessage(MethodCall)
   ├─ APS 데이터 파싱
   ├─ RemoteMessage 객체 생성
   └─ FCMService().handleRemoteMessage(message, isForeground: true)

3. FCMService (fcm_service.dart)
   ├─ _handleForegroundMessage(RemoteMessage)
   ├─ 수신 전화 조건 체크
   ├─ _handleIncomingCallFCM(message)
   ├─ WebSocket 연결 체크 (연결 시 FCM 무시)
   └─ _showIncomingCallScreen(message)
      ├─ 발신자 정보 추출
      ├─ 통화 기록 생성 (_createCallHistory)
      └─ IncomingCallScreen 표시 (fullscreenDialog)
```

---

### iOS Native 조건 체크 코드

```swift
// 조건 1: 기기 승인 요청
let isDeviceApproval = messageType == "device_approval_request"

// 조건 2: 수신 전화 (linkedid + call_type 존재)
let hasLinkedId = userInfo["linkedid"] != nil
let hasCallType = userInfo["call_type"] != nil
let isIncomingCall = hasLinkedId && hasCallType

// ✅ 기기 승인 또는 수신 전화일 때 Flutter로 전달
if isDeviceApproval || isIncomingCall {
  // Method Channel 호출
}
```

---

### Flutter 데이터 추출 코드

```dart
// 발신자 정보 추출 (여러 필드명 지원)
final callerName = message.data['caller_name'] ?? 
                   message.data['callerName'] ?? 
                   message.notification?.title?.split(' ').first ?? 
                   '알 수 없음';

final callerNumber = message.data['caller_num'] ?? 
                     message.data['caller_number'] ?? 
                     message.data['callerNumber'] ?? 
                     _extractPhoneNumber(message.notification?.title) ??
                     _extractPhoneNumber(message.notification?.body) ??
                     '번호 없음';

// 통화 메타데이터 추출
final linkedid = message.data['linkedid'] ?? 
                 message.data['linkedId'] ?? 
                 DateTime.now().millisecondsSinceEpoch.toString();

final callType = message.data['call_type'] ?? 
                 message.data['callType'] ?? 
                 message.data['type'] ??
                 'voice';

final receiverNumber = message.data['receiver_number'] ?? 
                       message.data['receiverNumber'] ?? 
                       message.data['extension'] ??
                       message.data['did'] ??
                       '';
```

---

## 테스트 예제

### 최소 요구사항 메시지

```json
{
  "to": "FCM_TOKEN_HERE",
  "notification": {
    "title": "📞 수신 전화",
    "body": "010-1234-5678"
  },
  "data": {
    "linkedid": "1704067200.123456",
    "call_type": "voice",
    "caller_num": "010-1234-5678"
  },
  "apns": {
    "payload": {
      "aps": {
        "alert": {
          "title": "📞 수신 전화",
          "body": "010-1234-5678"
        },
        "sound": "default",
        "content-available": 1
      }
    }
  }
}
```

---

### cURL 테스트 명령어

```bash
curl -X POST https://fcm.googleapis.com/fcm/send \
  -H "Authorization: Bearer YOUR_SERVER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "to": "FCM_TOKEN_HERE",
    "notification": {
      "title": "남궁현철 01026132471",
      "body": "새 전화 수신(01026132471)"
    },
    "data": {
      "linkedid": "1762843210.1787",
      "call_type": "external",
      "caller_num": "01026132471",
      "caller_name": "남궁현철",
      "channel": "PJSIP/DKCT-00000460",
      "receiverNumber": "07045144801"
    },
    "apns": {
      "payload": {
        "aps": {
          "alert": {
            "title": "남궁현철 01026132471",
            "body": "새 전화 수신(01026132471)"
          },
          "sound": "default",
          "content-available": 1
        }
      }
    }
  }'
```

---

## 실제 메시지 예제 (검증됨)

아래는 실제로 iOS에서 수신된 메시지 형식입니다:

```swift
[
  AnyHashable("linkedid"): 1762843210.1787,
  AnyHashable("call_type"): external,
  AnyHashable("caller_num"): 01026132471,
  AnyHashable("caller_name"): 남궁현철,
  AnyHashable("channel"): PJSIP/DKCT-00000460,
  AnyHashable("receiverNumber"): 07045144801,
  AnyHashable("timestamp"): 2025-11-13T23:01:21.330122,
  AnyHashable("gcm.message_id"): 1763042481733863,
  AnyHashable("google.c.fid"): eGNvWDcp6EmHrqLPgp_Lt6,
  AnyHashable("google.c.sender.id"): 793164633643,
  AnyHashable("google.c.a.e"): 1,
  AnyHashable("aps"): {
    alert = {
      body = "새 전화 수신(01026132471)";
      title = "남궁현철 01026132471";
    };
    badge = 1;
    category = "CALL_CATEGORY";
    "content-available" = 1;
    "mutable-content" = 1;
    sound = default;
    "thread-id" = "incoming_call";
  }
]
```

**처리 결과:**
- ✅ iOS Native가 수신 전화로 감지 (`linkedid` + `call_type` 존재)
- ✅ Method Channel을 통해 Flutter로 전달
- ✅ Flutter에서 RemoteMessage 생성
- ✅ FCMService가 수신 전화 처리
- ✅ IncomingCallScreen 자동 표시

---

## 예상 로그 출력

### iOS Native 로그

```
📨 [iOS-FCM] 포그라운드 알림 수신: 남궁현철 01026132471
📨 [iOS-FCM] userInfo: [...]
📞 [iOS-FCM] 수신 전화 감지 - Flutter로 전달
   - linkedid: 1762843210.1787
   - call_type: external
   - caller_num: 01026132471
🔄 [iOS-FCM] Flutter로 전송할 데이터 keys: [...]
✅ [iOS-FCM] Flutter 호출 성공
✅ [iOS-FCM] 처리 완료 (네이티브 알림 표시 안 함)
```

---

### Flutter 로그

```
📲 [Flutter-FCM] iOS Method Channel 호출: onForegroundMessage
📲 [Flutter-FCM] iOS 포그라운드 메시지 수신
📲 데이터 keys: [linkedid, call_type, caller_num, ...]
✅ [Flutter-FCM] RemoteMessage 생성 완료
   - type: null
   - approvalRequestId: null
✅ [Flutter-FCM] FCM 서비스 처리 완료

═══════════════════════════════════════════════
📨 [FLUTTER-FCM] _handleForegroundMessage() 호출됨!
═══════════════════════════════════════════════
📨 포그라운드 메시지: 남궁현철 01026132471
📨 메시지 데이터: {linkedid: 1762843210.1787, call_type: external, ...}

🔍 [FCM-DEBUG] 수신 전화 조건 체크:
   - hasIncomingCallType: false (type=null)
   - hasLinkedId: true (linkedid=1762843210.1787)
   - hasCallType: true (call_type=external)
   - 최종 조건: true

📞 [FCM] 수신 전화 감지:
   - type: null
   - linkedid: 1762843210.1787
   - call_type: external

📞 [FCM-INCOMING] 수신 전화 FCM 메시지 처리 시작
🔍 [FCM-INCOMING] WebSocket 연결 상태: false
⚠️ [FCM-INCOMING] WebSocket 연결 없음 - FCM으로 처리
📞 [FCM-INCOMING] _showIncomingCallScreen() 호출 시작...

🎬 [FCM-SCREEN] _showIncomingCallScreen() 시작
✅ [FCM-SCREEN] Context 확인 완료 (setContext 사용)
📞 [FCM-SCREEN] 수신 전화 데이터 추출:
   발신자: 남궁현철
   번호: 01026132471
   채널: PJSIP/DKCT-00000460
   링크ID: 1762843210.1787
   수신번호: 07045144801
   통화타입: external

🎬 [FCM] 수신 전화 화면 표시
✅ [FCM-INCOMING] _showIncomingCallScreen() 호출 완료
```

---

## 문제 해결

### ❌ 수신 전화 화면이 표시되지 않음

**원인 1: 필수 필드 누락**
```json
// ❌ 잘못된 예
{
  "data": {
    "caller_num": "010-1234-5678"
    // linkedid 없음!
    // call_type 없음!
  }
}

// ✅ 올바른 예
{
  "data": {
    "linkedid": "1704067200.123456",
    "call_type": "voice",
    "caller_num": "010-1234-5678"
  }
}
```

**원인 2: WebSocket 연결 활성**
- WebSocket이 연결되어 있으면 FCM 메시지는 무시됩니다
- 로그 확인: `✅ [FCM-INCOMING] WebSocket 연결 활성 - 웹소켓으로 처리 (FCM 무시)`

---

### ⚠️ iOS Native에서 Flutter 호출 실패

**원인: Method Channel 초기화 전 메시지 수신**
```
❌ [iOS-FCM] Method Channel이 없음
```

**해결:** 앱이 완전히 시작된 후 푸시 테스트

---

## 업데이트 이력

- **2025-01-13**: iOS 포그라운드 수신 전화 지원 추가
  - AppDelegate에 수신 전화 조건 추가 (`linkedid` + `call_type`)
  - 기기 승인과 수신 전화 모두 Method Channel로 전달
  - 수신 전화 화면 자동 표시 기능 완성

---

## 참고 자료

- **iOS AppDelegate**: `ios/Runner/AppDelegate.swift`
- **Flutter Main**: `lib/main.dart`
- **FCM Service**: `lib/services/fcm_service.dart`
- **Incoming Call Screen**: `lib/screens/call/incoming_call_screen.dart`

---

## 라이선스

이 문서는 MAKECALL 프로젝트의 일부입니다.
