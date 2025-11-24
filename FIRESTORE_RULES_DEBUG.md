# Firestore 보안 규칙 디버깅 가이드

## 🚨 현재 상황
iOS 애플 로그인 시 여전히 permission-denied 에러 발생:
```
Listen for query at users/apple_xxx failed: Missing or insufficient permissions.
[cloud_firestore/permission-denied] The caller does not have permission to execute the specified operation.
```

---

## 🔍 문제 진단

### 1. Firebase Console에서 현재 규칙 확인
**URL**: https://console.firebase.google.com/project/makecallio/firestore/rules

현재 배포된 규칙이 다음과 같은지 확인:
```javascript
match /users/{userId} {
  allow read: if request.auth != null && request.auth.uid == userId;
  allow create: if request.auth != null && 
                   request.auth.uid == userId &&
                   request.resource.data.uid == userId;
  allow update: if request.auth != null && 
                   request.auth.uid == userId &&
                   resource.data.uid == userId;
  allow delete: if false;
}
```

---

## ✅ 해결 방법 1: 개발 환경용 임시 규칙 (권장)

테스트를 위해 임시로 더 관대한 규칙을 사용합니다.

### Firebase Console → Rules 탭에서 다음 규칙으로 교체:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ================================
    // 사용자 관련 컬렉션 (개발 환경용 - 임시)
    // ================================
    
    match /users/{userId} {
      // 개발 환경: 로그인한 모든 사용자가 자신의 문서 생성/읽기/쓰기 가능
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // ================================
    // FCM 및 디바이스 관리
    // ================================
    
    match /fcm_tokens/{tokenId} {
      allow read, write: if request.auth != null;
    }
    
    match /device_approval_requests/{requestId} {
      allow read: if request.auth != null && 
                     resource.data.userId == request.auth.uid;
      allow create: if request.auth != null;
      allow update: if request.auth != null && 
                       resource.data.userId == request.auth.uid;
      allow delete: if false;
    }
    
    match /email_verification_requests/{requestId} {
      allow read: if request.auth != null && 
                     resource.data.userId == request.auth.uid;
      allow create: if request.auth != null;
      allow update: if request.auth != null && 
                       resource.data.userId == request.auth.uid;
      allow delete: if false;
    }
    
    match /fcm_approval_notification_queue/{queueId} {
      allow read, write: if false;
    }
    
    match /fcm_force_logout_queue/{queueId} {
      allow read, write: if false;
    }
    
    // ================================
    // 내선 및 연락처 관련
    // ================================
    
    match /my_extensions/{extensionId} {
      allow read: if request.auth != null && 
                     resource.data.userId == request.auth.uid;
      allow write: if request.auth != null && 
                      request.resource.data.userId == request.auth.uid;
    }
    
    match /call_forward_info/{infoId} {
      allow read: if request.auth != null && 
                     resource.data.userId == request.auth.uid;
      allow write: if request.auth != null && 
                      request.resource.data.userId == request.auth.uid;
    }
    
    match /user_notification_settings/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    match /phonebook_contacts/{contactId} {
      allow read: if request.auth != null && 
                     resource.data.userId == request.auth.uid;
      allow create: if request.auth != null && 
                       request.resource.data.userId == request.auth.uid;
      allow update: if request.auth != null && 
                       resource.data.userId == request.auth.uid;
      allow delete: if request.auth != null && 
                       resource.data.userId == request.auth.uid;
    }
    
    match /phonebooks/{phonebookId} {
      allow read: if request.auth != null && 
                     resource.data.userId == request.auth.uid;
      allow create: if request.auth != null && 
                       request.resource.data.userId == request.auth.uid;
      allow update: if request.auth != null && 
                       resource.data.userId == request.auth.uid;
      allow delete: if request.auth != null && 
                       resource.data.userId == request.auth.uid;
    }
    
    match /contacts/{contactId} {
      allow read: if request.auth != null && 
                     resource.data.userId == request.auth.uid;
      allow create: if request.auth != null && 
                       request.resource.data.userId == request.auth.uid;
      allow update: if request.auth != null && 
                       resource.data.userId == request.auth.uid;
      allow delete: if request.auth != null && 
                       resource.data.userId == request.auth.uid;
    }
    
    match /call_history/{historyId} {
      allow read: if request.auth != null && 
                     resource.data.userId == request.auth.uid;
      allow create: if request.auth != null && 
                       request.resource.data.userId == request.auth.uid;
      allow update: if request.auth != null && 
                       resource.data.userId == request.auth.uid;
      allow delete: if request.auth != null && 
                       resource.data.userId == request.auth.uid;
    }
    
    match /extensions/{extensionId} {
      allow read: if request.auth != null;
      allow write: if false;
    }
    
    match /registered_extensions/{extensionId} {
      allow read: if request.auth != null;
      allow write: if false;
    }
    
    match /main_numbers/{numberId} {
      allow read: if request.auth != null;
      allow write: if false;
    }
    
    // ================================
    // 기본 규칙
    // ================================
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

**주요 변경점**:
```javascript
// Before (복잡한 규칙):
allow create: if request.auth != null && 
                 request.auth.uid == userId &&
                 request.resource.data.uid == userId;
allow update: if request.auth != null && 
                 request.auth.uid == userId &&
                 resource.data.uid == userId;

// After (간소화된 규칙):
allow read, write: if request.auth != null && request.auth.uid == userId;
```

---

## ✅ 해결 방법 2: Rules Playground에서 테스트

### Firebase Console → Firestore → Rules → Rules Playground

#### Test Case 1: 문서 생성 (Create)
```
Simulator:
  Provider: Custom
  Location: /users/apple_001113.221871c46ba94c3c8ccfae3f17c86add.1253
  
Auth:
  Provider: Custom
  uid: apple_001113.221871c46ba94c3c8ccfae3f17c86add.1253
  
Operation: create
  
Data:
{
  "uid": "apple_001113.221871c46ba94c3c8ccfae3f17c86add.1253",
  "email": "test@privaterelay.appleid.com",
  "organizationName": "Apple User",
  "accountStatus": "approved"
}

Expected Result: ✅ Allow
```

#### Test Case 2: 문서 읽기 (Read)
```
Simulator:
  Provider: Custom
  Location: /users/apple_001113.221871c46ba94c3c8ccfae3f17c86add.1253
  
Auth:
  Provider: Custom
  uid: apple_001113.221871c46ba94c3c8ccfae3f17c86add.1253
  
Operation: get

Expected Result: ✅ Allow
```

---

## 🔍 디버깅 체크리스트

### 1. Firebase Console 확인
- [ ] Firestore Rules 탭에서 규칙 확인
- [ ] 마지막 배포 시간이 최근인지 확인 (1-2분 전)
- [ ] Rules Playground에서 테스트 실행

### 2. Firebase Authentication 확인
- [ ] Authentication 탭에서 사용자 목록 확인
- [ ] UID가 `apple_001113.221871c46ba94c3c8ccfae3f17c86add.1253`인지 확인
- [ ] Provider가 "Apple"인지 확인

### 3. Firestore Data 확인
- [ ] Data 탭에서 `users` 컬렉션 확인
- [ ] 해당 UID로 문서가 존재하는지 확인
- [ ] 존재하면 삭제 후 재시도

---

## 🚨 긴급 해결: 완전히 오픈된 규칙 (테스트 전용)

**⚠️ 경고**: 프로덕션 환경에서는 절대 사용하지 마세요!

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // 테스트 전용: 모든 접근 허용
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

이 규칙으로 테스트 후 애플 로그인이 성공하면, 규칙 문제가 맞습니다.
성공 후 위의 "해결 방법 1" 규칙으로 다시 변경하세요.

---

## 📊 예상 결과

### 규칙 수정 후 성공 로그:
```
✅ [Apple] 로그인 성공
🔄 [PROFILE UPDATE] Firestore 사용자 정보 업데이트 시작
🆕 [PROFILE UPDATE] 신규 사용자 문서 생성
✅ [PROFILE UPDATE] 신규 사용자 문서 생성 완료
✅ [SOCIAL LOGIN] AuthService userModel 재로드 완료
✅ 홈 화면으로 이동
```

### Firestore Data 확인:
- `users/apple_001113.221871c46ba94c3c8ccfae3f17c86add.1253` 문서 생성됨
- 필드: uid, email, organizationName, accountStatus, loginProvider 등

---

## 🔗 빠른 링크

- **Firestore Rules**: https://console.firebase.google.com/project/makecallio/firestore/rules
- **Firestore Data**: https://console.firebase.google.com/project/makecallio/firestore/data
- **Authentication Users**: https://console.firebase.google.com/project/makecallio/authentication/users

---

## 📞 다음 단계

1. **해결 방법 1의 규칙 복사**
2. **Firebase Console → Rules 탭에 붙여넣기**
3. **게시 (Publish) 클릭**
4. **2분 대기**
5. **iOS 앱에서 애플 로그인 재시도**

규칙을 적용한 후에도 문제가 계속되면 "긴급 해결" 규칙을 사용해보세요.
