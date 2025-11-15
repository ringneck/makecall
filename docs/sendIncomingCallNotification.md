# 📞 sendIncomingCallNotification 함수 사용 가이드

## 개요

`sendIncomingCallNotification`은 **외부 전화 시스템(PBX/Asterisk)이 HTTP POST 요청으로 호출**하는 **Firebase Cloud Function 엔드포인트**입니다.

외부 전화 시스템에서 수신 전화가 걸려올 때, 해당 사용자의 모든 디바이스로 FCM 푸시 알림을 전송합니다.

---

## 🎯 주요 기능

- **자동 사용자 식별**: 수신 내선번호로 사용자 자동 검색
- **멀티 디바이스 지원**: 사용자의 모든 등록된 디바이스에 동시 푸시 전송
- **통화 기록 자동 생성**: Firestore에 통화 정보 자동 저장
- **중복 방지**: linkedid 기반 중복 통화 기록 방지
- **CORS 지원**: 웹 앱에서도 직접 호출 가능

---

## 📡 API 엔드포인트

### **URL**
```
https://us-central1-[YOUR-PROJECT-ID].cloudfunctions.net/sendIncomingCallNotification
```

### **HTTP 메서드**
```
POST
```

### **Content-Type**
```
application/json
```

---

## 📋 요청 파라미터

### **Request Body (JSON)**

| 파라미터 | 타입 | 필수 | 설명 | 예시 |
|---------|------|------|------|------|
| `callerNumber` | string | ✅ 필수 | 발신자 전화번호 | "02-1234-5678" |
| `callerName` | string | ⭕ 선택 | 발신자 이름 | "홍길동" |
| `receiverNumber` | string | ✅ 필수 | 수신자 내선번호 | "1001" |
| `linkedid` | string | ✅ 필수 | 통화 고유 ID | "1234567890.123456" |
| `channel` | string | ⭕ 선택 | SIP 채널 정보 | "SIP/1001-00000001" |
| `callType` | string | ⭕ 선택 | 통화 유형 | "external" 또는 "internal" |

### **요청 예시**

```json
{
  "callerNumber": "02-1234-5678",
  "callerName": "홍길동",
  "receiverNumber": "1001",
  "linkedid": "1234567890.123456",
  "channel": "SIP/1001-00000001",
  "callType": "external"
}
```

---

## 🔄 처리 흐름

```
┌─────────────────┐
│  PBX/Asterisk   │  ① 수신 전화 발생
│   전화 시스템     │
└────────┬────────┘
         │ HTTP POST 요청
         │ (callerNumber, receiverNumber, linkedid)
         ▼
┌─────────────────────────────────────────────┐
│  sendIncomingCallNotification (Cloud Fn)    │
├─────────────────────────────────────────────┤
│                                             │
│  ② my_extensions 조회                       │
│     WHERE accountCode == receiverNumber     │
│     OR extension == receiverNumber          │
│     → userId 추출                           │
│                                             │
│  ③ fcm_tokens 조회                          │
│     WHERE userId == userId                  │
│     AND isActive == true                    │
│     → 활성화된 모든 FCM 토큰 추출            │
│                                             │
│  ④ call_history 생성                        │
│     Document ID: linkedid                   │
│     - userId, callerNumber, callerName      │
│     - status: "fcm_notification"            │
│     - timestamp: 서버 타임스탬프             │
│                                             │
│  ⑤ FCM 멀티캐스트 전송                      │
│     - 모든 활성 토큰에 푸시 알림 전송        │
│     - Android: high priority                │
│     - iOS: badge + sound                    │
│                                             │
└────────┬────────────────────────────────────┘
         │ FCM Push Notification
         ▼
┌─────────────────────────────────────────────┐
│  사용자의 모든 디바이스                      │
│  📱 스마트폰, 💻 태블릿, 🖥️ 웹               │
└─────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────┐
│  IncomingCallScreen 표시                    │
│  - 발신자 정보 표시                          │
│  - 통화 벨소리 재생                          │
│  - 수락/거절 버튼                            │
└─────────────────────────────────────────────┘
```

---

## 💡 실제 사용 예시

### **1. Asterisk Dialplan에서 호출**

```bash
; extensions.conf
[from-pstn]
exten => _X.,1,NoOp(수신 전화: ${CALLERID(num)} → ${EXTEN})
same => n,Set(CURL_RESULT=${CURL(
  https://us-central1-your-project.cloudfunctions.net/sendIncomingCallNotification,
  {
    "callerNumber":"${CALLERID(num)}",
    "callerName":"${CALLERID(name)}",
    "receiverNumber":"${EXTEN}",
    "linkedid":"${UNIQUEID}",
    "channel":"${CHANNEL}",
    "callType":"external"
  }
)})
same => n,NoOp(FCM 전송 결과: ${CURL_RESULT})
same => n,Dial(SIP/${EXTEN},30)
same => n,Hangup()
```

### **2. FreePBX Custom Dialplan**

```bash
; /etc/asterisk/extensions_custom.conf
[from-trunk-custom]
exten => _X.,1,AGI(agi://localhost/incoming_call_fcm.agi,${EXTEN})
same => n,Goto(from-trunk,${EXTEN},1)
```

### **3. curl 명령어로 테스트**

```bash
curl -X POST \
  https://us-central1-your-project.cloudfunctions.net/sendIncomingCallNotification \
  -H "Content-Type: application/json" \
  -d '{
    "callerNumber": "010-1234-5678",
    "callerName": "테스트 발신자",
    "receiverNumber": "1001",
    "linkedid": "test-'$(date +%s)'",
    "callType": "external"
  }'
```

### **4. Node.js에서 호출**

```javascript
const axios = require('axios');

async function notifyIncomingCall(callData) {
  try {
    const response = await axios.post(
      'https://us-central1-your-project.cloudfunctions.net/sendIncomingCallNotification',
      {
        callerNumber: callData.callerNumber,
        callerName: callData.callerName,
        receiverNumber: callData.receiverNumber,
        linkedid: callData.linkedid,
        channel: callData.channel,
        callType: 'external'
      }
    );
    
    console.log('✅ FCM 전송 성공:', response.data);
  } catch (error) {
    console.error('❌ FCM 전송 실패:', error.response?.data || error.message);
  }
}

// 사용 예시
notifyIncomingCall({
  callerNumber: '02-1234-5678',
  callerName: '홍길동',
  receiverNumber: '1001',
  linkedid: Date.now().toString(),
  channel: 'SIP/1001-00000001'
});
```

### **5. Python에서 호출**

```python
import requests
import time

def notify_incoming_call(call_data):
    url = 'https://us-central1-your-project.cloudfunctions.net/sendIncomingCallNotification'
    
    payload = {
        'callerNumber': call_data['caller_number'],
        'callerName': call_data.get('caller_name', call_data['caller_number']),
        'receiverNumber': call_data['receiver_number'],
        'linkedid': call_data['linkedid'],
        'channel': call_data.get('channel', ''),
        'callType': call_data.get('call_type', 'external')
    }
    
    try:
        response = requests.post(url, json=payload)
        response.raise_for_status()
        print(f"✅ FCM 전송 성공: {response.json()}")
    except requests.exceptions.RequestException as e:
        print(f"❌ FCM 전송 실패: {e}")

# 사용 예시
notify_incoming_call({
    'caller_number': '010-1234-5678',
    'caller_name': '테스트 발신자',
    'receiver_number': '1001',
    'linkedid': str(int(time.time())),
    'channel': 'SIP/1001-00000001',
    'call_type': 'external'
})
```

---

## 📤 응답 형식

### **성공 응답 (200 OK)**

```json
{
  "success": true,
  "message": "FCM notifications sent successfully",
  "linkedid": "1234567890.123456",
  "tokensCount": 2,
  "successCount": 2,
  "failureCount": 0
}
```

### **오류 응답**

#### **400 Bad Request - 필수 파라미터 누락**
```json
{
  "error": "Missing required parameters",
  "required": ["callerNumber", "receiverNumber", "linkedid"]
}
```

#### **404 Not Found - 내선번호 없음**
```json
{
  "error": "Extension not found",
  "receiverNumber": "1001"
}
```

#### **404 Not Found - FCM 토큰 없음**
```json
{
  "error": "No active FCM tokens",
  "userId": "user123"
}
```

#### **405 Method Not Allowed**
```json
{
  "error": "Method Not Allowed"
}
```

---

## 🚨 오류 처리 가이드

| HTTP 상태 | 오류 상황 | 원인 | 해결 방법 |
|-----------|----------|------|-----------|
| `400` | 필수 파라미터 누락 | `callerNumber`, `receiverNumber`, `linkedid` 중 하나가 없음 | 요청 본문에 필수 파라미터 포함 확인 |
| `404` | 내선번호를 찾을 수 없음 | `my_extensions` 컬렉션에 해당 내선번호가 없음 | Firebase Console에서 `my_extensions` 컬렉션 확인 및 내선 등록 |
| `404` | 활성 FCM 토큰 없음 | 사용자가 앱에 로그인한 적이 없거나 FCM 토큰이 만료됨 | 사용자에게 앱 로그인 요청 |
| `405` | 메서드 오류 | POST가 아닌 다른 메서드(GET, PUT 등) 사용 | POST 메서드로 요청 |
| `500` | 서버 내부 오류 | Firebase 연결 오류, 권한 문제 등 | Cloud Function 로그 확인 |

---

## 🔍 데이터베이스 구조

### **my_extensions 컬렉션**
```javascript
{
  userId: "user123",
  extension: "1001",              // 내선번호
  accountCode: "02-1234-5678",    // 외부 전화번호 (선택)
  name: "홍길동",
  isActive: true
}
```

### **fcm_tokens 컬렉션**
```javascript
{
  userId: "user123",
  fcmToken: "eXaMpLeFcMToKeN...",
  deviceId: "device123",
  platform: "android",
  isActive: true,
  createdAt: Timestamp,
  lastUsedAt: Timestamp
}
```

### **call_history 컬렉션**
```javascript
{
  // Document ID = linkedid
  userId: "user123",
  callerNumber: "02-1234-5678",
  callerName: "홍길동",
  receiverNumber: "1001",
  channel: "SIP/1001-00000001",
  linkedid: "1234567890.123456",
  callType: "incoming",
  callSubType: "external",
  status: "fcm_notification",      // 이 함수로 생성된 기록
  extensionUsed: "1001",
  timestamp: Timestamp,
  createdAt: Timestamp
}
```

---

## 📱 FCM 메시지 구조

### **Android 알림**
```json
{
  "notification": {
    "title": "수신전화",
    "body": "홍길동"
  },
  "data": {
    "type": "incoming_call",
    "caller_number": "02-1234-5678",
    "caller_name": "홍길동",
    "receiver_number": "1001",
    "linkedid": "1234567890.123456",
    "channel": "SIP/1001-00000001",
    "call_type": "external",
    "timestamp": "2024-01-15T10:30:00.000Z"
  },
  "android": {
    "priority": "high",
    "notification": {
      "channelId": "incoming_call_channel",
      "sound": "default",
      "priority": "high"
    }
  }
}
```

### **iOS 알림**
```json
{
  "notification": {
    "title": "수신전화",
    "body": "홍길동"
  },
  "data": {
    "type": "incoming_call",
    "caller_number": "02-1234-5678",
    "caller_name": "홍길동",
    "receiver_number": "1001",
    "linkedid": "1234567890.123456",
    "channel": "SIP/1001-00000001",
    "call_type": "external",
    "timestamp": "2024-01-15T10:30:00.000Z"
  },
  "apns": {
    "payload": {
      "aps": {
        "sound": "default",
        "badge": 1
      }
    }
  }
}
```

---

## 🔐 보안 고려사항

### **현재 구현**
- ✅ CORS 허용 (`Access-Control-Allow-Origin: *`)
- ✅ POST 메서드만 허용
- ✅ 필수 파라미터 검증
- ⚠️ **인증 없음** - 누구나 호출 가능

### **프로덕션 환경 권장사항**

1. **API 키 인증 추가**
```javascript
const apiKey = req.headers['x-api-key'];
if (apiKey !== functions.config().api.key) {
  res.status(401).json({ error: 'Unauthorized' });
  return;
}
```

2. **IP 화이트리스트 설정**
```javascript
const allowedIPs = ['203.0.113.1', '203.0.113.2'];
const clientIP = req.ip;
if (!allowedIPs.includes(clientIP)) {
  res.status(403).json({ error: 'Forbidden' });
  return;
}
```

3. **Rate Limiting 적용**
```javascript
const { RateLimiterMemory } = require('rate-limiter-flexible');
const rateLimiter = new RateLimiterMemory({
  points: 10,      // 10 requests
  duration: 60,    // per 60 seconds
});
```

---

## 📊 모니터링 및 로그

### **Cloud Functions 로그 확인**
```bash
# Firebase CLI로 실시간 로그 확인
firebase functions:log --only sendIncomingCallNotification

# 최근 100줄 로그 확인
firebase functions:log --only sendIncomingCallNotification --lines 100
```

### **로그 출력 예시**
```
📞 [FCM-INCOMING] 수신전화 FCM 요청 수신
   발신번호: 02-1234-5678
   발신자: 홍길동
   수신번호: 1001
   Linkedid: 1234567890.123456
   통화타입: external
🔍 [FCM-INCOMING] my_extensions 조회 중...
✅ [FCM-INCOMING] userId 확인: user123
   내선번호: 1001
🔍 [FCM-INCOMING] FCM 토큰 조회 중...
✅ [FCM-INCOMING] FCM 토큰 2개 발견
💾 [FCM-INCOMING] call_history 생성 중...
✅ [FCM-INCOMING] call_history 생성 완료
   문서 ID: 1234567890.123456
📤 [FCM-INCOMING] FCM 푸시 전송 중...
✅ [FCM-INCOMING] FCM 푸시 전송 완료
   성공: 2개, 실패: 0개
```

---

## 🧪 테스트 체크리스트

- [ ] 필수 파라미터만으로 호출 테스트
- [ ] 선택 파라미터 포함 호출 테스트
- [ ] 존재하지 않는 내선번호로 테스트 (404 확인)
- [ ] FCM 토큰이 없는 사용자로 테스트 (404 확인)
- [ ] 동일한 linkedid로 중복 호출 테스트 (중복 방지 확인)
- [ ] 멀티 디바이스 사용자로 테스트 (모든 디바이스에 푸시 확인)
- [ ] GET 메서드로 호출 테스트 (405 확인)
- [ ] 필수 파라미터 누락 테스트 (400 확인)

---

## 📖 관련 문서

- [Firebase Cloud Functions 공식 문서](https://firebase.google.com/docs/functions)
- [Firebase Cloud Messaging 공식 문서](https://firebase.google.com/docs/cloud-messaging)
- [Asterisk AGI 프로그래밍 가이드](https://wiki.asterisk.org/wiki/display/AST/AGI+Commands)
- [FreePBX Dialplan Hooks](https://wiki.freepbx.org/display/FOP/Hooks)

---

## 🆘 문제 해결 FAQ

### Q1: FCM 푸시가 전송되지 않아요
**A:** 다음을 확인하세요:
1. 사용자가 앱에 로그인했는지 확인
2. `fcm_tokens` 컬렉션에 활성 토큰이 있는지 확인
3. Firebase Cloud Messaging API가 활성화되어 있는지 확인
4. Cloud Functions 로그에서 오류 메시지 확인

### Q2: 내선번호를 찾을 수 없다고 나와요
**A:** `my_extensions` 컬렉션을 확인하세요:
- `extension` 또는 `accountCode` 필드에 해당 번호가 있는지 확인
- `userId`가 올바르게 설정되어 있는지 확인

### Q3: 중복 통화 기록이 생성돼요
**A:** `linkedid`가 매번 고유한 값인지 확인하세요:
- Asterisk의 `${UNIQUEID}` 사용 권장
- 동일한 통화는 동일한 linkedid를 사용해야 함

### Q4: 특정 디바이스만 푸시가 안 와요
**A:** 해당 디바이스의 FCM 토큰을 확인하세요:
- `fcm_tokens` 컬렉션에서 `isActive: true`인지 확인
- 토큰이 만료되었을 수 있으니 앱 재로그인 시도

---

## 📝 버전 히스토리

| 버전 | 날짜 | 변경 내용 |
|------|------|-----------|
| 1.0.0 | 2024-01 | 초기 버전 생성 |

---

## 👥 지원

문제가 발생하면 다음을 포함하여 문의하세요:
- Cloud Functions 로그 전체
- 요청 본문 (JSON)
- 예상 결과 vs 실제 결과
- Firebase 프로젝트 설정 스크린샷

---

**이 함수는 외부 전화 시스템과 Flutter 앱을 연결하는 중요한 브릿지 역할을 합니다!** 🌉📞

---
---

# 🛑 cancelIncomingCallNotification 함수 사용 가이드

## 개요

`cancelIncomingCallNotification`은 **다중 디바이스 환경에서 수신전화 알림을 취소**하는 **Firebase Cloud Function 엔드포인트**입니다.

한 디바이스에서 전화를 수락/거절하면, 동일 사용자의 **다른 모든 디바이스의 수신전화 알림이 자동으로 취소**됩니다.

---

## 🎯 주요 기능

- **멀티 디바이스 알림 취소**: 한 디바이스에서 전화 응답 시 다른 모든 디바이스 알림 자동 제거
- **하이브리드 취소 시스템**: FCM 푸시 + Firestore 리스너 이중 안전망
- **실시간 동기화**: Firestore 실시간 리스너로 포그라운드 앱 즉시 반응
- **백그라운드 지원**: FCM 데이터 메시지로 백그라운드/종료 상태 앱도 처리
- **통화 기록 업데이트**: call_history 문서에 취소 상태 자동 기록

---

## 🏗️ 하이브리드 아키텍처

이 함수는 **두 가지 방법을 동시에 사용**하여 확실한 알림 취소를 보장합니다:

### **방법 1: FCM 푸시 메시지** (백그라운드/종료 상태)
- **목적**: 앱이 백그라운드 또는 종료 상태일 때 알림 취소
- **전달 속도**: 약 500ms (네트워크 상태에 따라 다름)
- **처리 위치**: `FCMService._handleIncomingCallCancelled()`
- **메시지 타입**: 데이터 전용 메시지 (data-only message)

### **방법 3: Firestore 실시간 리스너** (포그라운드 상태)
- **목적**: 앱이 포그라운드 상태일 때 즉시 알림 취소
- **전달 속도**: 약 100-200ms (Firestore 실시간 동기화)
- **처리 위치**: `IncomingCallScreen._startCallHistoryListener()`
- **감지 필드**: `call_history/{linkedid}.cancelled == true`

### **동작 흐름**

```
디바이스 A: 전화 수락 클릭
         ↓
_acceptCall() → _cancelOtherDevicesNotification('answered')
         ↓
         ↓
┌────────┴────────────────────────────────────────────────┐
│  cancelIncomingCallNotification (Cloud Function)        │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                                          │
│  ① Firestore Update (방법 3)                           │
│     call_history/{linkedid}:                            │
│       cancelled: true                                   │
│       cancelledAt: SERVER_TIMESTAMP                     │
│       cancelledBy: 'answered'                           │
│     ───────────────────────────────────────────────     │
│     💨 실시간 리스너가 즉시 감지 (100-200ms)             │
│     → 포그라운드 앱들이 즉시 화면 닫기                   │
│                                                          │
│  ② FCM 푸시 전송 (방법 1)                               │
│     모든 활성 FCM 토큰에 전송:                           │
│     {                                                    │
│       data: {                                            │
│         type: "incoming_call_cancelled",                 │
│         linkedid: "...",                                 │
│         action: "answered"                               │
│       }                                                  │
│     }                                                    │
│     ───────────────────────────────────────────────     │
│     💨 데이터 전용 메시지 전달 (500ms)                    │
│     → 백그라운드/종료 앱들이 화면 닫기                   │
│                                                          │
└──────────────────────────────────────────────────────────┘
         ↓                           ↓
         ↓                           ↓
┌────────────────────┐    ┌────────────────────┐
│  디바이스 B         │    │  디바이스 C         │
│  (포그라운드)       │    │  (백그라운드)       │
│                    │    │                    │
│  Firestore 리스너  │    │  FCM 메시지 수신    │
│  cancelled=true    │    │  type=cancelled    │
│  감지 → 즉시 닫기  │    │  감지 → 화면 닫기  │
│  ⚡ 100-200ms      │    │  ⚡ 500ms          │
└────────────────────┘    └────────────────────┘
```

---

## 📡 API 엔드포인트

### **URL**
```
https://us-central1-[YOUR-PROJECT-ID].cloudfunctions.net/cancelIncomingCallNotification
```

### **HTTP 메서드**
```
POST
```

### **Content-Type**
```
application/json
```

---

## 📋 요청 파라미터

### **Request Body (JSON)**

| 파라미터 | 타입 | 필수 | 설명 | 예시 |
|---------|------|------|------|------|
| `linkedid` | string | ✅ 필수 | 취소할 통화의 고유 ID | "1234567890.123456" |
| `userId` | string | ✅ 필수 | 사용자 ID (Firebase Auth UID) | "user123" |
| `action` | string | ⭕ 선택 | 취소 이유 | "answered", "rejected", "timeout" |

### **요청 예시**

```json
{
  "linkedid": "1234567890.123456",
  "userId": "user123",
  "action": "answered"
}
```

---

## 🔄 처리 흐름

```
┌─────────────────────────────────────────────────┐
│  IncomingCallScreen (디바이스 A)                 │
│  - 사용자가 수락 버튼 클릭                        │
└────────┬────────────────────────────────────────┘
         │ _cancelOtherDevicesNotification()
         │
         ▼
┌─────────────────────────────────────────────────┐
│  cancelIncomingCallNotification (Cloud Fn)      │
├─────────────────────────────────────────────────┤
│                                                 │
│  ① call_history 문서 업데이트                   │
│     Document: call_history/{linkedid}           │
│     Update: {                                   │
│       cancelled: true,                          │
│       cancelledAt: SERVER_TIMESTAMP,            │
│       cancelledBy: 'answered',                  │
│       updatedAt: SERVER_TIMESTAMP               │
│     }                                           │
│     → Firestore 실시간 리스너가 즉시 감지        │
│                                                 │
│  ② 활성 FCM 토큰 조회                           │
│     WHERE userId == userId                      │
│     AND isActive == true                        │
│     → 사용자의 모든 디바이스 토큰 추출           │
│                                                 │
│  ③ FCM 데이터 메시지 전송                       │
│     sendEachForMulticast({                      │
│       tokens: [...],                            │
│       data: {                                   │
│         type: 'incoming_call_cancelled',        │
│         linkedid: '...',                        │
│         action: 'answered',                     │
│         timestamp: '...'                        │
│       }                                         │
│     })                                          │
│                                                 │
└────────┬────────────────────────────────────────┘
         │
         ├─────────────────────┬──────────────────┐
         ▼                     ▼                  ▼
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│  디바이스 B       │  │  디바이스 C       │  │  디바이스 D       │
│  (포그라운드)     │  │  (백그라운드)     │  │  (종료 상태)     │
├──────────────────┤  ├──────────────────┤  ├──────────────────┤
│                  │  │                  │  │                  │
│  방법 3:         │  │  방법 1:         │  │  방법 1:         │
│  Firestore 리스너│  │  FCM 메시지 수신 │  │  FCM 메시지 수신 │
│  cancelled=true  │  │                  │  │                  │
│  감지            │  │  FCMService      │  │  FCMService      │
│                  │  │  메시지 처리     │  │  메시지 처리     │
│  IncomingCall    │  │                  │  │                  │
│  Screen 즉시 닫기│  │  Navigator로     │  │  Navigator로     │
│                  │  │  화면 닫기       │  │  화면 닫기       │
│                  │  │                  │  │                  │
│  ⚡ 100-200ms    │  │  ⚡ 500ms        │  │  ⚡ 500ms        │
└──────────────────┘  └──────────────────┘  └──────────────────┘
```

---

## 💡 실제 사용 예시

### **1. Flutter 앱에서 호출 (자동 처리)**

```dart
// IncomingCallScreen에서 자동으로 호출됨
Future<void> _cancelOtherDevicesNotification(String action) async {
  try {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    
    // 🔥 Cloud Function 호출 (FCM 푸시 + Firestore 업데이트)
    final functions = FirebaseFunctions.instance;
    await functions.httpsCallable('cancelIncomingCallNotification').call({
      'linkedid': widget.linkedid,
      'userId': userId,
      'action': action, // 'answered', 'rejected', 'timeout'
    });
    
    debugPrint('✅ [CANCEL] 다른 기기 알림 취소 완료');
  } catch (e) {
    debugPrint('❌ [CANCEL] 알림 취소 오류: $e');
  }
}

// 전화 수락 시
Future<void> _acceptCall() async {
  await _stopRingtoneAndVibration();
  _cancelOtherDevicesNotification('answered'); // 🛑 다른 기기 취소
  widget.onAccept();
}

// 전화 거절 시
Future<void> _rejectCall() async {
  await _stopRingtoneAndVibration();
  _cancelOtherDevicesNotification('rejected'); // 🛑 다른 기기 취소
  widget.onReject();
}
```

### **2. Firestore 리스너 설정 (자동 감지)**

```dart
// IncomingCallScreen initState에서 자동 설정됨
StreamSubscription<DocumentSnapshot>? _callHistoryListener;

void _startCallHistoryListener() {
  _callHistoryListener = FirebaseFirestore.instance
      .collection('call_history')
      .doc(widget.linkedid)
      .snapshots()
      .listen((snapshot) {
        if (!mounted) return;
        
        if (snapshot.exists) {
          final data = snapshot.data();
          final cancelled = data?['cancelled'] as bool? ?? false;
          
          if (cancelled) {
            // 🛑 다른 기기에서 응답함 - 이 화면 닫기
            _stopRingtoneAndVibration();
            Navigator.of(context).pop();
          }
        }
      });
}

@override
void dispose() {
  _callHistoryListener?.cancel(); // 리스너 정리
  super.dispose();
}
```

### **3. FCM 메시지 처리 (자동 처리)**

```dart
// FCMService에서 자동으로 처리됨
void _handleIncomingCallCancelled(RemoteMessage message) {
  final linkedid = message.data['linkedid'] as String?;
  final action = message.data['action'] as String? ?? 'unknown';
  
  debugPrint('🛑 [FCM-CANCEL] 수신전화 취소 메시지 수신');
  debugPrint('   linkedid: $linkedid');
  debugPrint('   action: $action');
  
  // Navigator로 IncomingCallScreen 닫기
  final context = navigatorKey.currentContext;
  if (context != null) {
    Navigator.of(context).popUntil((route) {
      return route.settings.name != '/incoming_call' || route.isFirst;
    });
  }
}
```

### **4. curl 명령어로 테스트**

```bash
curl -X POST \
  https://us-central1-your-project.cloudfunctions.net/cancelIncomingCallNotification \
  -H "Content-Type: application/json" \
  -d '{
    "linkedid": "1234567890.123456",
    "userId": "user123",
    "action": "answered"
  }'
```

### **5. Node.js에서 호출**

```javascript
const axios = require('axios');

async function cancelIncomingCall(linkedid, userId, action) {
  try {
    const response = await axios.post(
      'https://us-central1-your-project.cloudfunctions.net/cancelIncomingCallNotification',
      {
        linkedid: linkedid,
        userId: userId,
        action: action
      }
    );
    
    console.log('✅ 알림 취소 성공:', response.data);
  } catch (error) {
    console.error('❌ 알림 취소 실패:', error.response?.data || error.message);
  }
}

// 사용 예시
cancelIncomingCall('1234567890.123456', 'user123', 'answered');
```

### **6. Python에서 호출**

```python
import requests

def cancel_incoming_call(linkedid, user_id, action):
    url = 'https://us-central1-your-project.cloudfunctions.net/cancelIncomingCallNotification'
    
    payload = {
        'linkedid': linkedid,
        'userId': user_id,
        'action': action
    }
    
    try:
        response = requests.post(url, json=payload)
        response.raise_for_status()
        print(f"✅ 알림 취소 성공: {response.json()}")
    except requests.exceptions.RequestException as e:
        print(f"❌ 알림 취소 실패: {e}")

# 사용 예시
cancel_incoming_call('1234567890.123456', 'user123', 'answered')
```

---

## 📤 응답 형식

### **성공 응답 (200 OK)**

```json
{
  "success": true,
  "linkedid": "1234567890.123456",
  "userId": "user123",
  "action": "answered",
  "sentCount": 2,
  "failureCount": 0,
  "totalTokens": 2,
  "firestoreUpdated": true
}
```

### **성공 응답 (활성 토큰 없음)**

```json
{
  "success": true,
  "message": "No active tokens to cancel",
  "linkedid": "1234567890.123456",
  "firestoreUpdated": true
}
```

### **오류 응답**

#### **400 Bad Request - 필수 파라미터 누락**
```json
{
  "error": "Missing required parameters",
  "required": ["linkedid", "userId"]
}
```

#### **405 Method Not Allowed**
```json
{
  "error": "Method Not Allowed"
}
```

#### **500 Internal Server Error**
```json
{
  "error": "Error message",
  "stack": "Stack trace..."
}
```

---

## 🚨 오류 처리 가이드

| HTTP 상태 | 오류 상황 | 원인 | 해결 방법 |
|-----------|----------|------|-----------|
| `400` | 필수 파라미터 누락 | `linkedid` 또는 `userId`가 없음 | 요청 본문에 필수 파라미터 포함 확인 |
| `405` | 메서드 오류 | POST가 아닌 다른 메서드 사용 | POST 메서드로 요청 |
| `500` | 서버 내부 오류 | Firestore/FCM 오류 | Cloud Function 로그 확인 |

---

## 🔍 데이터베이스 구조

### **call_history 업데이트**
```javascript
{
  // Document ID = linkedid
  userId: "user123",
  callerNumber: "02-1234-5678",
  receiverNumber: "1001",
  linkedid: "1234567890.123456",
  status: "fcm_notification",
  
  // 취소 정보 추가
  cancelled: true,                       // 🛑 취소 플래그
  cancelledAt: Timestamp,                // 취소 시각
  cancelledBy: "answered",               // 취소 이유 (answered/rejected/timeout)
  updatedAt: Timestamp                   // 업데이트 시각
}
```

---

## 📱 FCM 메시지 구조

### **데이터 전용 메시지 (Android & iOS)**
```json
{
  "data": {
    "type": "incoming_call_cancelled",
    "linkedid": "1234567890.123456",
    "action": "answered",
    "timestamp": "2024-01-15T10:30:00.000Z"
  },
  "android": {
    "priority": "high"
  },
  "apns": {
    "headers": {
      "apns-priority": "10"
    },
    "payload": {
      "aps": {
        "contentAvailable": true
      }
    }
  }
}
```

**⚠️ 중요**: 이 메시지는 **데이터 전용 메시지**이므로 **알림 UI가 표시되지 않습니다**. 앱이 백그라운드/종료 상태일 때 조용히 처리됩니다.

---

## 🎯 하이브리드 시스템의 장점

### **방법 1 (FCM 푸시) vs 방법 3 (Firestore 리스너) 비교**

| 특성 | 방법 1: FCM 푸시 | 방법 3: Firestore 리스너 |
|------|------------------|--------------------------|
| **전달 속도** | 500ms (네트워크 의존) | 100-200ms (실시간) |
| **백그라운드 지원** | ✅ 완벽 지원 | ❌ 동작 안 함 |
| **종료 상태 지원** | ✅ 완벽 지원 | ❌ 동작 안 함 |
| **포그라운드 지원** | ✅ 지원 (느림) | ✅ 완벽 지원 (빠름) |
| **네트워크 끊김** | ❌ 전달 실패 | ✅ 재연결 시 자동 동기화 |
| **BuildContext 필요** | ✅ 필요 | ❌ 불필요 (위젯 내부) |

### **하이브리드 방식의 이점**

1. **⚡ 빠른 반응**: 포그라운드 앱은 Firestore 리스너로 100-200ms 내 즉시 반응
2. **🛡️ 이중 안전망**: 한 방법이 실패해도 다른 방법이 보완
3. **📱 모든 상태 지원**: 포그라운드, 백그라운드, 종료 상태 모두 커버
4. **🌐 네트워크 회복력**: Firestore는 네트워크 재연결 시 자동 동기화
5. **🔄 자동 동기화**: 앱 재시작 시에도 취소 상태 감지 가능

---

## 📊 모니터링 및 로그

### **Cloud Functions 로그 확인**
```bash
# Firebase CLI로 실시간 로그 확인
firebase functions:log --only cancelIncomingCallNotification

# 최근 100줄 로그 확인
firebase functions:log --only cancelIncomingCallNotification --lines 100
```

### **로그 출력 예시**
```
🛑 [FCM-CANCEL] 수신전화 알림 취소 요청
   Linkedid: 1234567890.123456
   userId: user123
   Action: answered
✅ [FCM-CANCEL] call_history 업데이트 완료
✅ [FCM-CANCEL] FCM 토큰 2개 발견
✅ [FCM-CANCEL] FCM 취소 메시지 전송 완료
   성공: 2/2
```

### **Flutter 앱 로그 예시**

**디바이스 A (전화 수락):**
```
🛑 [CANCEL] 다른 기기 알림 취소 시작
   linkedid: 1234567890.123456
   action: answered
✅ [CANCEL] Cloud Function 호출 완료 (FCM 푸시)
```

**디바이스 B (포그라운드):**
```
🔥 [FIRESTORE-LISTENER] call_history 리스너 시작
   linkedid: 1234567890.123456
🛑 [FIRESTORE-LISTENER] 통화 취소 감지!
   linkedid: 1234567890.123456
   cancelledBy: answered
✅ [FIRESTORE-LISTENER] IncomingCallScreen 닫힘
```

**디바이스 C (백그라운드):**
```
🛑 [FCM-CANCEL] 수신전화 취소 메시지 수신
   linkedid: 1234567890.123456
   action: answered
✅ [FCM-CANCEL] IncomingCallScreen 닫기 완료 (FCM 푸시)
```

---

## 🧪 테스트 체크리스트

### **기본 기능 테스트**
- [ ] 필수 파라미터만으로 호출 테스트
- [ ] 선택 파라미터 포함 호출 테스트
- [ ] 필수 파라미터 누락 테스트 (400 확인)
- [ ] GET 메서드로 호출 테스트 (405 확인)

### **멀티 디바이스 시나리오**
- [ ] 2개 디바이스 (포그라운드) - 한쪽에서 수락 시 다른쪽 즉시 닫힘 확인
- [ ] 2개 디바이스 (한쪽 백그라운드) - FCM 메시지 도착 확인
- [ ] 3개 이상 디바이스 - 모든 디바이스 알림 취소 확인
- [ ] 디바이스 하나만 온라인 - 정상 동작 확인

### **앱 상태별 테스트**
- [ ] 포그라운드 앱 - Firestore 리스너로 즉시 반응 (100-200ms)
- [ ] 백그라운드 앱 - FCM 메시지로 화면 닫기
- [ ] 종료 상태 앱 - FCM 메시지 수신 후 앱 실행 시 화면 표시 안 됨

### **취소 이유별 테스트**
- [ ] action: "answered" - 전화 수락 시
- [ ] action: "rejected" - 전화 거절 시
- [ ] action: "timeout" - 타임아웃 시

### **에러 케이스 테스트**
- [ ] 존재하지 않는 linkedid - Firestore 업데이트 실패 확인
- [ ] 활성 FCM 토큰 없음 - 응답 메시지 확인
- [ ] 네트워크 끊김 상태 - 재연결 시 Firestore 동기화 확인

---

## 🔐 보안 고려사항

### **현재 구현**
- ✅ CORS 허용 (`Access-Control-Allow-Origin: *`)
- ✅ POST 메서드만 허용
- ✅ 필수 파라미터 검증
- ⚠️ **인증 없음** - 앱 내부에서만 호출 권장

### **프로덕션 환경 권장사항**

1. **Firebase Auth 토큰 검증**
```javascript
const authHeader = req.headers.authorization;
const token = authHeader?.split('Bearer ')[1];
const decodedToken = await admin.auth().verifyIdToken(token);
const userId = decodedToken.uid;

// userId와 요청의 userId 일치 확인
if (userId !== req.body.userId) {
  res.status(403).json({ error: 'Forbidden' });
  return;
}
```

2. **Firestore Security Rules 강화**
```javascript
match /call_history/{linkedid} {
  // 자신의 통화 기록만 업데이트 가능
  allow update: if request.auth != null 
                && request.auth.uid == resource.data.userId
                && request.resource.data.cancelled == true;
}
```

---

## 🆘 문제 해결 FAQ

### Q1: 한 디바이스에서 수락했는데 다른 디바이스 알림이 안 꺼져요
**A:** 다음을 확인하세요:
1. Cloud Function 로그에서 FCM 전송 성공 여부 확인
2. 다른 디바이스의 Flutter 로그에서 FCM 메시지 수신 확인
3. Firestore 리스너가 제대로 설정되어 있는지 확인
4. `call_history/{linkedid}` 문서에 `cancelled: true` 필드 확인

### Q2: 포그라운드 앱에서 반응이 느려요
**A:** Firestore 리스너를 확인하세요:
- `_startCallHistoryListener()`가 `initState`에서 호출되는지 확인
- 리스너가 `dispose`에서 취소되는지 확인
- 네트워크 연결 상태 확인

### Q3: 백그라운드 앱에서 화면이 안 닫혀요
**A:** FCM 메시지 처리를 확인하세요:
- `FCMService`의 `_handleIncomingCallCancelled()` 구현 확인
- `BuildContext`가 null이 아닌지 확인
- FCM 메시지 타입이 `incoming_call_cancelled`인지 확인

### Q4: 통화 기록에 취소 정보가 안 남아요
**A:** Firestore 업데이트를 확인하세요:
- `call_history/{linkedid}` 문서가 존재하는지 확인
- Firestore Security Rules에서 업데이트 권한 확인
- Cloud Function 로그에서 Firestore 업데이트 오류 확인

---

## 📖 관련 문서

- [Firebase Cloud Functions 공식 문서](https://firebase.google.com/docs/functions)
- [Firebase Cloud Messaging 공식 문서](https://firebase.google.com/docs/cloud-messaging)
- [Firestore 실시간 업데이트 가이드](https://firebase.google.com/docs/firestore/query-data/listen)
- [Flutter StreamSubscription 문서](https://api.flutter.dev/flutter/dart-async/StreamSubscription-class.html)

---

## 📝 버전 히스토리

| 버전 | 날짜 | 변경 내용 |
|------|------|-----------|
| 1.0.0 | 2024-01 | cancelIncomingCallNotification 함수 추가 (하이브리드 방식) |

---

## 👥 지원

문제가 발생하면 다음을 포함하여 문의하세요:
- Cloud Functions 로그 전체
- Flutter 앱 로그 (모든 디바이스)
- 요청 본문 (JSON)
- Firestore call_history 문서 스크린샷
- 디바이스 상태 (포그라운드/백그라운드/종료)

---

**이 함수는 멀티 디바이스 환경에서 사용자 경험을 크게 개선합니다!** 🚀📱
