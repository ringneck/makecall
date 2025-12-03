# Firestore 보안 규칙 V6 배포 가이드

## 📋 배포 전 확인사항

### 1. 설계 문서 확인
- [ ] `docs/FIRESTORE_SECURITY_RULES_DESIGN.md` 읽기
- [ ] 18개 컬렉션 분류 이해
- [ ] 4가지 타입 (A, B, C, D) 이해

### 2. 현재 규칙 백업
```bash
# Firebase Console에서 현재 규칙 복사하여 저장
# 문제 발생 시 롤백 가능하도록 준비
```

---

## 🚀 배포 절차

### Step 1: Firebase Console 접속
```
https://console.firebase.google.com/project/makecallio/firestore/rules
```

### Step 2: 전체 규칙 교체
1. 편집기의 **모든 내용 삭제**
2. 아래 규칙 **전체 복사**
3. 편집기에 **붙여넣기**

### Step 3: 새 보안 규칙 (V6)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ============================================
    // 🔵 TYPE A: User-Scoped Collections
    // 본인 데이터만 접근 가능한 컬렉션
    // ============================================
    
    // 1. users - 사용자 계정 정보
    match /users/{userId} {
      allow read, write, create: if request.auth != null 
                                 && request.auth.uid == userId;
    }
    
    // 2. main_numbers - 대표번호 관리
    match /main_numbers/{documentId} {
      allow read: if request.auth != null 
                  && resource.data.userId == request.auth.uid;
      allow write: if request.auth != null 
                   && resource.data.userId == request.auth.uid;
      allow create: if request.auth != null 
                    && request.resource.data.userId == request.auth.uid;
    }
    
    // 3. extensions - 단말번호 목록
    match /extensions/{documentId} {
      allow read: if request.auth != null 
                  && resource.data.userId == request.auth.uid;
      allow write: if request.auth != null 
                   && resource.data.userId == request.auth.uid;
      allow create: if request.auth != null 
                    && request.resource.data.userId == request.auth.uid;
    }
    
    // 4. call_history - 통화 기록
    match /call_history/{documentId} {
      allow read: if request.auth != null 
                  && resource.data.userId == request.auth.uid;
      allow write: if request.auth != null 
                   && resource.data.userId == request.auth.uid;
      allow create: if request.auth != null 
                    && request.resource.data.userId == request.auth.uid;
    }
    
    // 5. contacts - 연락처
    match /contacts/{documentId} {
      allow read: if request.auth != null 
                  && resource.data.userId == request.auth.uid;
      allow write: if request.auth != null 
                   && resource.data.userId == request.auth.uid;
      allow create: if request.auth != null 
                    && request.resource.data.userId == request.auth.uid;
    }
    
    // 6. phonebook_contacts - 주소록 연락처
    match /phonebook_contacts/{documentId} {
      allow read: if request.auth != null 
                  && resource.data.userId == request.auth.uid;
      allow write: if request.auth != null 
                   && resource.data.userId == request.auth.uid;
      allow create: if request.auth != null 
                    && request.resource.data.userId == request.auth.uid;
    }
    
    // 7. phonebooks - 주소록
    match /phonebooks/{documentId} {
      allow read: if request.auth != null 
                  && resource.data.userId == request.auth.uid;
      allow write: if request.auth != null 
                   && resource.data.userId == request.auth.uid;
      allow create: if request.auth != null 
                    && request.resource.data.userId == request.auth.uid;
    }
    
    // 8. my_extensions - 내 단말번호 정보
    match /my_extensions/{documentId} {
      allow read: if request.auth != null 
                  && resource.data.userId == request.auth.uid;
      allow write: if request.auth != null 
                   && resource.data.userId == request.auth.uid;
      allow create: if request.auth != null 
                    && request.resource.data.userId == request.auth.uid;
    }
    
    // 9. device_approval_requests - 기기 승인 요청
    match /device_approval_requests/{documentId} {
      allow read: if request.auth != null 
                  && resource.data.userId == request.auth.uid;
      allow write: if request.auth != null 
                   && resource.data.userId == request.auth.uid;
      allow create: if request.auth != null 
                    && request.resource.data.userId == request.auth.uid;
    }
    
    // 10. user_notification_settings - 사용자 알림 설정
    match /user_notification_settings/{userId} {
      allow read, write, create: if request.auth != null 
                                 && request.auth.uid == userId;
    }
    
    // ============================================
    // 🟢 TYPE B: Composite-ID Collections
    // Document ID로 소유권 판별 가능한 컬렉션
    // ============================================
    
    // 11. fcm_tokens - FCM 토큰 관리
    // Document ID 형식: {userId}_{deviceId}_{platform}
    match /fcm_tokens/{documentId} {
      allow read, write, create: if request.auth != null 
                                 && documentId.split('_')[0] == request.auth.uid;
    }
    
    // 12. call_forward_info - 착신전환 정보
    // Document ID 형식: {userId}_{extensionNumber}
    match /call_forward_info/{documentId} {
      allow read, write, create: if request.auth != null 
                                 && documentId.split('_')[0] == request.auth.uid;
    }
    
    // ============================================
    // 🟡 TYPE C: Shared Collections
    // 여러 사용자가 접근 가능한 공유 데이터
    // ============================================
    
    // 13. registered_extensions - 등록된 단말번호 (공개 정보)
    match /registered_extensions/{documentId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null 
                   && resource != null
                   && resource.data.userId == request.auth.uid;
      allow create: if request.auth != null 
                    && request.resource.data.userId == request.auth.uid;
    }
    
    // 14. fcm_approval_notification_queue - FCM 승인 알림 큐
    match /fcm_approval_notification_queue/{queueId} {
      allow read, write, create: if request.auth != null;
    }
    
    // 15. app_config - 앱 전역 설정 (읽기 전용)
    match /app_config/{configId} {
      allow read: if request.auth != null;
      allow write: if false;
    }
    
    // 16. shared_api_settings - 공유 API 설정 (읽기 전용)
    match /shared_api_settings/{settingId} {
      allow read: if request.auth != null;
      allow write: if false;
    }
    
    // ============================================
    // 🔴 TYPE D: Admin-Only Collections
    // 백엔드/관리자 전용, 클라이언트 접근 차단
    // ============================================
    
    // 17. email_verification_requests - 이메일 인증 요청
    match /email_verification_requests/{requestId} {
      allow read, write: if false;
    }
    
    // 18. fcm_notifications - FCM 알림 이력
    match /fcm_notifications/{notificationId} {
      allow read, write: if false;
    }
    
    // ============================================
    // ⚫ DEFAULT: 기타 모든 문서
    // ============================================
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

### Step 4: 게시 (Publish)
1. **"게시" 버튼** 클릭
2. 확인 대화상자에서 **"게시" 확인**
3. 배포 완료 메시지 확인

### Step 5: 배포 대기
- **대기 시간**: 5-10분
- Firestore 전역 배포 소요 시간

---

## ✅ 배포 후 검증

### 1. iOS 앱 재시작
```
1. iOS 앱 완전 종료 (백그라운드에서도 제거)
2. 앱 재시작
3. ringneck@naver.com 계정으로 로그인
```

### 2. 예상 성공 로그
```
✅ [FCM-SAVE] FCM 토큰 저장 완료
✅ [FCM-CHECK] 활성 FCM 토큰: 1개 발견
   - MacBook Pro (web) - 2025-01-XX XX:XX:XX
✅ [AUTH] MaxDeviceLimit 다이얼로그 표시 완료
✅ [MaxDeviceLimitDialog] 활성 기기 목록 로드 완료: 1개
   1. MacBook Pro (web) - 마지막 활동: 2025-01-XX XX:XX:XX
```

### 3. MaxDeviceLimit 다이얼로그 확인
- **제목**: "최대 사용 기기 수 초과"
- **메시지**: "현재 계정은 최대 1개의 기기에서만 사용할 수 있습니다."
- **활성 기기 목록** 표시:
  - 🌐 MacBook Pro (web)
  - 마지막 활동: XX분 전

### 4. 에러가 없어야 할 로그
```
❌ Missing or insufficient permissions (← 이 에러가 없어야 함!)
❌ [cloud_firestore/permission-denied] (← 이 에러가 없어야 함!)
```

---

## 🔧 문제 해결

### 문제 1: 여전히 permission-denied 에러 발생
**원인**: 규칙 배포가 아직 완료되지 않음  
**해결**: 
1. Firebase Console에서 **"게시 기록"** 확인
2. 최신 배포가 **"활성"** 상태인지 확인
3. 10분 더 대기 후 재시도

### 문제 2: 특정 컬렉션만 접근 실패
**원인**: 해당 컬렉션이 규칙에 포함되지 않음  
**해결**:
1. `docs/FIRESTORE_SECURITY_RULES_DESIGN.md` 확인
2. 누락된 컬렉션이 있는지 점검
3. 필요시 규칙 추가

### 문제 3: 앱이 작동하지 않음
**원인**: 규칙 문법 오류 또는 너무 제한적  
**해결**:
1. Firebase Console에서 **"시뮬레이터"** 사용
2. 특정 쿼리가 허용되는지 테스트
3. 문제 발견 시 이전 규칙으로 롤백

---

## 📊 V6 주요 개선사항

### Before (V1-V5의 문제점)
- ❌ 단편적 수정으로 일관성 부족
- ❌ Listening query 지원 불완전
- ❌ 새 문서 생성 시 권한 체크 실패
- ❌ 일부 컬렉션 규칙 누락
- ❌ 유지보수 어려움

### After (V6 개선사항)
- ✅ 18개 전체 컬렉션 완전 정의
- ✅ 4가지 타입별 통일된 패턴
- ✅ Listening query 완벽 지원
- ✅ 문서 생성/읽기/쓰기 모든 경우 처리
- ✅ 확장 가능한 구조
- ✅ 상세한 주석으로 이해 용이

---

## 📝 체크리스트

배포 전:
- [ ] 현재 규칙 백업 완료
- [ ] 설계 문서 읽고 이해
- [ ] Firebase Console 접속 가능

배포:
- [ ] 전체 규칙 복사 완료
- [ ] Firebase Console에 붙여넣기 완료
- [ ] 게시 버튼 클릭
- [ ] 10분 대기

검증:
- [ ] iOS 앱 재시작
- [ ] 로그인 성공
- [ ] FCM 토큰 저장 성공
- [ ] MaxDeviceLimit 다이얼로그 표시
- [ ] 활성기기 목록 표시
- [ ] permission-denied 에러 없음

---

**배포 완료 후 이 문서를 참조하여 검증을 완료해주세요!**

**문제 발생 시 GitHub Issue 또는 개발팀에 문의:**
- Repository: https://github.com/ringneck/makecall
- Commit: 3f11180 (Firestore 보안 규칙 V6)
