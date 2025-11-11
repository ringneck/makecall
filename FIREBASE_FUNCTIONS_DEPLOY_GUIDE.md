# 🚀 MAKECALL Firebase Functions 배포 가이드

## 📋 개요

이 문서는 MAKECALL 앱의 Firebase Cloud Functions를 배포하는 방법을 설명합니다.
Gmail SMTP를 사용한 이메일 인증 시스템과 FCM 푸시 알림 시스템이 포함되어 있습니다.

**Firebase 프로젝트:** `makecallio`

---

## ✅ 사전 준비 완료 사항

다음 파일들이 이미 준비되어 있습니다:

```
✅ functions/index.js              - Cloud Functions 코드
✅ functions/package.json          - npm 패키지 설정
✅ firestore.rules                 - Firestore 보안 규칙
✅ firebase.json                   - Firebase 설정
✅ .firebaserc                     - Firebase 프로젝트 설정
```

---

## 🔑 Step 1: Gmail 앱 비밀번호 생성

### 1.1 Google 계정 설정
1. Google 계정 (https://myaccount.google.com/) 접속
2. 왼쪽 메뉴에서 **"보안"** 클릭
3. **"2단계 인증"** 섹션 찾기

### 1.2 2단계 인증 활성화 (필수!)
1. **"2단계 인증"** 클릭
2. 화면의 안내에 따라 설정
3. 휴대폰 인증 완료

### 1.3 앱 비밀번호 생성
1. 보안 페이지로 돌아가기
2. **"앱 비밀번호"** 찾기 (검색창에 "앱 비밀번호" 입력)
3. 앱 비밀번호 생성 페이지에서:
   - **앱 선택**: "메일"
   - **기기 선택**: "기타(사용자 설정 이름)"
   - **이름 입력**: "MAKECALL Email Verification"
4. **"생성"** 버튼 클릭
5. **16자리 비밀번호**가 표시됨 (예: `abcd efgh ijkl mnop`)
6. ⚠️ **중요**: 이 비밀번호는 한 번만 표시되므로 안전한 곳에 복사 저장

**예시:**
```
Gmail 주소: makecall.notifications@gmail.com
앱 비밀번호: abcd efgh ijkl mnop (공백 포함 16자리)
```

---

## 💻 Step 2: Firebase CLI 설치 및 로그인

### 2.1 Firebase CLI 설치

**Windows (PowerShell):**
```powershell
npm install -g firebase-tools
```

**macOS/Linux:**
```bash
npm install -g firebase-tools
```

**설치 확인:**
```bash
firebase --version
# 출력 예: 13.0.2
```

### 2.2 Firebase 로그인

```bash
firebase login
```

**브라우저가 자동으로 열리고:**
1. Google 계정 선택
2. Firebase 액세스 권한 허용
3. "Success! Logged in as your-email@gmail.com" 메시지 확인

**로그인 확인:**
```bash
firebase projects:list
```

**출력 예시:**
```
┌──────────────┬────────────────┬────────────────┬──────────────────────┐
│ Project ID   │ Display Name   │ Resource Name  │ Location             │
├──────────────┼────────────────┼────────────────┼──────────────────────┤
│ makecallio   │ MAKECALL       │ [DEFAULT]      │ us-central           │
└──────────────┴────────────────┴────────────────┴──────────────────────┘
```

---

## 🛠️ Step 3: 프로젝트 디렉토리 이동

### 3.1 프로젝트 위치 확인

**현재 프로젝트 구조:**
```
makecall/
├── functions/
│   ├── index.js           ✅ Cloud Functions 코드
│   ├── package.json       ✅ npm 패키지 설정
│   └── node_modules/      (배포 시 자동 생성)
├── firebase.json          ✅ Firebase 설정
├── .firebaserc            ✅ 프로젝트 설정 (makecallio)
└── firestore.rules        ✅ Firestore 보안 규칙
```

### 3.2 디렉토리 이동

**로컬 환경:**
```bash
cd /path/to/makecall
```

**예시 (Windows):**
```powershell
cd C:\Users\YourName\Documents\makecall
```

**예시 (macOS/Linux):**
```bash
cd ~/Documents/makecall
```

---

## 📧 Step 4: Gmail 환경 변수 설정

### 4.1 Firebase Functions Config 설정

**명령어:**
```bash
firebase functions:config:set gmail.email="YOUR_EMAIL@gmail.com"
firebase functions:config:set gmail.password="YOUR_APP_PASSWORD"
```

**예시:**
```bash
firebase functions:config:set gmail.email="makecall.notifications@gmail.com"
firebase functions:config:set gmail.password="abcd efgh ijkl mnop"
```

**성공 메시지:**
```
✔  Functions config updated.

Please deploy your functions for the change to take effect by running:
   firebase deploy --only functions
```

### 4.2 설정 확인

**명령어:**
```bash
firebase functions:config:get
```

**출력 예시:**
```json
{
  "gmail": {
    "email": "makecall.notifications@gmail.com",
    "password": "abcd efgh ijkl mnop"
  }
}
```

⚠️ **주의**: 비밀번호는 마스킹되어 표시되지만 정상적으로 저장되어 있습니다.

---

## 📦 Step 5: npm 패키지 설치

### 5.1 Functions 디렉토리로 이동

```bash
cd functions
```

### 5.2 패키지 설치

```bash
npm install
```

**설치되는 패키지:**
- `firebase-admin` (v12.0.0) - Firebase Admin SDK
- `firebase-functions` (v4.5.0) - Cloud Functions SDK
- `nodemailer` (v6.9.7) - 이메일 전송 라이브러리

**출력 예시:**
```
added 156 packages, and audited 157 packages in 15s

23 packages are looking for funding
  run `npm fund` for details

found 0 vulnerabilities
```

### 5.3 상위 디렉토리로 복귀

```bash
cd ..
```

---

## 🚀 Step 6: Firebase Functions 배포

### 6.1 전체 배포 (Functions + Firestore Rules)

**명령어:**
```bash
firebase deploy --only functions,firestore:rules
```

**배포 진행 과정:**
```
=== Deploying to 'makecallio'...

i  deploying functions, firestore
i  firestore: checking firestore.rules for compilation errors...
✔  firestore: rules file firestore.rules compiled successfully
i  functions: ensuring required API cloudfunctions.googleapis.com is enabled...
i  functions: ensuring required API cloudbuild.googleapis.com is enabled...
✔  functions: required API cloudfunctions.googleapis.com is enabled
✔  functions: required API cloudbuild.googleapis.com is enabled
i  functions: preparing codebase default for deployment
i  functions: preparing functions directory for uploading...
i  functions: packaged functions (50.23 KB) for uploading
✔  functions: functions folder uploaded successfully
i  firestore: releasing rules firestore.rules...
✔  firestore: released rules firestore.rules to cloud.firestore

i  functions: creating Node.js 18 function sendVerificationEmail(us-central1)...
i  functions: creating Node.js 18 function sendApprovalNotification(us-central1)...
i  functions: creating Node.js 18 function cleanupExpiredRequests(us-central1)...
✔  functions[sendVerificationEmail(us-central1)]: Successful create operation.
✔  functions[sendApprovalNotification(us-central1)]: Successful create operation.
✔  functions[cleanupExpiredRequests(us-central1)]: Successful create operation.

✔  Deploy complete!

Project Console: https://console.firebase.google.com/project/makecallio/overview
```

### 6.2 Functions만 배포 (선택사항)

```bash
firebase deploy --only functions
```

### 6.3 Firestore Rules만 배포 (선택사항)

```bash
firebase deploy --only firestore:rules
```

---

## ✅ Step 7: 배포 확인

### 7.1 Firebase Console에서 확인

1. Firebase Console 접속: https://console.firebase.google.com/
2. **makecallio** 프로젝트 선택
3. 왼쪽 메뉴에서 **"Functions"** 클릭

**배포된 Functions 확인:**
```
✅ sendVerificationEmail        - us-central1
✅ sendApprovalNotification     - us-central1
✅ cleanupExpiredRequests       - us-central1
```

### 7.2 CLI로 확인

```bash
firebase functions:list
```

**출력 예시:**
```
┌──────────────────────────────────────────────┬───────────────┬──────────────┐
│ Function                                     │ Region        │ Trigger      │
├──────────────────────────────────────────────┼───────────────┼──────────────┤
│ sendVerificationEmail                        │ us-central1   │ Firestore    │
│ sendApprovalNotification                     │ us-central1   │ Firestore    │
│ cleanupExpiredRequests                       │ us-central1   │ Schedule     │
└──────────────────────────────────────────────┴───────────────┴──────────────┘
```

---

## 🧪 Step 8: 테스트

### 8.1 이메일 인증 테스트

**Flutter 앱에서:**
1. 로그인 시도 (새 기기)
2. "이메일 인증 코드 받기" 클릭
3. Gmail 수신함 확인 (1-3분 소요)
4. 6자리 코드 입력
5. 승인 완료 확인

### 8.2 FCM 푸시 알림 테스트

**Flutter 앱에서:**
1. 기기 1에서 로그인
2. 기기 2에서 동일 계정 로그인 시도
3. 기기 1에서 FCM 푸시 알림 수신
4. "승인" 버튼 클릭
5. 기기 2에서 로그인 완료 확인

### 8.3 로그 확인

**실시간 로그 스트리밍:**
```bash
firebase functions:log --follow
```

**특정 Function 로그만 보기:**
```bash
firebase functions:log --only sendVerificationEmail
```

**Firebase Console에서 로그 확인:**
1. Firebase Console → Functions → 로그 탭
2. 실시간 로그 확인 가능

---

## 🐛 트러블슈팅

### 문제 1: "Invalid login" 오류

**증상:**
```
Error: Invalid login: 535-5.7.8 Username and Password not accepted.
```

**원인:** Gmail 앱 비밀번호가 잘못되었거나 2단계 인증이 활성화되지 않음

**해결:**
1. Gmail 앱 비밀번호 재생성
2. 공백 포함 정확히 16자리 확인
3. 환경 변수 재설정:
   ```bash
   firebase functions:config:set gmail.password="새-비밀번호"
   firebase deploy --only functions
   ```

### 문제 2: 이메일 전송 안 됨

**증상:** 이메일이 도착하지 않음

**원인:** Firestore 트리거가 작동하지 않음

**해결:**
1. Firebase Console → Functions → 로그 확인
2. Firestore 컬렉션 이름 확인:
   ```
   email_verification_requests (정확한 이름)
   ```
3. Functions 재배포:
   ```bash
   firebase deploy --only functions
   ```

### 문제 3: FCM 푸시 알림 안 됨

**증상:** 푸시 알림이 표시되지 않음

**원인:** FCM 토큰이 유효하지 않음

**해결:**
1. Flutter 앱에서 FCM 토큰 로그 확인
2. Firestore `fcm_tokens` 컬렉션 확인
3. Firebase Console → Cloud Messaging → 테스트 메시지 전송

### 문제 4: "Billing account not configured"

**증상:**
```
Error: Billing account not configured. External network is not accessible 
and quotas are severely limited.
```

**원인:** Firebase Spark Plan(무료)에서 외부 네트워크 접근 제한

**해결:**
1. Firebase Console → 프로젝트 설정
2. Blaze Plan(종량제)로 업그레이드
3. **무료 할당량:**
   - Functions 호출: 2,000,000회/월
   - 네트워크 송신: 5GB/월
   - 대부분의 경우 무료 범위 내 사용 가능
4. 업그레이드 후 재배포:
   ```bash
   firebase deploy --only functions
   ```

### 문제 5: npm 패키지 설치 오류

**증상:**
```
npm ERR! code ENOENT
npm ERR! syscall open
```

**원인:** functions 디렉토리가 잘못되었거나 package.json이 없음

**해결:**
1. functions 디렉토리 존재 확인:
   ```bash
   ls -la functions/
   ```
2. package.json 확인:
   ```bash
   cat functions/package.json
   ```
3. 파일이 없으면 Git에서 다시 가져오기:
   ```bash
   git checkout functions/package.json
   ```

---

## 📊 배포된 Functions 상세

### 1. sendVerificationEmail

**트리거:** Firestore `email_verification_requests` 문서 생성
**기능:** Gmail SMTP로 6자리 인증 코드 이메일 전송
**실행 시간:** 평균 2-3초
**메모리:** 256MB (기본값)
**타임아웃:** 60초 (기본값)

**작동 방식:**
1. Firestore에 새 인증 요청 생성됨
2. Cloud Function 자동 트리거
3. userId로 사용자 이메일 조회
4. Nodemailer로 Gmail SMTP 이메일 전송
5. 전송 완료 표시 업데이트

### 2. sendApprovalNotification

**트리거:** Firestore `fcm_approval_notification_queue` 문서 생성
**기능:** FCM 푸시 알림 전송 (기기 승인 요청)
**실행 시간:** 평균 1-2초
**메모리:** 256MB (기본값)
**타임아웃:** 60초 (기본값)

**작동 방식:**
1. Firestore에 새 FCM 알림 큐 생성됨
2. Cloud Function 자동 트리거
3. Firebase Admin SDK로 FCM 푸시 전송
4. 전송 완료 표시 업데이트

### 3. cleanupExpiredRequests

**트리거:** Pub/Sub 스케줄 (매시간)
**기능:** 만료된 인증 요청 정리
**실행 시간:** 평균 5-10초
**메모리:** 256MB (기본값)
**타임아웃:** 60초 (기본값)

**작동 방식:**
1. 매시간 자동 실행
2. 5분 이상 경과한 이메일 인증 요청 삭제
3. 만료된 기기 승인 요청 상태 업데이트

---

## 💰 비용 예상

### Firebase Functions (Spark Plan - 무료)

**무료 할당량:**
- 호출: 2,000,000회/월
- 컴퓨팅: 400,000 GB-초/월
- 네트워크: 5GB/월

**예상 사용량 (월 10,000 사용자):**
- 이메일 인증: ~20,000회 (사용자당 2회)
- FCM 푸시: ~50,000회 (사용자당 5회)
- 정리 작업: ~720회 (매시간 1회)
- **총 호출: ~70,720회/월**

**예상 비용:**
- Spark Plan: **$0** (무료 범위 내)
- Blaze Plan: **$0** (무료 할당량 내)

### Gmail SMTP

**전송 제한:**
- 하루 500통 (Gmail 무료 계정)
- 초과 시 24시간 전송 차단

**비용:**
- **완전 무료**

### 총 예상 비용

**월 10,000 사용자:**
- Firebase Functions: **$0**
- Gmail SMTP: **$0**
- **총 비용: $0**

---

## 🔒 보안 권장 사항

### 1. Gmail 앱 비밀번호 보안
- ✅ Firebase Functions Config에만 저장
- ❌ 절대 코드에 하드코딩하지 않기
- ❌ Git에 커밋하지 않기
- ✅ 정기적으로 비밀번호 변경

### 2. Firestore 보안 규칙
- ✅ 사용자별 데이터 접근 제한
- ✅ Cloud Functions 전용 컬렉션 차단
- ✅ 읽기/쓰기 권한 최소화

### 3. Functions 보안
- ✅ 환경 변수만 사용
- ✅ 입력 데이터 검증
- ✅ 오류 로깅 및 모니터링

---

## 📚 추가 리소스

**공식 문서:**
- [Firebase Functions 시작하기](https://firebase.google.com/docs/functions/get-started)
- [Nodemailer Gmail 설정](https://nodemailer.com/usage/using-gmail/)
- [Firebase Functions Config](https://firebase.google.com/docs/functions/config-env)

**프로젝트 문서:**
- `firebase_setup/FIREBASE_SETUP_README.md` - 빠른 시작
- `firebase_setup/firebase_functions_setup.md` - 상세 가이드

---

## ✅ 배포 완료 체크리스트

- [ ] Gmail 앱 비밀번호 생성 완료
- [ ] Firebase CLI 설치 및 로그인 완료
- [ ] Gmail 환경 변수 설정 완료
- [ ] npm 패키지 설치 완료
- [ ] Functions 배포 완료
- [ ] Firestore 보안 규칙 배포 완료
- [ ] Firebase Console에서 Functions 확인 완료
- [ ] 테스트 이메일 전송 성공
- [ ] FCM 푸시 알림 테스트 성공
- [ ] 로그 확인 완료

---

## 🎉 배포 완료!

Firebase Functions가 성공적으로 배포되었습니다!
이제 Flutter 앱에서 다중 기기 로그인 및 이메일 인증 기능이 완전히 작동합니다.

**다음 단계:**
1. Flutter 앱에서 전체 플로우 테스트
2. 실제 기기에서 FCM 푸시 테스트
3. 프로덕션 환경으로 배포

**문제가 발생하면:**
- Firebase Console → Functions → 로그 확인
- `firebase functions:log` 명령어로 실시간 로그 확인
- 이 가이드의 트러블슈팅 섹션 참조

---

**배포 성공을 축하합니다! 🎊**
