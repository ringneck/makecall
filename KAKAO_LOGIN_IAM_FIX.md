# 🔐 카카오 로그인 IAM 권한 오류 해결 가이드

## ❌ 문제 상황

카카오 소셜 로그인 시 Firebase Functions에서 다음 오류 발생:

```
Error: 7 PERMISSION_DENIED: Missing or insufficient permissions
```

**오류 원인**: Firebase Functions의 서비스 계정에 Custom Token 생성 권한이 없음

## ✅ 해결 방법 (Firebase Console)

### 1️⃣ Firebase Console에서 프로젝트 설정 확인

1. **Firebase Console** 접속: https://console.firebase.google.com/
2. 프로젝트 선택
3. **프로젝트 설정** (⚙️ 아이콘) → **서비스 계정** 탭 클릭
4. **Firebase Admin SDK** 섹션에서 서비스 계정 이메일 확인
   - 형식: `firebase-adminsdk-xxxxx@your-project-id.iam.gserviceaccount.com`
   - 이 이메일을 복사하세요 (다음 단계에서 사용)

### 2️⃣ Google Cloud Console에서 IAM 권한 부여

1. **Google Cloud Console** 접속: https://console.cloud.google.com/
2. 프로젝트 선택 (Firebase 프로젝트와 동일한 프로젝트)
3. 왼쪽 메뉴 → **IAM 및 관리자** → **IAM** 클릭
4. 페이지 상단 **+ 액세스 권한 부여** 버튼 클릭
5. **새 주 구성원 추가**:
   - **새 주 구성원**: 위에서 복사한 서비스 계정 이메일 입력
   - **역할 선택**: 다음 역할들을 추가
     - ✅ **Service Account Token Creator** (`roles/iam.serviceAccountTokenCreator`)
     - ✅ **Service Usage Consumer** (`roles/serviceusage.serviceUsageConsumer`)
6. **저장** 버튼 클릭

### 3️⃣ 역할 검색 방법

IAM 페이지에서 역할을 추가할 때:

**Service Account Token Creator 역할 검색:**
- 역할 선택 드롭다운 클릭
- 검색창에 "token creator" 입력
- **Service Account Token Creator** 선택

**Service Usage Consumer 역할 검색:**
- 역할 선택 드롭다운 클릭
- 검색창에 "service usage" 입력
- **Service Usage Consumer** 선택

### 4️⃣ 권한 적용 확인

권한 부여 후:
1. 약 1-2분 대기 (권한 전파 시간)
2. Flutter 앱에서 카카오 로그인 재시도
3. 로그인 성공 확인

---

## 🖥️ 해결 방법 (gcloud CLI - 대안)

터미널에서 명령어로 권한 부여하는 방법:

### 1️⃣ gcloud CLI 설치 및 인증

```bash
# gcloud CLI가 없는 경우 설치
# https://cloud.google.com/sdk/docs/install

# Google Cloud 계정 인증
gcloud auth login

# 프로젝트 설정
gcloud config set project YOUR_PROJECT_ID
```

### 2️⃣ 서비스 계정 이메일 확인

```bash
# Firebase Functions 서비스 계정 이메일 확인
gcloud iam service-accounts list | grep firebase-adminsdk
```

출력 예시:
```
firebase-adminsdk-xxxxx@your-project-id.iam.gserviceaccount.com
```

### 3️⃣ IAM 역할 부여

```bash
# Service Account Token Creator 역할 부여
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:firebase-adminsdk-xxxxx@your-project-id.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountTokenCreator"

# Service Usage Consumer 역할 부여
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:firebase-adminsdk-xxxxx@your-project-id.iam.gserviceaccount.com" \
  --role="roles/serviceusage.serviceUsageConsumer"
```

### 4️⃣ 권한 확인

```bash
# 서비스 계정의 역할 확인
gcloud projects get-iam-policy YOUR_PROJECT_ID \
  --flatten="bindings[].members" \
  --format="table(bindings.role)" \
  --filter="bindings.members:firebase-adminsdk-xxxxx@your-project-id.iam.gserviceaccount.com"
```

---

## 📋 체크리스트

권한 부여 전 확인사항:

- [ ] Firebase Console에서 서비스 계정 이메일 확인
- [ ] Google Cloud Console IAM 페이지 접속
- [ ] Service Account Token Creator 역할 부여
- [ ] Service Usage Consumer 역할 부여
- [ ] 1-2분 대기 후 카카오 로그인 재시도

---

## 🔍 권한 부여가 제대로 되었는지 확인하는 방법

### Firebase Functions 로그 확인

1. **Firebase Console** → **Functions** → **로그** 탭
2. 카카오 로그인 시도
3. 로그에서 다음 메시지 확인:
   - ✅ 성공: `✅ [KAKAO] Custom token created successfully`
   - ❌ 실패: `❌ [KAKAO] IAM Permission Issue Detected`

### Flutter 앱에서 확인

카카오 로그인 버튼 클릭 후:
- ✅ 성공: 로그인 완료 후 메인 화면 이동
- ❌ 실패: "카카오 로그인에 실패했습니다" 에러 메시지

---

## 📚 참고 자료

- [Firebase Custom Token 생성 가이드](https://firebase.google.com/docs/auth/admin/create-custom-tokens)
- [Google Cloud IAM 역할 관리](https://cloud.google.com/iam/docs/granting-changing-revoking-access)
- [Service Account Token Creator 역할 설명](https://cloud.google.com/iam/docs/service-accounts-token-creator)

---

## ❓ 자주 묻는 질문 (FAQ)

### Q1. 권한을 부여했는데도 여전히 오류가 발생합니다.

**답변**: 권한 전파에 시간이 걸릴 수 있습니다.
- 1-2분 대기 후 재시도
- Firebase Functions 재배포: `firebase deploy --only functions:createCustomTokenForKakao`
- 브라우저 캐시 삭제 후 재시도

### Q2. 서비스 계정 이메일을 찾을 수 없습니다.

**답변**: Firebase Console → 프로젝트 설정 → 서비스 계정 탭에서 확인
- **Firebase Admin SDK** 섹션에 표시됨
- 형식: `firebase-adminsdk-xxxxx@your-project-id.iam.gserviceaccount.com`

### Q3. Google Cloud Console에 접속할 수 없습니다.

**답변**: Firebase 프로젝트와 연결된 Google Cloud 프로젝트 확인
- Firebase Console → 프로젝트 설정 → 일반 탭
- **Google Cloud 프로젝트 ID** 확인
- 해당 프로젝트에 대한 권한이 있는지 확인 (소유자 또는 편집자 역할 필요)

### Q4. IAM 페이지에서 역할을 추가할 수 없습니다.

**답변**: 프로젝트에 대한 IAM 관리 권한 필요
- 프로젝트 소유자 또는 IAM 관리자 역할 필요
- 권한이 없는 경우 프로젝트 소유자에게 요청

---

## 💡 추가 정보

### 필요한 역할 설명

**Service Account Token Creator** (`roles/iam.serviceAccountTokenCreator`):
- Firebase Custom Token 생성 시 필요
- `admin.auth().createCustomToken()` 호출 권한 부여
- OAuth 2.0 토큰 생성 권한

**Service Usage Consumer** (`roles/serviceusage.serviceUsageConsumer`):
- Google Cloud API 사용 권한
- Firebase Functions에서 다른 Google Cloud 서비스 호출 시 필요

---

## ✅ 해결 완료 후 확인사항

카카오 로그인 성공 시 다음 순서로 진행:
1. ✅ Firebase Functions에서 Custom Token 생성 성공
2. ✅ Flutter 앱에서 Firebase Auth로 Custom Token 로그인
3. ✅ Firestore에 사용자 정보 저장
4. ✅ 메인 화면으로 이동

---

**문제가 계속 발생하는 경우 Firebase Functions 로그를 확인하고, 필요 시 Firebase Support에 문의하세요.**
