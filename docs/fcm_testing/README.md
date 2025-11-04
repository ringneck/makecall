# 📱 FCM 푸시 알림 테스트 가이드

MakeCall 앱의 FCM 푸시 알림 기능을 테스트하기 위한 도구와 가이드입니다.

## 🚀 빠른 시작

### 1. Firebase Console에서 테스트 (가장 쉬운 방법) ⭐

1. [Firebase Console](https://console.firebase.google.com/) 접속
2. 프로젝트 선택 → **Engage** → **Messaging**
3. **"New campaign"** 클릭
4. 메시지 작성 후 **"Single device"** 선택
5. FCM 토큰 입력 후 **"Publish"**

**FCM 토큰 확인 방법:**
- 앱 실행 → 로그인 → 콘솔 로그 확인
- 또는 Firestore의 `fcm_tokens` 컬렉션에서 확인

---

### 2. Python 스크립트로 테스트 (자동화)

```bash
# 스크립트 실행
python3 docs/fcm_testing/send_fcm_test_message.py
```

**기능:**
- ✅ Firestore에서 활성 FCM 토큰 자동 조회
- ✅ 4가지 메시지 템플릿 제공
- ✅ 대화형 토큰/메시지 선택
- ✅ 발송 결과 자동 로깅

**메시지 타입:**
1. 기본 테스트 알림
2. 수신 전화 알림 📞
3. 부재중 전화 알림 📵
4. 새 메시지 알림 💬

---

### 3. curl 명령어로 테스트 (수동)

```bash
# 예제 보기
cat docs/fcm_testing/fcm_curl_examples.sh

# Server Key와 FCM Token을 변경 후 실행
curl -X POST https://fcm.googleapis.com/fcm/send \
  -H "Authorization: key=YOUR_SERVER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "to": "YOUR_FCM_TOKEN",
    "notification": {
      "title": "테스트 알림",
      "body": "FCM 푸시 알림 테스트입니다"
    }
  }'
```

---

## 📋 사전 준비

### 1. Firestore 컬렉션 생성

FCM 토큰과 설정을 저장할 컬렉션을 생성합니다:

```bash
python3 docs/fcm_testing/create_fcm_tokens_collection.py
```

생성되는 컬렉션:
- `fcm_tokens` - FCM 토큰 저장
- `user_notification_settings` - 사용자별 알림 설정
- `notification_logs` - 알림 발송 이력

### 2. Firebase Admin SDK 키 확인

Python 스크립트 사용 시 필요:
- 위치: `/opt/flutter/firebase-admin-sdk.json`
- 없다면: Firebase Console → Project Settings → Service accounts → Generate new private key

### 3. Firebase Server Key 확인

curl/Postman 사용 시 필요:
- Firebase Console → Project Settings → Cloud Messaging → Server key

---

## 🧪 테스트 시나리오

### 기본 알림 테스트
```json
{
  "notification": {
    "title": "테스트 알림",
    "body": "FCM 푸시 알림 테스트입니다"
  }
}
```

### 수신 전화 알림
```json
{
  "notification": {
    "title": "📞 수신 전화",
    "body": "010-1234-5678에서 전화가 왔습니다"
  },
  "data": {
    "type": "incoming_call",
    "phoneNumber": "010-1234-5678"
  }
}
```

### 부재중 전화 알림
```json
{
  "notification": {
    "title": "📵 부재중 전화",
    "body": "010-9876-5432님의 부재중 전화 1건"
  },
  "data": {
    "type": "missed_call",
    "phoneNumber": "010-9876-5432"
  }
}
```

---

## 🔍 문제 해결

### 알림이 수신되지 않을 때

1. **FCM 토큰 확인**
   - 토큰이 정확한지 확인
   - Firestore에서 `isActive: true`인지 확인

2. **알림 권한 확인**
   - 기기 설정 → 앱 알림 권한
   - 앱 내 설정 → 푸시 알림 활성화

3. **네트워크 연결 확인**
   - 인터넷 연결 상태
   - 방화벽 설정

4. **앱 상태 확인**
   - 포그라운드: 앱 실행 중
   - 백그라운드: 알림 트레이에 표시
   - 종료: Android는 수신 가능

5. **Firebase 설정 확인**
   - `google-services.json` 파일 확인
   - Firebase 프로젝트에서 FCM 활성화 확인

---

## 📚 추가 자료

- **상세 가이드**: [fcm_test_guide.md](./fcm_test_guide.md)
- **Python 스크립트**: [send_fcm_test_message.py](./send_fcm_test_message.py)
- **curl 예제**: [fcm_curl_examples.sh](./fcm_curl_examples.sh)
- **DB 초기화**: [create_fcm_tokens_collection.py](./create_fcm_tokens_collection.py)

---

## 🎯 권장 테스트 순서

1. ✅ **DB 초기화**: `create_fcm_tokens_collection.py` 실행
2. ✅ **앱 실행**: 로그인하여 FCM 토큰 생성
3. ✅ **Firebase Console**: 첫 테스트 메시지 발송
4. ✅ **Python 스크립트**: 자동화된 다양한 테스트
5. ✅ **로그 확인**: Firestore의 `notification_logs` 확인

---

## 💡 팁

- **개발 중**: Firebase Console의 "Send test message" 기능 사용
- **자동화 테스트**: Python 스크립트를 CI/CD에 통합
- **프로덕션**: Server Key 대신 Firebase Admin SDK 사용 권장
- **다중 기기**: `registration_ids` 배열로 여러 토큰에 동시 발송
- **토픽 구독**: 사용자 그룹별 알림 관리

---

## 📞 문의

FCM 테스트 관련 문제가 있다면:
1. [Firebase 공식 문서](https://firebase.google.com/docs/cloud-messaging) 참조
2. Firestore의 `notification_logs` 컬렉션에서 에러 로그 확인
3. Flutter 앱의 콘솔 로그 확인
