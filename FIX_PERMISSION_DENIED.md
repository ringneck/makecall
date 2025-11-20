# 🔥 PERMISSION_DENIED 오류 해결 체크리스트

## 현재 오류
```
[KAKAO] Error creating custom token: Error: 7 PERMISSION_DENIED: Missing or insufficient permissions
```

---

## ✅ 해결 체크리스트

### 1. IAM 권한 추가 ✅ (완료)
**Service Account:** `makecallio@appspot.gserviceaccount.com`

**필요한 역할:**
- ✅ Service Account Token Creator (`roles/iam.serviceAccountTokenCreator`)
- ✅ Service Usage Consumer (`roles/serviceusage.serviceUsageConsumer`)

**확인 방법:**
- Firebase Console: https://console.firebase.google.com/project/makecallio
- GCP IAM: https://console.cloud.google.com/iam-admin/iam?project=makecallio

---

### 2. Firebase Functions 재배포 ⚠️ (필수!)

**중요:** IAM 권한을 추가한 후 **반드시 Functions를 재배포**해야 합니다!

#### 방법 1: 자동 스크립트 사용
```bash
cd /home/user/flutter_app
./redeploy_functions.sh
```

#### 방법 2: 수동 배포
```bash
cd /home/user/flutter_app/functions
npm install
firebase deploy --only functions
```

#### 방법 3: 특정 Function만 배포
```bash
cd /home/user/flutter_app/functions

# Kakao Function만
firebase deploy --only functions:createCustomTokenForKakao

# Naver Function만
firebase deploy --only functions:createCustomTokenForNaver
```

---

### 3. 배포 확인

#### Firebase Console에서 확인
https://console.firebase.google.com/project/makecallio/functions

**확인 사항:**
- ✅ `createCustomTokenForKakao` 버전이 업데이트 되었는가?
- ✅ `createCustomTokenForNaver` 버전이 업데이트 되었는가?
- ✅ 배포 시간이 최근인가?

#### 버전 확인
Functions 목록에서:
- **이전 버전:** v1 (2024-01-XX)
- **새 버전:** v1 (오늘 날짜/시간)

---

### 4. 테스트

#### 앱 재시작
```bash
# 앱 완전 종료 후 재시작
flutter run
```

#### 카카오 로그인 테스트
1. "Kakao로 로그인" 버튼 클릭
2. 카카오 인증 진행
3. 결과 확인

---

### 5. Functions 로그 확인

#### 실시간 로그
```bash
firebase functions:log
```

#### Firebase Console에서 확인
https://console.firebase.google.com/project/makecallio/functions/logs

**성공 시 예상 로그:**
```
🔐 [KAKAO] Creating custom token for user: kakao_xxxxx
✅ [KAKAO] Custom token created successfully
```

**여전히 PERMISSION_DENIED 시:**
```
❌ [KAKAO] Error creating custom token: Error: 7 PERMISSION_DENIED
❌ [KAKAO] Error details: { message: "...", code: 7, ... }
🔐 [KAKAO] IAM Permission Issue Detected
   Required roles:
   - roles/iam.serviceAccountTokenCreator
   - roles/serviceusage.serviceUsageConsumer
   Service Account: [실제 사용 중인 계정]
```

---

## 🚨 여전히 오류가 발생하는 경우

### A. Service Account 확인
Functions 로그에서 실제 사용 중인 Service Account 확인

**예상:** `makecallio@appspot.gserviceaccount.com`

만약 다른 계정이라면, **해당 계정**에 IAM 권한을 추가해야 함

### B. 권한 전파 대기
IAM 권한 변경 후 **최대 5분** 정도 대기 필요

대기 후:
1. Functions 재배포
2. 앱 재시작
3. 다시 테스트

### C. Functions 완전 재배포
기존 Functions 삭제 후 재배포:

```bash
cd /home/user/flutter_app/functions

# 기존 Functions 삭제
firebase functions:delete createCustomTokenForKakao --force
firebase functions:delete createCustomTokenForNaver --force

# 대기
sleep 10

# 재배포
firebase deploy --only functions
```

### D. Firebase CLI 재인증
```bash
firebase logout
firebase login
firebase use makecallio
firebase deploy --only functions
```

---

## 📋 최종 체크리스트

수행 순서대로 체크:

- [ ] 1. IAM 권한 추가 확인 (GCP Console)
- [ ] 2. Firebase Functions 재배포 실행
- [ ] 3. Firebase Console에서 배포 확인
- [ ] 4. Functions 버전 업데이트 확인
- [ ] 5. 앱 완전 재시작
- [ ] 6. 카카오/네이버 로그인 테스트
- [ ] 7. Functions 로그에서 성공 메시지 확인

---

## 🎯 예상 결과

**재배포 후 예상 동작:**

1. **Flutter 앱 로그:**
```
🟡 [Kakao] 로그인 시작
🔄 [Kakao] 웹뷰 로그인 시도...
✅ [Kakao] 웹뷰 로그인 성공
✅ [Kakao] OAuth 토큰 획득 완료
🔄 [Kakao] 사용자 정보 조회 중...
✅ [Kakao] 사용자 정보 조회 완료
🔄 [Kakao] Firebase Custom Token 생성 요청 중...
✅ [Kakao] Firebase Custom Token 생성 완료  ← 여기서 성공해야 함!
🔄 [Kakao] Firebase 로그인 중...
✅ [Kakao] Firebase 로그인 완료
✅ [Kakao] 전체 로그인 프로세스 성공
```

2. **Functions 로그:**
```
🔐 [KAKAO] Creating custom token for user: kakao_12345
✅ [KAKAO] Custom token created successfully
```

---

## 💡 핵심 포인트

**가장 중요한 것:**
1. ✅ IAM 권한 추가 (이미 완료)
2. ⚠️ **Functions 재배포** (아직 안 했을 가능성 높음)

**재배포 없이는 권한 변경이 적용되지 않습니다!**

```bash
# 이 명령어를 실행하지 않으면 권한이 적용되지 않음!
firebase deploy --only functions
```

