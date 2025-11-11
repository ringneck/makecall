# 📧 Gmail SMTP를 이용한 이메일 인증 시스템 설정 가이드

## 🎯 개요
Gmail SMTP를 사용하여 Firebase Cloud Functions에서 이메일 인증 코드를 자동으로 전송하는 시스템을 구축합니다.

---

## 📋 사전 준비

### 1. Gmail 계정 설정
Gmail 계정에서 **앱 비밀번호**를 생성해야 합니다.

#### **Google 앱 비밀번호 생성 단계:**
1. Google 계정 (https://myaccount.google.com/) 접속
2. **보안** 섹션 이동
3. **2단계 인증** 활성화 (필수!)
4. **앱 비밀번호** 메뉴 선택
5. 앱: **메일**, 기기: **기타(사용자 설정 이름)** 선택
6. 이름 입력: "MAKECALL Email Verification"
7. **생성** 클릭 → **16자리 앱 비밀번호** 복사

⚠️ **중요**: 이 비밀번호는 한 번만 표시되므로 안전하게 보관하세요!

---

## 🚀 Firebase Cloud Functions 설정

### Step 1: Firebase CLI 설치 및 로그인
```bash
# Firebase CLI 설치 (Node.js 필요)
npm install -g firebase-tools

# Firebase 로그인
firebase login

# 프로젝트 초기화
cd /home/user/flutter_app
firebase init functions
```

**초기화 옵션 선택:**
- Language: **JavaScript** 또는 **TypeScript**
- ESLint: **Yes**
- Install dependencies: **Yes**

### Step 2: 이메일 전송용 패키지 설치
```bash
cd functions
npm install nodemailer
```

### Step 3: 환경 변수 설정 (Gmail 계정 정보)
```bash
# Firebase 프로젝트에 Gmail 계정 정보 저장
firebase functions:config:set gmail.email="your-email@gmail.com"
firebase functions:config:set gmail.password="your-16-digit-app-password"
```

**예시:**
```bash
firebase functions:config:set gmail.email="makecall.notifications@gmail.com"
firebase functions:config:set gmail.password="abcd efgh ijkl mnop"
```

### Step 4: Cloud Functions 코드 작성

#### **functions/index.js** (JavaScript 버전)
```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

admin.initializeApp();

// Gmail SMTP 설정
const gmailEmail = functions.config().gmail.email;
const gmailPassword = functions.config().gmail.password;

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: gmailEmail,
    pass: gmailPassword,
  },
});

/**
 * 이메일 인증 코드 전송 Cloud Function
 * 
 * Firestore 'email_verification_requests' 컬렉션에 새 문서가 생성되면
 * 자동으로 이메일을 전송합니다.
 */
exports.sendVerificationEmail = functions.firestore
  .document('email_verification_requests/{requestId}')
  .onCreate(async (snap, context) => {
    try {
      const requestId = context.params.requestId;
      const data = snap.data();
      
      const userId = data.userId;
      const code = data.code;
      const createdAt = data.createdAt;
      
      console.log(`📧 이메일 인증 요청 수신: ${requestId}`);
      console.log(`   User ID: ${userId}`);
      console.log(`   인증 코드: ${code}`);
      
      // Firestore에서 사용자 이메일 가져오기
      const userDoc = await admin.firestore().collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        console.error(`❌ 사용자 문서 없음: ${userId}`);
        return;
      }
      
      const userData = userDoc.data();
      const userEmail = userData.email;
      
      if (!userEmail) {
        console.error(`❌ 사용자 이메일 없음: ${userId}`);
        return;
      }
      
      console.log(`   받는 사람: ${userEmail}`);
      
      // 이메일 전송
      const mailOptions = {
        from: `MAKECALL <${gmailEmail}>`,
        to: userEmail,
        subject: '🔐 MAKECALL 새 기기 로그인 인증 코드',
        html: `
          <!DOCTYPE html>
          <html>
          <head>
            <meta charset="utf-8">
            <style>
              body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
              .container { max-width: 600px; margin: 0 auto; padding: 20px; }
              .header { background: #2196F3; color: white; padding: 20px; text-align: center; }
              .content { padding: 30px; background: #f9f9f9; }
              .code-box { 
                background: white; 
                border: 2px solid #2196F3; 
                padding: 20px; 
                text-align: center; 
                margin: 20px 0;
                border-radius: 8px;
              }
              .code { 
                font-size: 32px; 
                font-weight: bold; 
                letter-spacing: 8px; 
                color: #2196F3; 
              }
              .footer { padding: 20px; text-align: center; color: #666; font-size: 12px; }
              .warning { background: #fff3cd; border: 1px solid #ffc107; padding: 15px; margin: 15px 0; border-radius: 8px; }
            </style>
          </head>
          <body>
            <div class="container">
              <div class="header">
                <h1>🔐 새 기기 로그인 인증</h1>
              </div>
              
              <div class="content">
                <p>안녕하세요,</p>
                <p>새 기기에서 로그인을 시도하고 있습니다. 본인이 맞다면 아래 인증 코드를 입력하세요.</p>
                
                <div class="code-box">
                  <p style="margin: 0; font-size: 14px; color: #666;">인증 코드</p>
                  <div class="code">${code}</div>
                </div>
                
                <div class="warning">
                  <strong>⚠️ 주의사항:</strong>
                  <ul style="margin: 10px 0;">
                    <li>이 코드는 <strong>5분간</strong> 유효합니다.</li>
                    <li>본인이 아닌 경우 이 이메일을 무시하세요.</li>
                    <li>MAKECALL은 절대 이메일로 비밀번호를 요청하지 않습니다.</li>
                  </ul>
                </div>
                
                <p style="margin-top: 20px; color: #666;">
                  문제가 있으신가요? support@makecall.com으로 문의하세요.
                </p>
              </div>
              
              <div class="footer">
                <p>© 2024 MAKECALL. All rights reserved.</p>
                <p>이 이메일은 MAKECALL 새 기기 로그인 인증을 위해 자동으로 발송되었습니다.</p>
              </div>
            </div>
          </body>
          </html>
        `,
        text: `
MAKECALL 새 기기 로그인 인증 코드

인증 코드: ${code}

이 코드는 5분간 유효합니다.
본인이 아닌 경우 이 이메일을 무시하세요.

문의: support@makecall.com
        `.trim(),
      };
      
      await transporter.sendMail(mailOptions);
      
      console.log(`✅ 이메일 전송 완료: ${userEmail}`);
      
      // 전송 완료 표시 (선택사항)
      await snap.ref.update({
        emailSent: true,
        emailSentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
    } catch (error) {
      console.error('❌ 이메일 전송 오류:', error);
      throw error;
    }
  });

/**
 * FCM 기기 승인 알림 전송 Cloud Function
 * 
 * Firestore 'fcm_approval_notification_queue' 컬렉션에 새 문서가 생성되면
 * 자동으로 FCM 푸시 알림을 전송합니다.
 */
exports.sendApprovalNotification = functions.firestore
  .document('fcm_approval_notification_queue/{queueId}')
  .onCreate(async (snap, context) => {
    try {
      const queueId = context.params.queueId;
      const data = snap.data();
      
      const targetToken = data.targetToken;
      const message = data.message;
      const approvalRequestId = data.approvalRequestId;
      const newDeviceName = data.newDeviceName;
      const newPlatform = data.newPlatform;
      
      console.log(`🔔 FCM 승인 알림 요청 수신: ${queueId}`);
      console.log(`   Target Token: ${targetToken.substring(0, 20)}...`);
      console.log(`   New Device: ${newDeviceName} (${newPlatform})`);
      
      // FCM 푸시 알림 전송
      const fcmMessage = {
        token: targetToken,
        notification: {
          title: message.title,
          body: message.body,
        },
        data: {
          type: message.type,
          approvalRequestId: approvalRequestId,
          newDeviceName: newDeviceName,
          newPlatform: newPlatform,
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'high_importance_channel',
            priority: 'high',
            sound: 'default',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              contentAvailable: true,
            },
          },
        },
      };
      
      await admin.messaging().send(fcmMessage);
      
      console.log(`✅ FCM 알림 전송 완료: ${targetToken.substring(0, 20)}...`);
      
      // 처리 완료 표시
      await snap.ref.update({
        processed: true,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
    } catch (error) {
      console.error('❌ FCM 알림 전송 오류:', error);
      
      // 오류 정보 저장
      await snap.ref.update({
        processed: false,
        error: error.message,
        errorAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });

/**
 * 만료된 인증 요청 정리 Cloud Function (스케줄링)
 * 
 * 매시간 실행되어 5분 이상 경과한 미처리 인증 요청을 삭제합니다.
 */
exports.cleanupExpiredRequests = functions.pubsub
  .schedule('every 1 hours')
  .onRun(async (context) => {
    try {
      console.log('🧹 만료된 인증 요청 정리 시작');
      
      const now = admin.firestore.Timestamp.now();
      const fiveMinutesAgo = new Date(now.toDate().getTime() - 5 * 60 * 1000);
      
      // 만료된 이메일 인증 요청 삭제
      const expiredEmailRequests = await admin.firestore()
        .collection('email_verification_requests')
        .where('createdAt', '<', fiveMinutesAgo)
        .where('used', '==', false)
        .get();
      
      const emailBatch = admin.firestore().batch();
      expiredEmailRequests.docs.forEach(doc => {
        emailBatch.delete(doc.ref);
      });
      await emailBatch.commit();
      
      console.log(`✅ 만료된 이메일 인증 요청 ${expiredEmailRequests.size}개 삭제`);
      
      // 만료된 기기 승인 요청 정리
      const expiredApprovalRequests = await admin.firestore()
        .collection('device_approval_requests')
        .where('expiresAt', '<', now)
        .where('status', '==', 'pending')
        .get();
      
      const approvalBatch = admin.firestore().batch();
      expiredApprovalRequests.docs.forEach(doc => {
        approvalBatch.update(doc.ref, { status: 'expired' });
      });
      await approvalBatch.commit();
      
      console.log(`✅ 만료된 기기 승인 요청 ${expiredApprovalRequests.size}개 업데이트`);
      
    } catch (error) {
      console.error('❌ 정리 작업 오류:', error);
    }
  });
```

### Step 5: Cloud Functions 배포
```bash
# Functions 디렉토리에서 배포
cd functions
firebase deploy --only functions
```

배포 완료 후 출력:
```
✔  functions[sendVerificationEmail(us-central1)]: Successful create operation.
✔  functions[sendApprovalNotification(us-central1)]: Successful create operation.
✔  functions[cleanupExpiredRequests(us-central1)]: Successful create operation.

✔  Deploy complete!
```

---

## 🔒 Firestore 보안 규칙 업데이트

Firebase Console → Firestore Database → 규칙 탭에서 다음 규칙 추가:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // 사용자 문서 (이메일 조회용)
    match /users/{userId} {
      allow read: if request.auth != null && request.auth.uid == userId;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // 기기 승인 요청
    match /device_approval_requests/{requestId} {
      // 자신의 userId와 일치하는 요청만 읽기/쓰기 가능
      allow read: if request.auth != null && 
                     resource.data.userId == request.auth.uid;
      allow create: if request.auth != null;
      allow update: if request.auth != null && 
                       resource.data.userId == request.auth.uid;
    }
    
    // 이메일 인증 요청
    match /email_verification_requests/{requestId} {
      // 자신의 userId와 일치하는 요청만 읽기/쓰기 가능
      allow read: if request.auth != null && 
                     resource.data.userId == request.auth.uid;
      allow create: if request.auth != null;
      allow update: if request.auth != null && 
                       resource.data.userId == request.auth.uid;
    }
    
    // FCM 알림 큐 (Cloud Functions 전용)
    match /fcm_approval_notification_queue/{queueId} {
      allow read, write: if false; // 클라이언트 접근 차단
    }
    
    // FCM 토큰 관리
    match /fcm_tokens/{tokenId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
  }
}
```

**규칙 배포:**
```bash
firebase deploy --only firestore:rules
```

---

## 🧪 테스트 방법

### 1. 로컬 테스트 (Functions Emulator)
```bash
# Firebase Emulator 시작
firebase emulators:start

# 다른 터미널에서 Flutter 앱 실행
cd /home/user/flutter_app
flutter run -d chrome
```

### 2. 프로덕션 테스트
1. Flutter 앱에서 로그인 시도
2. "이메일 인증 코드 받기" 클릭
3. Gmail 수신함 확인 (1-3분 소요)
4. 6자리 코드 입력
5. 승인 완료 확인

---

## 📊 비용 예상

**Firebase Cloud Functions 무료 할당량 (Spark Plan):**
- 호출: 2,000,000회/월
- 컴퓨팅 시간: 400,000 GB-초/월
- 네트워크 송신: 5GB/월

**Gmail SMTP:**
- 완전 무료 (하루 500통 제한)

**예상 사용량:**
- 이메일 인증: 사용자당 1-2회/월
- FCM 푸시: 사용자당 3-5회/월
→ 월 10,000 사용자 기준: 약 50,000회 호출 (무료 범위 내)

---

## ⚠️ 주의사항

1. **Gmail 앱 비밀번호 보안**
   - 절대 코드에 하드코딩하지 마세요
   - Firebase Functions Config 사용 필수
   - `.env` 파일 사용 금지 (Firebase Config 사용)

2. **Gmail 전송 제한**
   - 하루 500통 제한 (Gmail 무료 계정)
   - 사용자가 많아지면 SendGrid/Mailgun 고려

3. **Firebase Functions 콜드 스타트**
   - 첫 호출 시 3-5초 지연 가능
   - 프리미엄 요금제에서 최소 인스턴스 설정 가능

4. **Firestore 읽기/쓰기 비용**
   - 무료: 50,000 읽기/20,000 쓰기/일
   - 초과 시 과금 ($0.06/100,000 읽기)

---

## 🔧 트러블슈팅

### 문제 1: "Invalid login" 오류
**원인**: Gmail 앱 비밀번호 오류
**해결**: 
1. Google 계정 → 보안 → 2단계 인증 확인
2. 앱 비밀번호 재생성
3. `firebase functions:config:set gmail.password="새-비밀번호"` 재설정
4. `firebase deploy --only functions` 재배포

### 문제 2: 이메일 전송 안 됨
**원인**: Cloud Functions 트리거 안 됨
**해결**:
1. Firebase Console → Functions → 로그 확인
2. Firestore 컬렉션 이름 확인: `email_verification_requests`
3. Functions 배포 상태 확인: `firebase functions:log`

### 문제 3: FCM 푸시 안 됨
**원인**: 잘못된 FCM 토큰
**해결**:
1. Flutter 앱에서 FCM 토큰 로그 확인
2. Firestore `fcm_tokens` 컬렉션 확인
3. Firebase Console → Cloud Messaging → 테스트 메시지 전송

---

## 📚 추가 자료

- [Firebase Cloud Functions 공식 문서](https://firebase.google.com/docs/functions)
- [Nodemailer Gmail 설정 가이드](https://nodemailer.com/usage/using-gmail/)
- [Firebase Functions Config 사용법](https://firebase.google.com/docs/functions/config-env)
- [Gmail SMTP 설정 가이드](https://support.google.com/mail/answer/7126229)

---

## ✅ 체크리스트

배포 전 확인 사항:

- [ ] Gmail 앱 비밀번호 생성 완료
- [ ] Firebase CLI 설치 및 로그인 완료
- [ ] `firebase init functions` 실행 완료
- [ ] `nodemailer` 패키지 설치 완료
- [ ] Gmail 환경 변수 설정 완료
- [ ] `functions/index.js` 코드 작성 완료
- [ ] Firestore 보안 규칙 업데이트 완료
- [ ] `firebase deploy --only functions` 배포 완료
- [ ] 테스트 이메일 전송 확인 완료

---

**구현 완료 후 Flutter 앱에서 자동으로 작동합니다! 🎉**
