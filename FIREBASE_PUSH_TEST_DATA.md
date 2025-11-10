# Firebase Console 푸시 메시지 테스트 데이터

## 🧪 테스트 시나리오

### 1️⃣ 기본 수신 전화 테스트

**Firebase Console > Cloud Messaging > 새 캠페인**

```json
{
  "notification": {
    "title": "김철수",
    "body": "010-1234-5678"
  },
  "data": {
    "caller_name": "김철수",
    "caller_number": "010-1234-5678",
    "call_type": "external"
  }
}
```

**예상 결과**:
- ✅ 포그라운드 알림 표시
- ✅ IncomingCallScreen 자동 표시
- ✅ 발신자: "김철수"
- ✅ 번호: "010-1234-5678"
- ✅ 통화 타입: "external"

---

### 2️⃣ 프로필 이미지 포함 테스트

```json
{
  "notification": {
    "title": "이영희 과장",
    "body": "내선번호: 1234"
  },
  "data": {
    "caller_name": "이영희 과장",
    "caller_number": "1234",
    "caller_avatar": "https://example.com/profile/lee.jpg",
    "call_type": "internal",
    "receiver_number": "5678"
  }
}
```

**예상 결과**:
- ✅ 프로필 이미지 표시 (URL에서 로드)
- ✅ 내선 번호 표시
- ✅ 통화 타입: "internal" (내선)

---

### 3️⃣ 최소 데이터 테스트 (기본값 사용)

```json
{
  "notification": {
    "title": "MAKECALL",
    "body": "수신 전화가 있습니다"
  },
  "data": {}
}
```

**예상 결과**:
- ✅ 발신자: "알 수 없는 발신자" (기본값)
- ✅ 번호: "" (빈 문자열)
- ✅ 통화 타입: "unknown"
- ✅ 화면은 정상 표시됨

---

### 4️⃣ WebSocket 메타데이터 포함 테스트

```json
{
  "notification": {
    "title": "박민수 부장",
    "body": "010-9876-5432"
  },
  "data": {
    "caller_name": "박민수 부장",
    "caller_number": "010-9876-5432",
    "channel": "SIP/1234-00000001",
    "linkedid": "1234567890.123",
    "receiver_number": "5678",
    "call_type": "external"
  }
}
```

**예상 결과**:
- ✅ WebSocket 재연결 시도
- ✅ 채널 정보: "SIP/1234-00000001"
- ✅ 링크 ID: "1234567890.123"
- ✅ 수신 번호: "5678"

---

## 📋 지원되는 데이터 키 목록

| 키 이름 | 대체 키 | 타입 | 필수 | 기본값 | 설명 |
|--------|---------|------|------|--------|------|
| `caller_name` | `callerName` | String | ❌ | "알 수 없는 발신자" | 발신자 이름 |
| `caller_number` | `callerNumber` | String | ❌ | "" | 발신자 전화번호 |
| `caller_avatar` | `callerAvatar` | String (URL) | ❌ | null | 프로필 이미지 URL |
| `channel` | - | String | ❌ | "FCM-PUSH" | 통화 채널 정보 |
| `linkedid` | `linkedId` | String | ❌ | "fcm_[timestamp]" | 통화 연결 ID |
| `receiver_number` | `receiverNumber`, `extension` | String | ❌ | "" | 수신 번호 (내선) |
| `call_type` | `callType` | String | ❌ | "unknown" | internal/external/emergency |

---

## 🔍 Firebase Console 푸시 전송 방법

### **방법 1: FCM 토큰으로 직접 전송** (추천)

1. **Firebase Console 접속**
   ```
   https://console.firebase.google.com/project/makecallio/messaging
   ```

2. **"새 알림" 또는 "새 캠페인" 클릭**

3. **알림 내용 입력**
   - 제목: `김철수`
   - 본문: `010-1234-5678`

4. **대상 선택**
   - "단일 기기"
   - FCM 등록 토큰 입력 (Firestore `fcm_tokens` 컬렉션에서 확인)

5. **추가 옵션 > 맞춤 데이터**
   ```
   caller_name = 김철수
   caller_number = 010-1234-5678
   call_type = external
   ```

6. **"검토" > "게시" 클릭**

---

### **방법 2: REST API로 전송**

```bash
# FCM Server Key 필요 (Firebase Console > 프로젝트 설정 > 클라우드 메시징)

curl -X POST https://fcm.googleapis.com/fcm/send \
  -H "Authorization: key=YOUR_SERVER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "to": "FCM_TOKEN_HERE",
    "notification": {
      "title": "김철수",
      "body": "010-1234-5678"
    },
    "data": {
      "caller_name": "김철수",
      "caller_number": "010-1234-5678",
      "call_type": "external"
    }
  }'
```

---

### **방법 3: Firestore에서 FCM 토큰 확인**

```bash
# Firebase Console > Firestore Database > fcm_tokens 컬렉션
# 문서 선택 후 "fcmToken" 필드 복사
```

**토큰 확인 경로**:
```
fcm_tokens/{userId}_{deviceId}
  └─ fcmToken: "eXXX...XXX" (이 값을 복사)
```

---

## 🎯 테스트 체크리스트

### 포그라운드 테스트
- [ ] 앱이 열려있는 상태에서 푸시 전송
- [ ] 알림 팝업 표시 확인
- [ ] IncomingCallScreen 자동 표시 확인
- [ ] 발신자 정보 정확히 표시되는지 확인
- [ ] 수락 버튼 동작 확인 (스낵바 표시)
- [ ] 거절 버튼 동작 확인 (스낵바 표시)

### 백그라운드 테스트
- [ ] 앱을 백그라운드로 보냄 (홈 버튼)
- [ ] 푸시 전송
- [ ] 알림바에 알림 표시 확인
- [ ] 알림 클릭 시 IncomingCallScreen 표시 확인

### 앱 종료 상태 테스트
- [ ] 앱 완전 종료 (최근 앱에서 닫기)
- [ ] 푸시 전송
- [ ] 알림 수신 확인
- [ ] 알림 클릭 시 앱 실행 및 화면 표시 확인

### 다양한 데이터 시나리오
- [ ] 최소 데이터 (기본값 사용)
- [ ] 프로필 이미지 포함
- [ ] WebSocket 메타데이터 포함
- [ ] 내선 전화 (internal)
- [ ] 외부 전화 (external)

---

## 📝 ADB Logcat 모니터링

테스트 중 실시간 로그 확인:

```bash
adb logcat | grep -E "(FCM|FirebaseMessaging|IncomingCall)"
```

**예상 로그 시퀀스**:
```
I/flutter: 📨 포그라운드 메시지: 김철수
I/flutter: 📨 메시지 데이터: {caller_name: 김철수, caller_number: 010-1234-5678}
I/flutter: 🔔 [FCM] 안드로이드 알림 표시 시작
I/flutter:    제목: 김철수
I/flutter:    내용: 010-1234-5678
I/flutter: 📞 [FCM] 수신 전화 화면 표시 시작...
I/flutter: 📞 [FCM] 수신 전화 화면 표시:
I/flutter:    발신자: 김철수
I/flutter:    번호: 010-1234-5678
I/flutter:    채널: FCM-PUSH
I/flutter:    링크ID: fcm_1234567890123
I/flutter: ✅ [FCM] 안드로이드 알림 표시 완료
I/flutter: ✅ [FCM] 수신 전화 화면 표시 완료
```

---

## 🚨 트러블슈팅

### 문제 1: IncomingCallScreen이 표시되지 않음
**원인**: BuildContext가 설정되지 않음  
**해결**: `main.dart`에서 `FCMService.setContext(context)` 호출 확인

### 문제 2: 데이터가 전달되지 않음
**원인**: Firebase Console에서 "맞춤 데이터" 입력 누락  
**해결**: "추가 옵션 > 맞춤 데이터" 섹션에서 키-값 입력

### 문제 3: 백그라운드에서 화면 표시 안됨
**원인**: 백그라운드 메시지 핸들러 미구현  
**해결**: `main.dart`의 `@pragma('vm:entry-point')` 핸들러 확인

### 문제 4: 프로필 이미지가 로드되지 않음
**원인**: 잘못된 URL 또는 CORS 문제  
**해결**: 유효한 이미지 URL 사용, 네트워크 권한 확인

---

**작성일**: 2025-01-XX  
**다음 단계**: 실제 통화 연결 로직 구현 (SIP/WebRTC)
