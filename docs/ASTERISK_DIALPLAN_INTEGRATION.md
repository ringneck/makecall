# 📞 Asterisk 다이얼플랜 Firebase 통합 가이드

Asterisk 20+ 다이얼플랜에서 Firebase Admin SDK를 사용하여 FCM 푸시 알림을 전송하는 방법입니다.

## 🎯 구현 방식

- **Asterisk 버전**: 20 이상
- **패턴**: GoSub/Return 모듈화 구조
- **변수**: LOCAL 변수로 격리
- **에러 처리**: HTTP 코드 검증 및 자동 재시도
- **로깅**: 이벤트 추적 서브루틴

---

## 📋 아키텍처

```
Asterisk Dialplan
  ↓
GoSub: SendFirebaseFCM
  ↓
External Script (Node.js/Python)
  ↓
Firebase Admin SDK
  ↓
Firestore + FCM
```

---

## 🔧 구현 단계

### Step 1: Node.js FCM 스크립트 작성

**파일 위치**: `/usr/local/bin/send_fcm_push.js`

```javascript
#!/usr/bin/env node

/**
 * Asterisk용 Firebase FCM 푸시 전송 스크립트
 * 
 * 사용법:
 *   node send_fcm_push.js <callerNumber> <callerName> <receiverNumber> <linkedid> <channel> <callType>
 * 
 * 반환값:
 *   성공: SUCCESS:<userId>:<sentCount>:<totalTokens>
 *   실패: ERROR:<errorCode>:<errorMessage>
 */

const admin = require('firebase-admin');

// Service Account Key 초기화
const serviceAccount = require('/opt/flutter/firebase-admin-sdk.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

async function sendFCM() {
  try {
    // 명령줄 인자 파싱
    const [
      callerNumber,
      callerName,
      receiverNumber,
      linkedid,
      channel,
      callType
    ] = process.argv.slice(2);

    // 필수 파라미터 검증
    if (!callerNumber || !receiverNumber || !linkedid) {
      console.log(`ERROR:400:Missing required parameters`);
      process.exit(1);
    }

    // 1. receiverNumber로 my_extensions 조회
    let extensionSnapshot = await db.collection('my_extensions')
      .where('accountCode', '==', receiverNumber)
      .limit(1)
      .get();

    if (extensionSnapshot.empty) {
      extensionSnapshot = await db.collection('my_extensions')
        .where('extension', '==', receiverNumber)
        .limit(1)
        .get();
    }

    if (extensionSnapshot.empty) {
      console.log(`ERROR:404:Extension not found:${receiverNumber}`);
      process.exit(1);
    }

    const extensionData = extensionSnapshot.docs[0].data();
    const userId = extensionData.userId;
    const extensionUsed = extensionData.extension;

    // 2. FCM 토큰 조회
    const tokensSnapshot = await db.collection('fcm_tokens')
      .where('userId', '==', userId)
      .where('isActive', '==', true)
      .get();

    if (tokensSnapshot.empty) {
      console.log(`ERROR:404:No active FCM tokens:${userId}`);
      process.exit(1);
    }

    const tokens = tokensSnapshot.docs.map(doc => doc.data().fcmToken);

    // 3. 통화 기록 생성
    const callHistoryRef = db.collection('call_history').doc(linkedid);
    const existingHistory = await callHistoryRef.get();

    if (!existingHistory.exists) {
      await callHistoryRef.set({
        userId: userId,
        callerNumber: callerNumber,
        callerName: callerName || callerNumber,
        receiverNumber: receiverNumber,
        channel: channel || '',
        linkedid: linkedid,
        callType: 'incoming',
        callSubType: callType || 'external',
        status: 'fcm_notification',
        extensionUsed: extensionUsed,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }

    // 4. FCM 푸시 전송
    const message = {
      notification: {
        title: '수신전화',
        body: callerName || callerNumber
      },
      data: {
        type: 'incoming_call',
        caller_number: callerNumber,
        caller_name: callerName || callerNumber,
        receiver_number: receiverNumber,
        linkedid: linkedid,
        channel: channel || '',
        call_type: callType || 'external',
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

    const response = await admin.messaging().sendEachForMulticast({
      tokens: tokens,
      ...message
    });

    // 성공 반환
    console.log(`SUCCESS:${userId}:${response.successCount}:${tokens.length}`);
    process.exit(0);

  } catch (error) {
    console.log(`ERROR:500:${error.message}`);
    process.exit(1);
  }
}

sendFCM();
```

**권한 설정**:
```bash
chmod +x /usr/local/bin/send_fcm_push.js
```

---

### Step 2: Asterisk 다이얼플랜 구현

**파일 위치**: `/etc/asterisk/extensions_custom.conf`

```ini
; ============================================================
; Firebase FCM 푸시 알림 전송 서브루틴
; ============================================================

[sub-send-firebase-fcm]
; 용도: 수신전화 시 Firebase FCM 푸시 알림 전송
; 
; 필수 변수:
;   ARG1: callerNumber (발신번호)
;   ARG2: callerName (발신자 이름)
;   ARG3: receiverNumber (수신번호 - accountCode 또는 extension)
;   ARG4: linkedid (통화 고유 ID)
;   ARG5: channel (채널 정보)
;   ARG6: callType (통화 타입: external/internal)
;
; 반환 변수:
;   FCM_RESULT: SUCCESS 또는 ERROR
;   FCM_USER_ID: 사용자 ID (성공 시)
;   FCM_SENT_COUNT: 전송 성공 개수 (성공 시)
;   FCM_TOTAL_TOKENS: 전체 토큰 개수 (성공 시)
;   FCM_ERROR_CODE: 에러 코드 (실패 시)
;   FCM_ERROR_MSG: 에러 메시지 (실패 시)

exten => s,1,NoOp(=== Firebase FCM Push Start ===)
    ; LOCAL 변수 설정 (서브루틴 내부 격리)
    same => n,Set(LOCAL(callerNumber)=${ARG1})
    same => n,Set(LOCAL(callerName)=${ARG2})
    same => n,Set(LOCAL(receiverNumber)=${ARG3})
    same => n,Set(LOCAL(linkedid)=${ARG4})
    same => n,Set(LOCAL(channel)=${ARG5})
    same => n,Set(LOCAL(callType)=${ARG6})
    same => n,Set(LOCAL(retryCount)=0)
    same => n,Set(LOCAL(maxRetries)=3)
    
    ; 파라미터 로깅
    same => n,GoSub(sub-log-fcm-event,s,1(INFO,FCM_START,Caller:${LOCAL(callerNumber)} Receiver:${LOCAL(receiverNumber)} Linkedid:${LOCAL(linkedid)}))
    
    ; 필수 파라미터 검증
    same => n,GotoIf($["${LOCAL(callerNumber)}" = ""]?missing_params)
    same => n,GotoIf($["${LOCAL(receiverNumber)}" = ""]?missing_params)
    same => n,GotoIf($["${LOCAL(linkedid)}" = ""]?missing_params)
    same => n,Goto(execute_fcm)

exten => s,n(missing_params),NoOp(Missing required parameters)
    same => n,Set(FCM_RESULT=ERROR)
    same => n,Set(FCM_ERROR_CODE=400)
    same => n,Set(FCM_ERROR_MSG=Missing required parameters)
    same => n,GoSub(sub-log-fcm-event,s,1(ERROR,FCM_FAILED,Missing parameters))
    same => n,Return()

exten => s,n(execute_fcm),NoOp(Executing Firebase FCM script)
    ; Node.js 스크립트 실행
    same => n,Set(LOCAL(scriptCmd)=/usr/local/bin/send_fcm_push.js "${LOCAL(callerNumber)}" "${LOCAL(callerName)}" "${LOCAL(receiverNumber)}" "${LOCAL(linkedid)}" "${LOCAL(channel)}" "${LOCAL(callType)}")
    same => n,Set(LOCAL(scriptOutput)=${SHELL(node ${LOCAL(scriptCmd)})})
    
    ; 스크립트 실행 결과 로깅
    same => n,NoOp(Script output: ${LOCAL(scriptOutput)})
    
    ; 결과 파싱 (구분자: :)
    same => n,Set(LOCAL(resultStatus)=${CUT(LOCAL(scriptOutput),:,1)})
    
    ; 결과 분기
    same => n,GotoIf($["${LOCAL(resultStatus)}" = "SUCCESS"]?parse_success:parse_error)

exten => s,n(parse_success),NoOp(FCM push sent successfully)
    ; 성공 결과 파싱: SUCCESS:<userId>:<sentCount>:<totalTokens>
    same => n,Set(FCM_RESULT=SUCCESS)
    same => n,Set(FCM_USER_ID=${CUT(LOCAL(scriptOutput),:,2)})
    same => n,Set(FCM_SENT_COUNT=${CUT(LOCAL(scriptOutput),:,3)})
    same => n,Set(FCM_TOTAL_TOKENS=${CUT(LOCAL(scriptOutput),:,4)})
    
    ; 성공 로깅
    same => n,GoSub(sub-log-fcm-event,s,1(INFO,FCM_SUCCESS,UserId:${FCM_USER_ID} Sent:${FCM_SENT_COUNT}/${FCM_TOTAL_TOKENS}))
    same => n,Return()

exten => s,n(parse_error),NoOp(FCM push failed)
    ; 에러 결과 파싱: ERROR:<errorCode>:<errorMessage>
    same => n,Set(LOCAL(errorCode)=${CUT(LOCAL(scriptOutput),:,2)})
    same => n,Set(LOCAL(errorMsg)=${CUT(LOCAL(scriptOutput),:,3)})
    
    ; 재시도 로직
    same => n,Set(LOCAL(retryCount)=$[${LOCAL(retryCount)} + 1])
    same => n,GoSub(sub-log-fcm-event,s,1(WARN,FCM_RETRY,Attempt ${LOCAL(retryCount)}/${LOCAL(maxRetries)} - Error:${LOCAL(errorCode)} ${LOCAL(errorMsg)}))
    
    ; 최대 재시도 횟수 확인
    same => n,GotoIf($[${LOCAL(retryCount)} < ${LOCAL(maxRetries)}]?retry_delay:final_error)

exten => s,n(retry_delay),NoOp(Retry delay)
    ; 재시도 전 대기 (1초)
    same => n,Wait(1)
    same => n,Goto(execute_fcm)

exten => s,n(final_error),NoOp(Max retries reached)
    ; 최종 실패
    same => n,Set(FCM_RESULT=ERROR)
    same => n,Set(FCM_ERROR_CODE=${LOCAL(errorCode)})
    same => n,Set(FCM_ERROR_MSG=${LOCAL(errorMsg)})
    
    ; 실패 로깅
    same => n,GoSub(sub-log-fcm-event,s,1(ERROR,FCM_FAILED,Code:${FCM_ERROR_CODE} Msg:${FCM_ERROR_MSG}))
    same => n,Return()


; ============================================================
; FCM 이벤트 로깅 서브루틴
; ============================================================

[sub-log-fcm-event]
; 용도: FCM 관련 이벤트 로깅
; 
; 필수 변수:
;   ARG1: logLevel (INFO/WARN/ERROR)
;   ARG2: eventType (FCM_START/FCM_SUCCESS/FCM_FAILED/FCM_RETRY)
;   ARG3: eventDetails (상세 정보)

exten => s,1,NoOp(=== FCM Event Log ===)
    same => n,Set(LOCAL(logLevel)=${ARG1})
    same => n,Set(LOCAL(eventType)=${ARG2})
    same => n,Set(LOCAL(eventDetails)=${ARG3})
    same => n,Set(LOCAL(timestamp)=${STRFTIME(${EPOCH},,%Y-%m-%d %H:%M:%S)})
    
    ; 로그 출력
    same => n,NoOp([${LOCAL(timestamp)}] [${LOCAL(logLevel)}] ${LOCAL(eventType)}: ${LOCAL(eventDetails)})
    
    ; Asterisk 로그에 기록
    same => n,ExecIf($["${LOCAL(logLevel)}" = "ERROR"]?Log(ERROR,FCM: ${LOCAL(eventType)} - ${LOCAL(eventDetails)}))
    same => n,ExecIf($["${LOCAL(logLevel)}" = "WARN"]?Log(WARNING,FCM: ${LOCAL(eventType)} - ${LOCAL(eventDetails)}))
    same => n,ExecIf($["${LOCAL(logLevel)}" = "INFO"]?Log(NOTICE,FCM: ${LOCAL(eventType)} - ${LOCAL(eventDetails)}))
    
    same => n,Return()


; ============================================================
; 수신전화 FCM 알림 통합 예시
; ============================================================

[from-trunk-external]
; 외부 수신전화 처리
exten => _X.,1,NoOp(=== Incoming Call from ${CALLERID(num)} ===)
    ; 변수 설정
    same => n,Set(CALLER_NUMBER=${CALLERID(num)})
    same => n,Set(CALLER_NAME=${CALLERID(name)})
    same => n,Set(RECEIVER_NUMBER=${EXTEN})
    same => n,Set(CALL_LINKEDID=${LINKEDID})
    same => n,Set(CALL_CHANNEL=${CHANNEL})
    
    ; Firebase FCM 푸시 전송 (비동기 - 통화 흐름 방해 안 함)
    same => n,GoSub(sub-send-firebase-fcm,s,1(${CALLER_NUMBER},${CALLER_NAME},${RECEIVER_NUMBER},${CALL_LINKEDID},${CALL_CHANNEL},external))
    
    ; FCM 결과 확인 (선택사항 - 로깅용)
    same => n,NoOp(FCM Result: ${FCM_RESULT})
    same => n,ExecIf($["${FCM_RESULT}" = "SUCCESS"]?NoOp(FCM sent to ${FCM_SENT_COUNT} devices))
    same => n,ExecIf($["${FCM_RESULT}" = "ERROR"]?NoOp(FCM failed: ${FCM_ERROR_MSG}))
    
    ; 일반 통화 처리 계속
    same => n,Dial(PJSIP/${EXTEN},30,tT)
    same => n,Hangup()


[from-internal]
; 내부 통화 처리
exten => _X.,1,NoOp(=== Internal Call from ${CALLERID(num)} to ${EXTEN} ===)
    ; 변수 설정
    same => n,Set(CALLER_NUMBER=${CALLERID(num)})
    same => n,Set(CALLER_NAME=${CALLERID(name)})
    same => n,Set(RECEIVER_NUMBER=${EXTEN})
    same => n,Set(CALL_LINKEDID=${LINKEDID})
    same => n,Set(CALL_CHANNEL=${CHANNEL})
    
    ; Firebase FCM 푸시 전송
    same => n,GoSub(sub-send-firebase-fcm,s,1(${CALLER_NUMBER},${CALLER_NAME},${RECEIVER_NUMBER},${CALL_LINKEDID},${CALL_CHANNEL},internal))
    
    ; 일반 통화 처리 계속
    same => n,Dial(PJSIP/${EXTEN},30,tT)
    same => n,Hangup()
```

---

## 🔧 설치 및 설정

### 1. Node.js 및 Firebase Admin SDK 설치

```bash
# Node.js 설치 (Ubuntu/Debian)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Firebase Admin SDK 설치 (전역)
sudo npm install -g firebase-admin

# 또는 프로젝트 디렉토리에 설치
cd /usr/local/bin
sudo npm init -y
sudo npm install firebase-admin
```

### 2. Service Account Key 복사

```bash
# Service Account Key 파일 복사
sudo cp /opt/flutter/firebase-admin-sdk.json /opt/flutter/

# 권한 설정
sudo chmod 600 /opt/flutter/firebase-admin-sdk.json
sudo chown asterisk:asterisk /opt/flutter/firebase-admin-sdk.json
```

### 3. FCM 스크립트 배포

```bash
# 스크립트 생성
sudo nano /usr/local/bin/send_fcm_push.js
# (위의 Node.js 스크립트 내용 복사)

# 실행 권한 부여
sudo chmod +x /usr/local/bin/send_fcm_push.js

# 소유자 변경
sudo chown asterisk:asterisk /usr/local/bin/send_fcm_push.js
```

### 4. Asterisk 다이얼플랜 적용

```bash
# 다이얼플랜 파일 편집
sudo nano /etc/asterisk/extensions_custom.conf
# (위의 다이얼플랜 내용 복사)

# Asterisk 다이얼플랜 리로드
sudo asterisk -rx "dialplan reload"

# 확인
sudo asterisk -rx "dialplan show sub-send-firebase-fcm"
```

---

## 🧪 테스트

### 1. 스크립트 단독 테스트

```bash
# 직접 실행
node /usr/local/bin/send_fcm_push.js \
  "16682471" \
  "테스트발신자" \
  "07045144801" \
  "test_linkedid_123" \
  "PJSIP/TEST-0001" \
  "external"

# 예상 출력:
# SUCCESS:<userId>:<sentCount>:<totalTokens>
# 또는
# ERROR:<errorCode>:<errorMessage>
```

### 2. Asterisk CLI 테스트

```bash
# Asterisk CLI 접속
sudo asterisk -rvvv

# 다이얼플랜 테스트
CLI> dialplan show sub-send-firebase-fcm

# 로그 모니터링
CLI> core set verbose 5
CLI> core set debug 5
```

### 3. 실제 통화 테스트

```bash
# 외부에서 테스트 통화
# 1. 전화 걸기
# 2. Asterisk CLI에서 로그 확인:
#    [INFO] FCM_START: Caller:xxx Receiver:xxx
#    [INFO] FCM_SUCCESS: UserId:xxx Sent:2/2
```

---

## 📊 동작 흐름

```
수신전화 발생
  ↓
Asterisk Dialplan (from-trunk-external)
  ↓
GoSub(sub-send-firebase-fcm)
  ┌─────────────────────────────────────┐
  │ 1. 파라미터 검증                     │
  │ 2. Node.js 스크립트 실행             │
  │    ├─ Firebase Admin SDK 초기화      │
  │    ├─ Firestore 내선번호 조회        │
  │    ├─ FCM 토큰 조회                  │
  │    ├─ 통화 기록 생성                 │
  │    └─ FCM 푸시 전송                  │
  │ 3. 결과 파싱 (SUCCESS/ERROR)         │
  │ 4. 재시도 로직 (실패 시 최대 3회)    │
  │ 5. 로깅                              │
  └─────────────────────────────────────┘
  ↓
Return (반환값 설정)
  ↓
일반 Dial 처리 계속
```

---

## 🔍 반환 변수 사용 예시

```ini
[custom-handler]
exten => s,1,NoOp(=== Custom FCM Handler ===)
    ; FCM 전송
    same => n,GoSub(sub-send-firebase-fcm,s,1(${CALLERID(num)},${CALLERID(name)},${EXTEN},${LINKEDID},${CHANNEL},external))
    
    ; 결과에 따른 분기 처리
    same => n,GotoIf($["${FCM_RESULT}" = "SUCCESS"]?fcm_success:fcm_failed)

exten => s,n(fcm_success),NoOp(FCM sent successfully)
    same => n,NoOp(User ID: ${FCM_USER_ID})
    same => n,NoOp(Sent: ${FCM_SENT_COUNT}/${FCM_TOTAL_TOKENS} devices)
    same => n,Goto(continue_call)

exten => s,n(fcm_failed),NoOp(FCM failed)
    same => n,NoOp(Error Code: ${FCM_ERROR_CODE})
    same => n,NoOp(Error Msg: ${FCM_ERROR_MSG})
    ; 실패해도 통화는 계속 진행
    same => n,Goto(continue_call)

exten => s,n(continue_call),NoOp(Continue call processing)
    same => n,Dial(PJSIP/${EXTEN},30,tT)
    same => n,Hangup()
```

---

## 🐛 문제 해결

### 1. "node: command not found"

```bash
# Node.js 경로 확인
which node

# Asterisk에서 사용할 수 있도록 절대 경로 사용
# 스크립트에서:
/usr/bin/node /usr/local/bin/send_fcm_push.js ...
```

### 2. "Permission denied"

```bash
# 파일 권한 확인
ls -l /usr/local/bin/send_fcm_push.js
ls -l /opt/flutter/firebase-admin-sdk.json

# 권한 수정
sudo chmod +x /usr/local/bin/send_fcm_push.js
sudo chmod 600 /opt/flutter/firebase-admin-sdk.json
sudo chown asterisk:asterisk /usr/local/bin/send_fcm_push.js
sudo chown asterisk:asterisk /opt/flutter/firebase-admin-sdk.json
```

### 3. "Module not found: firebase-admin"

```bash
# 전역 설치 확인
npm list -g firebase-admin

# 다시 설치
sudo npm install -g firebase-admin

# 또는 로컬 설치
cd /usr/local/bin
sudo npm install firebase-admin
```

### 4. "Extension not found"

```bash
# Firestore my_extensions 컬렉션 확인
# 1. accountCode 필드 존재 여부
# 2. extension 필드 존재 여부
# 3. 데이터 값 확인

# Firebase Console에서 확인:
# https://console.firebase.google.com/
# → Firestore Database → my_extensions
```

### 5. 스크립트 실행 로그 확인

```bash
# Asterisk 로그
sudo tail -f /var/log/asterisk/full

# 또는 CLI에서
sudo asterisk -rvvv
CLI> core set verbose 10
CLI> core set debug 10
```

---

## ⚡ 성능 최적화

### 1. 스크립트 실행 최적화

```javascript
// 연결 재사용 (pm2 또는 데몬으로 실행)
// 매번 초기화하지 않고 연결 유지

// pm2 설치
npm install -g pm2

// 데몬 모드로 실행 (선택사항)
pm2 start send_fcm_push.js --name fcm-service
```

### 2. 다이얼플랜 최적화

```ini
; 조건부 FCM 전송 (특정 내선번호만)
exten => _X.,1,NoOp(Incoming call)
    ; FCM이 필요한 내선번호만 전송
    same => n,GotoIf($["${DB_EXISTS(fcm_enabled/${EXTEN})}" = "1"]?send_fcm:skip_fcm)
    
exten => s,n(send_fcm),GoSub(sub-send-firebase-fcm,s,1(...))
    same => n,Goto(continue_call)
    
exten => s,n(skip_fcm),NoOp(FCM disabled for this extension)
    
exten => s,n(continue_call),Dial(PJSIP/${EXTEN},30,tT)
```

---

## 📝 로그 분석

### 성공 케이스
```
[2024-01-15 10:30:45] [INFO] FCM_START: Caller:16682471 Receiver:07045144801 Linkedid:1705288245.123
Script output: SUCCESS:00UZFjXMjnSj0ThUnGlgkn8cgVy2:2:2
[2024-01-15 10:30:46] [INFO] FCM_SUCCESS: UserId:00UZFjXMjnSj0ThUnGlgkn8cgVy2 Sent:2/2
```

### 재시도 케이스
```
[2024-01-15 10:30:45] [INFO] FCM_START: Caller:16682471 Receiver:07045144801 Linkedid:1705288245.123
Script output: ERROR:404:Extension not found:07045144801
[2024-01-15 10:30:46] [WARN] FCM_RETRY: Attempt 1/3 - Error:404 Extension not found:07045144801
[2024-01-15 10:30:47] [WARN] FCM_RETRY: Attempt 2/3 - Error:404 Extension not found:07045144801
[2024-01-15 10:30:48] [WARN] FCM_RETRY: Attempt 3/3 - Error:404 Extension not found:07045144801
[2024-01-15 10:30:48] [ERROR] FCM_FAILED: Code:404 Msg:Extension not found:07045144801
```

---

## ✅ 체크리스트

배포 전 확인사항:

- [ ] Node.js 설치 확인 (`node --version`)
- [ ] Firebase Admin SDK 설치 확인 (`npm list -g firebase-admin`)
- [ ] Service Account Key 파일 복사 및 권한 설정
- [ ] FCM 스크립트 생성 및 실행 권한 부여
- [ ] Asterisk 다이얼플랜 적용 및 리로드
- [ ] 스크립트 단독 테스트 성공
- [ ] 테스트 통화로 FCM 푸시 확인
- [ ] Asterisk 로그 모니터링 설정

---

## 📚 참고 자료

- [Asterisk 20 Dialplan](https://docs.asterisk.org/Asterisk_20_Documentation/Configuration/Dialplan/)
- [Firebase Admin SDK - Node.js](https://firebase.google.com/docs/admin/setup?hl=ko#node.js)
- [Asterisk SHELL() Function](https://docs.asterisk.org/Asterisk_20_Documentation/API_Documentation/Dialplan_Functions/SHELL/)

---

## 💬 추가 지원

문제가 발생하면:
1. Asterisk full 로그 확인: `/var/log/asterisk/full`
2. 스크립트 직접 실행하여 에러 확인
3. Firebase Console에서 Firestore 데이터 확인
4. docs/CALL_SERVER_INTEGRATION_GUIDE.md 참조
