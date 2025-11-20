# Firebase Functions 배포 가이드

## 변경 사항

### 1. Service Account 명시적 초기화
```javascript
// 이전
admin.initializeApp();

// 변경 후
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
});
```

### 2. 에러 로깅 개선
- PERMISSION_DENIED 에러 상세 정보 추가
- Service Account 정보 로깅
- 필요한 IAM 역할 출력

---

## 배포 방법

### 1. Functions 디렉토리로 이동
```bash
cd /home/user/flutter_app/functions
```

### 2. 종속성 설치 (선택)
```bash
npm install
```

### 3. Firebase Functions 배포
```bash
firebase deploy --only functions
```

또는 특정 Function만 배포:
```bash
# Kakao Function만
firebase deploy --only functions:createCustomTokenForKakao

# Naver Function만
firebase deploy --only functions:createCustomTokenForNaver
```

### 4. 배포 확인
Firebase Console에서 확인:
- https://console.firebase.google.com/project/makecallio/functions

배포된 Functions:
- ✅ `createCustomTokenForKakao`
- ✅ `createCustomTokenForNaver`

---

## 배포 후 테스트

### 1. Functions 로그 확인
```bash
firebase functions:log
```

또는 Firebase Console:
- https://console.firebase.google.com/project/makecallio/functions/logs

### 2. 앱에서 소셜 로그인 테스트
- Kakao 로그인 시도
- Naver 로그인 시도

### 3. 로그에서 확인할 내용
성공 시:
```
🔐 [KAKAO] Creating custom token for user: kakao_xxxxx
✅ [KAKAO] Custom token created successfully
```

PERMISSION_DENIED 오류 시:
```
❌ [KAKAO] Error creating custom token: Error: 7 PERMISSION_DENIED
🔐 [KAKAO] IAM Permission Issue Detected
   Required roles:
   - roles/iam.serviceAccountTokenCreator
   - roles/serviceusage.serviceUsageConsumer
```

---

## 문제 해결

### PERMISSION_DENIED 오류가 계속 발생하는 경우

#### 1. IAM 권한 다시 확인
```bash
gcloud projects get-iam-policy makecallio \
  --flatten="bindings[].members" \
  --filter="bindings.members:makecallio@appspot.gserviceaccount.com"
```

예상 출력에 다음 역할이 포함되어야 함:
- `roles/iam.serviceAccountTokenCreator`
- `roles/serviceusage.serviceUsageConsumer`

#### 2. Service Account 확인
Firebase Console에서:
1. 프로젝트 설정 → 서비스 계정
2. Firebase Admin SDK 탭
3. 서비스 계정 이메일 확인: `makecallio@appspot.gserviceaccount.com`

#### 3. Functions 완전 재배포
```bash
# 기존 Functions 삭제 후 재배포
firebase functions:delete createCustomTokenForKakao --force
firebase functions:delete createCustomTokenForNaver --force

# 재배포
firebase deploy --only functions
```

#### 4. 프로젝트 ID 확인
`.firebaserc` 파일 확인:
```bash
cat .firebaserc
```

예상 출력:
```json
{
  "projects": {
    "default": "makecallio"
  }
}
```

#### 5. Firebase CLI 재인증
```bash
firebase logout
firebase login
firebase use makecallio
```

---

## 추가 디버깅

### Functions 에뮬레이터로 로컬 테스트
```bash
cd functions
firebase emulators:start --only functions
```

### cURL로 직접 호출 테스트
```bash
# Kakao Token 생성 테스트
curl -X POST \
  https://asia-northeast3-makecallio.cloudfunctions.net/createCustomTokenForKakao \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "kakaoUid": "test_user_123",
      "email": "test@example.com",
      "displayName": "Test User",
      "photoUrl": "https://example.com/photo.jpg"
    }
  }'
```

---

## 참고 링크

- Firebase Console: https://console.firebase.google.com/project/makecallio
- GCP IAM: https://console.cloud.google.com/iam-admin/iam?project=makecallio
- Functions 로그: https://console.firebase.google.com/project/makecallio/functions/logs

