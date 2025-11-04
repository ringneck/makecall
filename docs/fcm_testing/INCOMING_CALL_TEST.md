# 📞 수신 전화 풀스크린 FCM 테스트 가이드

## 🎯 개요

이 문서는 **미래지향적 수신 전화 풀스크린 UI**를 FCM 푸시 알림으로 테스트하는 방법을 설명합니다.

## 🎨 구현된 기능

### ✨ 세련된 UI 디자인
- 🌊 **3단계 파동 애니메이션** - 연속 반복되는 물결 효과
- 🎨 **동적 그라데이션 배경** - 다크 블루 톤의 미래지향적 배경
- 💫 **글로우/펄스 효과** - 아바타와 버튼의 부드러운 빛 효과
- 🎭 **페이드 인/아웃** - 부드러운 화면 전환 애니메이션
- 🔍 **스케일 애니메이션** - 발신자 정보의 탄성 효과

### 📱 풀스크린 기능
- 📞 발신자 이름, 전화번호, 아바타 표시
- ✅ **수락 버튼** (녹색) - 통화 시작 준비
- ❌ **거절 버튼** (빨간색) - 통화 거부

### 🔔 FCM 통합
- 포그라운드: 앱 실행 중 즉시 풀스크린 표시
- 백그라운드: 알림 탭 시 풀스크린 표시
- `incoming_call` 타입 자동 감지 및 처리

## 🧪 테스트 방법

### 방법 1: Python 스크립트 (가장 간편)

```bash
cd /home/user/flutter_app
python3 docs/fcm_testing/send_fcm_test_message.py
```

**대화형 메뉴:**
```
메시지 타입을 선택하세요:
1. 기본 테스트 알림
2. 수신 전화 알림  ← 이것을 선택!
3. 부재중 전화 알림
4. 새 메시지 알림
5. 모든 타입 순차 발송

선택 (1-5, Enter=1): 2
```

### 방법 2: Firebase Console (GUI)

1. **Firebase Console 접속**: https://console.firebase.google.com/
2. **프로젝트 선택** → **Messaging** → **Send test message**
3. **FCM 토큰 입력**: 앱 로그인 시 출력된 토큰 복사
4. **메시지 구성**:

   **Notification 탭:**
   - Title: `김철수`
   - Body: `010-1234-5678`

   **Additional options 탭 → Custom data:**
   ```json
   {
     "type": "incoming_call",
     "caller_name": "김철수",
     "caller_number": "010-1234-5678",
     "caller_avatar": "",
     "callId": "call_12345"
   }
   ```

5. **Test** 버튼 클릭

### 방법 3: curl (고급 사용자)

```bash
# 1. Firebase Admin SDK에서 Access Token 획득
ACCESS_TOKEN=$(python3 -c "
import firebase_admin
from firebase_admin import credentials
cred = credentials.Certificate('/opt/flutter/firebase-admin-sdk.json')
firebase_admin.initialize_app(cred)
import google.auth.transport.requests
request = google.auth.transport.requests.Request()
cred.get_access_token(request)
print(cred.access_token)
")

# 2. FCM v1 API로 메시지 발송
curl -X POST \
  "https://fcm.googleapis.com/v1/projects/YOUR_PROJECT_ID/messages:send" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "message": {
      "token": "YOUR_FCM_TOKEN",
      "notification": {
        "title": "김철수",
        "body": "010-1234-5678"
      },
      "data": {
        "type": "incoming_call",
        "caller_name": "김철수",
        "caller_number": "010-1234-5678",
        "caller_avatar": "",
        "callId": "call_67890"
      },
      "android": {
        "priority": "high"
      }
    }
  }'
```

## 📋 FCM 데이터 형식

### ✅ 올바른 형식

```json
{
  "notification": {
    "title": "발신자 이름",
    "body": "전화번호"
  },
  "data": {
    "type": "incoming_call",
    "caller_name": "발신자 이름",
    "caller_number": "010-1234-5678",
    "caller_avatar": "https://example.com/avatar.jpg",  // 옵션
    "callId": "unique_call_id"
  }
}
```

### ❌ 잘못된 형식

```json
{
  "data": {
    "type": "incoming_call",
    "phoneNumber": "010-1234-5678"  // ❌ caller_name, caller_number 필수!
  }
}
```

## 🔍 코드 흐름

### 1. FCM 메시지 수신

```dart
// FCMService.initialize() 시 리스너 등록
FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
```

### 2. 타입 확인

```dart
if (message.data['type'] == 'incoming_call') {
  _showIncomingCallScreen(message);
}
```

### 3. 데이터 파싱

```dart
final callerName = message.data['caller_name'] ?? '알 수 없음';
final callerNumber = message.data['caller_number'] ?? '';
final callerAvatar = message.data['caller_avatar'];  // 옵션
```

### 4. 풀스크린 네비게이션

```dart
Navigator.of(context).push(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (context) => IncomingCallScreen(
      callerName: callerName,
      callerNumber: callerNumber,
      callerAvatar: callerAvatar,
      onAccept: () { /* 수락 로직 */ },
      onReject: () { /* 거절 로직 */ },
    ),
  ),
);
```

## 📱 예상 결과

### 포그라운드 (앱 실행 중)
1. FCM 메시지 수신
2. 즉시 풀스크린 오버레이 표시
3. 애니메이션 시작 (파동, 글로우, 페이드)
4. 사용자가 수락/거절 버튼 탭
5. 콜백 실행 및 화면 닫힘

### 백그라운드 (앱 미실행 or 백그라운드)
1. 시스템 알림 표시
2. 사용자가 알림 탭
3. 앱 포그라운드로 복귀
4. 풀스크린 표시

## 🐛 트러블슈팅

### 문제: 풀스크린이 표시되지 않음

**원인 1: BuildContext 미설정**
```dart
// main.dart에서 확인
FCMService.setContext(context);  // ✅ 이 코드가 있어야 함
```

**원인 2: FCM 데이터 형식 오류**
```dart
// 콘솔 로그 확인
debugPrint('📨 수신 데이터: ${message.data}');
// 필수 필드 확인: type, caller_name, caller_number
```

**원인 3: 알림 권한 미승인**
```dart
// FCM 초기화 시 권한 요청
await _messaging.requestPermission(...);
```

### 문제: 애니메이션이 작동하지 않음

**원인: TickerProviderStateMixin 누락**
```dart
class _IncomingCallScreenState extends State<IncomingCallScreen>
    with TickerProviderStateMixin {  // ✅ 이것이 있어야 함
  // ...
}
```

### 문제: 버튼을 눌러도 반응 없음

**원인: 콜백 미구현**
```dart
IncomingCallScreen(
  // ...
  onAccept: () {
    Navigator.of(context).pop();
    // TODO: 실제 통화 수락 로직 추가
  },
  onReject: () {
    Navigator.of(context).pop();
    // TODO: 실제 통화 거절 로직 추가
  },
)
```

## 📊 로그 확인

### 성공적인 FCM 수신 로그

```
🔔 로그인 성공 - FCM 초기화 시작...
============================================================
🔔 FCM 토큰 정보
============================================================
📱 전체 토큰:
eFG3hD9k2L7mP1qR4sT6vX8yZ0aC2eF4gH6jK8lM0nP2rT4vX6zB1cE3gH5jL7nQ9sU1wY3
============================================================
📨 포그라운드 메시지 수신:
  제목: 김철수
  내용: 010-1234-5678
  데이터: {type: incoming_call, caller_name: 김철수, ...}
📞 수신 전화 화면 표시:
  발신자: 김철수
  번호: 010-1234-5678
```

### 수락/거절 로그

```
✅ 전화 수락됨: 010-1234-5678
// 또는
❌ 전화 거절됨: 010-1234-5678
```

## 🚀 다음 단계

1. **SIP 통화 연동**: 수락/거절 시 실제 SIP 세션 생성/종료
2. **벨소리 추가**: 수신 시 시스템 벨소리 또는 커스텀 사운드
3. **진동 효과**: Vibration API 사용하여 진동 패턴 추가
4. **통화 중 UI**: 수락 후 통화 중 화면으로 전환
5. **통화 기록**: Firestore에 통화 이력 자동 저장

## 💡 팁

- **테스트 시나리오 1**: 앱 실행 중 → 즉시 풀스크린 표시 확인
- **테스트 시나리오 2**: 앱 종료 후 → 알림 탭 → 풀스크린 표시 확인
- **다양한 데이터**: 긴 이름, 특수문자 포함 번호로 테스트
- **아바타 이미지**: caller_avatar에 실제 이미지 URL 전달하여 테스트

## 📚 관련 파일

- `/lib/screens/call/incoming_call_screen.dart` - 풀스크린 UI
- `/lib/services/fcm_service.dart` - FCM 처리 로직
- `/lib/main.dart` - 백그라운드 핸들러 등록
- `/docs/fcm_testing/send_fcm_test_message.py` - 테스트 스크립트

---

**작성일**: 2024-11-03  
**버전**: 1.0.0  
**작성자**: AI Assistant
