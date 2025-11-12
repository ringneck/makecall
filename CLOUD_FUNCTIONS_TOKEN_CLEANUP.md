# Cloud Functions FCM 토큰 정리 가이드

## 🚨 발생 중인 에러

```
messaging/registration-token-not-registered
Requested entity was not found.
```

**원인**: Firestore에 저장된 FCM 토큰이 유효하지 않음
- 앱 삭제 후 재설치
- 앱 데이터 삭제
- 기기 초기화
- 토큰 만료

---

## ✅ 해결 방법

### **Option 1: Cloud Functions에서 자동 정리 (권장)**

`sendApprovalNotification` Cloud Functions에 토큰 정리 로직 추가:

```javascript
exports.sendApprovalNotification = functions.firestore
  .document('fcm_approval_notification_queue/{docId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const targetToken = data.targetToken;
    
    // FCM 메시지 구조 (notification 필드 포함!)
    const message = {
      notification: {
        title: data.message.title,
        body: data.message.body
      },
      data: {
        type: data.message.type,
        approvalRequestId: data.approvalRequestId,
        newDeviceName: data.newDeviceName,
        newPlatform: data.newPlatform
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'high_importance_channel',
          priority: 'high',
          sound: 'default'
        }
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: data.message.title,
              body: data.message.body
            },
            sound: 'default',
            badge: 1
          }
        },
        headers: {
          'apns-priority': '10'
        }
      },
      token: targetToken
    };
    
    try {
      const response = await admin.messaging().send(message);
      console.log('✅ FCM 전송 성공:', response);
      
      // processed 플래그 업데이트
      await snap.ref.update({ 
        processed: true, 
        processedAt: admin.firestore.FieldValue.serverTimestamp() 
      });
      
    } catch (error) {
      console.error('❌ FCM 전송 오류:', error);
      
      // ✅ 토큰 에러 처리
      if (error.code === 'messaging/registration-token-not-registered' ||
          error.code === 'messaging/invalid-registration-token') {
        
        console.log('🗑️ 유효하지 않은 토큰 감지 - fcm_tokens에서 삭제');
        
        // fcm_tokens 컬렉션에서 해당 토큰 삭제
        const tokensQuery = await admin.firestore()
          .collection('fcm_tokens')
          .where('fcmToken', '==', targetToken)
          .get();
        
        const deletePromises = tokensQuery.docs.map(doc => doc.ref.delete());
        await Promise.all(deletePromises);
        
        console.log(`✅ 유효하지 않은 토큰 ${tokensQuery.size}개 삭제됨`);
      }
      
      // 에러 정보 저장
      await snap.ref.update({ 
        processed: false, 
        error: error.message,
        errorCode: error.code 
      });
    }
  });
```

---

### **Option 2: 수동 Firestore 정리**

Firebase Console에서 수동으로 정리:

1. **Firebase Console** → **Firestore Database**
2. `fcm_tokens` 컬렉션 선택
3. 각 문서 확인:
   - `isActive: true`인 문서들
   - 오래된 `lastActiveAt` 날짜 (예: 7일 이상)
4. 의심되는 문서 삭제

---

### **Option 3: Scheduled Function으로 자동 정리**

정기적으로 비활성 토큰 정리:

```javascript
exports.cleanupInvalidTokens = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    console.log('🧹 FCM 토큰 정리 시작');
    
    const db = admin.firestore();
    const sevenDaysAgo = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)
    );
    
    // 7일 이상 비활성 토큰 조회
    const inactiveTokens = await db.collection('fcm_tokens')
      .where('lastActiveAt', '<', sevenDaysAgo)
      .get();
    
    console.log(`🗑️ 비활성 토큰 ${inactiveTokens.size}개 발견`);
    
    // 각 토큰 유효성 검증
    const deletePromises = [];
    
    for (const doc of inactiveTokens.docs) {
      const token = doc.data().fcmToken;
      
      try {
        // FCM 토큰 유효성 확인 (dry-run 메시지 전송)
        await admin.messaging().send({
          token: token,
          data: { test: 'validation' }
        }, true); // dry-run = true
        
        console.log(`✅ 토큰 유효: ${token.substring(0, 20)}...`);
        
      } catch (error) {
        if (error.code === 'messaging/registration-token-not-registered' ||
            error.code === 'messaging/invalid-registration-token') {
          
          console.log(`❌ 토큰 무효 - 삭제: ${token.substring(0, 20)}...`);
          deletePromises.push(doc.ref.delete());
        }
      }
    }
    
    await Promise.all(deletePromises);
    console.log(`✅ 유효하지 않은 토큰 ${deletePromises.length}개 삭제 완료`);
  });
```

---

## 🔍 토큰 에러가 발생하는 이유

### **정상적인 경우**
1. **앱 재설치**: 사용자가 앱을 삭제하고 재설치
2. **기기 초기화**: 기기를 공장 초기화
3. **앱 데이터 삭제**: 설정에서 앱 데이터 삭제
4. **토큰 만료**: FCM 토큰이 자동 갱신되었지만 Firestore가 업데이트되지 않음

### **비정상적인 경우**
1. **로그아웃 누락**: 로그아웃 시 FCM 토큰이 Firestore에서 삭제되지 않음
2. **네트워크 오류**: 토큰 업데이트 중 네트워크 오류로 동기화 실패
3. **여러 기기**: 동일 계정에 여러 기기가 있었지만 일부만 활성화

---

## ✅ 현재 상황 분석

로그를 보면:
- ✅ 1개 토큰은 성공: `fw6BkblAI0xZtdBPNF1X...`
- ❌ 3개 토큰은 실패: `fMuCZrqOOU3xqFO1y_GO...`, `ckUFwNuhIUMevYVAYwCC...`, `dXLy8e87S66Hh7JsmQpb...`

**결론**: 
- 기존 기기 중 1대는 활성화되어 있고 FCM 알림 수신 가능
- 나머지 3대는 비활성 상태 (앱 삭제/재설치/기기 변경 등)
- **승인 알림은 1대에만 전송되므로 정상 작동**

---

## 🚀 권장 조치

### **즉시 조치 (필수)**
✅ **Option 1** 적용: Cloud Functions에 토큰 정리 로직 추가
- 에러 발생 시 자동으로 유효하지 않은 토큰 삭제
- 다음 로그인 시도에서 깨끗한 상태 유지

### **장기 조치 (선택)**
✅ **Option 3** 적용: Scheduled Function으로 정기 정리
- 매일 자동으로 비활성 토큰 검증 및 삭제
- Firestore 용량 절약 및 성능 개선

---

## 📋 테스트 체크리스트

승인 대기 로직 추가 후 테스트:

1. **새 기기 로그인**
   - 새 기기에서 로그인 시도
   - "기존 기기의 승인 대기 중..." 메시지 확인
   - 로그인이 즉시 완료되지 않는지 확인 ✅

2. **기존 기기 승인**
   - 기존 기기에서 FCM 알림 수신
   - 알림 클릭 → 승인 다이얼로그 표시
   - "승인" 버튼 클릭
   - 새 기기에서 로그인 완료 확인 ✅

3. **기존 기기 거부**
   - 기존 기기에서 "거부" 버튼 클릭
   - 새 기기에서 로그인 실패 확인 ✅

4. **시간 초과**
   - 5분간 승인/거부하지 않음
   - 새 기기에서 로그인 실패 확인 ✅

---

## 🔗 관련 파일

- Flutter 코드: `/home/user/flutter_app/lib/services/fcm_service.dart`
- Security Rules: `/home/user/flutter_app/firestore_security_rules.txt`
- FCM 가이드: `/home/user/flutter_app/cloud_functions_fcm_message_structure.md`

---

**상태**: 
- ✅ Flutter 승인 대기 로직 완료
- ⚠️ Cloud Functions 토큰 정리 권장
- ✅ 승인 시스템 보안 강화 완료
