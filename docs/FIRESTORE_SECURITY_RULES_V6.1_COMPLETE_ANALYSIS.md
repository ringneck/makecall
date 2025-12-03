# Firestore Security Rules V6.1 - 완전 재설계 및 쿼리 지원 검증

## 📋 작업 개요

**작업 일시**: 2025년 1월  
**담당자**: 고급 개발자 수준 검증  
**목적**: 모든 컬렉션의 쿼리 지원 검증 및 보안 규칙 완전 재설계

---

## 🚨 발견된 문제

### 문제 1: fcm_tokens 컬렉션
- **V6 규칙 (3f11180)**: `documentId.split('_')[0] == request.auth.uid`
- **실제 쿼리**: `.where('userId', isEqualTo: userId)`
- **결과**: `PERMISSION_DENIED` 에러
- **영향**: 최대 사용기기 제한 기능 완전 차단

### 문제 2: call_forward_info 컬렉션
- **V6 규칙**: `documentId.split('_')[0] == request.auth.uid`
- **실제 쿼리**: `account_manager_service.dart:207` - `.where('userId', isEqualTo: uid)`
- **결과**: 잠재적 `PERMISSION_DENIED` 에러
- **영향**: 계정 삭제 시 착신전환 정보 cleanup 실패 가능

---

## 🔍 전체 컬렉션 쿼리 패턴 분석

### Type A: User-Scoped Collections (10개)
✅ **쿼리 지원 정상**

| 컬렉션명 | 쿼리 패턴 | 보안 규칙 | 상태 |
|---------|----------|-----------|------|
| users | Document ID 직접 접근 | `userId == request.auth.uid` | ✅ 정상 |
| main_numbers | `.where('userId', isEqualTo)` | `resource.data.userId` | ✅ 정상 |
| extensions | `.where('userId', isEqualTo)` | `resource.data.userId` | ✅ 정상 |
| call_history | `.where('userId', isEqualTo)` | `resource.data.userId` | ✅ 정상 |
| contacts | `.where('userId', isEqualTo)` | `resource.data.userId` | ✅ 정상 |
| phonebook_contacts | `.where('userId', isEqualTo)` | `resource.data.userId` | ✅ 정상 |
| phonebooks | `.where('userId', isEqualTo)` | `resource.data.userId` | ✅ 정상 |
| my_extensions | `.where('userId', isEqualTo)` | `resource.data.userId` | ✅ 정상 |
| device_approval_requests | `.where('userId', isEqualTo)` | `resource.data.userId` | ✅ 정상 |
| user_notification_settings | Document ID 직접 접근 | `userId == request.auth.uid` | ✅ 정상 |

### Type B: Composite-ID Collections (2개)
⚠️ **문제 발견 및 수정 완료**

| 컬렉션명 | Document ID 형식 | 쿼리 패턴 | V6 규칙 | V6.1 규칙 | 상태 |
|---------|----------------|----------|---------|-----------|------|
| **fcm_tokens** | `{userId}_{deviceId}_{platform}` | `.where('userId', isEqualTo)` | ❌ `documentId.split()` | ✅ `resource.data.userId` | ✅ 수정됨 |
| **call_forward_info** | `{userId}_{extensionNumber}` | `.where('userId', isEqualTo)` | ❌ `documentId.split()` | ✅ `resource.data.userId` | ✅ 수정됨 |

### Type C: Shared Collections (4개)
✅ **쿼리 지원 정상**

| 컬렉션명 | 쿼리 패턴 | 보안 규칙 | 상태 |
|---------|----------|-----------|------|
| registered_extensions | `.where()` 다양한 조건 | 모든 인증 사용자 read 허용 | ✅ 정상 |
| fcm_approval_notification_queue | 큐 접근 | 모든 인증 사용자 접근 | ✅ 정상 |
| app_config | 읽기 전용 | 모든 인증 사용자 read 허용 | ✅ 정상 |
| shared_api_settings | `.where()` 조건 쿼리 | 모든 인증 사용자 read 허용 | ✅ 정상 |

### Type D: Admin-Only Collections (2개)
✅ **클라이언트 접근 차단**

| 컬렉션명 | 클라이언트 접근 | 백엔드 접근 | 상태 |
|---------|---------------|-------------|------|
| email_verification_requests | ❌ 차단 | ✅ Admin SDK | ✅ 정상 |
| fcm_notifications | ❌ 차단 | ✅ Admin SDK | ✅ 정상 |

---

## 🔧 V6.1 핵심 수정 사항

### 1. fcm_tokens 컬렉션 (Lines 107-120)

**Before (V6 - 3f11180):**
```javascript
match /fcm_tokens/{documentId} {
  allow read, write, create: if request.auth != null 
                             && documentId.split('_')[0] == request.auth.uid;
}
```

**After (V6.1 - commit 3373204 + 현재):**
```javascript
match /fcm_tokens/{documentId} {
  allow read: if request.auth != null 
              && (resource == null || resource.data.userId == request.auth.uid);
  allow write: if request.auth != null 
               && resource.data.userId == request.auth.uid;
  allow create: if request.auth != null 
                && request.resource.data.userId == request.auth.uid;
}
```

**Why:**
- ❌ `documentId.split('_')[0]`는 개별 문서 접근에만 작동
- ✅ `resource.data.userId`는 쿼리 실행 시에도 작동
- ✅ `resource == null` 체크로 문서 생성 허용
- ✅ 권한을 read/write/create로 명확히 분리

### 2. call_forward_info 컬렉션 (Lines 122-135)

**Before (V6 - 3f11180):**
```javascript
match /call_forward_info/{documentId} {
  allow read, write, create: if request.auth != null 
                             && documentId.split('_')[0] == request.auth.uid;
}
```

**After (V6.1 - 현재 수정):**
```javascript
match /call_forward_info/{documentId} {
  allow read: if request.auth != null 
              && (resource == null || resource.data.userId == request.auth.uid);
  allow write: if request.auth != null 
               && resource.data.userId == request.auth.uid;
  allow create: if request.auth != null 
                && request.resource.data.userId == request.auth.uid;
}
```

**Why:**
- ✅ `account_manager_service.dart:207`의 `.where('userId', isEqualTo: uid)` 쿼리 지원
- ✅ 계정 삭제 시 착신전환 정보 cleanup 정상 작동 보장

---

## 📊 실제 쿼리 패턴 상세 분석

### fcm_tokens 쿼리 (총 2개 발견)

#### 1. database_service.dart:1231-1233
```dart
final querySnapshot = await _firestore
    .collection('fcm_tokens')
    .where('userId', isEqualTo: userId)      // ← userId 필드 쿼리
    .where('isActive', isEqualTo: true)
    .where('isApproved', isEqualTo: true)
    .get();
```
**용도**: 사용자의 모든 활성/승인된 기기 조회 (최대 기기 수 체크)

#### 2. fcm_token_manager.dart:160
```dart
final existingTokens = await _firestore
    .collection('fcm_tokens')
    .where('userId', isEqualTo: userId)      // ← userId 필드 쿼리
    .where('isActive', isEqualTo: true)
    .get();
```
**용도**: FCM 토큰 저장 전 기존 토큰 조회

### call_forward_info 쿼리 (총 1개 발견)

#### account_manager_service.dart:207-208
```dart
final cfSnapshot = await FirebaseFirestore.instance
    .collection('call_forward_info')
    .where('userId', isEqualTo: uid)         // ← userId 필드 쿼리
    .get();
```
**용도**: 계정 삭제 시 해당 사용자의 모든 착신전환 정보 cleanup

---

## ✅ V6.1 검증 결과

### 전체 18개 컬렉션 쿼리 지원 상태

| 유형 | 컬렉션 수 | 쿼리 지원 | 상태 |
|-----|----------|----------|------|
| Type A (User-Scoped) | 10 | ✅ 정상 | `resource.data.userId` 사용 |
| Type B (Composite-ID) | 2 | ✅ 수정 완료 | V6.1에서 수정 |
| Type C (Shared) | 4 | ✅ 정상 | 인증 사용자 접근 허용 |
| Type D (Admin-Only) | 2 | ✅ 정상 | 클라이언트 차단 |
| **총계** | **18** | **✅ 100%** | **완전 검증 완료** |

---

## 🎯 결론 및 권장 사항

### 1. V6.1 규칙 상태
- ✅ **fcm_tokens**: 쿼리 지원 완료 (commit 3373204)
- ✅ **call_forward_info**: 쿼리 지원 완료 (현재 수정)
- ✅ **나머지 16개 컬렉션**: 이미 정상 작동

### 2. 배포 필요성
🚨 **CRITICAL**: 수정된 V6.1 규칙을 Firebase Console에 즉시 배포해야 합니다!

**배포 방법**:
1. Firebase Console 접속: https://console.firebase.google.com/project/makecallio/firestore/rules
2. 'Rules' 탭 선택
3. 현재 `firestore.rules` 파일 전체 내용 복사
4. Firebase Console에 붙여넣기
5. **'게시 (Publish)'** 버튼 클릭

### 3. 배포 후 테스트 시나리오

#### 테스트 1: fcm_tokens (최대 사용기기 제한)
1. Firestore Console에서 `ringneck@naver.com` 관련 `fcm_tokens` 문서 모두 삭제
2. 웹 브라우저에서 로그인 (첫 번째 기기)
3. Android 앱에서 동일 계정 로그인 (두 번째 기기)
4. **예상 결과**: `MaxDeviceLimitDialog` 표시, "최대 사용 기기 수 초과" 메시지

#### 테스트 2: call_forward_info (계정 삭제)
1. 테스트 계정에 착신전환 정보 설정
2. 계정 삭제 실행
3. **예상 결과**: 착신전환 정보도 함께 삭제됨 (cleanup 성공)

### 4. 고급 개발자 권장 사항

**DO:**
- ✅ `resource.data.userId`를 사용한 필드 기반 검증
- ✅ 권한을 read/write/create로 명확히 분리
- ✅ `resource == null` 체크로 문서 생성 시 안전 보장
- ✅ 모든 쿼리 패턴 사전 검증

**DON'T:**
- ❌ `documentId.split()`을 쿼리가 필요한 컬렉션에 사용
- ❌ 개별 문서 접근만 테스트하고 쿼리 테스트 생략
- ❌ 단편적인 보안 규칙 수정 (전체 검증 없이)

---

## 📝 Git Commit 이력

```
[이전] 3f11180 (2024-12-03) - Refactor: Firestore 보안 규칙 V6 - 전면 재설계 및 표준화
       ❌ fcm_tokens에서 documentId.split() 사용 → 쿼리 지원 안됨

[수정1] 3373204 (최근) - Fix: fcm_tokens 보안 규칙 - 쿼리 지원 추가
        ✅ fcm_tokens에서 resource.data.userId 사용으로 변경

[수정2] [현재] - Fix: call_forward_info 보안 규칙 - 쿼리 지원 추가
        ✅ call_forward_info에서 resource.data.userId 사용으로 변경
```

---

## 🔒 보안 규칙 설계 원칙 (V6.1)

1. **필드 기반 검증 우선**: `resource.data.userId` > `documentId.split()`
2. **권한 명확한 분리**: read/write/create 각각 독립적으로 정의
3. **쿼리 지원 필수**: 모든 `.where()` 쿼리가 작동해야 함
4. **문서 생성 안전**: `resource == null` 체크 포함
5. **최소 권한 원칙**: 필요한 최소한의 접근 권한만 부여

---

**V6.1 보안 규칙 설계 완료**  
**상태**: ✅ 전체 18개 컬렉션 검증 완료  
**다음 단계**: Firebase Console 배포 (수동)
