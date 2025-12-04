# 🔥 Firebase Console 배포 가이드 - Firestore Rules V6.2

## 📋 배포 정보

- **버전**: Firestore Security Rules V6.2 (최종)
- **날짜**: 2025-12-04
- **Git Commit**: ff83437
- **우선순위**: 🚨 **즉시 배포 필요**

---

## 🎯 배포해야 하는 이유

### 현재 문제
```
⚠️ device_approval_requests 쿼리 리슨 중 에러:
[cloud_firestore/permission-denied] Missing or insufficient permissions.
```

### 영향
- ❌ iOS 기기 로그인 시 승인 대기 화면이 제대로 표시되지 않음
- ❌ 새 기기가 승인 요청 상태를 실시간으로 모니터링 불가
- ❌ 사용자가 로그인 화면으로 돌아가버림

### 해결
- ✅ V6.2 규칙 배포 시 즉시 해결
- ✅ iOS 기기 승인 플로우 정상 작동

---

## 📝 배포 단계별 가이드

### Step 1: Firebase Console 접속

**URL**: https://console.firebase.google.com/

1. Google 계정 로그인
2. **MAKECALL** 프로젝트 선택

---

### Step 2: Firestore 규칙 메뉴 이동

1. 왼쪽 메뉴에서 **"Firestore Database"** 클릭
2. 상단 탭에서 **"규칙 (Rules)"** 클릭

---

### Step 3: 현재 규칙 백업 (선택사항)

배포 전 현재 규칙을 복사해두는 것을 권장합니다.

**방법**:
1. 현재 규칙 에디터의 전체 내용 복사
2. 로컬 텍스트 파일로 저장 (예: `firestore-rules-backup-2025-12-04.txt`)

---

### Step 4: 새 규칙 배포

#### 방법 A: 전체 파일 교체 (권장)

1. **로컬 파일 열기**:
   ```
   /home/user/flutter_app/firestore.rules
   ```

2. **전체 내용 복사**:
   - 파일의 처음부터 끝까지 모든 내용 복사

3. **Firebase Console에 붙여넣기**:
   - 규칙 에디터의 기존 내용 전체 삭제
   - 복사한 내용 붙여넣기

#### 방법 B: 수정 부분만 변경 (빠른 방법)

**수정 위치**: Line 86-96 (device_approval_requests 섹션)

**찾을 내용**:
```javascript
// 9. device_approval_requests - 기기 승인 요청
match /device_approval_requests/{documentId} {
  allow read: if request.auth != null 
              && resource.data.userId == request.auth.uid;
```

**변경할 내용**:
```javascript
// 9. device_approval_requests - 기기 승인 요청
// 🔑 CRITICAL: .doc().snapshots() 리스너 지원을 위해 resource null 체크 필요
// fcm_device_approval_service.dart:312에서 .doc(approvalRequestId).snapshots() 사용
// 첫 리스닝 시 문서가 아직 생성되지 않아 resource == null 상황 발생
match /device_approval_requests/{documentId} {
  allow read: if request.auth != null 
              && (resource == null || resource.data.userId == request.auth.uid);
```

**핵심 변경**:
```javascript
// ❌ Before
allow read: if request.auth != null 
            && resource.data.userId == request.auth.uid;

// ✅ After
allow read: if request.auth != null 
            && (resource == null || resource.data.userId == request.auth.uid);
```

---

### Step 5: 규칙 검증

배포 전 Firebase Console이 자동으로 구문 검증을 수행합니다.

**확인 사항**:
- ✅ 빨간색 에러 표시 없음
- ✅ "규칙이 유효합니다" 메시지 확인
- ✅ 구문 하이라이팅 정상

**에러 발생 시**:
- 복사/붙여넣기 과정에서 문자가 누락되었을 가능성
- 전체 파일 교체(방법 A)를 다시 시도

---

### Step 6: 게시 (Publish)

1. 우측 상단의 **"게시 (Publish)"** 버튼 클릭
2. 확인 다이얼로그에서 **"게시"** 확인
3. "규칙이 게시되었습니다" 메시지 확인

**⏱️ 적용 시간**: 즉시 (몇 초 이내)

---

## ✅ 배포 후 검증

### 자동 검증
Firebase Console에서 자동으로 다음을 확인합니다:
- ✅ 구문 오류 없음
- ✅ 규칙 충돌 없음
- ✅ 배포 성공

### 수동 검증 (iOS 테스트)

#### 테스트 시나리오 1: 기기 승인 플로우

**준비**:
1. Web에서 `ringneck@naver.com` 로그인 (기존 활성 기기)

**테스트**:
2. iOS (iPhone 15 Pro)에서 `ringneck@naver.com` 로그인 시도

**예상 결과**:
```
✅ "기기 승인 대기" 화면 표시
✅ 실시간 승인 상태 모니터링 작동
✅ Web에서 승인 요청 알림 수신
✅ Web에서 승인 후 iOS 자동 로그인
```

**실패 시 예상되는 로그**:
```
❌ ⚠️ device_approval_requests 쿼리 리슨 중 에러:
    [cloud_firestore/permission-denied]
```

#### 테스트 시나리오 2: 로그 확인

**iOS 디버그 콘솔에서 확인**:
```
✅ 📱 새 기기 승인 필요
✅ ⏳ 기기 승인 대기 화면 표시
✅ 🔔 기존 기기로 승인 요청 알림 전송

❌ 더 이상 나타나지 않아야 할 로그:
   ⚠️ device_approval_requests 쿼리 리슨 중 에러
```

---

## 🔧 트러블슈팅

### 문제 1: 게시 버튼이 비활성화됨

**원인**: 구문 오류 또는 변경 사항 없음

**해결**:
- 빨간색 에러 메시지 확인 및 수정
- 실제로 내용이 변경되었는지 확인

---

### 문제 2: 배포 후에도 permission-denied 에러 발생

**원인**: 캐시 또는 적용 지연

**해결**:
1. Firebase Console에서 규칙 다시 확인
   - `device_approval_requests` 섹션에 `(resource == null || ...)` 포함 여부
2. 30초 대기 후 재시도
3. iOS 앱 완전 종료 후 재시작

---

### 문제 3: 다른 컬렉션에서 권한 오류 발생

**원인**: 복사/붙여넣기 과정에서 내용 손상

**해결**:
1. Firebase Console에서 현재 규칙 전체 삭제
2. 로컬 `firestore.rules` 파일 전체 복사
3. 다시 붙여넣기 및 게시

---

## 📊 배포 완료 확인

### 체크리스트

- [ ] Firebase Console 접속 완료
- [ ] Firestore Database → 규칙 메뉴 이동
- [ ] 기존 규칙 백업 (선택사항)
- [ ] V6.2 규칙 붙여넣기
- [ ] 구문 검증 통과
- [ ] 게시 버튼 클릭
- [ ] "규칙이 게시되었습니다" 확인
- [ ] iOS 테스트 완료
- [ ] permission-denied 에러 사라짐 확인

---

## 🎯 배포 후 기대 효과

### 해결되는 문제
1. ✅ iOS 기기 승인 대기 화면 정상 작동
2. ✅ 실시간 승인 상태 모니터링 가능
3. ✅ permission-denied 에러 완전 제거

### 영향받는 기능
- ✅ 기기 승인 플로우 (iOS, Android, Web)
- ✅ 다중 기기 관리
- ✅ 기기 제한 정책 (MaxDeviceLimit)

### 추가 수정 필요 여부
- ❌ **없음** - V6.2가 최종 버전

---

## 📞 배포 지원

### 배포 중 문제 발생 시

1. **구문 에러**:
   - 전체 파일 교체(방법 A) 재시도
   - 로컬 파일 무결성 확인

2. **권한 에러 지속**:
   - Firebase Console 규칙 재확인
   - 30초 대기 후 재시도
   - 앱 캐시 클리어

3. **기타 문제**:
   - Git Commit ff83437 확인
   - `firestore.rules` 파일 재다운로드

---

## 🔗 관련 문서

- **V6.2 최종 문서**: `docs/FIRESTORE_SECURITY_RULES_V6.2_FINAL.md`
- **Git Commit**: `ff83437`
- **GitHub**: https://github.com/ringneck/makecall

---

**배포 시작 시간**: _________________

**배포 완료 시간**: _________________

**배포 담당자**: _________________

**검증 완료 여부**: ☐ 완료 / ☐ 미완료
