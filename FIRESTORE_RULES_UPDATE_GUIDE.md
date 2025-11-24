# Firestore 보안 규칙 업데이트 가이드

## 🚨 문제 상황
iOS 애플 로그인 시 다음 에러 발생:
```
[cloud_firestore/permission-denied] The caller does not have permission to execute the specified operation.
```

**원인**: Firestore 보안 규칙이 신규 사용자 문서 생성(`create`)을 허용하지 않음

---

## ✅ 해결 방법: Firebase Console에서 보안 규칙 수동 업데이트

### 1️⃣ Firebase Console 접속
1. **Firebase Console** 접속: https://console.firebase.google.com/
2. **프로젝트 선택**: `makecallio`
3. **좌측 메뉴**: Build → **Firestore Database**
4. **상단 탭**: **규칙 (Rules)** 클릭

---

### 2️⃣ 기존 규칙 찾기
기존 `users` 컬렉션 규칙 (6-12번 라인):
```javascript
// ============================================
// 사용자 문서
// ============================================
match /users/{userId} {
  // 로그인한 사용자만 자신의 문서 읽기/쓰기 가능
  allow read: if request.auth != null && request.auth.uid == userId;
  allow write: if request.auth != null && request.auth.uid == userId;
}
```

---

### 3️⃣ 새로운 규칙으로 교체
다음 규칙으로 **완전히 교체**:
```javascript
// ============================================
// 사용자 문서
// ============================================
match /users/{userId} {
  // 로그인한 사용자만 자신의 문서 읽기 가능
  allow read: if request.auth != null && request.auth.uid == userId;
  
  // 신규 사용자 문서 생성 허용 (소셜 로그인 자동 등록)
  allow create: if request.auth != null && 
                   request.auth.uid == userId &&
                   request.resource.data.uid == userId;
  
  // 기존 사용자 문서 업데이트 허용
  allow update: if request.auth != null && 
                   request.auth.uid == userId &&
                   resource.data.uid == userId;
  
  // 삭제는 불가
  allow delete: if false;
}
```

---

### 4️⃣ 규칙 게시 (Deploy)
1. **게시 (Publish)** 버튼 클릭
2. 배포 완료 확인
3. 약 1-2분 후 새 규칙 적용

---

## 📋 주요 변경 사항

### Before (기존 규칙):
```javascript
allow write: if request.auth != null && request.auth.uid == userId;
```
- **문제점**: `write` 권한이 모호하여 신규 문서 생성(`create`) 시 실패

### After (수정된 규칙):
```javascript
// 신규 문서 생성
allow create: if request.auth != null && 
                 request.auth.uid == userId &&
                 request.resource.data.uid == userId;

// 기존 문서 업데이트
allow update: if request.auth != null && 
                 request.auth.uid == userId &&
                 resource.data.uid == userId;
```
- **개선점**: `create`와 `update` 권한 명시적 분리
- **보안 강화**: `uid` 필드 일치 검증 추가

---

## 🔐 보안 규칙 설명

### 1. Read 권한
```javascript
allow read: if request.auth != null && request.auth.uid == userId;
```
- 로그인한 사용자만 **자신의 문서** 읽기 가능
- 다른 사용자의 문서는 읽기 불가

### 2. Create 권한 (신규 추가)
```javascript
allow create: if request.auth != null && 
                 request.auth.uid == userId &&
                 request.resource.data.uid == userId;
```
- 로그인한 사용자가 **자신의 UID로** 문서 생성 가능
- `request.resource.data.uid` 검증으로 다른 사용자 문서 생성 방지
- **소셜 로그인 자동 등록**에 필수

### 3. Update 권한
```javascript
allow update: if request.auth != null && 
                 request.auth.uid == userId &&
                 resource.data.uid == userId;
```
- 로그인한 사용자만 **자신의 문서** 업데이트 가능
- `resource.data.uid` 검증으로 기존 문서 소유자 확인

### 4. Delete 권한 (차단)
```javascript
allow delete: if false;
```
- 모든 사용자 문서 삭제 차단
- 관리자만 Firebase Admin SDK로 삭제 가능

---

## 🧪 테스트 방법

### 1. iOS 기기에서 애플 로그인 테스트
```
1. 앱 실행
2. 애플 로그인 버튼 클릭
3. Apple ID 인증
4. 로그인 성공 확인
```

### 2. Firestore 문서 생성 확인
Firebase Console에서 확인:
1. Firestore Database → Data 탭
2. `users` 컬렉션 확인
3. 새로운 사용자 문서 생성 여부 확인 (UID: `apple_xxx...`)

### 3. 예상 로그 출력
```
✅ [Apple] 로그인 성공
🔄 [PROFILE UPDATE] Firestore 사용자 정보 업데이트 시작
🆕 [PROFILE UPDATE] 신규 사용자 문서 생성
✅ [PROFILE UPDATE] 신규 사용자 문서 생성 완료
✅ [SOCIAL LOGIN] AuthService userModel 재로드 완료
✅ 홈 화면으로 이동
```

---

## ⚠️ 중요 사항

### 1. 규칙 배포 시간
- Firebase Console에서 게시 후 **1-2분** 소요
- 즉시 반영되지 않을 수 있으니 잠시 대기 후 테스트

### 2. 보안 규칙 백업
기존 규칙을 복사해두거나 Firebase Console의 버전 관리 기능 활용

### 3. 다른 컬렉션 규칙
- `users` 컬렉션 외 다른 규칙은 변경하지 마세요
- 기존 규칙이 정상 작동하므로 유지

---

## 🔗 참고 링크

- **Firebase Console**: https://console.firebase.google.com/project/makecallio/firestore
- **Firestore 보안 규칙 문서**: https://firebase.google.com/docs/firestore/security/rules-conditions
- **보안 규칙 테스트**: Firebase Console → Rules → Rules Playground

---

## 📞 문제 발생 시

규칙 업데이트 후에도 문제가 계속되면:
1. Firebase Console에서 규칙이 올바르게 배포되었는지 확인
2. 앱을 완전히 종료한 후 재시작
3. Firebase Authentication 콘솔에서 사용자 UID 확인
4. Firestore 규칙 시뮬레이터로 테스트

---

이 가이드를 따라 Firestore 보안 규칙을 업데이트하면 iOS 애플 로그인이 정상 작동합니다! 🎉
