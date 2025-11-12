# Cloud Functions 수정 및 배포 가이드

## 🎯 목표

`sendApprovalNotification` Cloud Functions에 다음 두 가지 수정 적용:
1. ✅ **notification 필드 추가** - 포그라운드 알림 표시
2. ✅ **토큰 정리 로직 추가** - 유효하지 않은 토큰 자동 삭제

---

## 📋 STEP 1: 현재 Cloud Functions 코드 확인

### **Option A: Firebase Console에서 확인**

1. Firebase Console 접속: https://console.firebase.google.com/
2. 프로젝트 선택
3. **Build** → **Functions** 탭
4. `sendApprovalNotification` 함수 찾기
5. **소스 탭** 클릭 → 현재 코드 확인

### **Option B: 로컬 프로젝트에서 확인**

Cloud Functions 소스 코드가 있다면:
```bash
# Cloud Functions 프로젝트 디렉토리로 이동
cd path/to/firebase-functions

# index.js 또는 함수 파일 확인
cat functions/index.js
# 또는
cat functions/src/index.ts
```

---

## 📝 STEP 2: 수정할 코드

### **현재 코드 (추정)**

```javascript
exports.sendApprovalNotification = functions.firestore
  .document('fcm_approval_notification_queue/{docId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    
    const message = {
      // ❌ notification 필드 없음!
      data: {
        type: data.message.type,
        approvalRequestId: data.approvalRequestId,
        newDeviceName: data.newDeviceName,
        newPlatform: data.newPlatform
      },
      token: data.targetToken
    };
    
    try {
      await admin.messaging().send(message);
      console.log('✅ FCM 알림 전송 완료');
    } catch (error) {
      console.error('❌ FCM 알림 전송 오류:', error);
      // ❌ 토큰 정리 로직 없음!
    }
  });
```

### **수정된 코드 (적용 필요)**

```javascript
const admin = require('firebase-admin');
const functions = require('firebase-functions');

exports.sendApprovalNotification = functions.firestore
  .document('fcm_approval_notification_queue/{docId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    
    console.log('🔔 FCM 승인 알림 요청 수신:', context.params.docId);
    console.log('Target Token:', data.targetToken.substring(0, 20) + '...');
    console.log('New Device:', data.newDeviceName, '(' + data.newPlatform + ')');
    
    // ✅ CRITICAL: notification 필드 추가!
    const message = {
      notification: {
        title: data.message.title || '🔐 새 기기 로그인 감지',
        body: data.message.body || `${data.newDeviceName} (${data.newPlatform})에서 로그인 시도`
      },
      data: {
        type: data.message.type || 'device_approval_request',
        approvalRequestId: data.approvalRequestId,
        newDeviceName: data.newDeviceName,
        newPlatform: data.newPlatform
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'high_importance_channel',
          priority: 'high',
          sound: 'default',
          vibrationPattern: [0, 500, 250, 500]
        }
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: data.message.title || '🔐 새 기기 로그인 감지',
              body: data.message.body || `${data.newDeviceName} (${data.newPlatform})에서 로그인 시도`
            },
            sound: 'default',
            badge: 1,
            'content-available': 1
          }
        },
        headers: {
          'apns-priority': '10'
        }
      },
      token: data.targetToken
    };
    
    try {
      const response = await admin.messaging().send(message);
      console.log('✅ FCM 알림 전송 완료:', data.targetToken.substring(0, 20) + '...');
      
      // processed 플래그 업데이트
      await snap.ref.update({ 
        processed: true, 
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        response: response
      });
      
    } catch (error) {
      console.error('❌ FCM 알림 전송 오류:', error.message);
      
      // ✅ 토큰 에러 처리 및 자동 정리
      if (error.code === 'messaging/registration-token-not-registered' ||
          error.code === 'messaging/invalid-registration-token') {
        
        console.log('🗑️ 유효하지 않은 토큰 감지 - fcm_tokens에서 삭제 시작');
        
        try {
          // fcm_tokens 컬렉션에서 해당 토큰 검색
          const tokensQuery = await admin.firestore()
            .collection('fcm_tokens')
            .where('fcmToken', '==', data.targetToken)
            .get();
          
          if (!tokensQuery.empty) {
            // 모든 일치하는 토큰 삭제
            const deletePromises = tokensQuery.docs.map(doc => {
              console.log('🗑️ 토큰 삭제:', doc.id);
              return doc.ref.delete();
            });
            
            await Promise.all(deletePromises);
            console.log(`✅ 유효하지 않은 토큰 ${tokensQuery.size}개 삭제 완료`);
          } else {
            console.log('ℹ️ fcm_tokens에서 해당 토큰을 찾지 못함');
          }
        } catch (cleanupError) {
          console.error('❌ 토큰 정리 오류:', cleanupError);
        }
      }
      
      // 에러 정보 저장
      await snap.ref.update({ 
        processed: false, 
        error: error.message,
        errorCode: error.code,
        processedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }
  });
```

---

## 🚀 STEP 3: 배포 방법

### **Option A: Firebase CLI 사용 (권장)**

1. **Firebase CLI 설치 확인**
   ```bash
   firebase --version
   # 없으면: npm install -g firebase-tools
   ```

2. **Firebase 로그인**
   ```bash
   firebase login
   ```

3. **프로젝트 초기화 (최초 1회)**
   ```bash
   cd path/to/project
   firebase init functions
   # 언어 선택: JavaScript 또는 TypeScript
   ```

4. **함수 코드 수정**
   ```bash
   cd functions
   # index.js 또는 src/index.ts 파일 수정
   # 위의 "수정된 코드" 내용으로 교체
   ```

5. **배포**
   ```bash
   firebase deploy --only functions:sendApprovalNotification
   # 또는 모든 함수 배포: firebase deploy --only functions
   ```

6. **배포 확인**
   ```bash
   firebase functions:log --only sendApprovalNotification
   ```

### **Option B: Firebase Console에서 직접 수정 (간단하지만 비추천)**

⚠️ **주의**: Firebase Console에서는 간단한 수정만 가능하며, 복잡한 로직은 로컬 개발 권장

1. Firebase Console → Functions
2. `sendApprovalNotification` 함수 선택
3. **편집** 버튼 클릭
4. 코드 수정
5. **배포** 버튼 클릭

---

## 📂 STEP 4: 프로젝트 구조 (참고)

일반적인 Cloud Functions 프로젝트 구조:

```
project-root/
├── functions/
│   ├── index.js (또는 src/index.ts)
│   ├── package.json
│   └── node_modules/
├── firebase.json
└── .firebaserc
```

---

## 🧪 STEP 5: 테스트

### **테스트 1: 로그 확인**
```bash
firebase functions:log --only sendApprovalNotification
```

### **테스트 2: 실제 알림 테스트**
1. 새 기기에서 로그인 시도
2. Firebase Console → Functions → Logs 확인
3. 기대되는 로그:
   ```
   🔔 FCM 승인 알림 요청 수신: [docId]
   Target Token: [token]...
   New Device: [deviceName] ([platform])
   ✅ FCM 알림 전송 완료: [token]...
   ```

### **테스트 3: Flutter 앱 확인**
1. 기존 기기에서 알림 수신 확인 (포그라운드)
2. 알림 클릭 → 다이얼로그 표시 확인
3. 승인/거부 동작 확인

---

## ❓ 자주 묻는 질문

### **Q1: Cloud Functions 소스 코드가 어디 있나요?**
**A**: 보통 다음 위치 중 하나:
- GitHub 저장소의 `functions/` 디렉토리
- 로컬 개발 환경의 Firebase 프로젝트
- Firebase Console에서 직접 작성한 경우 Console에만 존재

### **Q2: 배포 권한이 없다면?**
**A**: Firebase 프로젝트 소유자나 관리자에게 요청:
1. Firebase Console → 프로젝트 설정 → 사용자 및 권한
2. 계정에 "Firebase Admin" 또는 "Editor" 역할 부여
3. 또는 수정된 코드를 공유하여 배포 요청

### **Q3: 이미 배포된 함수를 수정하면?**
**A**: 
- 기존 함수가 새 코드로 완전히 교체됨
- 트리거 설정은 유지됨
- 다운타임 없음 (Firebase가 자동 처리)

### **Q4: 롤백하려면?**
**A**:
```bash
# 이전 버전으로 롤백
firebase functions:delete sendApprovalNotification
firebase deploy --only functions:sendApprovalNotification
```

---

## 📋 체크리스트

배포 전:
- [ ] Firebase CLI 설치 확인
- [ ] Firebase 프로젝트 로그인 확인
- [ ] 함수 코드 백업
- [ ] 수정 사항 검토

배포 후:
- [ ] 배포 성공 메시지 확인
- [ ] 함수 로그 확인
- [ ] 실제 알림 테스트
- [ ] 포그라운드/백그라운드 모두 확인

---

## 🔗 참고 자료

- Firebase Functions 문서: https://firebase.google.com/docs/functions
- Firebase CLI 문서: https://firebase.google.com/docs/cli
- FCM 메시지 구조: https://firebase.google.com/docs/cloud-messaging/concept-options

---

## 💡 간단 요약

**가장 빠른 방법**:
1. 로컬에 Firebase Functions 프로젝트 클론
2. `functions/index.js` 파일 수정
3. `firebase deploy --only functions:sendApprovalNotification`
4. 테스트

**Cloud Functions 소스가 없다면**:
- GitHub 저장소 확인
- 프로젝트 관리자에게 소스 코드 요청
- 또는 위의 수정된 코드를 전달하여 배포 요청

---

**필요한 것**: Cloud Functions 소스 코드 접근 권한 + Firebase 배포 권한

Cloud Functions 소스 코드를 공유해주시면 정확한 수정 사항을 알려드릴 수 있습니다! 🚀
