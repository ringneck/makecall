# Asterisk에서 FCM 푸시 전송 솔루션 (Debian 12+)

## 🎯 아키텍처 개요

```
┌─────────────────────┐
│ Asterisk Server 1   │─┐
│ (Dialplan)          │ │
└─────────────────────┘ │
                        │    ┌──────────────────┐
┌─────────────────────┐ ├───→│ Push Server 1    │─┐
│ Asterisk Server 2   │ │    │ (Primary)        │ │
│ (Dialplan)          │ │    └──────────────────┘ │
└─────────────────────┘ │                         │   ┌──────────────┐
                        │    ┌──────────────────┐ ├──→│ FCM Server   │
┌─────────────────────┐ ├───→│ Push Server 2    │ │   │ (Google)     │
│ Asterisk Server N   │ │    │ (Backup)         │─┘   └──────────────┘
│ (Dialplan)          │ │    └──────────────────┘
└─────────────────────┘─┘
```

---

## 📦 1. Push Server 설치 (Python FastAPI)

### 1.1 시스템 요구사항
- **OS**: Debian 12 이상
- **Python**: 3.11+
- **메모리**: 최소 512MB (권장 1GB)
- **디스크**: 10GB

### 1.2 필수 패키지 설치

```bash
#!/bin/bash
# install_push_server.sh

# 시스템 패키지 업데이트
apt update && apt upgrade -y

# Python 3.11 및 pip 설치
apt install -y python3.11 python3.11-venv python3-pip

# 필수 도구 설치
apt install -y curl wget git vim supervisor nginx

# 작업 디렉토리 생성
mkdir -p /opt/fcm-push-server
cd /opt/fcm-push-server

# Python 가상환경 생성
python3.11 -m venv venv
source venv/bin/activate

# Python 패키지 설치 (고정 버전)
pip install --upgrade pip
pip install fastapi==0.104.1
pip install uvicorn[standard]==0.24.0
pip install firebase-admin==6.2.0
pip install pydantic==2.5.0
pip install python-multipart==0.0.6
pip install requests==2.31.0

echo "✅ Push Server 설치 완료"
```

---

## 🔥 2. Push Server 코드 (fcm_push_server.py)

```python
#!/usr/bin/env python3
# /opt/fcm-push-server/fcm_push_server.py

from fastapi import FastAPI, HTTPException, Header
from pydantic import BaseModel
from typing import Optional, Dict, Any
import firebase_admin
from firebase_admin import credentials, messaging
import logging
import os
import sys
from datetime import datetime

# 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/fcm-push-server.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

# FastAPI 앱 초기화
app = FastAPI(
    title="FCM Push Server for Asterisk",
    version="1.0.0",
    description="High-performance FCM push notification server"
)

# Firebase Admin SDK 초기화
FIREBASE_CREDENTIALS_PATH = os.getenv(
    'FIREBASE_CREDENTIALS_PATH',
    '/opt/fcm-push-server/firebase-admin-sdk.json'
)

# API 인증 토큰 (환경변수에서 로드)
API_SECRET_TOKEN = os.getenv('API_SECRET_TOKEN', 'YOUR_SECURE_TOKEN_HERE')

# Firebase 초기화
try:
    cred = credentials.Certificate(FIREBASE_CREDENTIALS_PATH)
    firebase_admin.initialize_app(cred)
    logger.info("✅ Firebase Admin SDK 초기화 완료")
except Exception as e:
    logger.error(f"❌ Firebase 초기화 실패: {e}")
    sys.exit(1)


# 요청 모델
class PushRequest(BaseModel):
    fcm_token: str
    title: str
    body: str
    caller_id: Optional[str] = None
    caller_name: Optional[str] = None
    call_type: Optional[str] = "voice"
    data: Optional[Dict[str, Any]] = None


class BatchPushRequest(BaseModel):
    tokens: list[str]
    title: str
    body: str
    data: Optional[Dict[str, Any]] = None


# 헬스 체크
@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "service": "FCM Push Server"
    }


# 단일 푸시 전송
@app.post("/send")
async def send_push(
    request: PushRequest,
    authorization: str = Header(None)
):
    """
    단일 FCM 푸시 알림 전송
    
    Headers:
        Authorization: Bearer YOUR_SECRET_TOKEN
    
    Body:
        {
            "fcm_token": "FCM_TOKEN",
            "title": "수신 전화",
            "body": "010-1234-5678",
            "caller_id": "01012345678",
            "caller_name": "홍길동",
            "call_type": "voice",
            "data": {"key": "value"}
        }
    """
    # 인증 확인
    if not authorization or authorization != f"Bearer {API_SECRET_TOKEN}":
        logger.warning(f"❌ 인증 실패: {authorization}")
        raise HTTPException(status_code=401, detail="Unauthorized")
    
    try:
        # FCM 메시지 구성
        message = messaging.Message(
            notification=messaging.Notification(
                title=request.title,
                body=request.body,
            ),
            data={
                "caller_id": request.caller_id or "",
                "caller_name": request.caller_name or "",
                "call_type": request.call_type,
                "timestamp": datetime.now().isoformat(),
                **(request.data or {})
            },
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        alert=messaging.ApsAlert(
                            title=request.title,
                            body=request.body
                        ),
                        sound="default",  # ← iOS 알림음 필수!
                        badge=1,
                        category="CALL_CATEGORY",
                        thread_id="incoming_call"
                    )
                )
            ),
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    sound="default",
                    priority="max",
                    channel_id="calls"
                )
            ),
            token=request.fcm_token
        )
        
        # 메시지 전송
        response = messaging.send(message)
        
        logger.info(f"✅ 푸시 전송 성공: {response}")
        logger.info(f"   - Token: {request.fcm_token[:20]}...")
        logger.info(f"   - Title: {request.title}")
        logger.info(f"   - Body: {request.body}")
        
        return {
            "success": True,
            "message_id": response,
            "timestamp": datetime.now().isoformat()
        }
        
    except messaging.UnregisteredError:
        logger.error(f"❌ 유효하지 않은 FCM 토큰: {request.fcm_token[:20]}...")
        raise HTTPException(status_code=404, detail="Invalid FCM token")
    
    except Exception as e:
        logger.error(f"❌ 푸시 전송 실패: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# 배치 푸시 전송
@app.post("/send-batch")
async def send_batch_push(
    request: BatchPushRequest,
    authorization: str = Header(None)
):
    """
    배치 FCM 푸시 알림 전송 (최대 500개)
    """
    # 인증 확인
    if not authorization or authorization != f"Bearer {API_SECRET_TOKEN}":
        raise HTTPException(status_code=401, detail="Unauthorized")
    
    if len(request.tokens) > 500:
        raise HTTPException(
            status_code=400,
            detail="Maximum 500 tokens per batch"
        )
    
    try:
        messages = [
            messaging.Message(
                notification=messaging.Notification(
                    title=request.title,
                    body=request.body
                ),
                data=request.data or {},
                apns=messaging.APNSConfig(
                    payload=messaging.APNSPayload(
                        aps=messaging.Aps(
                            sound="default",
                            badge=1
                        )
                    )
                ),
                token=token
            )
            for token in request.tokens
        ]
        
        response = messaging.send_all(messages)
        
        logger.info(f"✅ 배치 전송 완료: {response.success_count}/{len(request.tokens)}")
        
        return {
            "success": True,
            "success_count": response.success_count,
            "failure_count": response.failure_count,
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"❌ 배치 전송 실패: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# 서버 시작
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "fcm_push_server:app",
        host="0.0.0.0",
        port=8000,
        workers=4,  # CPU 코어 수에 맞춰 조정
        log_level="info"
    )
```

---

## 🔐 3. OAuth 2.0 문제 해결

### 3.1 Firebase Admin SDK 서비스 계정 키 다운로드

```bash
# Firebase Console에서 서비스 계정 키 다운로드
# 1. Firebase Console → Project Settings → Service Accounts
# 2. "Generate new private key" 클릭
# 3. JSON 파일 다운로드

# 다운로드한 파일을 서버로 복사
scp firebase-admin-sdk.json root@push-server:/opt/fcm-push-server/

# 파일 권한 설정
chmod 600 /opt/fcm-push-server/firebase-admin-sdk.json
chown root:root /opt/fcm-push-server/firebase-admin-sdk.json
```

### 3.2 환경변수 설정

```bash
# /opt/fcm-push-server/.env
FIREBASE_CREDENTIALS_PATH=/opt/fcm-push-server/firebase-admin-sdk.json
API_SECRET_TOKEN=$(openssl rand -hex 32)  # 랜덤 토큰 생성

# .env 파일 권한 설정
chmod 600 /opt/fcm-push-server/.env
```

**중요**: Firebase Admin SDK는 **서비스 계정 키를 사용하므로 OAuth 2.0 사용자 인증이 필요 없습니다!** 서버에서 자동으로 액세스 토큰을 관리합니다.

---

## 🚀 4. Supervisor로 자동 시작 설정

```ini
# /etc/supervisor/conf.d/fcm-push-server.conf

[program:fcm-push-server]
command=/opt/fcm-push-server/venv/bin/python /opt/fcm-push-server/fcm_push_server.py
directory=/opt/fcm-push-server
user=root
autostart=true
autorestart=true
redirect_stderr=true
stdout_logfile=/var/log/fcm-push-server.log
environment=FIREBASE_CREDENTIALS_PATH="/opt/fcm-push-server/firebase-admin-sdk.json",API_SECRET_TOKEN="YOUR_SECRET_TOKEN"
```

```bash
# Supervisor 설정 리로드
supervisorctl reread
supervisorctl update
supervisorctl start fcm-push-server

# 상태 확인
supervisorctl status fcm-push-server
```

---

## 🔄 5. 이중화 구성 (Load Balancing)

### 5.1 Nginx 리버스 프록시 설정

```nginx
# /etc/nginx/sites-available/fcm-push-lb

upstream fcm_push_servers {
    # Primary 서버
    server push-server-1.example.com:8000 weight=5 max_fails=3 fail_timeout=30s;
    
    # Backup 서버
    server push-server-2.example.com:8000 weight=3 max_fails=3 fail_timeout=30s backup;
    
    # Health check
    keepalive 32;
}

server {
    listen 80;
    server_name fcm-push.example.com;
    
    # 보안: IP 화이트리스트 (Asterisk 서버들만 허용)
    allow 192.168.1.10;  # Asterisk Server 1
    allow 192.168.1.11;  # Asterisk Server 2
    allow 192.168.1.12;  # Asterisk Server 3
    deny all;
    
    location / {
        proxy_pass http://fcm_push_servers;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        
        # Timeout 설정
        proxy_connect_timeout 5s;
        proxy_send_timeout 10s;
        proxy_read_timeout 10s;
    }
    
    location /health {
        proxy_pass http://fcm_push_servers/health;
        access_log off;
    }
}
```

```bash
# Nginx 설정 활성화
ln -s /etc/nginx/sites-available/fcm-push-lb /etc/nginx/sites-enabled/
nginx -t
systemctl reload nginx
```

---

## 📞 6. Asterisk Dialplan 통합

### 6.1 extensions.conf 설정

```ini
; /etc/asterisk/extensions.conf

[globals]
FCM_PUSH_SERVER=http://fcm-push.example.com
FCM_API_TOKEN=YOUR_SECRET_TOKEN_HERE

[macro-send-fcm-push]
; 사용법: Gosub(macro-send-fcm-push,s,1(${FCM_TOKEN},${CALLERID(num)},${CALLERID(name)}))
exten => s,1,NoOp(=== FCM Push 전송 시작 ===)
 same => n,Set(FCM_TOKEN=${ARG1})
 same => n,Set(CALLER_NUM=${ARG2})
 same => n,Set(CALLER_NAME=${ARG3})
 same => n,NoOp(FCM Token: ${FCM_TOKEN})
 same => n,NoOp(Caller: ${CALLER_NAME} <${CALLER_NUM}>)
 
 ; JSON 페이로드 생성
 same => n,Set(JSON_PAYLOAD={"fcm_token":"${FCM_TOKEN}","title":"수신 전화","body":"${CALLER_NAME} (${CALLER_NUM})","caller_id":"${CALLER_NUM}","caller_name":"${CALLER_NAME}","call_type":"voice"})
 
 ; curl로 FCM 서버에 POST 요청 (비동기)
 same => n,System(curl -X POST "${FCM_PUSH_SERVER}/send" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer ${FCM_API_TOKEN}" \
     -d '${JSON_PAYLOAD}' \
     --max-time 3 \
     --silent \
     >> /var/log/asterisk/fcm-push.log 2>&1 &)
 
 same => n,NoOp(=== FCM Push 전송 완료 (비동기) ===)
 same => n,Return()

[from-internal]
; 내선 → 외부 발신 시
exten => _X.,1,NoOp(발신: ${CALLERID(all)} → ${EXTEN})
 same => n,Dial(SIP/${EXTEN}@trunk,60,g)
 same => n,Hangup()

[from-trunk]
; 외부 → 내선 착신 시 FCM 푸시 전송
exten => _X.,1,NoOp(착신: ${CALLERID(all)} → ${EXTEN})
 
 ; 데이터베이스에서 FCM 토큰 조회 (예: ODBC)
 same => n,Set(FCM_TOKEN=${ODBC_FETCH_TOKEN(${EXTEN})})
 
 ; FCM 토큰이 있으면 푸시 전송
 same => n,GotoIf($["${FCM_TOKEN}" != ""]?send_push:skip_push)
 
 same => n(send_push),Gosub(macro-send-fcm-push,s,1(${FCM_TOKEN},${CALLERID(num)},${CALLERID(name)}))
 
 same => n(skip_push),Dial(SIP/${EXTEN},60,m)
 same => n,Hangup()
```

### 6.2 AGI 스크립트 버전 (더 강력함)

```bash
#!/bin/bash
# /usr/share/asterisk/agi-bin/send_fcm_push.sh

# AGI 환경변수 읽기
read REQUEST

FCM_PUSH_SERVER="http://fcm-push.example.com"
FCM_API_TOKEN="YOUR_SECRET_TOKEN_HERE"

# AGI 변수 가져오기
FCM_TOKEN="$1"
CALLER_NUM="$2"
CALLER_NAME="$3"

# JSON 페이로드 생성 (jq 사용)
JSON_PAYLOAD=$(jq -n \
  --arg token "$FCM_TOKEN" \
  --arg title "수신 전화" \
  --arg body "$CALLER_NAME ($CALLER_NUM)" \
  --arg caller_id "$CALLER_NUM" \
  --arg caller_name "$CALLER_NAME" \
  '{
    fcm_token: $token,
    title: $title,
    body: $body,
    caller_id: $caller_id,
    caller_name: $caller_name,
    call_type: "voice"
  }')

# FCM 서버에 요청 전송
RESPONSE=$(curl -X POST "$FCM_PUSH_SERVER/send" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $FCM_API_TOKEN" \
  -d "$JSON_PAYLOAD" \
  --max-time 3 \
  --silent)

# 로그 기록
echo "$(date '+%Y-%m-%d %H:%M:%S') - FCM Push: $CALLER_NAME <$CALLER_NUM> → Token: ${FCM_TOKEN:0:20}... - Response: $RESPONSE" >> /var/log/asterisk/fcm-push.log

# AGI 응답
echo "VERBOSE \"FCM Push Sent\" 1"
echo "SET VARIABLE PUSH_STATUS \"$RESPONSE\""
```

```ini
; Dialplan에서 AGI 호출
exten => _X.,1,NoOp(착신 시작)
 same => n,AGI(send_fcm_push.sh,${FCM_TOKEN},${CALLERID(num)},${CALLERID(name)})
 same => n,Dial(SIP/${EXTEN},60)
```

---

## 🧪 7. 테스트

### 7.1 서버 헬스 체크

```bash
# Push Server 1 체크
curl http://push-server-1.example.com:8000/health

# Push Server 2 체크
curl http://push-server-2.example.com:8000/health

# Load Balancer 체크
curl http://fcm-push.example.com/health
```

### 7.2 수동 푸시 전송 테스트

```bash
#!/bin/bash
# test_fcm_push.sh

FCM_PUSH_SERVER="http://fcm-push.example.com"
FCM_API_TOKEN="YOUR_SECRET_TOKEN_HERE"
FCM_TOKEN="실제_FCM_토큰"

curl -X POST "$FCM_PUSH_SERVER/send" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $FCM_API_TOKEN" \
  -d '{
    "fcm_token": "'$FCM_TOKEN'",
    "title": "테스트 수신 전화",
    "body": "홍길동 (010-1234-5678)",
    "caller_id": "01012345678",
    "caller_name": "홍길동",
    "call_type": "voice"
  }'
```

### 7.3 Asterisk에서 테스트

```bash
# Asterisk CLI에서 실행
asterisk -rx "console dial 1000@from-trunk"
```

---

## 📊 8. 모니터링

### 8.1 로그 확인

```bash
# Push Server 로그
tail -f /var/log/fcm-push-server.log

# Asterisk FCM 로그
tail -f /var/log/asterisk/fcm-push.log

# Nginx 로그
tail -f /var/log/nginx/access.log
```

### 8.2 성능 모니터링

```bash
# Push Server 프로세스 확인
ps aux | grep fcm_push_server

# 포트 리스닝 확인
netstat -tlnp | grep 8000

# CPU/메모리 사용률
top -p $(pgrep -f fcm_push_server)
```

---

## 🔧 9. 최적화 팁

### 9.1 성능 최적화
- **Worker 수**: CPU 코어 수 × 2 + 1
- **Keep-alive**: Nginx upstream에서 keepalive 설정
- **Connection Pool**: Firebase Admin SDK는 자동 관리

### 9.2 보안 최적화
- **방화벽**: Asterisk 서버 IP만 허용
- **API 토큰**: 강력한 랜덤 토큰 사용 (32+ chars)
- **HTTPS**: 프로덕션에서는 SSL/TLS 필수

### 9.3 장애 대응
- **Backup 서버**: Nginx upstream에 backup 플래그
- **Health Check**: 30초마다 자동 체크
- **자동 재시작**: Supervisor의 autorestart

---

## ✅ 요약

| 구성 요소 | 설명 | 위치 |
|----------|------|------|
| Push Server | FastAPI + Firebase Admin | `/opt/fcm-push-server/` |
| 서비스 관리 | Supervisor | `/etc/supervisor/conf.d/` |
| Load Balancer | Nginx | `/etc/nginx/sites-available/` |
| Asterisk 통합 | Dialplan + AGI | `/etc/asterisk/extensions.conf` |
| 로그 | 모든 이벤트 기록 | `/var/log/` |

**장점:**
- ✅ OAuth 2.0 문제 없음 (서비스 계정 키 사용)
- ✅ 여러 Asterisk 서버 지원
- ✅ 이중화 자동 장애 조치
- ✅ 비동기 처리로 Asterisk 영향 최소화
- ✅ iOS 알림음/진동 완벽 지원

**GitHub 업로드 완료! 🚀**
