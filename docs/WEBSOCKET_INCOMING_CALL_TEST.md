# 🌐 WebSocket 수신 전화 테스트 가이드

## 🎯 개요

WebSocket Newchannel 이벤트를 통한 **실시간 수신 전화 감지** 및 **자동 풀스크린 표시** 기능을 테스트하는 가이드입니다.

---

## ✨ 구현된 기능

### 🌊 **WebSocket 이벤트 감지**
- **type: 3** (Call Event) 메시지 자동 감지
- **Event: "Newchannel"** 이벤트 필터링
- **my_extensions 검증**: `Exten` 필드가 사용자의 등록된 내선번호(`extension` 또는 `accountCode`)와 일치해야 처리

### 📞 **자동 수신 전화 표시**
- CallerIDNum (발신번호) 자동 추출
- Exten (수신번호) 자동 추출
- CallerIDName이 있으면 사용, 없으면 발신번호 표시
- 미래지향적 풀스크린 UI 자동 표시

### 🔄 **FCM Push + WebSocket 재연결**
- 앱이 백그라운드일 때 FCM Push 수신
- 자동으로 WebSocket 재연결 시도
- Firestore에서 서버 설정 자동 로드

---

## 🧪 테스트 방법

### **방법 1: 실제 WebSocket 서버 연결 (실전 테스트)**

#### **전제 조건:**
- WebSocket 서버 실행 중 (`ws://서버주소:7099`)
- 앱에서 로그인 완료
- WebSocket 연결 성공 상태

#### **테스트 단계:**

1. **Flutter 앱 실행 및 로그인**
   ```bash
   # 웹 프리뷰 URL에서 로그인
   https://5060-ijpqhzty575rh093zweuw-c81df28e.sandbox.novita.ai
   ```

2. **WebSocket 연결 확인**
   - 로그인 후 MainScreen에서 자동 연결됨
   - 콘솔 로그 확인: `✅ DCMIWS: Connected successfully`

3. **실제 전화 걸기**
   - 외부에서 앱에 등록된 번호로 전화 걸기
   - WebSocket 서버가 Newchannel 이벤트 전송

4. **예상 결과**
   - 🌊 수신 전화 풀스크린 자동 표시
   - 발신자 정보 표시 (CallerIDNum)
   - 파동 애니메이션 실행
   - 수락/거절 버튼 표시

---

### **방법 2: 수동 WebSocket 메시지 전송 (개발 테스트)**

#### **Python 스크립트로 테스트**

```python
#!/usr/bin/env python3
import asyncio
import websockets
import json

async def send_test_newchannel():
    uri = "ws://localhost:7099"  # WebSocket 서버 주소
    
    async with websockets.connect(uri) as websocket:
        # Newchannel 이벤트 메시지
        test_message = {
            "type": 3,
            "server_id": 1,
            "server_name": "dcrm.makecall.io",
            "ssl": False,
            "data": {
                "Event": "Newchannel",
                "Privilege": "call,all",
                "Timestamp": "1762257300.238151",
                "Channel": "PJSIP/DKCT-000001b1",
                "ChannelState": "4",
                "ChannelStateDesc": "Ring",
                "CallerIDNum": "01026132471",
                "CallerIDName": "김철수",
                "ConnectedLineNum": "",
                "ConnectedLineName": "",
                "Language": "en",
                "AccountCode": "",
                "Context": "trk-11-in",
                "Exten": "07045144801",
                "Priority": "1",
                "Uniqueid": "1762257300.677",
                "Linkedid": "1762257300.677"
            }
        }
        
        # 메시지 전송
        await websocket.send(json.dumps(test_message))
        print("✅ Test Newchannel event sent!")

# 실행
asyncio.run(send_test_newchannel())
```

**사용법:**
```bash
python3 test_websocket_newchannel.py
```

---

### **방법 3: WebSocket 클라이언트 도구 사용**

#### **wscat 사용 (Node.js)**

```bash
# 1. wscat 설치
npm install -g wscat

# 2. WebSocket 서버 연결
wscat -c ws://서버주소:7099

# 3. Newchannel 이벤트 메시지 전송 (JSON)
{
  "type": 3,
  "server_id": 1,
  "server_name": "dcrm.makecall.io",
  "ssl": false,
  "data": {
    "Event": "Newchannel",
    "Context": "trk-11-in",
    "CallerIDNum": "01026132471",
    "CallerIDName": "김철수",
    "Exten": "07045144801",
    "ChannelStateDesc": "Ring"
  }
}
```

---

## 📋 이벤트 데이터 형식

### ✅ **올바른 Newchannel 이벤트**

```json
{
  "type": 3,
  "server_id": 1,
  "server_name": "dcrm.makecall.io",
  "ssl": false,
  "data": {
    "Event": "Newchannel",
    "Context": "trk-11-in",
    "CallerIDNum": "01026132471",
    "CallerIDName": "김철수",
    "Exten": "07045144801",
    "ChannelStateDesc": "Ring"
  }
}
```

### ⚠️ **필수 필드**

| 필드 | 위치 | 설명 | 필수 여부 |
|------|------|------|----------|
| `type` | 루트 | 3 (Call Event) | ✅ 필수 |
| `Event` | data | "Newchannel" | ✅ 필수 |
| `CallerIDNum` | data | 발신 전화번호 | ✅ 필수 |
| `Exten` | data | 수신 전화번호 (my_extensions와 일치 필요) | ✅ 필수 |
| `Channel` | data | 채널 정보 (모바일 수신용) | ✅ 필수 |
| `Linkedid` | data | 통화 연결 ID (통화 기록 추적용) | ✅ 필수 |
| `CallerIDName` | data | 발신자 이름 | ⭕ 옵션 |

### ❌ **처리되지 않는 이벤트**

```json
// type이 3이 아닌 경우
{"type": 1, "data": {...}}

// Event가 Newchannel이 아닌 경우
{"type": 3, "data": {"Event": "Hangup", ...}}

// Exten이 등록된 내선번호가 아닌 경우 (my_extensions에 없음)
{"type": 3, "data": {"Event": "Newchannel", "Exten": "01099999999", ...}}
```

---

## 🔍 코드 흐름

### **1. WebSocket 메시지 수신**

```dart
// DCMIWSService._handleMessage()
void _handleMessage(dynamic message) {
  final data = json.decode(message);
  _checkIncomingCall(data);  // ← 수신 전화 체크
  // ...
}
```

### **2. Newchannel 이벤트 감지**

```dart
Future<void> _checkIncomingCall(Map<String, dynamic> data) async {
  // type이 3인지 확인 (Call Event)
  if (data['type'] != 3) return;
  
  // Event가 "Newchannel"인지 확인
  final event = data['data']['Event'];
  if (event != 'Newchannel') return;
  
  // CallerIDNum, Exten, Channel, Linkedid 추출
  final callerIdNum = data['data']['CallerIDNum'];
  final exten = data['data']['Exten'];
  final channel = data['data']['Channel'];
  final linkedid = data['data']['Linkedid'];
  
  // 🔐 my_extensions 유효성 검사 (등록된 내선번호인지 확인)
  final isValidExtension = await _validateMyExtension(exten);
  if (!isValidExtension) {
    debugPrint('⚠️ 등록되지 않은 내선번호: $exten');
    return;
  }
  
  // 풀스크린 표시
  _showIncomingCallScreen(callerIdNum, exten, channel, linkedid, data);
}
```

### **2-1. my_extensions 유효성 검사**

```dart
Future<bool> _validateMyExtension(String exten) async {
  final userId = FirebaseAuth.instance.currentUser?.uid;
  if (userId == null) return false;
  
  // 1️⃣ extension 필드와 일치하는지 확인
  final extensionQuery = await FirebaseFirestore.instance
      .collection('my_extensions')
      .where('userId', isEqualTo: userId)
      .where('extension', isEqualTo: exten)
      .limit(1)
      .get();
  
  if (extensionQuery.docs.isNotEmpty) return true;
  
  // 2️⃣ accountCode 필드와 일치하는지 확인
  final accountCodeQuery = await FirebaseFirestore.instance
      .collection('my_extensions')
      .where('userId', isEqualTo: userId)
      .where('accountCode', isEqualTo: exten)
      .limit(1)
      .get();
  
  return accountCodeQuery.docs.isNotEmpty;
}
```

### **3. 풀스크린 표시**

```dart
void _showIncomingCallScreen(
  String callerNumber,
  String receiverNumber,
  Map<String, dynamic> callEventData,
) {
  // CallerIDName이 있으면 사용, 없으면 번호 사용
  final callerName = eventData['CallerIDName']?.isNotEmpty == true
      ? eventData['CallerIDName']
      : callerNumber;
  
  Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => IncomingCallScreen(
        callerName: callerName,
        callerNumber: callerNumber,
        onAccept: () { /* 수락 로직 */ },
        onReject: () { /* 거절 로직 */ },
      ),
    ),
  );
}
```

---

## 🎨 예상 결과

### ✅ **성공 시**

**콘솔 로그:**
```
📨 DCMIWS: Received message: {type: 3, data: {Event: Newchannel, ...}}
📞 수신 전화 감지!
  발신번호: 01026132471
  수신번호: 07045144801
  Context: trk-11-in
📞 수신 전화 화면 표시:
  발신자: 김철수
  발신번호: 01026132471
  수신번호: 07045144801
```

**화면:**
- 🌊 파동 애니메이션이 있는 풀스크린
- 👤 발신자 정보 (아바타, 이름/번호)
- ✅ 수락 버튼 (녹색, 글로우)
- ❌ 거절 버튼 (빨간색)

---

## 🐛 트러블슈팅

### **문제 1: 풀스크린이 표시되지 않음**

**원인 1: BuildContext 미설정**
```dart
// main.dart 확인
DCMIWSService.setContext(context);  // ✅ 이 코드가 있어야 함
```

**원인 2: WebSocket 미연결**
```bash
# 콘솔 로그 확인
✅ DCMIWS: Connected successfully  # ← 이 메시지가 있어야 함
```

**원인 3: my_extensions 미등록**
```bash
# Firestore 확인: users/{userId}/my_extensions
# Exten 필드가 extension 또는 accountCode와 일치해야 함

# ✅ 올바른 예시
{
  "userId": "abc123",
  "extension": "07045144801",
  "accountCode": "DKCT"
}

# ❌ Exten이 등록되지 않은 경우
Exten: "01099999999"  # my_extensions에 없음
```

---

### **문제 2: FCM Push 후 WebSocket 재연결 실패**

**원인 1: Firestore 서버 설정 없음**
```dart
// users 컬렉션에 필요한 필드
{
  'serverAddress': 'makecall.io',
  'serverPort': 7099,
  'serverSSL': false
}
```

**원인 2: 네트워크 연결 문제**
```bash
# WebSocket 서버 접근 가능 확인
curl -I ws://서버주소:7099
```

---

### **문제 3: 특정 이벤트만 처리 안 됨**

**디버깅 체크리스트:**
```dart
// 1. type 확인
debugPrint('type: ${data['type']}');  // 3이어야 함

// 2. Event 확인
debugPrint('Event: ${data['data']['Event']}');  // "Newchannel"이어야 함

// 3. 필수 필드 확인
debugPrint('CallerIDNum: ${data['data']['CallerIDNum']}');  // null이 아니어야 함
debugPrint('Exten: ${data['data']['Exten']}');  // null이 아니어야 함
debugPrint('Channel: ${data['data']['Channel']}');  // null이 아니어야 함
debugPrint('Linkedid: ${data['data']['Linkedid']}');  // null이 아니어야 함

// 4. my_extensions 검증 확인
// 콘솔 로그에서 다음 메시지 확인:
// ✅ my_extensions 검증 성공 (extension 필드 일치)
// ✅ my_extensions 검증 성공 (accountCode 필드 일치)
// ⚠️ 등록되지 않은 내선번호: {exten}
```

---

## 🔐 my_extensions 검증 흐름

### **목적**
- 사용자가 등록한 내선번호로만 수신 전화 알림을 받도록 보안 필터링
- 타인의 내선번호로 오는 전화는 무시

### **검증 과정**

```
1. Newchannel 이벤트 수신
   ↓
2. Exten 필드 추출 (예: "07045144801")
   ↓
3. Firestore my_extensions 컬렉션 조회
   - where('userId', isEqualTo: currentUserId)
   - where('extension', isEqualTo: exten)
   ↓
4-1. 일치하는 문서 있음 → ✅ 검증 성공
   ↓
4-2. 일치하는 문서 없음 → accountCode로 재검증
   - where('userId', isEqualTo: currentUserId)
   - where('accountCode', isEqualTo: exten)
   ↓
5-1. accountCode 일치 → ✅ 검증 성공
   ↓
5-2. accountCode도 불일치 → ❌ 검증 실패 (이벤트 무시)
```

### **my_extensions 컬렉션 구조**

```json
{
  "userId": "abc123",
  "extension": "07045144801",
  "accountCode": "DKCT",
  "name": "내 대표번호",
  "createdAt": "2024-11-03T10:00:00Z"
}
```

### **등록 방법**
1. 앱의 **프로필 탭** → **내선번호 관리** 접속
2. **+ 추가** 버튼 클릭
3. **내선번호** 입력 (예: "07045144801")
4. **계정 코드** 입력 (예: "DKCT")
5. **저장** → my_extensions 컬렉션에 자동 추가

### **검증 실패 시 동작**
```
📨 WebSocket 메시지 수신
📞 수신 전화 감지!
  발신번호: 01026132471
  수신번호: 01099999999
  Channel: PJSIP/DKCT-000001b1
  Linkedid: 1762257300.677
❌ my_extensions 검증 실패
  userId: abc123
  exten: 01099999999
  등록된 내선번호가 아닙니다
⚠️ 등록되지 않은 내선번호: 01099999999
  해당 이벤트는 무시됩니다.
```

### **검증 성공 시 동작**
```
📨 WebSocket 메시지 수신
📞 수신 전화 감지!
  발신번호: 01026132471
  수신번호: 07045144801
  Channel: PJSIP/DKCT-000001b1
  Linkedid: 1762257300.677
✅ my_extensions 검증 성공 (extension 필드 일치)
  userId: abc123
  extension: 07045144801
✅ 등록된 내선번호 확인됨: 07045144801
📞 수신 전화 화면 표시:
  발신자: 김철수
  발신번호: 01026132471
  수신번호: 07045144801
  Channel: PJSIP/DKCT-000001b1
  Linkedid: 1762257300.677
```

---

## 🔄 FCM + WebSocket 통합 흐름

### **시나리오 1: 앱이 포그라운드 (WebSocket 연결됨)**

```
1. 전화 수신
   ↓
2. WebSocket Newchannel 이벤트 수신
   ↓
3. DCMIWSService._checkIncomingCall() 호출
   ↓
4. 즉시 풀스크린 표시
```

### **시나리오 2: 앱이 백그라운드 (WebSocket 연결 끊김)**

```
1. 전화 수신
   ↓
2. FCM Push 발송 (서버 측)
   ↓
3. 앱이 FCM Push 수신
   ↓
4. FCMService._ensureWebSocketConnection() 호출
   ↓
5. Firestore에서 서버 설정 로드
   ↓
6. WebSocket 재연결
   ↓
7. Newchannel 이벤트 수신
   ↓
8. 풀스크린 표시
```

---

## 💡 테스트 팁

### **빠른 개발 루프**

```bash
# Terminal 1: Flutter 앱 실행
cd /home/user/flutter_app
flutter run -d web-server --web-port 5060

# Terminal 2: WebSocket 테스트 메시지 전송
python3 test_websocket_newchannel.py
```

### **다양한 시나리오**

```json
// 시나리오 1: CallerIDName 있음
{"CallerIDNum": "010-1234-5678", "CallerIDName": "김철수"}

// 시나리오 2: CallerIDName 없음
{"CallerIDNum": "010-1234-5678", "CallerIDName": ""}

// 시나리오 3: 긴 번호
{"CallerIDNum": "+82-10-1234-5678"}

// 시나리오 4: 특수문자
{"CallerIDNum": "010-1234-5678", "CallerIDName": "홍길동 부장님"}
```

---

## 📚 관련 파일

- `/lib/services/dcmiws_service.dart` - WebSocket 이벤트 처리
- `/lib/services/fcm_service.dart` - FCM Push + WebSocket 재연결
- `/lib/screens/call/incoming_call_screen.dart` - 풀스크린 UI
- `/lib/main.dart` - BuildContext 등록

---

## 🚀 다음 단계

1. **SIP 통화 연동**: 수락/거절 시 실제 SIP 세션 제어
2. **통화 중 UI**: 수락 후 통화 중 화면으로 전환
3. **통화 기록**: Firestore에 통화 이력 저장
4. **멀티 콜 지원**: 여러 수신 전화 동시 처리
5. **통화 대기**: 통화 중 새 전화 수신 시 대기 기능

---

## 🔄 변경 이력

### **v1.1.0** (2024-11-04)
- ✅ **my_extensions 검증 기능 추가**: 등록된 내선번호만 수신 전화 알림
- ✅ **Channel, Linkedid 필드 추가**: 통화 기록 추적 및 모바일 수신 지원
- ⚠️ **Context 필터 제거**: 모든 Newchannel 이벤트 처리 (my_extensions 검증으로 대체)

### **v1.0.0** (2024-11-03)
- 🎉 **초기 릴리스**: WebSocket Newchannel 이벤트 감지 및 풀스크린 표시
- ✅ FCM Push + WebSocket 재연결 기능

---

**최종 업데이트**: 2024-11-04  
**버전**: 1.1.0
