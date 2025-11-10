# iOS 푸시 알림 소리/진동 설정 가이드

## 🔊 문제: iOS에서 알림음과 진동이 작동하지 않음

---

## ✅ 해결 방법

### 1. **FCM 페이로드에 `sound` 필드 추가**

iOS에서 알림음이 울리려면 반드시 `sound` 필드를 포함해야 합니다.

#### ❌ 잘못된 페이로드 (소리 없음):
```json
{
  "notification": {
    "title": "새 메시지",
    "body": "안녕하세요!"
  },
  "token": "FCM_TOKEN"
}
```

#### ✅ 올바른 페이로드 (소리 있음):
```json
{
  "notification": {
    "title": "새 메시지",
    "body": "안녕하세요!",
    "sound": "default"
  },
  "apns": {
    "payload": {
      "aps": {
        "alert": {
          "title": "새 메시지",
          "body": "안녕하세요!"
        },
        "sound": "default",
        "badge": 1,
        "category": "MESSAGE_CATEGORY"
      }
    }
  },
  "token": "FCM_TOKEN"
}
```

---

## 📱 Firebase Console에서 테스트하기

### 1. Firebase Console → Cloud Messaging
1. **"Send test message"** 또는 **"새 알림"** 클릭
2. **알림 제목**: "테스트 메시지"
3. **알림 텍스트**: "소리와 진동 테스트"
4. **대상**: 테스트할 FCM 토큰 입력

### 2. **추가 옵션 설정 (중요!)**
- **소리**: "기본값" 또는 "default" 선택 ✅
- **iOS 알림 옵션** 탭:
  - ✅ **사운드**: "default"
  - ✅ **배지**: 1
  - ✅ **중요도**: "high"

---

## 🔧 코드에서 FCM 메시지 전송 시

### Node.js (Firebase Admin SDK):
```javascript
const message = {
  notification: {
    title: '새 메시지',
    body: '안녕하세요!'
  },
  apns: {
    payload: {
      aps: {
        alert: {
          title: '새 메시지',
          body: '안녕하세요!'
        },
        sound: 'default',  // ← 필수!
        badge: 1
      }
    }
  },
  token: fcmToken
};

await admin.messaging().send(message);
```

### Python (Firebase Admin SDK):
```python
from firebase_admin import messaging

message = messaging.Message(
    notification=messaging.Notification(
        title='새 메시지',
        body='안녕하세요!'
    ),
    apns=messaging.APNSConfig(
        payload=messaging.APNSPayload(
            aps=messaging.Aps(
                alert=messaging.ApsAlert(
                    title='새 메시지',
                    body='안녕하세요!'
                ),
                sound='default',  # ← 필수!
                badge=1
            )
        )
    ),
    token=fcm_token
)

response = messaging.send(message)
```

### REST API (HTTP v1):
```bash
curl -X POST https://fcm.googleapis.com/v1/projects/YOUR_PROJECT_ID/messages:send \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "message": {
      "notification": {
        "title": "새 메시지",
        "body": "안녕하세요!"
      },
      "apns": {
        "payload": {
          "aps": {
            "alert": {
              "title": "새 메시지",
              "body": "안녕하세요!"
            },
            "sound": "default",
            "badge": 1
          }
        }
      },
      "token": "FCM_TOKEN"
    }
  }'
```

---

## 📱 iOS 기기 설정 확인

### 1. **앱 알림 권한 확인**
- 설정 → 알림 → **MakeCall** (앱 이름)
- ✅ **알림 허용** 켜짐
- ✅ **소리** 켜짐
- ✅ **배지** 켜짐
- ✅ **알림 스타일**: 배너 또는 알림

### 2. **기기 사운드 설정 확인**
- 설정 → 사운드 및 햅틱
- ✅ **벨소리 및 알림** 볼륨 확인 (중간 이상)
- ✅ **무음 모드에서 진동** 켜짐 (선택사항)

### 3. **무음 모드 확인**
- 기기 측면의 **무음 스위치** 확인
- ⚠️ 무음 모드일 때는 **진동만** 울림 (소리 없음)

### 4. **방해 금지 모드 확인**
- 설정 → 집중 모드
- ⚠️ 방해 금지 모드가 켜져 있으면 알림이 울리지 않음

---

## 🧪 테스트 순서

### 1단계: Firebase Console 테스트
1. Firebase Console → Cloud Messaging
2. "Send test message" 클릭
3. FCM 토큰 입력
4. **추가 옵션** → iOS 알림 옵션 → **사운드: "default"** 설정 ✅
5. 메시지 전송

### 2단계: 앱 상태별 테스트
- **포그라운드** (앱 실행 중): 배너 알림 + 소리 + 진동
- **백그라운드** (앱 백그라운드): 알림 센터 + 소리 + 진동
- **종료 상태** (앱 완전 종료): 알림 센터 + 소리 + 진동

### 3단계: 기기 설정 확인
- 무음 모드 **OFF** 상태에서 테스트
- 볼륨 중간 이상으로 설정
- 방해 금지 모드 **OFF** 상태에서 테스트

---

## 🎯 예상 동작

### ✅ 정상 동작:
```
📬 푸시 알림 수신
🔊 "딩동" 소리 (기본 알림음)
📳 진동 (1-2초)
📱 화면 켜짐
🔔 배너 또는 알림 센터에 표시
🔴 앱 아이콘 배지 숫자 증가
```

### ❌ 비정상 동작 (소리/진동 없음):
```
📬 푸시 알림 수신
❌ 소리 없음
❌ 진동 없음
📱 화면 켜지지 않음
🔔 알림 센터에만 조용히 표시
```

→ **FCM 페이로드에 `sound: "default"` 추가 필요!**

---

## 🔍 디버깅 로그

AppDelegate에 추가된 로그를 확인하세요:

```
📬 [NOTIFICATION] 알림 탭됨
   - Title: 새 메시지
   - Body: 안녕하세요!
   - UserInfo: [AnyHashable("gcm.message_id"): "...", ...]
```

**UserInfo에 `sound` 필드가 있는지 확인**하세요!

---

## 🚀 커스텀 알림음 사용하기

기본 소리 대신 커스텀 소리를 사용하려면:

### 1. 사운드 파일 추가
- **파일 형식**: `.aiff`, `.wav`, `.caf` (30초 이하)
- **파일 위치**: `ios/Runner/Resources/` 폴더
- **파일 이름**: 예) `notification_sound.aiff`

### 2. Xcode 프로젝트에 추가
1. Xcode에서 `ios/Runner.xcworkspace` 열기
2. Runner → Resources 폴더에 사운드 파일 드래그
3. **"Copy items if needed"** 체크 ✅
4. **"Add to targets: Runner"** 체크 ✅

### 3. FCM 페이로드에서 사용
```json
{
  "apns": {
    "payload": {
      "aps": {
        "sound": "notification_sound.aiff"
      }
    }
  }
}
```

---

## 📊 요약

| 항목 | 필수 여부 | 설정 위치 |
|------|----------|----------|
| FCM 페이로드 `sound: "default"` | ✅ 필수 | 서버 코드 또는 Firebase Console |
| iOS 앱 알림 권한 | ✅ 필수 | 기기 설정 → 알림 |
| iOS 사운드 볼륨 | ✅ 필수 | 기기 설정 → 사운드 |
| 무음 모드 OFF | ⚠️ 권장 | 기기 측면 스위치 |
| 방해 금지 모드 OFF | ⚠️ 권장 | 기기 설정 → 집중 모드 |

---

## ✅ 체크리스트

- [ ] FCM 페이로드에 `"sound": "default"` 포함됨
- [ ] iOS 기기 설정 → 알림 → 앱 → **소리** 켜짐
- [ ] iOS 기기 설정 → 사운드 → **볼륨** 중간 이상
- [ ] 무음 모드 **OFF** (측면 스위치)
- [ ] 방해 금지 모드 **OFF**
- [ ] Firebase Console 테스트에서 **iOS 알림 옵션** → **사운드** 설정
- [ ] 앱 완전히 재시작 후 테스트

모든 항목을 확인한 후에도 소리가 나지 않으면, **FCM 페이로드 로그를 공유**해주세요! 🔊
