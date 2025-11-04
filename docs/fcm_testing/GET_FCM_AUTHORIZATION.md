# 🔑 FCM Authorization Key 획득 가이드

## 📋 목차

1. [방법 1: Firebase Admin SDK (권장)](#방법-1-firebase-admin-sdk-권장)
2. [방법 2: Legacy Server Key (간단하지만 구형)](#방법-2-legacy-server-key-간단하지만-구형)
3. [방법 3: OAuth 2.0 Access Token (고급)](#방법-3-oauth-20-access-token-고급)

---

## 방법 1: Firebase Admin SDK (권장)

### ✅ **장점**
- 자동으로 Access Token 생성 및 갱신
- 보안성 높음 (서버 측에서만 사용)
- Firebase의 모든 기능 사용 가능

### 📦 **필요한 것**
- Firebase Admin SDK JSON 파일 (`/opt/flutter/firebase-admin-sdk.json`)

### 🔧 **이미 구현된 방법 (Python)**

현재 프로젝트에서 사용 중인 방법입니다:

```python
# send_fcm_test_message.py 참고
import firebase_admin
from firebase_admin import credentials, messaging

# 1. Admin SDK 초기화
cred = credentials.Certificate('/opt/flutter/firebase-admin-sdk.json')
firebase_admin.initialize_app(cred)

# 2. 메시지 발송 (자동으로 인증 처리됨)
message = messaging.Message(
    notification=messaging.Notification(
        title='수신 전화',
        body='010-1234-5678',
    ),
    data={'type': 'incoming_call', ...},
    token='FCM_TOKEN_HERE',
)

response = messaging.send(message)  # ✅ 인증 자동 처리!
```

### 📱 **사용 방법**
```bash
cd /home/user/flutter_app
python3 docs/fcm_testing/send_fcm_test_message.py
```

---

## 방법 2: Legacy Server Key (간단하지만 구형)

### ⚠️ **단점**
- Google이 권장하지 않음 (곧 deprecated 예정)
- 보안성 낮음 (키가 노출되면 위험)

### 🔍 **Server Key 확인 방법**

#### **단계 1: Firebase Console 접속**
1. https://console.firebase.google.com/ 접속
2. 프로젝트 선택

#### **단계 2: Cloud Messaging 설정 열기**
1. ⚙️ **Project Settings** (왼쪽 상단 톱니바퀴 아이콘)
2. **Cloud Messaging** 탭 클릭

#### **단계 3: Server Key 복사**
```
Server key: AAAA...xyz (긴 문자열)
```

### 💻 **curl 사용 예제**

```bash
# Legacy FCM HTTP API (곧 deprecated)
curl -X POST https://fcm.googleapis.com/fcm/send \
  -H "Authorization: key=YOUR_SERVER_KEY_HERE" \
  -H "Content-Type: application/json" \
  -d '{
    "to": "FCM_TOKEN_HERE",
    "notification": {
      "title": "김철수",
      "body": "010-1234-5678"
    },
    "data": {
      "type": "incoming_call",
      "caller_name": "김철수",
      "caller_number": "010-1234-5678"
    },
    "priority": "high"
  }'
```

### ⚠️ **주의사항**
- 이 방법은 **Legacy API**이므로 새 프로젝트에는 권장하지 않음
- 2024년 이후 지원 중단 예정
- 대신 **FCM v1 API** 사용 권장

---

## 방법 3: OAuth 2.0 Access Token (고급)

### ✅ **장점**
- 최신 FCM v1 API 사용
- 보안성 최고
- Google 권장 방법

### 🔧 **Access Token 생성 방법**

#### **Python 코드**

```python
import firebase_admin
from firebase_admin import credentials
import google.auth.transport.requests

# 1. Admin SDK 초기화
cred = credentials.Certificate('/opt/flutter/firebase-admin-sdk.json')
firebase_admin.initialize_app(cred)

# 2. Access Token 생성
request = google.auth.transport.requests.Request()
cred.get_access_token(request)

print(f"Access Token: {cred.access_token}")
print(f"Token Expiry: {cred.expiry}")
```

#### **자동화 스크립트**

```bash
#!/bin/bash
# get_access_token.sh

ACCESS_TOKEN=$(python3 -c "
import firebase_admin
from firebase_admin import credentials
import google.auth.transport.requests

cred = credentials.Certificate('/opt/flutter/firebase-admin-sdk.json')
firebase_admin.initialize_app(cred)

request = google.auth.transport.requests.Request()
cred.get_access_token(request)
print(cred.access_token)
")

echo "Access Token: $ACCESS_TOKEN"
```

### 💻 **curl 사용 예제 (FCM v1 API)**

```bash
# 1. Access Token 획득
ACCESS_TOKEN=$(python3 -c "
import firebase_admin
from firebase_admin import credentials
import google.auth.transport.requests
cred = credentials.Certificate('/opt/flutter/firebase-admin-sdk.json')
firebase_admin.initialize_app(cred)
request = google.auth.transport.requests.Request()
cred.get_access_token(request)
print(cred.access_token)
")

# 2. Project ID 확인 (Admin SDK JSON에서)
PROJECT_ID=$(python3 -c "
import json
with open('/opt/flutter/firebase-admin-sdk.json') as f:
    data = json.load(f)
    print(data['project_id'])
")

# 3. FCM v1 API로 메시지 발송
curl -X POST \
  "https://fcm.googleapis.com/v1/projects/${PROJECT_ID}/messages:send" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "message": {
      "token": "FCM_TOKEN_HERE",
      "notification": {
        "title": "김철수",
        "body": "010-1234-5678"
      },
      "data": {
        "type": "incoming_call",
        "caller_name": "김철수",
        "caller_number": "010-1234-5678",
        "caller_avatar": "",
        "callId": "call_12345"
      },
      "android": {
        "priority": "high"
      }
    }
  }'
```

---

## 🎯 **권장 방법 비교**

| 방법 | 난이도 | 보안성 | 유효기간 | 권장도 |
|-----|--------|--------|---------|--------|
| **Admin SDK (Python)** | ⭐ 쉬움 | ⭐⭐⭐ 높음 | 자동 갱신 | ✅ **최고 권장** |
| **OAuth Access Token** | ⭐⭐ 보통 | ⭐⭐⭐ 높음 | 1시간 | ✅ 권장 |
| **Legacy Server Key** | ⭐ 매우 쉬움 | ⭐ 낮음 | 영구 | ⚠️ 비권장 |

---

## 📝 **실전 사용 예제**

### **시나리오 1: Python 스크립트로 테스트 (현재 방법)**

```bash
# ✅ 가장 간편하고 권장됨
cd /home/user/flutter_app
python3 docs/fcm_testing/send_fcm_test_message.py
# "2" 선택 (수신 전화 알림)
```

**장점:**
- 인증 완전 자동화
- Access Token 자동 생성 및 갱신
- 코드가 간결함

---

### **시나리오 2: curl로 빠른 테스트**

```bash
# 1. Access Token 생성 스크립트 저장
cat > /tmp/get_fcm_token.py << 'EOF'
import firebase_admin
from firebase_admin import credentials
import google.auth.transport.requests

cred = credentials.Certificate('/opt/flutter/firebase-admin-sdk.json')
firebase_admin.initialize_app(cred)
request = google.auth.transport.requests.Request()
cred.get_access_token(request)
print(cred.access_token)
EOF

# 2. 환경 변수 설정
export FCM_TOKEN="YOUR_FCM_TOKEN_HERE"
export ACCESS_TOKEN=$(python3 /tmp/get_fcm_token.py)
export PROJECT_ID=$(python3 -c "import json; print(json.load(open('/opt/flutter/firebase-admin-sdk.json'))['project_id'])")

# 3. FCM 메시지 발송
curl -X POST \
  "https://fcm.googleapis.com/v1/projects/${PROJECT_ID}/messages:send" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"message\": {
      \"token\": \"${FCM_TOKEN}\",
      \"notification\": {
        \"title\": \"김철수\",
        \"body\": \"010-1234-5678\"
      },
      \"data\": {
        \"type\": \"incoming_call\",
        \"caller_name\": \"김철수\",
        \"caller_number\": \"010-1234-5678\"
      }
    }
  }"
```

---

### **시나리오 3: Postman/Insomnia 사용**

#### **단계 1: Access Token 생성**

```python
# Terminal에서 실행
python3 -c "
import firebase_admin
from firebase_admin import credentials
import google.auth.transport.requests
cred = credentials.Certificate('/opt/flutter/firebase-admin-sdk.json')
firebase_admin.initialize_app(cred)
request = google.auth.transport.requests.Request()
cred.get_access_token(request)
print(cred.access_token)
"
```

#### **단계 2: Postman 설정**

**Request 설정:**
- **Method**: POST
- **URL**: `https://fcm.googleapis.com/v1/projects/YOUR_PROJECT_ID/messages:send`

**Headers:**
```
Authorization: Bearer YOUR_ACCESS_TOKEN
Content-Type: application/json
```

**Body (JSON):**
```json
{
  "message": {
    "token": "FCM_TOKEN_HERE",
    "notification": {
      "title": "김철수",
      "body": "010-1234-5678"
    },
    "data": {
      "type": "incoming_call",
      "caller_name": "김철수",
      "caller_number": "010-1234-5678",
      "caller_avatar": "",
      "callId": "call_12345"
    },
    "android": {
      "priority": "high"
    }
  }
}
```

---

## 🔍 **Admin SDK JSON 파일 구조**

```json
{
  "type": "service_account",
  "project_id": "your-project-id",
  "private_key_id": "...",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
  "client_email": "firebase-adminsdk-xxxxx@your-project.iam.gserviceaccount.com",
  "client_id": "...",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "..."
}
```

**중요 필드:**
- `project_id`: FCM API URL에 사용
- `private_key`: Access Token 생성에 사용
- `client_email`: 서비스 계정 이메일

---

## 🛡️ **보안 주의사항**

### ❌ **절대 하지 말아야 할 것**
- Admin SDK JSON 파일을 Git에 커밋
- Server Key를 클라이언트 코드에 포함
- Access Token을 로그에 출력

### ✅ **권장 사항**
- Admin SDK JSON은 서버 측에만 저장
- 환경 변수로 민감한 정보 관리
- Access Token은 1시간마다 자동 갱신

---

## 📚 **참고 자료**

- [Firebase Admin SDK 공식 문서](https://firebase.google.com/docs/admin/setup)
- [FCM HTTP v1 API 문서](https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages)
- [Firebase Admin Python 참조](https://firebase.google.com/docs/reference/admin/python)

---

## 💡 **빠른 참조**

### **현재 프로젝트에서 사용 중인 방법**
```bash
# ✅ 가장 간편 - 이미 구현되어 있음
python3 docs/fcm_testing/send_fcm_test_message.py
```

### **Access Token만 빠르게 확인**
```bash
python3 -c "
import firebase_admin
from firebase_admin import credentials
import google.auth.transport.requests
cred = credentials.Certificate('/opt/flutter/firebase-admin-sdk.json')
firebase_admin.initialize_app(cred)
request = google.auth.transport.requests.Request()
cred.get_access_token(request)
print('Access Token:', cred.access_token)
print('Expires:', cred.expiry)
"
```

### **Legacy Server Key 확인**
Firebase Console → Project Settings → Cloud Messaging → Server key

---

**작성일**: 2024-11-03  
**버전**: 1.0.0
