# 📞 FCM 수신전화 푸시 알림 설정 가이드

## 🎯 개요

DCMIWS 웹소켓 연결이 중지되었을 때 Firebase Cloud Functions를 통해 FCM 푸시 알림으로 수신전화를 처리하는 기능입니다.

---

## ✅ 구현 완료 사항

### 1. Firebase Cloud Functions
- ✅ `sendIncomingCallNotification` HTTP endpoint 추가
- ✅ FCM 푸시 전송 로직 구현
- ✅ Firestore call_history 생성 (linkedid 기반 중복 방지)
- ✅ receiverNumber → userId 매핑 로직

### 2. Flutter FCM 핸들러
- ✅ `_handleIncomingCallFCM()` 메서드 추가
- ✅ WebSocket 연결 상태 확인 로직
- ✅ FCM 수신 시 IncomingCallScreen 표시
- ✅ `type: incoming_call` 메시지 타입 처리

### 3. DCMIWS 웹소켓 서비스
- ✅ `_sendIncomingCallFCM()` 메서드 추가
- ✅ Newchannel 이벤트 시 Firebase Functions 호출
- ✅ BridgeEnter 이벤트 시 FCM 기록 확인 및 중복 방지
- ✅ linkedid 기반 통화기록 중복 생성 방지

---

## 🔧 배포 전 설정 필요 사항

### Step 1: Firebase Functions 배포

```bash
cd /home/user/flutter_app/functions
npm install
firebase deploy --only functions
```

**배포 후 함수 URL 확인:**
```
✔  functions[sendIncomingCallNotification(us-central1)]: Successful create operation.
Function URL (sendIncomingCallNotification): https://us-central1-YOUR_PROJECT.cloudfunctions.net/sendIncomingCallNotification
```

---

### Step 2: Flutter 앱에 Functions URL 설정

**파일:** `lib/services/dcmiws_service.dart` (라인 ~2010)

**변경 전:**
```dart
// TODO: 배포 후 실제 URL로 변경 필요
const functionsUrl = 'https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/sendIncomingCallNotification';
```

**변경 후:** (Firebase Console에서 확인한 실제 URL)
```dart
const functionsUrl = 'https://us-central1-makecallio.cloudfunctions.net/sendIncomingCallNotification';
```

**또는 환경 변수 사용 (권장):**

1. **사용자 문서에서 Functions URL 가져오기:**

```dart
/// Firebase Functions에 수신전화 FCM 전송 요청
Future<void> _sendIncomingCallFCM({
  required String callerNumber,
  required String callerName,
  required String receiverNumber,
  required String linkedid,
  required String channel,
  required String callType,
}) async {
  try {
    // Firestore에서 Functions URL 가져오기
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    
    final functionsUrl = userDoc.data()?['functionsUrl'] as String?;
    
    // Functions URL이 설정되지 않은 경우 기본값 사용
    final url = functionsUrl ?? 
        'https://us-central1-YOUR_PROJECT.cloudfunctions.net/sendIncomingCallNotification';
    
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'callerNumber': callerNumber,
        'callerName': callerName,
        'receiverNumber': receiverNumber,
        'linkedid': linkedid,
        'channel': channel,
        'callType': callType,
      }),
    ).timeout(const Duration(seconds: 5));
    
    // ... (나머지 코드)
  } catch (e) {
    if (kDebugMode) {
      debugPrint('⚠️ [DCMIWS-FCM] FCM 전송 오류: $e');
    }
  }
}
```

2. **Firestore에 Functions URL 저장:**

Firebase Console → Firestore → `users/{userId}` 문서:
```json
{
  "functionsUrl": "https://us-central1-makecallio.cloudfunctions.net/sendIncomingCallNotification",
  ...
}
```

---

## 🔄 워크플로우

### DCMIWS 연결 중 (웹소켓 우선)

```
DCMIWS Newchannel 이벤트
    ↓
_checkIncomingCall() 실행
    ↓
┌───────────────────────────────────────┐
│ 1. IncomingCallScreen 표시 (웹소켓) │
│ 2. Firebase Functions FCM 전송       │ ← 백업 (다른 기기 알림)
└───────────────────────────────────────┘
    ↓
BridgeEnter 이벤트
    ↓
_saveCallHistoryOnBridgeEnter()
    ↓
📝 Firestore 확인:
   - linkedid가 이미 존재? (FCM으로 생성됨)
   - Yes → status만 업데이트 (device_answered)
   - No → 새 통화기록 생성
```

### DCMIWS 연결 중지 (FCM 폴백)

```
Firebase Functions FCM 전송
    ↓
Flutter FCM 수신 (onMessage)
    ↓
_handleIncomingCallFCM() 실행
    ↓
WebSocket 연결 확인
    ↓
연결 없음 → FCM 처리
    ↓
┌───────────────────────────────────────┐
│ 1. IncomingCallScreen 표시 (FCM)    │
│ 2. call_history 이미 생성됨          │ ← Firebase Functions에서 생성
└───────────────────────────────────────┘
```

---

## 📊 Firestore call_history 구조

### FCM으로 생성된 통화기록

```json
{
  "userId": "abc123",
  "callerNumber": "16682471",
  "callerName": "얼쑤팩토리",
  "receiverNumber": "07045144801",
  "channel": "PJSIP/DKCT-00000460",
  "linkedid": "1762843210.1787",
  "callType": "incoming",
  "callSubType": "external",
  "status": "fcm_notification",
  "extensionUsed": "1010",
  "timestamp": "2025-01-11T14:30:00Z",
  "createdAt": "2025-01-11T14:30:00Z"
}
```

### BridgeEnter 이벤트 후 업데이트

```json
{
  "userId": "abc123",
  "callerNumber": "16682471",
  "callerName": "얼쑤팩토리",
  "receiverNumber": "07045144801",
  "channel": "PJSIP/DKCT-00000460",
  "linkedid": "1762843210.1787",
  "callType": "incoming",
  "callSubType": "external",
  "status": "device_answered",
  "extensionUsed": "1010",
  "timestamp": "2025-01-11T14:30:00Z",
  "answeredAt": "2025-01-11T14:30:15Z",
  "createdAt": "2025-01-11T14:30:00Z"
}
```

**주요 변경 사항:**
- `status`: `fcm_notification` → `device_answered`
- `answeredAt`: 단말 수신 확인 시간 추가

---

## 🧪 테스트 방법

### 1. Firebase Functions 테스트 (Postman/curl)

```bash
curl -X POST https://us-central1-YOUR_PROJECT.cloudfunctions.net/sendIncomingCallNotification \
  -H "Content-Type: application/json" \
  -d '{
    "callerNumber": "16682471",
    "callerName": "얼쑤팩토리",
    "receiverNumber": "07045144801",
    "linkedid": "1762843210.1787",
    "channel": "PJSIP/DKCT-00000460",
    "callType": "external"
  }'
```

**예상 응답:**
```json
{
  "success": true,
  "linkedid": "1762843210.1787",
  "userId": "abc123",
  "sentCount": 2,
  "failureCount": 0,
  "totalTokens": 2,
  "callHistoryCreated": true
}
```

### 2. Flutter 앱 테스트

**시나리오 1: DCMIWS 연결 중**
1. DCMIWS 웹소켓 연결
2. 수신 전화 발생
3. ✅ IncomingCallScreen 표시 (웹소켓)
4. ✅ FCM 푸시도 전송 (다른 기기 알림)
5. ✅ BridgeEnter 시 FCM 기록 확인 후 업데이트

**시나리오 2: DCMIWS 연결 중지**
1. DCMIWS 웹소켓 종료
2. 수신 전화 발생
3. ✅ Firebase Functions에서 FCM 전송
4. ✅ Flutter 앱에서 FCM 수신
5. ✅ IncomingCallScreen 표시 (FCM)
6. ✅ call_history 이미 생성됨 (Functions)

---

## 🚨 문제 해결

### Firebase Functions 로그 확인

```bash
firebase functions:log --only sendIncomingCallNotification
```

**주요 로그 메시지:**
```
📞 [FCM-INCOMING] 수신전화 FCM 요청 수신
   발신번호: 16682471
   발신자: 얼쑤팩토리
   수신번호: 07045144801
   Linkedid: 1762843210.1787
   통화타입: external
✅ [FCM-INCOMING] FCM 전송 완료
   성공: 2/2
✅ [FCM-INCOMING] call_history 생성 완료
```

### Flutter 디버그 로그 확인

```
📨 포그라운드 메시지: 수신전화
📨 메시지 데이터: {type: incoming_call, caller_number: 16682471, ...}
📞 [FCM-INCOMING] 수신 전화 FCM 메시지 처리
⚠️ [FCM-INCOMING] WebSocket 연결 없음 - FCM으로 처리
✅ [FCM] Context 확인 완료
📞 [FCM] 수신 전화 화면 표시
```

### DCMIWS 중복 방지 로그

```
📞 [DCMIWS-BRIDGE] FCM으로 이미 생성된 통화 기록 발견
   Linkedid: 1762843210.1787
   → 상태만 업데이트 (device_answered)
✅ 통화 기록 업데이트 완료
```

---

## 📝 주요 코드 위치

| 파일 | 메서드/함수 | 라인 | 설명 |
|------|-------------|------|------|
| `functions/index.js` | `sendIncomingCallNotification` | ~300-530 | FCM 전송 및 통화기록 생성 |
| `fcm_service.dart` | `_handleIncomingCallFCM()` | ~502-515 | FCM 수신전화 처리 |
| `dcmiws_service.dart` | `_sendIncomingCallFCM()` | ~1990-2050 | Firebase Functions 호출 |
| `dcmiws_service.dart` | `_saveCallHistoryOnBridgeEnter()` | ~950-1100 | FCM 기록 확인 및 중복 방지 |

---

## 🎉 완료

FCM 수신전화 푸시 알림 기능이 완전히 구현되었습니다!

**다음 단계:**
1. Firebase Functions 배포
2. Flutter 앱에 Functions URL 설정
3. 테스트 및 검증
4. 프로덕션 배포

**문의:** 추가 지원이 필요하면 알려주세요! 🚀
