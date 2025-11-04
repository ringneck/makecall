# FCM 푸시 알림 테스트 가이드

## 방법 1: Firebase Console에서 테스트 메시지 보내기 (권장)

### 단계 1: Firebase Console 접속
1. https://console.firebase.google.com/ 접속
2. 프로젝트 선택
3. 좌측 메뉴에서 **"Engage" → "Messaging"** 클릭
4. **"Send your first message"** 또는 **"New campaign"** 클릭

### 단계 2: 메시지 작성
1. **Notification title**: "테스트 알림"
2. **Notification text**: "FCM 푸시 알림 테스트입니다"
3. **Notification image** (선택사항): 이미지 URL 입력
4. **Next** 클릭

### 단계 3: 대상 선택
1. **Target**에서 다음 중 하나 선택:
   - **User segment**: 모든 사용자
   - **Topic**: 특정 토픽 구독자
   - **Single device**: 특정 FCM 토큰 (개발 테스트에 가장 좋음)

2. **Single device** 선택 시:
   - **FCM registration token** 입력란에 테스트할 기기의 FCM 토큰 붙여넣기
   - 토큰은 앱 실행 시 콘솔 로그에서 확인 가능

### 단계 4: 추가 옵션 설정 (선택사항)
1. **Scheduling**: 즉시 발송 또는 예약
2. **Additional options**:
   - Custom data 추가 가능
   - Sound, Badge, Click action 설정

### 단계 5: 발송
1. **Review** 클릭하여 내용 확인
2. **Publish** 클릭하여 메시지 발송
3. 기기에서 알림 수신 확인

---

## 방법 2: Python 스크립트로 테스트 메시지 보내기

### 장점
- 자동화된 테스트 가능
- 다양한 메시지 형식 테스트 가능
- CI/CD 파이프라인에 통합 가능

### 스크립트 사용 방법
```bash
# Python 스크립트 실행
python3 /home/user/send_fcm_test_message.py
```

### 스크립트 주요 기능
1. Firestore에서 활성 FCM 토큰 자동 조회
2. 다양한 메시지 템플릿 제공
3. 발송 결과 로깅
4. 오류 처리 및 재시도

---

## 방법 3: Postman을 사용한 HTTP 요청

### 준비사항
1. Firebase 프로젝트의 **Server Key** 필요
   - Firebase Console → Project Settings → Cloud Messaging → Server key

### HTTP 요청 설정
- **Method**: POST
- **URL**: https://fcm.googleapis.com/fcm/send
- **Headers**:
  ```
  Content-Type: application/json
  Authorization: key=YOUR_SERVER_KEY
  ```
- **Body** (raw JSON):
  ```json
  {
    "to": "FCM_TOKEN_HERE",
    "notification": {
      "title": "테스트 알림",
      "body": "Postman에서 보낸 메시지입니다",
      "sound": "default"
    },
    "data": {
      "type": "test",
      "timestamp": "2024-01-01T00:00:00Z"
    },
    "priority": "high"
  }
  ```

---

## FCM 토큰 확인 방법

### Android/iOS 앱에서
1. 앱 실행
2. 로그인
3. Flutter 콘솔 로그 확인:
   ```
   🔔 FCM 서비스 초기화 시작...
   📱 알림 권한 상태: authorized
   ✅ FCM 토큰 획득: eFG3hD9k2L7mP1qR4sT6...
   ```

### Firestore에서 직접 확인
1. Firebase Console → Firestore Database
2. `fcm_tokens` 컬렉션 열기
3. 문서 ID가 FCM 토큰
4. 원하는 사용자의 토큰 복사

---

## 테스트 시나리오

### 1. 기본 알림 테스트
```json
{
  "to": "YOUR_FCM_TOKEN",
  "notification": {
    "title": "수신 전화",
    "body": "010-1234-5678에서 전화가 왔습니다"
  }
}
```

### 2. 데이터 메시지 테스트
```json
{
  "to": "YOUR_FCM_TOKEN",
  "data": {
    "type": "incoming_call",
    "phoneNumber": "010-1234-5678",
    "callId": "call_12345",
    "timestamp": "1640000000000"
  }
}
```

### 3. 알림 + 데이터 조합
```json
{
  "to": "YOUR_FCM_TOKEN",
  "notification": {
    "title": "부재중 전화",
    "body": "010-1234-5678님의 부재중 전화 1건"
  },
  "data": {
    "type": "missed_call",
    "phoneNumber": "010-1234-5678",
    "missedAt": "1640000000000"
  }
}
```

---

## 문제 해결

### 알림이 수신되지 않을 때

1. **FCM 토큰 확인**
   - 토큰이 정확한지 확인
   - 토큰이 활성화되어 있는지 Firestore에서 확인

2. **알림 권한 확인**
   - 기기 설정 → 앱 알림 권한 확인
   - 앱 내 설정 → 푸시 알림 활성화 확인

3. **네트워크 연결 확인**
   - 기기가 인터넷에 연결되어 있는지 확인
   - 방화벽이 FCM 트래픽을 차단하지 않는지 확인

4. **앱 상태 확인**
   - 포그라운드: 앱 실행 중
   - 백그라운드: 앱이 백그라운드에 있음
   - 종료: 앱이 완전히 종료됨 (Android는 수신 가능)

5. **Firebase 프로젝트 설정 확인**
   - google-services.json (Android) 파일이 올바른지 확인
   - Firebase 프로젝트 설정에서 FCM이 활성화되어 있는지 확인

---

## 고급 테스트

### 다중 기기 테스트
```json
{
  "registration_ids": [
    "TOKEN_1",
    "TOKEN_2",
    "TOKEN_3"
  ],
  "notification": {
    "title": "그룹 알림",
    "body": "모든 기기에 동시 발송"
  }
}
```

### 토픽 기반 테스트
```json
{
  "to": "/topics/all_users",
  "notification": {
    "title": "공지사항",
    "body": "모든 사용자에게 공지"
  }
}
```

### 조건부 발송
```json
{
  "condition": "'android' in topics || 'ios' in topics",
  "notification": {
    "title": "플랫폼별 알림",
    "body": "Android 또는 iOS 사용자만"
  }
}
```

---

## 참고 자료

- Firebase Cloud Messaging 공식 문서: https://firebase.google.com/docs/cloud-messaging
- FCM HTTP v1 API: https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages
- Flutter Firebase Messaging 패키지: https://pub.dev/packages/firebase_messaging
