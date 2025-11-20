# 🔍 카카오 로그인 INTERNAL 에러 종합 분석

## 📊 현재 상황

### ✅ 성공한 단계
```
🟡 [Kakao] 로그인 시작
✅ [Kakao] 카카오톡 앱 로그인 성공
✅ [Kakao] OAuth 토큰 획득 완료
✅ [Kakao] 사용자 정보 조회 완료
   - User ID: 4550398105
   - Email: norman.southcastle@gmail.com
   - Nickname: 남궁현철
```

### ❌ 실패한 단계
```
🔄 [Kakao] Firebase Custom Token 생성 요청 중...
❌ [Kakao] Firebase 인증 실패
   에러 타입: FirebaseFunctionsException
   Functions 에러 코드: internal
   Functions 에러 메시지: INTERNAL
   Functions 에러 상세: null
```

---

## 🎯 INTERNAL 에러의 가능한 원인

### 1️⃣ Firebase Functions 미배포 (가장 가능성 높음) 🥇

**증상**:
- ✅ 로컬 `functions/index.js`에는 코드 존재
- ❌ Firebase에 실제로 배포되지 않음
- 에러 메시지: `INTERNAL` (구체적인 정보 없음)

**확인 방법**:
```
1. Firebase Console 접속
   https://console.firebase.google.com/project/makecallio/functions

2. Functions 목록에서 확인
   - createCustomTokenForKakao 함수가 있는가?
   - 리전: asia-northeast3
   - 상태: Active
```

**해결 방법**:
```bash
cd functions
firebase deploy --only functions:createCustomTokenForKakao
```

---

### 2️⃣ Firebase Admin SDK 초기화 오류

**증상**:
- Functions 배포는 되었으나 실행 중 오류
- `admin.auth()` 또는 `admin.firestore()` 호출 실패

**가능한 원인**:
- serviceAccountKey.json 파일 문제 (로컬 개발 환경)
- Application Default Credentials 문제 (배포 환경)

**확인 방법**:
Firebase Functions 로그 확인 (아래 "로그 확인 섹션" 참조)

---

### 3️⃣ Firestore Database 미생성

**증상**:
- Custom Token 생성은 성공
- Firestore에 사용자 정보 저장 시 실패

**확인 방법**:
```
1. Firebase Console → Firestore Database
   https://console.firebase.google.com/project/makecallio/firestore

2. Database 존재 여부 확인
   - 없으면: "Create database" 버튼 표시
   - 있으면: Collections 목록 표시
```

**해결 방법**:
```
Firebase Console → Firestore Database → Create Database
→ Production mode 선택 → 리전 선택 (asia-northeast3)
```

---

### 4️⃣ Billing 미활성화 (Blaze 플랜 필수)

**증상**:
- Firebase Functions 호출 시 INTERNAL 에러
- Cloud Functions는 Spark 플랜(무료)에서 작동 안함

**확인 방법**:
```
Google Cloud Console → Billing
https://console.cloud.google.com/billing

프로젝트가 Billing 계정에 연결되었는지 확인
```

**해결 방법**:
```
Blaze 플랜 활성화 (종량제)
- Cloud Functions 사용 시 필수
- 무료 할당량 존재 (소량 사용 시 무료)
```

---

### 5️⃣ IAM 권한 문제 (다시 확인)

**증상**:
- 에러 코드: `internal` (또는 `permission-denied`)
- Custom Token 생성 시 권한 부족

**확인 방법**:
```
Google Cloud Console → IAM
https://console.cloud.google.com/iam-admin/iam

Firebase 서비스 계정 찾기:
firebase-adminsdk-xxxxx@makecallio.iam.gserviceaccount.com

필요한 역할:
✅ Service Account Token Creator
✅ Service Usage Consumer
```

---

## 🔍 Firebase Functions 로그 확인 방법

### 방법 1: Firebase Console (추천)

1. **Firebase Console 접속**:
   ```
   https://console.firebase.google.com/project/makecallio/functions/logs
   ```

2. **로그 필터링**:
   - 함수: `createCustomTokenForKakao` 선택
   - 시간: 최근 1시간
   - 심각도: 모두

3. **찾을 메시지**:
   ```
   ✅ 성공 시:
   🔐 [KAKAO] Creating custom token for user: kakao_4550398105
   ✅ [KAKAO] Custom token created successfully

   ❌ 실패 시:
   ❌ [KAKAO] Error creating custom token: [에러 메시지]
   🔐 [KAKAO] IAM Permission Issue Detected (IAM 문제인 경우)
   ```

### 방법 2: gcloud CLI

```bash
# 최근 로그 확인
gcloud functions logs read createCustomTokenForKakao \
  --region=asia-northeast3 \
  --limit=50

# 실시간 로그 스트리밍
gcloud functions logs read createCustomTokenForKakao \
  --region=asia-northeast3 \
  --tail
```

---

## 🛠️ 단계별 문제 해결

### ✅ 체크리스트

진행 순서대로 확인하세요:

#### 1단계: Firebase Functions 배포 확인 ⭐ 최우선
```
[ ] Firebase Console → Functions 페이지 접속
[ ] createCustomTokenForKakao 함수가 목록에 존재하는가?
[ ] 리전이 asia-northeast3인가?
[ ] 상태가 Active인가?
[ ] 마지막 배포 시간이 최근인가?

배포되지 않았다면:
→ cd functions && firebase deploy --only functions:createCustomTokenForKakao
```

#### 2단계: Billing 확인
```
[ ] Google Cloud Console → Billing
[ ] 프로젝트가 Billing 계정에 연결되었는가?
[ ] Blaze 플랜이 활성화되었는가?

활성화되지 않았다면:
→ Blaze 플랜 활성화 (무료 할당량 있음)
```

#### 3단계: Firestore Database 확인
```
[ ] Firebase Console → Firestore Database
[ ] Database가 생성되었는가?
[ ] Collections를 볼 수 있는가?

생성되지 않았다면:
→ Create database → Production mode → asia-northeast3
```

#### 4단계: IAM 권한 재확인
```
[ ] Google Cloud Console → IAM
[ ] Firebase 서비스 계정 찾기
[ ] Service Account Token Creator 역할 존재하는가?
[ ] Service Usage Consumer 역할 존재하는가?

없다면:
→ IAM 역할 추가 (KAKAO_LOGIN_IAM_FIX.md 참조)
```

#### 5단계: Firebase Functions 로그 확인
```
[ ] Firebase Console → Functions → Logs
[ ] 카카오 로그인 시도
[ ] 로그에 에러 메시지가 표시되는가?
[ ] 구체적인 에러 내용 확인

로그 확인 후:
→ 에러 메시지에 따라 조치
```

---

## 🧪 Firebase Console에서 함수 직접 테스트

Functions가 배포되었다면, Firebase Console에서 직접 테스트하세요:

1. **Firebase Console → Functions**
2. **createCustomTokenForKakao** 함수 클릭
3. **테스트** 탭 선택
4. **테스트 데이터 입력**:
   ```json
   {
     "data": {
       "kakaoUid": "4550398105",
       "email": "norman.southcastle@gmail.com",
       "displayName": "남궁현철"
     }
   }
   ```
5. **실행** 버튼 클릭
6. **결과 확인**:
   - ✅ 성공: `{ "result": { "customToken": "eyJ..." } }`
   - ❌ 실패: 에러 메시지 확인

---

## 📝 진단 스크립트 실행

터미널에서 종합 진단 실행:

```bash
cd flutter_app
bash functions/check-kakao-function-status.sh
```

이 스크립트는 다음을 자동 확인:
- ✅ Firebase 프로젝트 ID
- ✅ Functions 코드 존재 여부
- ✅ 리전 설정
- ✅ 체크리스트 제공

---

## 🎯 가장 가능성 높은 원인 (순위)

| 순위 | 원인 | 가능성 | 확인 방법 |
|------|------|--------|----------|
| 🥇 | **Functions 미배포** | 80% | Firebase Console → Functions 목록 |
| 🥈 | **Billing 미활성화** | 15% | Google Cloud Console → Billing |
| 🥉 | **Firestore 미생성** | 3% | Firebase Console → Firestore Database |
| 4️⃣ | **IAM 권한 (재확인)** | 2% | Google Cloud Console → IAM |

---

## 💡 추천 조치 순서

### 1️⃣ Firebase Console에서 Functions 배포 확인
```
https://console.firebase.google.com/project/makecallio/functions
```
- createCustomTokenForKakao 함수가 있는가?
- **없다면**: 로컬에서 배포 필요

### 2️⃣ 로컬에서 Functions 배포 (함수가 없는 경우)
```bash
cd flutter_app/functions
firebase deploy --only functions:createCustomTokenForKakao
```

### 3️⃣ Firebase Functions 로그 확인
```
https://console.firebase.google.com/project/makecallio/functions/logs
```
- 카카오 로그인 재시도
- 로그에서 구체적인 에러 확인

### 4️⃣ Firebase Console에서 직접 테스트
- Functions → createCustomTokenForKakao → 테스트
- 위의 테스트 데이터로 실행
- 결과 확인

---

## 🔗 관련 문서

- **IAM 권한 가이드**: KAKAO_LOGIN_IAM_FIX.md
- **진단 스크립트**: functions/check-kakao-function-status.sh
- **Firebase Functions 문서**: https://firebase.google.com/docs/functions
- **Custom Token 생성 가이드**: https://firebase.google.com/docs/auth/admin/create-custom-tokens

---

## 📞 다음 단계

**가장 먼저 확인할 것**:

1. Firebase Console → Functions
2. createCustomTokenForKakao 함수 존재 여부
3. 없으면 → 로컬에서 배포
4. 있으면 → Functions 로그 확인

**로그 확인 후 에러 메시지를 공유해주세요!**
