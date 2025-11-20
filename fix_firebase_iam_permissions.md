# Firebase IAM 권한 오류 해결 가이드

## 오류 내용
```
[KAKAO] Error creating custom token: Error: 7 PERMISSION_DENIED: Missing or insufficient permissions
```

## 원인
Firebase Functions에서 `admin.auth().createCustomToken()` 호출 시 필요한 IAM 권한이 없음

## 해결 방법

### 1. Firebase Console 접속
https://console.firebase.google.com/

### 2. 프로젝트 선택
- **makecallio** 프로젝트 선택

### 3. IAM 권한 설정
1. **프로젝트 설정** (톱니바퀴 아이콘) 클릭
2. **서비스 계정** 탭 클릭
3. **Google Cloud Platform에서 권한 관리** 클릭

또는 직접 GCP Console 접속:
https://console.cloud.google.com/iam-admin/iam?project=makecallio

### 4. Service Account 찾기
다음 Service Account를 찾으세요:
```
makecallio@appspot.gserviceaccount.com
```

### 5. 권한 추가
**편집** (연필 아이콘) 클릭 후 다음 역할 추가:

#### 필수 권한:
- ✅ **Service Account Token Creator** (`roles/iam.serviceAccountTokenCreator`)
  - Custom Token 생성에 필요

- ✅ **Service Usage Consumer** (`roles/serviceusage.serviceUsageConsumer`)
  - Firebase 서비스 사용에 필요

#### 추가 권한 (이미 있을 수 있음):
- **Firebase Admin SDK Administrator Service Agent**
- **Cloud Functions Service Agent**

### 6. 저장 및 대기
- **저장** 버튼 클릭
- 권한 적용까지 1-2분 대기

### 7. 테스트
앱에서 Kakao/Naver 로그인 다시 시도

---

## 빠른 확인 방법

### 현재 권한 확인:
```bash
gcloud projects get-iam-policy makecallio \
  --flatten="bindings[].members" \
  --filter="bindings.members:makecallio@appspot.gserviceaccount.com"
```

### 권한 추가 (gcloud CLI 사용 시):
```bash
# Service Account Token Creator 추가
gcloud projects add-iam-policy-binding makecallio \
  --member="serviceAccount:makecallio@appspot.gserviceaccount.com" \
  --role="roles/iam.serviceAccountTokenCreator"

# Service Usage Consumer 추가
gcloud projects add-iam-policy-binding makecallio \
  --member="serviceAccount:makecallio@appspot.gserviceaccount.com" \
  --role="roles/serviceusage.serviceUsageConsumer"
```

---

## 참고사항

### 왜 이 권한이 필요한가?
- **createCustomToken()**: Firebase Admin SDK가 JWT 토큰을 생성하려면 Service Account Token Creator 권한 필요
- **Firebase Functions**: Cloud 서비스를 사용하려면 Service Usage Consumer 권한 필요

### 이전에 추가했는데 왜 또 오류?
- IAM 권한 변경 후 1-2분 전파 시간 필요
- Functions 재배포 필요할 수 있음: `firebase deploy --only functions`
- 캐시 문제일 수 있음: 앱 완전 재시작

### 네이버 로그인도 같은 오류?
- 네이버도 같은 IAM 권한 필요
- 한 번 추가하면 Kakao, Naver 모두 해결됨

---

## 문제 해결 체크리스트

- [ ] Firebase Console에서 IAM 권한 확인
- [ ] Service Account Token Creator 역할 추가
- [ ] Service Usage Consumer 역할 추가
- [ ] 1-2분 대기 (권한 전파)
- [ ] 앱 완전 재시작
- [ ] Kakao 로그인 테스트
- [ ] Naver 로그인 테스트

---

## 여전히 오류 발생 시

1. **Functions 로그 확인**:
   ```
   Firebase Console → Functions → 로그 탭
   ```

2. **Service Account 확인**:
   ```
   Firebase Console → 프로젝트 설정 → 서비스 계정
   ```

3. **Functions 재배포**:
   ```bash
   cd functions
   firebase deploy --only functions
   ```

