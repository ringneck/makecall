# 🚀 Firebase Functions 배포 가이드

## 📋 목차
1. [환경 변수 설정](#1-환경-변수-설정)
2. [Functions 배포](#2-functions-배포)
3. [배포 후 확인](#3-배포-후-확인)
4. [문제 해결](#4-문제-해결)

---

## 1. 환경 변수 설정

### ⚠️ 중요: `functions.config()` 지원 종료 (2026년 3월)

Firebase는 `functions.config()` API 지원을 2026년 3월에 종료합니다.  
이 프로젝트는 이미 **dotenv 방식**으로 마이그레이션되어 있습니다. ✅

### 📝 `.env` 파일 생성

**Step 1**: functions 디렉토리로 이동
```bash
cd functions
```

**Step 2**: `.env.example`을 복사하여 `.env` 파일 생성
```bash
cp .env.example .env
```

**Step 3**: `.env` 파일 편집
```bash
# 텍스트 에디터로 .env 파일 열기
nano .env  # 또는 vim, code, 등
```

**Step 4**: Gmail 정보 입력
```env
# Gmail 이메일 주소
GMAIL_EMAIL=your-email@gmail.com

# Gmail 앱 비밀번호 (16자리)
GMAIL_PASSWORD=abcd efgh ijkl mnop
```

### 🔐 Gmail 앱 비밀번호 생성 방법

1. **Google 계정** 접속: https://myaccount.google.com/
2. **보안** → **2단계 인증** 활성화 (필수!)
3. **보안** → **앱 비밀번호** 생성
4. 앱 선택: **메일**, 기기 선택: **기타 (사용자 지정 이름)**
5. **16자리 비밀번호** 복사 (공백 포함)
6. `.env` 파일에 붙여넣기

### ⚠️ 보안 주의사항

- ❌ `.env` 파일은 **절대 Git에 커밋하지 마세요**!
- ✅ `.env`는 이미 `.gitignore`에 포함되어 있습니다
- ✅ `.env.example`만 Git에 커밋됩니다

---

## 2. Functions 배포

### 📍 현재 리전: **asia-northeast3** (서울)

이 프로젝트의 모든 Functions는 서울 리전에 배포됩니다:
- `sendVerificationEmail`
- `sendApprovalNotification`
- `cleanupExpiredRequests`
- `sendIncomingCallNotification`
- `cancelIncomingCallNotification`

### 🚀 배포 명령어

**방법 1: 전체 배포 (권장)**
```bash
# 프로젝트 루트에서 실행
firebase deploy --only functions
```

**방법 2: 특정 Function만 배포**
```bash
firebase deploy --only functions:sendVerificationEmail
firebase deploy --only functions:sendIncomingCallNotification
```

**방법 3: 특정 리전의 Functions만 배포**
```bash
firebase deploy --only functions --region asia-northeast3
```

### 📊 배포 진행 상황

배포 시 다음과 같은 메시지가 표시됩니다:

```
✔  functions[asia-northeast3-sendVerificationEmail]: Successful create operation.
✔  functions[asia-northeast3-sendApprovalNotification]: Successful create operation.
✔  functions[asia-northeast3-cleanupExpiredRequests]: Successful create operation.
✔  functions[asia-northeast3-sendIncomingCallNotification]: Successful create operation.
✔  functions[asia-northeast3-cancelIncomingCallNotification]: Successful create operation.

✔  Deploy complete!
```

---

## 3. 배포 후 확인

### ✅ Firebase Console 확인

1. **Firebase Console** 접속: https://console.firebase.google.com/
2. **Functions** 메뉴 선택
3. 다음 항목 확인:
   - 모든 Functions가 `asia-northeast3` 리전에 배포되었는지
   - 각 Function의 상태가 **Active**인지
   - Cloud Scheduler가 정상 등록되었는지 (cleanupExpiredRequests)

### 🧪 기능 테스트

#### 1. 이메일 인증 테스트
```bash
# Flutter 앱에서 새 기기 로그인 시도
# → 이메일로 6자리 인증 코드 수신 확인
```

#### 2. FCM 푸시 알림 테스트
```bash
# 기기 승인 요청 → FCM 푸시 수신 확인
# 수신전화 → FCM 알림 수신 확인
```

#### 3. Cloud Scheduler 확인
```bash
# Firebase Console → Cloud Scheduler
# cleanupExpiredRequests가 매시간 실행되는지 확인
```

### 📋 로그 확인

```bash
# 전체 Functions 로그 확인
firebase functions:log --region asia-northeast3

# 특정 Function 로그 확인
firebase functions:log --only sendVerificationEmail --region asia-northeast3

# 실시간 로그 스트리밍
firebase functions:log --region asia-northeast3 --follow
```

---

## 4. 문제 해결

### ❌ 문제: `.env` 파일이 없다는 오류

**증상**:
```
Error: Gmail 환경 변수가 설정되지 않았습니다.
```

**해결 방법**:
1. `functions/.env` 파일이 존재하는지 확인
2. `.env` 파일에 `GMAIL_EMAIL`과 `GMAIL_PASSWORD`가 올바르게 설정되었는지 확인
3. Gmail 앱 비밀번호가 올바른지 확인 (16자리)

### ❌ 문제: 배포 시 리전 관련 오류

**증상**:
```
Error: Functions must be deployed to a single region
```

**해결 방법**:
모든 Functions가 `functions.region(region)`으로 감싸져 있는지 확인:
```javascript
exports.myFunction = functions.region(region).firestore...
```

### ❌ 문제: 기존 us-central1 Functions와 충돌

**증상**:
```
Error: Multiple functions with same name in different regions
```

**해결 방법**:
기존 us-central1 Functions를 삭제:
```bash
firebase functions:delete sendVerificationEmail --region us-central1
firebase functions:delete sendApprovalNotification --region us-central1
firebase functions:delete cleanupExpiredRequests --region us-central1
firebase functions:delete sendIncomingCallNotification --region us-central1
firebase functions:delete cancelIncomingCallNotification --region us-central1
```

### ❌ 문제: Gmail SMTP 인증 실패

**증상**:
```
Error: Invalid login: 534-5.7.9 Application-specific password required
```

**해결 방법**:
1. Gmail 계정에서 **2단계 인증** 활성화
2. **앱 비밀번호** 재생성
3. `.env` 파일 업데이트 후 재배포

### ❌ 문제: Node.js 버전 오류

**증상**:
```
Error: Unsupported Node.js version
```

**해결 방법**:
`functions/package.json`에서 Node.js 버전 확인:
```json
"engines": {
  "node": "22"
}
```

로컬 Node.js 버전과 일치하는지 확인:
```bash
node --version
```

---

## 📚 추가 리소스

- [Firebase Functions 공식 문서](https://firebase.google.com/docs/functions)
- [환경 변수 마이그레이션 가이드](https://firebase.google.com/docs/functions/config-env#migrate-to-dotenv)
- [Firebase CLI 레퍼런스](https://firebase.google.com/docs/cli)
- [Cloud Scheduler 문서](https://cloud.google.com/scheduler/docs)

---

## 🎯 체크리스트

배포 전 최종 확인:

- [ ] `functions/.env` 파일 생성 완료
- [ ] Gmail 앱 비밀번호 설정 완료
- [ ] `.env` 파일이 `.gitignore`에 포함되어 있음
- [ ] `firebase deploy --only functions` 실행
- [ ] Firebase Console에서 Functions 확인
- [ ] 이메일 인증 테스트 완료
- [ ] FCM 푸시 알림 테스트 완료
- [ ] Cloud Scheduler 정상 작동 확인
- [ ] 기존 us-central1 Functions 삭제 (선택사항)

---

## 💡 팁

### 배포 시간 단축
```bash
# 변경된 Functions만 배포
firebase deploy --only functions:functionName
```

### 개발 환경에서 테스트
```bash
# 로컬 에뮬레이터 실행
npm run serve

# Functions Shell 실행
npm run shell
```

### 프로덕션 로그 모니터링
```bash
# 실시간 로그 스트리밍
firebase functions:log --region asia-northeast3 --follow
```

---

**마지막 업데이트**: 2024-11-14  
**리전**: asia-northeast3 (서울)  
**Node.js 버전**: 22
