# 🔐 PERMISSION_DENIED 에러 심층 분석

## 📊 확인된 에러 메시지

```json
{
  "error": {
    "message": "Failed to create custom token: 7 PERMISSION_DENIED: Missing or insufficient permissions.",
    "status": "INTERNAL"
  }
}
```

**에러 코드 7**: gRPC 에러 코드 (PERMISSION_DENIED)

---

## 🎯 IAM 권한을 10번 이상 확인했는데도 실패하는 이유

### ❌ 흔한 실수들

#### 1️⃣ **잘못된 서비스 계정에 권한 부여**

**문제**:
- Firebase Functions가 사용하는 **실제 서비스 계정**이 아닌 다른 계정에 권한 부여
- 프로젝트에 여러 서비스 계정이 존재할 수 있음

**해결 방법**:
```bash
# Firebase Functions가 실제로 사용하는 서비스 계정 확인
# Firebase Console → Functions → 함수 선택 → Details 탭

실제 사용 중인 서비스 계정:
PROJECT_ID@appspot.gserviceaccount.com (기본 App Engine 서비스 계정)
또는
firebase-adminsdk-xxxxx@PROJECT_ID.iam.gserviceaccount.com
```

**확인 체크리스트**:
```
[ ] makecallio@appspot.gserviceaccount.com 계정 확인
[ ] firebase-adminsdk-xxxxx@makecallio.iam.gserviceaccount.com 계정 확인
[ ] 두 계정 모두에 Service Account Token Creator 역할 부여
```

---

#### 2️⃣ **권한 부여 후 전파 시간 필요**

**문제**:
- IAM 권한 변경 후 즉시 적용되지 않음
- 전파 시간: 1~10분 (경우에 따라 더 길 수 있음)

**해결 방법**:
```
1. IAM 권한 부여 완료
2. 5~10분 대기 ⏰
3. Firebase Functions 재배포 (선택사항)
4. 카카오 로그인 재시도
```

---

#### 3️⃣ **프로젝트 레벨이 아닌 서비스 레벨 권한**

**문제**:
- 서비스 계정에 권한을 부여했지만 **프로젝트 레벨**이 아님
- 특정 리소스에만 권한이 제한됨

**확인 방법**:
```
Google Cloud Console → IAM
→ 서비스 계정 찾기
→ "프로젝트" 열에서 권한 범위 확인
→ "프로젝트" 또는 "전역"이어야 함
```

---

#### 4️⃣ **Service Account Token Creator 역할만 부여**

**문제**:
- Token Creator 역할만 있고 다른 필수 역할 누락
- Firebase Admin SDK가 다른 API를 호출할 때 권한 부족

**필요한 역할 (전체)**:
```
✅ Service Account Token Creator (roles/iam.serviceAccountTokenCreator)
✅ Service Usage Consumer (roles/serviceusage.serviceUsageConsumer)
✅ Firebase Admin (roles/firebase.admin) - 선택사항이지만 권장
```

---

#### 5️⃣ **Organization Policy 제약**

**문제**:
- 조직 수준에서 IAM 정책 제약 설정
- 프로젝트 레벨 권한 부여가 조직 정책에 의해 차단됨

**확인 방법**:
```
Google Cloud Console → IAM & Admin → Organization Policies
→ 제약 조건 확인
→ iam.disableServiceAccountKeyCreation
→ iam.disableServiceAccountCreation
```

**해결 방법**:
- 조직 관리자에게 문의
- 정책 예외 요청

---

## 🔧 단계별 해결 방법

### **Step 1: 실제 사용 중인 서비스 계정 확인**

#### 방법 A: Firebase Console
```
1. Firebase Console → Functions
   https://console.firebase.google.com/project/makecallio/functions

2. createCustomTokenForKakao 함수 클릭

3. Details 탭 확인
   - Runtime service account 확인
   - 일반적으로: PROJECT_ID@appspot.gserviceaccount.com
```

#### 방법 B: Firebase Functions 로그
```
Firebase Console → Functions → Logs
→ 다음 로그 메시지 찾기:
   "Service Account: [계정 이메일]"
```

#### 방법 C: gcloud CLI
```bash
gcloud functions describe createCustomTokenForKakao \
  --region=asia-northeast3 \
  --format="value(serviceAccountEmail)"
```

---

### **Step 2: 올바른 서비스 계정에 권한 부여**

#### Google Cloud Console에서:

1. **IAM 페이지 접속**:
   ```
   https://console.cloud.google.com/iam-admin/iam?project=makecallio
   ```

2. **올바른 서비스 계정 찾기**:
   ```
   makecallio@appspot.gserviceaccount.com
   또는
   firebase-adminsdk-xxxxx@makecallio.iam.gserviceaccount.com
   ```

3. **권한 확인 및 추가**:
   - 계정 옆의 연필 아이콘 클릭 (편집)
   - 현재 역할 목록 확인
   - 다음 역할이 **모두** 있는지 확인:
     ```
     ✅ Service Account Token Creator
     ✅ Service Usage Consumer
     ✅ Firebase Admin (선택사항)
     ```
   - 없으면 "역할 추가" 클릭하여 추가

4. **저장** 클릭

5. **5~10분 대기** ⏰ (권한 전파 시간)

---

### **Step 3: gcloud CLI로 권한 부여 (대안)**

```bash
# 프로젝트 설정
gcloud config set project makecallio

# 실제 서비스 계정 이메일 확인
SERVICE_ACCOUNT=$(gcloud functions describe createCustomTokenForKakao \
  --region=asia-northeast3 \
  --format="value(serviceAccountEmail)")

echo "서비스 계정: $SERVICE_ACCOUNT"

# Service Account Token Creator 역할 부여
gcloud projects add-iam-policy-binding makecallio \
  --member="serviceAccount:$SERVICE_ACCOUNT" \
  --role="roles/iam.serviceAccountTokenCreator"

# Service Usage Consumer 역할 부여
gcloud projects add-iam-policy-binding makecallio \
  --member="serviceAccount:$SERVICE_ACCOUNT" \
  --role="roles/serviceusage.serviceUsageConsumer"

# 권한 확인
gcloud projects get-iam-policy makecallio \
  --flatten="bindings[].members" \
  --format="table(bindings.role)" \
  --filter="bindings.members:$SERVICE_ACCOUNT"
```

---

### **Step 4: App Engine 기본 서비스 계정 권한 부여**

Firebase Functions는 기본적으로 **App Engine 기본 서비스 계정**을 사용합니다:

```
makecallio@appspot.gserviceaccount.com
```

이 계정에도 권한을 부여해야 합니다:

```bash
# App Engine 기본 서비스 계정에 권한 부여
gcloud projects add-iam-policy-binding makecallio \
  --member="serviceAccount:makecallio@appspot.gserviceaccount.com" \
  --role="roles/iam.serviceAccountTokenCreator"

gcloud projects add-iam-policy-binding makecallio \
  --member="serviceAccount:makecallio@appspot.gserviceaccount.com" \
  --role="roles/serviceusage.serviceUsageConsumer"
```

---

### **Step 5: Firebase Admin SDK 서비스 계정 권한 부여**

```bash
# Firebase Admin SDK 서비스 계정 찾기
ADMIN_SDK_ACCOUNT=$(gcloud iam service-accounts list \
  --filter="email:firebase-adminsdk" \
  --format="value(email)")

echo "Firebase Admin SDK 계정: $ADMIN_SDK_ACCOUNT"

# 권한 부여
gcloud projects add-iam-policy-binding makecallio \
  --member="serviceAccount:$ADMIN_SDK_ACCOUNT" \
  --role="roles/iam.serviceAccountTokenCreator"

gcloud projects add-iam-policy-binding makecallio \
  --member="serviceAccount:$ADMIN_SDK_ACCOUNT" \
  --role="roles/serviceusage.serviceUsageConsumer"
```

---

## 🔍 권한 전파 확인 방법

### 방법 1: IAM 정책 확인

```bash
# 특정 서비스 계정의 모든 권한 확인
gcloud projects get-iam-policy makecallio \
  --flatten="bindings[].members" \
  --format="table(bindings.role)" \
  --filter="bindings.members:makecallio@appspot.gserviceaccount.com"
```

### 방법 2: Firebase Console에서 함수 재실행

```
Firebase Console → Functions → createCustomTokenForKakao → 테스트
→ 테스트 데이터:
{
  "data": {
    "kakaoUid": "4550398105",
    "email": "norman.southcastle@gmail.com",
    "displayName": "남궁현철"
  }
}
→ 실행 버튼 클릭
```

**성공 시**:
```json
{
  "result": {
    "customToken": "eyJhbGciOiJS..."
  }
}
```

**실패 시**:
```json
{
  "error": {
    "message": "Failed to create custom token: 7 PERMISSION_DENIED...",
    "status": "INTERNAL"
  }
}
```

---

## 🎯 가장 효과적인 해결 방법 (All-in-One)

### **방법: 3개 서비스 계정 모두에 권한 부여**

```bash
#!/bin/bash

# 프로젝트 설정
PROJECT_ID="makecallio"
gcloud config set project $PROJECT_ID

# 3개 서비스 계정 정의
ACCOUNTS=(
  "$PROJECT_ID@appspot.gserviceaccount.com"
  "firebase-adminsdk-xxxxx@$PROJECT_ID.iam.gserviceaccount.com"
  "$(gcloud functions describe createCustomTokenForKakao --region=asia-northeast3 --format='value(serviceAccountEmail)')"
)

# 각 계정에 필요한 역할 부여
for account in "${ACCOUNTS[@]}"; do
  echo "권한 부여: $account"
  
  gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$account" \
    --role="roles/iam.serviceAccountTokenCreator"
  
  gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$account" \
    --role="roles/serviceusage.serviceUsageConsumer"
done

echo "✅ 모든 서비스 계정에 권한 부여 완료"
echo "⏰ 5~10분 후 카카오 로그인 재시도"
```

---

## 💡 추가 트러블슈팅

### 문제: 권한 부여 후에도 계속 실패

**시도 1**: Firebase Functions 재배포
```bash
cd functions
firebase deploy --only functions:createCustomTokenForKakao --force
```

**시도 2**: 캐시 무효화
```bash
# Functions 완전 삭제 후 재배포
firebase functions:delete createCustomTokenForKakao --region=asia-northeast3
firebase deploy --only functions:createCustomTokenForKakao
```

**시도 3**: 새 서비스 계정 생성 및 사용
```bash
# 새 서비스 계정 생성
gcloud iam service-accounts create kakao-login-service \
  --display-name="Kakao Login Service Account"

# 권한 부여
gcloud projects add-iam-policy-binding makecallio \
  --member="serviceAccount:kakao-login-service@makecallio.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountTokenCreator"

# Functions 배포 시 이 서비스 계정 지정
firebase deploy --only functions:createCustomTokenForKakao \
  --service-account=kakao-login-service@makecallio.iam.gserviceaccount.com
```

---

## 📋 최종 체크리스트

```
[ ] App Engine 기본 서비스 계정 권한 확인
    → makecallio@appspot.gserviceaccount.com
    
[ ] Firebase Admin SDK 서비스 계정 권한 확인
    → firebase-adminsdk-xxxxx@makecallio.iam.gserviceaccount.com
    
[ ] Functions 실제 사용 서비스 계정 확인
    → gcloud functions describe로 확인
    
[ ] 3개 계정 모두에 다음 역할 부여:
    → Service Account Token Creator
    → Service Usage Consumer
    
[ ] 5~10분 대기 (권한 전파)

[ ] Firebase Console에서 함수 직접 테스트

[ ] 성공하면 Flutter 앱에서 카카오 로그인 재시도
```

---

## 🚀 즉시 실행할 명령어 (복사해서 실행)

```bash
# 1. 프로젝트 설정
gcloud config set project makecallio

# 2. App Engine 기본 서비스 계정 권한 부여
gcloud projects add-iam-policy-binding makecallio \
  --member="serviceAccount:makecallio@appspot.gserviceaccount.com" \
  --role="roles/iam.serviceAccountTokenCreator"

gcloud projects add-iam-policy-binding makecallio \
  --member="serviceAccount:makecallio@appspot.gserviceaccount.com" \
  --role="roles/serviceusage.serviceUsageConsumer"

# 3. Firebase Admin SDK 서비스 계정 찾기 및 권한 부여
ADMIN_SDK=$(gcloud iam service-accounts list --filter="email:firebase-adminsdk" --format="value(email)")
echo "Firebase Admin SDK: $ADMIN_SDK"

gcloud projects add-iam-policy-binding makecallio \
  --member="serviceAccount:$ADMIN_SDK" \
  --role="roles/iam.serviceAccountTokenCreator"

gcloud projects add-iam-policy-binding makecallio \
  --member="serviceAccount:$ADMIN_SDK" \
  --role="roles/serviceusage.serviceUsageConsumer"

# 4. 권한 확인
echo "=== App Engine 계정 권한 ==="
gcloud projects get-iam-policy makecallio \
  --flatten="bindings[].members" \
  --format="table(bindings.role)" \
  --filter="bindings.members:makecallio@appspot.gserviceaccount.com"

echo "=== Firebase Admin SDK 계정 권한 ==="
gcloud projects get-iam-policy makecallio \
  --flatten="bindings[].members" \
  --format="table(bindings.role)" \
  --filter="bindings.members:$ADMIN_SDK"

echo "✅ 권한 부여 완료! 5~10분 후 카카오 로그인 재시도하세요."
```

---

## 📞 결론

**핵심**: Firebase Functions가 사용하는 **실제 서비스 계정**을 정확히 찾아서 권한을 부여해야 합니다.

**가장 효과적인 방법**:
1. App Engine 기본 서비스 계정 (`makecallio@appspot.gserviceaccount.com`)에 권한 부여
2. Firebase Admin SDK 서비스 계정에 권한 부여
3. 5~10분 대기
4. Firebase Console에서 함수 직접 테스트
5. 성공하면 Flutter 앱에서 재시도
