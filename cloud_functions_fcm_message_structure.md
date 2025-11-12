# Cloud Functions FCM 메시지 구조 가이드

## 🚨 중요: notification 필드 필수!

FCM 메시지가 포그라운드/백그라운드에서 제대로 표시되려면 **notification 필드가 반드시 필요**합니다.

---

## ✅ 올바른 FCM 메시지 구조 (sendApprovalNotification)

```javascript
const message = {
  // ✅ CRITICAL: notification 필드 필수!
  notification: {
    title: '🔐 새 기기 로그인 감지',
    body: `${newDeviceName} (${newPlatform})에서 로그인 시도`
  },
  
  // ✅ data 필드: Flutter에서 처리할 정보
  data: {
    type: 'device_approval_request',
    approvalRequestId: approvalRequestId,
    newDeviceName: newDeviceName,
    newPlatform: newPlatform
  },
  
  // ✅ Android 설정
  android: {
    priority: 'high',
    notification: {
      channelId: 'high_importance_channel',
      priority: 'high',
      sound: 'default',
      vibrationPattern: [0, 500, 250, 500]
    }
  },
  
  // ✅ iOS 설정 (APNs)
  apns: {
    payload: {
      aps: {
        alert: {
          title: '🔐 새 기기 로그인 감지',
          body: `${newDeviceName} (${newPlatform})에서 로그인 시도`
        },
        sound: 'default',
        badge: 1,
        'content-available': 1  // 백그라운드 처리
      }
    },
    headers: {
      'apns-priority': '10'
    }
  },
  
  // 타겟 토큰
  token: targetToken
};
```

---

## ❌ 잘못된 구조 (notification 필드 없음)

```javascript
// ❌ WRONG: notification 필드가 없으면 알림이 표시되지 않음
const message = {
  data: {
    type: 'device_approval_request',
    approvalRequestId: approvalRequestId,
    newDeviceName: newDeviceName,
    newPlatform: newPlatform,
    // ❌ message 객체 내부에 title, body를 넣어도 표시 안 됨!
    message: {
      title: '...',
      body: '...'
    }
  },
  token: targetToken
};
```

---

## 📋 Cloud Functions 코드 예시

```javascript
const admin = require('firebase-admin');

exports.sendApprovalNotification = functions.firestore
  .document('fcm_approval_notification_queue/{docId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    
    const message = {
      // ✅ notification 필드 추가!
      notification: {
        title: data.message.title,
        body: data.message.body
      },
      
      // data 필드
      data: {
        type: data.message.type,
        approvalRequestId: data.approvalRequestId,
        newDeviceName: data.newDeviceName,
        newPlatform: data.newPlatform
      },
      
      // Android/iOS 설정
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
      
      token: data.targetToken
    };
    
    try {
      const response = await admin.messaging().send(message);
      console.log('✅ FCM 전송 성공:', response);
      
      // processed 플래그 업데이트
      await snap.ref.update({ processed: true, processedAt: admin.firestore.FieldValue.serverTimestamp() });
      
    } catch (error) {
      console.error('❌ FCM 전송 실패:', error);
      await snap.ref.update({ processed: false, error: error.message });
    }
  });
```

---

## 🔍 확인 사항

### 1. Cloud Functions 로그 확인
```
Firebase Console → Functions → sendApprovalNotification → 로그
```

확인할 내용:
- ✅ 함수가 실행되었는가?
- ✅ message 객체에 notification 필드가 있는가?
- ✅ FCM 전송 성공 로그가 있는가?
- ❌ 에러 로그가 있는가?

### 2. Flutter 로그 확인
```
포그라운드:
📨 [FLUTTER-FCM] _handleForegroundMessage() 호출됨!
   - notification.title: 🔐 새 기기 로그인 감지
   - notification.body: Galaxy S21 (android)에서 로그인 시도
   - data[type]: device_approval_request
🔔 [FCM] 기기 승인 요청 - 포그라운드 알림 표시 예정
✅ [FCM] 안드로이드 알림 표시 완료

백그라운드 (알림 클릭 시):
🔔 [FLUTTER-FCM] _handleMessageOpenedApp() 호출됨!
🔔 [FCM] 기기 승인 요청 알림 클릭 - 다이얼로그 표시
✅ [FCM] 기기 승인 다이얼로그 표시
```

---

## 🚀 다음 단계

1. **Cloud Functions 코드 확인**
   - `sendApprovalNotification` 함수에 notification 필드 추가 여부 확인

2. **테스트 실행**
   - 새 기기 로그인
   - 기존 기기에서 알림 수신 확인
   - Flutter 로그 확인

3. **문제 지속 시**
   - Cloud Functions 로그 공유
   - Flutter 로그 공유
   - FCM 메시지 구조 공유

---

## 📞 현재 작동하는 수신 전화 알림 참고

수신 전화 알림은 제대로 작동하고 있으므로, 동일한 구조를 사용하면 됩니다:

```javascript
// 수신 전화 알림 (참고용)
const message = {
  notification: {
    title: caller_name,
    body: `전화가 왔습니다`
  },
  data: {
    type: 'incoming_call',
    linkedid: linkedid,
    caller_num: caller_num,
    caller_name: caller_name,
    // ... 기타 데이터
  },
  // Android/iOS 설정...
};
```

동일한 패턴으로 device_approval_request도 작성하면 됩니다!
