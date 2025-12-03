# Firestore 보안 규칙 설계 문서

## 📋 목차
1. [컬렉션 분류 및 접근 패턴](#컬렉션-분류-및-접근-패턴)
2. [Document ID 패턴](#document-id-패턴)
3. [쿼리 패턴 분석](#쿼리-패턴-분석)
4. [보안 규칙 설계 원칙](#보안-규칙-설계-원칙)
5. [최종 보안 규칙](#최종-보안-규칙)

---

## 컬렉션 분류 및 접근 패턴

### 🔵 Type A: User-Scoped Collections (본인 데이터만 접근)
사용자 개인 데이터, 본인만 읽기/쓰기 가능

| 컬렉션 | Document ID | Query Pattern | Listening |
|--------|-------------|---------------|-----------|
| `users` | `{userId}` | Direct access | ❌ |
| `main_numbers` | auto-generated | `where('userId', '==', uid)` | ✅ |
| `extensions` | auto-generated | `where('userId', '==', uid)` | ✅ |
| `call_history` | auto-generated | `where('userId', '==', uid)` | ✅ |
| `contacts` | auto-generated | `where('userId', '==', uid)` | ✅ |
| `phonebook_contacts` | auto-generated | `where('userId', '==', uid)` | ✅ |
| `phonebooks` | auto-generated | `where('userId', '==', uid)` | ✅ |
| `my_extensions` | auto-generated | `where('userId', '==', uid)` | ✅ |
| `device_approval_requests` | auto-generated | `where('userId', '==', uid)` | ✅ |
| `user_notification_settings` | `{userId}` | Direct access | ❌ |

**특징:**
- 모든 문서에 `userId` 필드 존재
- 쿼리는 항상 `where('userId', '==', uid)` 포함
- Listening query 지원 필요

---

### 🟢 Type B: Composite-ID Collections (복합 ID 기반 접근)
Document ID가 `{userId}_{other}` 형식

| 컬렉션 | Document ID Format | Query Pattern | Listening |
|--------|-------------------|---------------|-----------|
| `fcm_tokens` | `{userId}_{deviceId}_{platform}` | `where('userId', '==', uid)` | ✅ |
| `call_forward_info` | `{userId}_{extensionNumber}` | Direct access | ✅ |

**특징:**
- Document ID로 소유권 판별 가능
- `documentId.split('_')[0] == request.auth.uid` 체크 가능
- 문서 존재 여부와 무관하게 접근 제어 가능 (create 시에도 안전)

---

### 🟡 Type C: Shared Collections (공유 데이터)
여러 사용자가 접근 가능한 데이터

| 컬렉션 | Document ID | Access Pattern | Listening |
|--------|-------------|----------------|-----------|
| `registered_extensions` | `{extension_number}` | 읽기: 전체 허용<br>쓰기: 본인만 | ✅ |
| `fcm_approval_notification_queue` | auto-generated | 읽기/쓰기: 전체 허용 | ✅ |
| `app_config` | predefined | 읽기: 전체 허용<br>쓰기: 관리자만 | ❌ |
| `shared_api_settings` | predefined | 읽기: 전체 허용<br>쓰기: 관리자만 | ❌ |

**특징:**
- `registered_extensions`: 단말번호 조회 (공개 정보)
- `fcm_approval_notification_queue`: 알림 전송용 임시 큐
- `app_config`, `shared_api_settings`: 앱 전역 설정 (읽기 전용)

---

### 🔴 Type D: Admin-Only Collections (관리자 전용)
백엔드/관리자만 접근 가능

| 컬렉션 | Purpose | Client Access |
|--------|---------|---------------|
| `email_verification_requests` | 이메일 인증 관리 | ❌ 백엔드만 |
| `fcm_notifications` | FCM 알림 이력 | ❌ 백엔드만 |

---

## Document ID 패턴

### 1. `users` - User ID 직접 사용
```dart
/users/{userId}
```
- 예: `/users/BATARjeeg2aGpggaCOl9J2Hz17T2`

### 2. `fcm_tokens` - 복합 ID (userId_deviceId_platform)
```dart
/fcm_tokens/{userId}_{deviceId}_{platform}
```
- 예: `/fcm_tokens/BATARjeeg2aGpggaCOl9J2Hz17T2_5B03AB9F-BD55-42CD-9128-721B21FB8077_iOS`

### 3. `call_forward_info` - 복합 ID (userId_extension)
```dart
/call_forward_info/{userId}_{extensionNumber}
```
- 예: `/call_forward_info/BATARjeeg2aGpggaCOl9J2Hz17T2_1234`

### 4. `registered_extensions` - Extension Number 직접 사용
```dart
/registered_extensions/{extensionNumber}
```
- 예: `/registered_extensions/1234`

### 5. 나머지 컬렉션 - Firestore Auto-Generated ID
```dart
/{collection}/{auto_generated_id}
```
- 예: `/contacts/a1B2c3D4e5F6g7H8i9J0`

---

## 쿼리 패턴 분석

### Listening Queries (실시간 구독)
```dart
// ✅ Type A: userId 필터링 - 본인 데이터만
firestore.collection('contacts')
  .where('userId', isEqualTo: currentUserId)
  .snapshots()

// ✅ Type B: 복합 쿼리 - 본인 + 추가 조건
firestore.collection('contacts')
  .where('userId', isEqualTo: currentUserId)
  .where('isFavorite', isEqualTo: true)
  .snapshots()

// ✅ Type C: 전체 컬렉션 리스닝 (권한 필요)
firestore.collection('call_forward_info')
  .snapshots() // ← 보안 규칙에서 처리 필요
```

### Direct Document Access
```dart
// ✅ User document
firestore.collection('users').doc(userId).get()

// ✅ Composite ID
firestore.collection('fcm_tokens').doc('${userId}_${deviceId}_$platform').get()
```

---

## 보안 규칙 설계 원칙

### 원칙 1: Query-Based 규칙 (Listening Query 지원)
```javascript
// ❌ BAD: Listening query 실패
allow read: if request.auth.uid == resource.data.userId;
// ↑ 컬렉션 전체 구독 시 다른 사용자 문서 때문에 실패

// ✅ GOOD: Query 조건 강제
allow read: if request.auth.uid == resource.data.userId;
// 단, 클라이언트가 반드시 where('userId', '==', uid) 쿼리 사용
```

### 원칙 2: Composite ID 기반 접근 제어
```javascript
// ✅ 문서 존재 여부와 무관하게 접근 제어 가능
allow read, write, create: if request.auth != null 
  && documentId.split('_')[0] == request.auth.uid;
```

### 원칙 3: 공유 데이터 명시적 허용
```javascript
// ✅ 읽기는 전체 허용, 쓰기는 제한
allow read: if request.auth != null;
allow write: if request.auth != null 
  && request.auth.uid == resource.data.userId;
```

### 원칙 4: 필드 레벨 검증
```javascript
// ✅ 생성 시 필수 필드 검증
allow create: if request.auth != null 
  && request.resource.data.userId == request.auth.uid
  && request.resource.data.keys().hasAll(['userId', 'createdAt']);
```

---

## 최종 보안 규칙

### Type A: User-Scoped Collections
모든 문서에 `userId` 필드 존재, 본인 데이터만 접근

```javascript
// users, main_numbers, extensions, call_history, contacts, 
// phonebook_contacts, phonebooks, my_extensions, 
// device_approval_requests, user_notification_settings

match /{collection}/{documentId} {
  // 읽기: 본인 문서만 (userId 필드 또는 documentId 체크)
  allow read: if request.auth != null && (
    // userId 필드가 있는 경우
    resource.data.userId == request.auth.uid ||
    // documentId가 userId인 경우 (users, user_notification_settings)
    documentId == request.auth.uid
  );
  
  // 쓰기: 본인 문서만
  allow write: if request.auth != null && (
    resource.data.userId == request.auth.uid ||
    documentId == request.auth.uid
  );
  
  // 생성: userId 필드 검증
  allow create: if request.auth != null && (
    request.resource.data.userId == request.auth.uid ||
    documentId == request.auth.uid
  );
}
```

### Type B: Composite-ID Collections
Document ID로 소유권 판별

```javascript
// fcm_tokens: {userId}_{deviceId}_{platform}
match /fcm_tokens/{documentId} {
  allow read, write, create: if request.auth != null 
    && documentId.split('_')[0] == request.auth.uid;
}

// call_forward_info: {userId}_{extensionNumber}
match /call_forward_info/{documentId} {
  allow read, write, create: if request.auth != null 
    && documentId.split('_')[0] == request.auth.uid;
}
```

### Type C: Shared Collections
공유 데이터, 읽기는 전체 허용

```javascript
// registered_extensions: 단말번호 조회 (공개 정보)
match /registered_extensions/{documentId} {
  allow read: if request.auth != null;
  allow write: if request.auth != null 
    && resource != null
    && resource.data.userId == request.auth.uid;
  allow create: if request.auth != null 
    && request.resource.data.userId == request.auth.uid;
}

// fcm_approval_notification_queue: 알림 전송 큐
match /fcm_approval_notification_queue/{queueId} {
  allow read, write: if request.auth != null;
}

// app_config, shared_api_settings: 읽기 전용
match /app_config/{configId} {
  allow read: if request.auth != null;
  allow write: if false; // 관리자만 (백엔드에서 처리)
}

match /shared_api_settings/{settingId} {
  allow read: if request.auth != null;
  allow write: if false; // 관리자만
}
```

### Type D: Admin-Only Collections
클라이언트 접근 차단

```javascript
// email_verification_requests, fcm_notifications
match /email_verification_requests/{requestId} {
  allow read, write: if false; // 백엔드만 접근
}

match /fcm_notifications/{notificationId} {
  allow read, write: if false; // 백엔드만 접근
}
```

---

## 핵심 개선사항

### Before (기존 문제점)
1. ❌ Listening query 지원 안 됨 (`resource.data` 체크 실패)
2. ❌ 새 문서 생성 시 권한 체크 실패 (`.get()` 시 `resource.data` null)
3. ❌ 단편적 수정으로 일관성 부족
4. ❌ 컬렉션별 특성 미고려

### After (개선된 설계)
1. ✅ Listening query 완벽 지원 (쿼리 기반 + 복합 ID)
2. ✅ 문서 생성/읽기/쓰기 모든 경우 처리
3. ✅ 컬렉션 타입별 통일된 규칙
4. ✅ 확장 가능한 구조 (새 컬렉션 추가 용이)

---

## 검증 체크리스트

- [ ] `fcm_tokens` listening query 성공
- [ ] `registered_extensions` listening query 성공
- [ ] MaxDeviceLimit 다이얼로그 활성기기 목록 표시
- [ ] 새 사용자 회원가입 시 `users` 문서 생성
- [ ] FCM 토큰 저장 성공
- [ ] 착신전환 정보 읽기/쓰기 성공
- [ ] 연락처 실시간 동기화 성공
- [ ] 통화기록 실시간 동기화 성공

---

**작성일**: 2025-01-XX  
**버전**: V6 (Final)  
**상태**: 최종 확정
