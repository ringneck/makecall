# 📞 콜서버 Firebase 통합 가이드

Firebase를 사용하여 콜서버에서 FCM 푸시 알림을 전송하는 방법입니다.

## 🎯 목표

- ✅ **토큰 만료 문제 해결**: 영구 사용 가능한 인증 방식
- ✅ **보안 강화**: API Key 기반 인증
- ✅ **간단한 구현**: HTTP 요청으로 간편하게 통합
- ✅ **유연한 선택**: Admin SDK 또는 HTTP 방식 중 선택 가능

---

## 🔐 인증 방식 선택

### 방법 1: Firebase Web API Key (권장 - 간단함)

**장점**:
- ✅ 구현이 매우 간단 (HTTP 요청만으로 가능)
- ✅ 영구적으로 사용 가능 (만료 없음)
- ✅ 추가 라이브러리 설치 불필요
- ✅ curl, axios, requests 등 어떤 HTTP 클라이언트로도 사용 가능

**사용 방법**:
```bash
# HTTP 요청 헤더에 API Key 추가
X-Firebase-API-Key: AIzaSyCB4mI5Kj61f6E532vg46GnmnnCfsI9XIM
```

### 방법 2: Service Account Key (고급 - 직접 SDK 사용)

**장점**:
- ✅ Firebase Functions 우회로 성능 향상
- ✅ Firestore/FCM 직접 제어
- ✅ 서버 간 통신 최적화

**필요 사항**:
- Firebase Admin SDK 설치 필요
- Service Account Key 파일 관리 필요

---

## 📋 방법 1: Firebase Web API Key 사용 (권장)

### 1. API Key 정보

**Firebase Web API Key**: `AIzaSyCB4mI5Kj61f6E532vg46GnmnnCfsI9XIM`

- ✅ 영구 사용 가능 (만료 없음)
- ✅ 별도 파일 관리 불필요
- ✅ 환경 변수로 간단히 설정 가능

### 2. HTTP 요청 예시

#### curl 예시

```bash
curl -X POST \
  https://asia-northeast3-makecallio.cloudfunctions.net/sendIncomingCallNotification \
  -H "Content-Type: application/json" \
  -H "X-Firebase-API-Key: AIzaSyCB4mI5Kj61f6E532vg46GnmnnCfsI9XIM" \
  -d '{
    "callerNumber": "16682471",
    "callerName": "얼쑤팩토리",
    "receiverNumber": "07045144801",
    "linkedid": "1762843210.1787",
    "channel": "PJSIP/DKCT-00000460",
    "callType": "external"
  }'
```

#### Node.js (axios) 예시

```javascript
const axios = require('axios');

async function sendFCMNotification(callData) {
  try {
    const response = await axios.post(
      'https://asia-northeast3-makecallio.cloudfunctions.net/sendIncomingCallNotification',
      {
        callerNumber: callData.callerNumber,
        callerName: callData.callerName,
        receiverNumber: callData.receiverNumber,
        linkedid: callData.linkedid,
        channel: callData.channel,
        callType: callData.callType
      },
      {
        headers: {
          'Content-Type': 'application/json',
          'X-Firebase-API-Key': 'AIzaSyCB4mI5Kj61f6E532vg46GnmnnCfsI9XIM'
        }
      }
    );
    
    console.log('✅ FCM 전송 성공:', response.data);
    return response.data;
  } catch (error) {
    console.error('❌ FCM 전송 실패:', error.response?.data || error.message);
    throw error;
  }
}

// 사용 예시
sendFCMNotification({
  callerNumber: '16682471',
  callerName: '얼쑤팩토리',
  receiverNumber: '07045144801',
  linkedid: '1762843210.1787',
  channel: 'PJSIP/DKCT-00000460',
  callType: 'external'
});
```

#### Python (requests) 예시

```python
import requests

def send_fcm_notification(call_data):
    url = 'https://asia-northeast3-makecallio.cloudfunctions.net/sendIncomingCallNotification'
    
    headers = {
        'Content-Type': 'application/json',
        'X-Firebase-API-Key': 'AIzaSyCB4mI5Kj61f6E532vg46GnmnnCfsI9XIM'
    }
    
    payload = {
        'callerNumber': call_data['caller_number'],
        'callerName': call_data['caller_name'],
        'receiverNumber': call_data['receiver_number'],
        'linkedid': call_data['linkedid'],
        'channel': call_data['channel'],
        'callType': call_data['call_type']
    }
    
    try:
        response = requests.post(url, json=payload, headers=headers)
        response.raise_for_status()
        
        print(f"✅ FCM 전송 성공: {response.json()}")
        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"❌ FCM 전송 실패: {e}")
        raise

# 사용 예시
send_fcm_notification({
    'caller_number': '16682471',
    'caller_name': '얼쑤팩토리',
    'receiver_number': '07045144801',
    'linkedid': '1762843210.1787',
    'channel': 'PJSIP/DKCT-00000460',
    'call_type': 'external'
})
```

### 3. 환경 변수 설정 (권장)

API Key를 코드에 직접 하드코딩하지 말고 환경 변수로 관리하세요:

```bash
# .env 파일 또는 시스템 환경 변수
FIREBASE_API_KEY=AIzaSyCB4mI5Kj61f6E532vg46GnmnnCfsI9XIM
FIREBASE_FUNCTIONS_URL=https://asia-northeast3-makecallio.cloudfunctions.net/sendIncomingCallNotification
```

**Node.js (.env 사용)**:
```javascript
require('dotenv').config();

const apiKey = process.env.FIREBASE_API_KEY;
const functionsUrl = process.env.FIREBASE_FUNCTIONS_URL;
```

**Python (.env 사용)**:
```python
import os
from dotenv import load_dotenv

load_dotenv()

api_key = os.getenv('FIREBASE_API_KEY')
functions_url = os.getenv('FIREBASE_FUNCTIONS_URL')
```

### 4. 응답 형식

**성공 응답** (HTTP 200):
```json
{
  "success": true,
  "linkedid": "1762843210.1787",
  "userId": "00UZFjXMjnSj0ThUnGlgkn8cgVy2",
  "sentCount": 2,
  "failureCount": 0,
  "totalTokens": 2,
  "callHistoryCreated": true
}
```

**실패 응답** (HTTP 401):
```json
{
  "error": "Unauthorized",
  "message": "Invalid or missing X-Firebase-API-Key header"
}
```

**실패 응답** (HTTP 404):
```json
{
  "error": "Extension not found",
  "receiverNumber": "07045144801"
}
```

---

## 📋 방법 2: Service Account Key 사용 (고급)

### 1. 사전 준비

### 1. Service Account Key 파일 준비

**파일 위치**: `/opt/flutter/firebase-admin-sdk.json`

이 파일을 콜서버로 복사하세요:

```bash
# 예시: SCP로 복사
scp /opt/flutter/firebase-admin-sdk.json user@callserver:/path/to/
```

### 2. 파일 권한 설정

```bash
# 보안을 위해 읽기 전용으로 설정
chmod 600 /path/to/firebase-admin-sdk.json

# 환경 변수로 경로 설정 (권장)
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/firebase-admin-sdk.json"
```

### 3. Git에서 제외

```bash
# .gitignore에 추가
echo "firebase-admin-sdk.json" >> .gitignore
echo "**/*-adminsdk-*.json" >> .gitignore
```

---

## 🔧 구현 방법

### Node.js 예시

#### 1. Firebase Admin SDK 설치

```bash
npm install firebase-admin
```

#### 2. 초기화 (서버 시작 시 1회만)

```javascript
const admin = require('firebase-admin');

// Service Account Key 초기화
const serviceAccount = require('./firebase-admin-sdk.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const messaging = admin.messaging();

console.log('✅ Firebase Admin SDK 초기화 완료');
```

#### 3. 수신전화 FCM 전송 함수

```javascript
/**
 * 수신전화 FCM 푸시 알림 전송
 * 
 * @param {Object} callData - 통화 정보
 * @param {string} callData.callerNumber - 발신번호
 * @param {string} callData.callerName - 발신자 이름
 * @param {string} callData.receiverNumber - 수신번호 (accountCode 또는 extension)
 * @param {string} callData.linkedid - 통화 고유 ID
 * @param {string} callData.channel - 채널 정보
 * @param {string} callData.callType - 통화 타입 (external/internal)
 */
async function sendIncomingCallPush(callData) {
  try {
    console.log('📞 [FCM] 수신전화 FCM 전송 시작');
    console.log(`   발신번호: ${callData.callerNumber}`);
    console.log(`   수신번호: ${callData.receiverNumber}`);
    console.log(`   Linkedid: ${callData.linkedid}`);

    // 1. receiverNumber로 my_extensions 조회 → userId 찾기
    let extensionSnapshot = await db.collection('my_extensions')
      .where('accountCode', '==', callData.receiverNumber)
      .limit(1)
      .get();

    // 내부 수신: extension으로 조회
    if (extensionSnapshot.empty) {
      extensionSnapshot = await db.collection('my_extensions')
        .where('extension', '==', callData.receiverNumber)
        .limit(1)
        .get();
    }

    if (extensionSnapshot.empty) {
      console.error(`❌ [FCM] 내선번호 없음: ${callData.receiverNumber}`);
      return { success: false, error: 'Extension not found' };
    }

    const extensionData = extensionSnapshot.docs[0].data();
    const userId = extensionData.userId;
    const extensionUsed = extensionData.extension;

    console.log(`✅ [FCM] userId 확인: ${userId}`);
    console.log(`   내선번호: ${extensionUsed}`);

    // 2. 해당 사용자의 활성 FCM 토큰 조회
    const tokensSnapshot = await db.collection('fcm_tokens')
      .where('userId', '==', userId)
      .where('isActive', '==', true)
      .get();

    if (tokensSnapshot.empty) {
      console.error(`❌ [FCM] 활성 FCM 토큰 없음: ${userId}`);
      return { success: false, error: 'No active FCM tokens' };
    }

    const tokens = tokensSnapshot.docs.map(doc => doc.data().fcmToken);
    console.log(`✅ [FCM] FCM 토큰 ${tokens.length}개 발견`);

    // 3. Firestore call_history 컬렉션에 통화 기록 생성
    const callHistoryRef = db.collection('call_history').doc(callData.linkedid);
    const existingHistory = await callHistoryRef.get();

    if (!existingHistory.exists) {
      await callHistoryRef.set({
        userId: userId,
        callerNumber: callData.callerNumber,
        callerName: callData.callerName || callData.callerNumber,
        receiverNumber: callData.receiverNumber,
        channel: callData.channel || '',
        linkedid: callData.linkedid,
        callType: 'incoming',
        callSubType: callData.callType || 'external',
        status: 'fcm_notification',
        extensionUsed: extensionUsed,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
      console.log(`✅ [FCM] call_history 생성 완료: ${callData.linkedid}`);
    }

    // 4. FCM 푸시 메시지 구성
    const message = {
      notification: {
        title: '수신전화',
        body: callData.callerName || callData.callerNumber
      },
      data: {
        type: 'incoming_call',
        caller_number: callData.callerNumber,
        caller_name: callData.callerName || callData.callerNumber,
        receiver_number: callData.receiverNumber,
        linkedid: callData.linkedid,
        channel: callData.channel || '',
        call_type: callData.callType || 'external',
        timestamp: new Date().toISOString()
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'incoming_call_channel',
          sound: 'default',
          priority: 'high'
        }
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1
          }
        }
      }
    };

    // 5. FCM 멀티캐스트 전송
    const response = await messaging.sendEachForMulticast({
      tokens: tokens,
      ...message
    });

    console.log(`✅ [FCM] FCM 전송 완료`);
    console.log(`   성공: ${response.successCount}/${tokens.length}`);

    if (response.failureCount > 0) {
      console.error(`⚠️ [FCM] 실패: ${response.failureCount}개`);
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          console.error(`   토큰 ${idx + 1}: ${resp.error.message}`);
        }
      });
    }

    return {
      success: true,
      linkedid: callData.linkedid,
      userId: userId,
      sentCount: response.successCount,
      failureCount: response.failureCount,
      totalTokens: tokens.length
    };

  } catch (error) {
    console.error('❌ [FCM] FCM 전송 오류:', error);
    return {
      success: false,
      error: error.message
    };
  }
}
```

#### 4. Asterisk Manager Interface 통합 예시

```javascript
const ami = require('asterisk-manager');

// AMI 연결
const amiClient = ami(
  'ami_port',
  'ami_host',
  'ami_user',
  'ami_password',
  true // keepConnected
);

amiClient.keepConnected();

// Newchannel 이벤트 리스너
amiClient.on('managerevent', async (event) => {
  if (event.event === 'Newchannel') {
    // 수신전화 판별 (예시 로직)
    const isIncoming = event.exten && event.calleridnum;
    
    if (isIncoming) {
      await sendIncomingCallPush({
        callerNumber: event.calleridnum,
        callerName: event.calleridname,
        receiverNumber: event.exten,
        linkedid: event.linkedid,
        channel: event.channel,
        callType: 'external'
      });
    }
  }
});

console.log('✅ Asterisk Manager Interface 연결 완료');
```

---

### Python 예시

#### 1. Firebase Admin SDK 설치

```bash
pip install firebase-admin
```

#### 2. 초기화 (서버 시작 시 1회만)

```python
import firebase_admin
from firebase_admin import credentials, firestore, messaging
from datetime import datetime

# Service Account Key 초기화
cred = credentials.Certificate('./firebase-admin-sdk.json')
firebase_admin.initialize_app(cred)

db = firestore.client()

print('✅ Firebase Admin SDK 초기화 완료')
```

#### 3. 수신전화 FCM 전송 함수

```python
def send_incoming_call_push(call_data):
    """
    수신전화 FCM 푸시 알림 전송
    
    Args:
        call_data (dict): 통화 정보
            - caller_number (str): 발신번호
            - caller_name (str): 발신자 이름
            - receiver_number (str): 수신번호
            - linkedid (str): 통화 고유 ID
            - channel (str): 채널 정보
            - call_type (str): 통화 타입
    
    Returns:
        dict: 전송 결과
    """
    try:
        print(f"📞 [FCM] 수신전화 FCM 전송 시작")
        print(f"   발신번호: {call_data['caller_number']}")
        print(f"   수신번호: {call_data['receiver_number']}")
        print(f"   Linkedid: {call_data['linkedid']}")

        # 1. receiverNumber로 my_extensions 조회
        extensions_ref = db.collection('my_extensions')
        
        # 외부 수신: accountCode로 조회
        query = extensions_ref.where('accountCode', '==', call_data['receiver_number']).limit(1)
        extensions = list(query.stream())
        
        # 내부 수신: extension으로 조회
        if not extensions:
            query = extensions_ref.where('extension', '==', call_data['receiver_number']).limit(1)
            extensions = list(query.stream())
        
        if not extensions:
            print(f"❌ [FCM] 내선번호 없음: {call_data['receiver_number']}")
            return {'success': False, 'error': 'Extension not found'}
        
        extension_data = extensions[0].to_dict()
        user_id = extension_data['userId']
        extension_used = extension_data['extension']
        
        print(f"✅ [FCM] userId 확인: {user_id}")
        print(f"   내선번호: {extension_used}")

        # 2. 해당 사용자의 활성 FCM 토큰 조회
        tokens_ref = db.collection('fcm_tokens')
        tokens_query = tokens_ref.where('userId', '==', user_id).where('isActive', '==', True)
        tokens_docs = list(tokens_query.stream())
        
        if not tokens_docs:
            print(f"❌ [FCM] 활성 FCM 토큰 없음: {user_id}")
            return {'success': False, 'error': 'No active FCM tokens'}
        
        tokens = [doc.to_dict()['fcmToken'] for doc in tokens_docs]
        print(f"✅ [FCM] FCM 토큰 {len(tokens)}개 발견")

        # 3. Firestore call_history 생성
        call_history_ref = db.collection('call_history').document(call_data['linkedid'])
        existing_history = call_history_ref.get()
        
        if not existing_history.exists:
            call_history_ref.set({
                'userId': user_id,
                'callerNumber': call_data['caller_number'],
                'callerName': call_data.get('caller_name', call_data['caller_number']),
                'receiverNumber': call_data['receiver_number'],
                'channel': call_data.get('channel', ''),
                'linkedid': call_data['linkedid'],
                'callType': 'incoming',
                'callSubType': call_data.get('call_type', 'external'),
                'status': 'fcm_notification',
                'extensionUsed': extension_used,
                'timestamp': firestore.SERVER_TIMESTAMP,
                'createdAt': firestore.SERVER_TIMESTAMP
            })
            print(f"✅ [FCM] call_history 생성 완료: {call_data['linkedid']}")

        # 4. FCM 푸시 메시지 구성
        message = messaging.MulticastMessage(
            notification=messaging.Notification(
                title='수신전화',
                body=call_data.get('caller_name', call_data['caller_number'])
            ),
            data={
                'type': 'incoming_call',
                'caller_number': call_data['caller_number'],
                'caller_name': call_data.get('caller_name', call_data['caller_number']),
                'receiver_number': call_data['receiver_number'],
                'linkedid': call_data['linkedid'],
                'channel': call_data.get('channel', ''),
                'call_type': call_data.get('call_type', 'external'),
                'timestamp': datetime.now().isoformat()
            },
            android=messaging.AndroidConfig(
                priority='high',
                notification=messaging.AndroidNotification(
                    channel_id='incoming_call_channel',
                    sound='default',
                    priority='high'
                )
            ),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        sound='default',
                        badge=1
                    )
                )
            ),
            tokens=tokens
        )

        # 5. FCM 멀티캐스트 전송
        response = messaging.send_multicast(message)
        
        print(f"✅ [FCM] FCM 전송 완료")
        print(f"   성공: {response.success_count}/{len(tokens)}")
        
        if response.failure_count > 0:
            print(f"⚠️ [FCM] 실패: {response.failure_count}개")
        
        return {
            'success': True,
            'linkedid': call_data['linkedid'],
            'userId': user_id,
            'sentCount': response.success_count,
            'failureCount': response.failure_count,
            'totalTokens': len(tokens)
        }

    except Exception as e:
        print(f"❌ [FCM] FCM 전송 오류: {e}")
        return {
            'success': False,
            'error': str(e)
        }
```

#### 4. Asterisk AMI 통합 예시 (Python)

```python
from asterisk.ami import AMIClient

def on_newchannel(event, manager):
    """Newchannel 이벤트 핸들러"""
    # 수신전화 판별
    if event.get('Exten') and event.get('CallerIDNum'):
        send_incoming_call_push({
            'caller_number': event.get('CallerIDNum'),
            'caller_name': event.get('CallerIDName', ''),
            'receiver_number': event.get('Exten'),
            'linkedid': event.get('Linkedid'),
            'channel': event.get('Channel', ''),
            'call_type': 'external'
        })

# AMI 클라이언트 생성 및 연결
ami_client = AMIClient(address='ami_host', port=5038)
ami_client.login(username='ami_user', secret='ami_password')

# 이벤트 리스너 등록
ami_client.add_event_listener(on_newchannel, white_list=['Newchannel'])

print('✅ Asterisk Manager Interface 연결 완료')

# 이벤트 대기
ami_client.run_forever()
```

---

## 🔒 보안 주의사항

### 1. Service Account Key 파일 보호

```bash
# ❌ 절대 하지 말 것
- Git 저장소에 커밋
- 공개 디렉토리에 저장
- 다른 사용자에게 공유

# ✅ 필수 조치
- 파일 권한 600 설정
- 환경 변수로 경로 관리
- .gitignore에 추가
- 정기적인 키 로테이션
```

### 2. 네트워크 보안

```javascript
// Firestore 보안 규칙 (Firebase Console에서 설정)
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Service Account는 모든 규칙 우회 가능
    // 그러나 추가 보안을 위해 규칙 설정 권장
    
    match /fcm_tokens/{token} {
      allow read, write: if request.auth != null;
    }
    
    match /my_extensions/{extension} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == resource.data.userId;
    }
    
    match /call_history/{history} {
      allow read: if request.auth.uid == resource.data.userId;
      allow write: if request.auth != null;
    }
  }
}
```

---

## 📊 성능 최적화

### 1. 연결 재사용

```javascript
// ✅ 좋은 예: 서버 시작 시 1회만 초기화
const admin = require('firebase-admin');
admin.initializeApp({ /* ... */ });

// ❌ 나쁜 예: 매번 초기화
function sendPush() {
  const admin = require('firebase-admin');
  admin.initializeApp({ /* ... */ });  // 성능 저하!
}
```

### 2. 배치 처리

```javascript
// 여러 사용자에게 동시 전송
async function sendBatchPushes(callDataList) {
  const promises = callDataList.map(data => sendIncomingCallPush(data));
  const results = await Promise.all(promises);
  return results;
}
```

---

## 🐛 문제 해결

### 1. "Permission denied" 오류

```bash
# 원인: Service Account Key 파일 권한 문제
# 해결:
chmod 600 firebase-admin-sdk.json
```

### 2. "App already initialized" 오류

```javascript
// 원인: admin.initializeApp() 중복 호출
// 해결: 이미 초기화되었는지 확인
if (!admin.apps.length) {
  admin.initializeApp({ /* ... */ });
}
```

### 3. "Extension not found" 오류

```javascript
// 원인: receiverNumber가 Firestore에 없음
// 해결: my_extensions 컬렉션 데이터 확인
// 1. accountCode 필드 확인
// 2. extension 필드 확인
```

---

## ✅ 체크리스트

배포 전 확인사항:

- [ ] Service Account Key 파일을 안전한 위치에 저장
- [ ] 파일 권한 600으로 설정
- [ ] .gitignore에 추가
- [ ] 환경 변수로 경로 설정
- [ ] Firebase Admin SDK 초기화 확인
- [ ] 테스트 통화로 FCM 푸시 전송 확인
- [ ] 로그 모니터링 설정
- [ ] 오류 알림 설정

---

## 📚 참고 문서

- [Firebase Admin SDK 문서](https://firebase.google.com/docs/admin/setup)
- [Firebase Cloud Messaging 문서](https://firebase.google.com/docs/cloud-messaging)
- [Firestore 보안 규칙](https://firebase.google.com/docs/firestore/security/get-started)

---

## 💬 문의

구현 중 문제가 발생하면 Firebase Console의 로그를 확인하거나, 개발팀에 문의하세요.

**Firebase Console 로그**: https://console.firebase.google.com/ → Functions → Logs
