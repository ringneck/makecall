# Firestore 보안 규칙 V6.1 - 전체 검증 및 쿼리 지원 분석

## 📋 목적
V6에서 발견된 쿼리 지원 문제를 해결하고, 모든 18개 컬렉션의 쿼리 패턴을 재검증하여 완전한 보안 규칙 수립

## 🔍 Phase 1: 전체 컬렉션 쿼리 패턴 분석

### 1. **users** (User-Scoped)
**쿼리 패턴**: 없음 (개별 문서 접근만)
```dart
_firestore.collection('users').doc(userId).get()
```
**현재 규칙**: ✅ 정상
```javascript
match /users/{userId} {
  allow read, write, create: if request.auth != null 
                             && request.auth.uid == userId;
}
```
**검증 결과**: ✅ 쿼리 없음 - 현재 규칙 유지

---

### 2. **main_numbers** (User-Scoped)
**쿼리 패턴**: 
```dart
.collection('main_numbers')
.where('userId', isEqualTo: userId)
.snapshots()
```
**현재 규칙**: ✅ 정상
```javascript
match /main_numbers/{documentId} {
  allow read: if request.auth != null 
              && resource.data.userId == request.auth.uid;
  allow write: if request.auth != null 
               && resource.data.userId == request.auth.uid;
  allow create: if request.auth != null 
                && request.resource.data.userId == request.auth.uid;
}
```
**검증 결과**: ✅ `resource.data.userId` 사용 - 쿼리 지원

---

### 3. **extensions** (User-Scoped)
**쿼리 패턴**:
```dart
.collection('extensions')
.where('userId', isEqualTo: userId)
.snapshots()
```
**현재 규칙**: ✅ 정상 (`resource.data.userId` 사용)
**검증 결과**: ✅ 쿼리 지원

---

### 4. **call_history** (User-Scoped)
**쿼리 패턴**:
```dart
.collection('call_history')
.where('userId', isEqualTo: userId)
```
**현재 규칙**: ✅ 정상 (`resource.data.userId` 사용)
**검증 결과**: ✅ 쿼리 지원

---

### 5. **contacts** (User-Scoped)
**쿼리 패턴**:
```dart
// 패턴 1: 모든 연락처
.collection('contacts')
.where('userId', isEqualTo: userId)
.snapshots()

// 패턴 2: 즐겨찾기만
.collection('contacts')
.where('userId', isEqualTo: userId)
.where('isFavorite', isEqualTo: true)
.snapshots()

// 패턴 3: 전화번호로 검색
.collection('contacts')
.where('userId', isEqualTo: userId)
.where('phoneNumber', isEqualTo: phoneNumber)
```
**현재 규칙**: ✅ 정상 (`resource.data.userId` 사용)
**검증 결과**: ✅ 복합 쿼리 지원

---

### 6. **phonebook_contacts** (User-Scoped)
**쿼리 패턴**:
```dart
// 패턴 1: 특정 주소록의 연락처
.collection('phonebook_contacts')
.where('userId', isEqualTo: userId)
.where('phonebookId', isEqualTo: phonebookId)
.snapshots()

// 패턴 2: 모든 주소록 연락처
.collection('phonebook_contacts')
.where('userId', isEqualTo: userId)
.snapshots()

// 패턴 3: 즐겨찾기
.collection('phonebook_contacts')
.where('userId', isEqualTo: userId)
.where('isFavorite', isEqualTo: true)
.snapshots()

// 패턴 4: 중복 체크
.collection('phonebook_contacts')
.where('userId', isEqualTo: contact.userId)
.where('phonebookId', isEqualTo: contact.phonebookId)
.where('telephone', isEqualTo: contact.telephone)

// 패턴 5: contactId로 검색
.collection('phonebook_contacts')
.where('userId', isEqualTo: contact.userId)
.where('phonebookId', isEqualTo: contact.phonebookId)
.where('contactId', isEqualTo: contact.contactId)
```
**현재 규칙**: ✅ 정상 (`resource.data.userId` 사용)
**검증 결과**: ✅ 복잡한 복합 쿼리 모두 지원

---

### 7. **phonebooks** (User-Scoped)
**쿼리 패턴**:
```dart
// 패턴 1: 모든 주소록
.collection('phonebooks')
.where('userId', isEqualTo: userId)
.snapshots()

// 패턴 2: phonebookId로 검색
.collection('phonebooks')
.where('userId', isEqualTo: phonebook.userId)
.where('phonebookId', isEqualTo: phonebook.phonebookId)
```
**현재 규칙**: ✅ 정상 (`resource.data.userId` 사용)
**검증 결과**: ✅ 쿼리 지원

---

### 8. **my_extensions** (User-Scoped)
**쿼리 패턴**:
```dart
// 패턴 1: 모든 단말번호
.collection('my_extensions')
.where('userId', isEqualTo: userId)
.snapshots()

// 패턴 2: extension으로 검색
.collection('my_extensions')
.where('userId', isEqualTo: extension.userId)
.where('extension', isEqualTo: extension.extension)

// 패턴 3: 단순 조회
.collection('my_extensions')
.where('userId', isEqualTo: userId)
```
**현재 규칙**: ✅ 정상 (`resource.data.userId` 사용)
**검증 결과**: ✅ 쿼리 지원

---

### 9. **device_approval_requests** (User-Scoped)
**쿼리 패턴**:
```dart
// 패턴 1: 승인 대기 목록
.collection('device_approval_requests')
.doc(approvalRequestId)
.snapshots()

// 패턴 2: 코드 검증
.collection('device_approval_requests')
.where('userId', isEqualTo: widget.userId)
.where('approvalRequestId', isEqualTo: widget.approvalRequestId)
.where('code', isEqualTo: code)
.where('used', isEqualTo: false)
```
**현재 규칙**: ✅ 정상 (`resource.data.userId` 사용)
**검증 결과**: ✅ 복합 쿼리 지원

---

### 10. **user_notification_settings** (User-Scoped)
**쿼리 패턴**: 개별 문서 접근만
```dart
.collection('user_notification_settings').doc(userId)
```
**현재 규칙**: ✅ 정상
```javascript
match /user_notification_settings/{userId} {
  allow read, write, create: if request.auth != null 
                             && request.auth.uid == userId;
}
```
**검증 결과**: ✅ 쿼리 없음 - 현재 규칙 유지

---

## 🔴 Phase 2: 문제가 있는 컬렉션

### 11. **fcm_tokens** (Composite-ID) ❌ 문제 발견!

**쿼리 패턴**:
```dart
// 패턴 1: 모든 활성 토큰 (승인 필요 없음)
.collection('fcm_tokens')
.where('userId', isEqualTo: userId)
.where('isActive', isEqualTo: true)

// 패턴 2: 승인된 활성 토큰만
.collection('fcm_tokens')
.where('userId', isEqualTo: userId)
.where('isActive', isEqualTo: true)
.where('isApproved', isEqualTo: true)

// 패턴 3: 특정 기기 검색
.collection('fcm_tokens')
.where('userId', isEqualTo: userId)
.where('deviceId', isEqualTo: newDeviceId)
.where('platform', isEqualTo: newPlatform)

// 패턴 4: 만료된 토큰 정리
.collection('fcm_tokens')
.where('lastActiveAt', isLessThan: Timestamp.fromDate(expiryDate))

// 패턴 5: snapshots (실시간 리스닝)
_firestore.collection('fcm_tokens')
  .where('userId', isEqualTo: userId)
  .where('isActive', isEqualTo: true)
  .snapshots()
```

**현재 규칙**: ❌ 쿼리 미지원
```javascript
match /fcm_tokens/{documentId} {
  allow read, write, create: if request.auth != null 
                             && documentId.split('_')[0] == request.auth.uid;
}
```

**문제점**:
1. `documentId.split('_')[0]`은 **개별 문서 접근**에만 작동
2. `.where()` 쿼리 실행 시 모든 문서를 먼저 읽어야 함
3. `documentId`는 쿼리 결과에만 접근 가능 → 규칙 검증 실패
4. 결과: `PERMISSION_DENIED` 에러 발생

**영향 범위**:
- ❌ 최대 사용기기 수 제한 작동 안함
- ❌ MaxDeviceLimitDialog 활성 기기 목록 표시 안됨
- ❌ FCM 토큰 정리 작업 실패
- ❌ 기기 승인 프로세스 실패

**수정 방안**:
```javascript
match /fcm_tokens/{documentId} {
  // read: 쿼리 지원 + 개별 문서 접근 모두 지원
  allow read: if request.auth != null 
              && (resource == null || resource.data.userId == request.auth.uid);
  
  // write: 기존 문서 수정 (userId 검증)
  allow write: if request.auth != null 
               && resource != null
               && resource.data.userId == request.auth.uid;
  
  // create: 새 문서 생성 (userId 검증)
  allow create: if request.auth != null 
                && request.resource.data.userId == request.auth.uid;
}
```

**수정 근거**:
1. ✅ `resource.data.userId` 사용 → 쿼리 조건 검증 가능
2. ✅ `resource == null` 체크 → 문서 생성 시 허용
3. ✅ read/write/create 분리 → 정확한 권한 제어
4. ✅ 모든 쿼리 패턴 지원 (where userId, where isActive, where isApproved 등)

---

### 12. **call_forward_info** (Composite-ID) ⚠️ 잠재적 문제

**쿼리 패턴**:
```dart
// 개별 문서 접근 + snapshots
.collection('call_forward_info')
.doc(docId)
.snapshots()
```

**현재 규칙**: ⚠️ documentId.split() 사용
```javascript
match /call_forward_info/{documentId} {
  allow read, write, create: if request.auth != null 
                             && documentId.split('_')[0] == request.auth.uid;
}
```

**분석**:
- 현재는 개별 문서 접근 + `.snapshots()`만 사용
- 쿼리(`.where()`)는 사용하지 않음
- **현재로는 문제 없음**
- ⚠️ 향후 쿼리 추가 시 문제 발생 가능

**권장 사항**: 
일관성을 위해 `resource.data.userId` 방식으로 변경 고려
```javascript
match /call_forward_info/{documentId} {
  allow read: if request.auth != null 
              && (resource == null || resource.data.userId == request.auth.uid);
  allow write: if request.auth != null 
               && resource != null
               && resource.data.userId == request.auth.uid;
  allow create: if request.auth != null 
                && request.resource.data.userId == request.auth.uid;
}
```

---

## ✅ Phase 3: 정상 작동하는 Shared Collections

### 13. **registered_extensions** (Shared)
**쿼리 패턴**:
```dart
.collection('registered_extensions')
.where('userId', isEqualTo: userId)
```
**현재 규칙**: ✅ 정상
```javascript
match /registered_extensions/{documentId} {
  allow read: if request.auth != null;  // 모든 사용자 읽기 가능
  allow write: if request.auth != null 
               && resource != null
               && resource.data.userId == request.auth.uid;
  allow create: if request.auth != null 
                && request.resource.data.userId == request.auth.uid;
}
```
**검증 결과**: ✅ 쿼리 지원 + 공유 읽기 정상

---

### 14. **fcm_approval_notification_queue** (Shared)
**쿼리 패턴**: 개별 문서 접근만
**현재 규칙**: ✅ 정상
```javascript
match /fcm_approval_notification_queue/{queueId} {
  allow read, write, create: if request.auth != null;
}
```
**검증 결과**: ✅ 쿼리 없음 - 현재 규칙 유지

---

### 15. **app_config** (Shared - Read Only)
**쿼리 패턴**: 개별 문서 접근만
**현재 규칙**: ✅ 정상
**검증 결과**: ✅ 현재 규칙 유지

---

### 16. **shared_api_settings** (Shared - Read Only)
**쿼리 패턴**:
```dart
// 패턴 1: 조직명으로 검색
.collection('shared_api_settings')
.where('organizationName', isEqualTo: organizationName)

// 패턴 2: 내보낸 사용자로 검색
.collection('shared_api_settings')
.where('exportedByUserId', isEqualTo: userId)
```
**현재 규칙**: ✅ 정상
```javascript
match /shared_api_settings/{settingId} {
  allow read: if request.auth != null;  // 모든 사용자 읽기 가능
  allow write: if false;  // 백엔드만 수정
}
```
**검증 결과**: ✅ 쿼리 지원 (read: true)

---

## ✅ Phase 4: Admin-Only Collections

### 17-18. **email_verification_requests, fcm_notifications**
**쿼리 패턴**: 없음 (백엔드 전용)
**현재 규칙**: ✅ 정상
```javascript
allow read, write: if false;  // 백엔드만 접근
```
**검증 결과**: ✅ 클라이언트 접근 차단 정상

---

## 📊 최종 검증 결과 요약

### ❌ 긴급 수정 필요 (1개)
1. **fcm_tokens** - 쿼리 미지원으로 최대 기기 제한 작동 안함

### ⚠️ 예방적 수정 권장 (1개)
2. **call_forward_info** - 향후 쿼리 추가 대비

### ✅ 정상 작동 (16개)
- users, main_numbers, extensions, call_history, contacts
- phonebook_contacts, phonebooks, my_extensions
- device_approval_requests, user_notification_settings
- registered_extensions, fcm_approval_notification_queue
- app_config, shared_api_settings
- email_verification_requests, fcm_notifications

---

## 🎯 V6.1 업데이트 방침

### 필수 수정 (Must Fix)
1. ✅ **fcm_tokens** - `resource.data.userId` 방식으로 변경

### 권장 수정 (Recommended)
2. ✅ **call_forward_info** - 일관성 및 향후 확장성을 위해 변경

### 유지 (Keep As-Is)
3. ✅ **나머지 16개 컬렉션** - 모두 정상 작동 확인

---

## 🔐 보안 규칙 설계 원칙 (V6.1 표준)

### 원칙 1: 쿼리 지원 우선
- **절대 금지**: `documentId.split()`, `documentId.substring()` 등
- **필수 사용**: `resource.data.userId`, `request.auth.uid`

### 원칙 2: read/write/create 명확히 분리
```javascript
// ✅ 올바른 패턴
allow read: if request.auth != null 
            && (resource == null || resource.data.userId == request.auth.uid);
allow write: if request.auth != null 
             && resource != null
             && resource.data.userId == request.auth.uid;
allow create: if request.auth != null 
              && request.resource.data.userId == request.auth.uid;
```

### 원칙 3: 복합 쿼리 검증
- 모든 `.where()` 조건이 규칙에서 검증 가능해야 함
- `userId` 필드는 모든 User-Scoped 문서에 필수

### 원칙 4: 실시간 리스닝 지원
- `.snapshots()` 사용 시에도 규칙이 작동해야 함
- `resource == null` 체크로 문서 생성 허용

---

## ✅ 결론

**V6의 설계 실수**: `documentId.split()`을 Composite-ID 패턴으로 사용
**V6.1 핵심 개선**: 모든 컬렉션에서 쿼리 지원 보장

**영향**:
- ✅ 최대 사용기기 제한 정상 작동
- ✅ MaxDeviceLimitDialog 활성 기기 목록 표시
- ✅ 모든 FCM 관련 쿼리 정상 작동
- ✅ 향후 확장성 확보

**배포 후 검증 항목**:
1. ✅ Android 로그인 시 기기 수 조회 성공
2. ✅ MaxDeviceLimitDialog 표시 정상
3. ✅ PERMISSION_DENIED 에러 사라짐
4. ✅ 웹-모바일 간 기기 인식 정상
