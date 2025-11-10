# Firebase Functions 배포 최종 솔루션

## 🚨 문제 상황

### 발생한 오류
```bash
=== Deploying to 'staging'...

Error: Request to https://cloudresourcemanager.googleapis.com/v1/projects/staging 
had HTTP Error: 403, The caller does not have permission
```

### 근본 원인
1. **Firebase CLI 인증 문제**: `firebase login` 필요
2. **서비스 계정 제약**: `firebase-admin-sdk.json`은 Firestore/FCM 작업만 가능, 배포 권한 없음
3. **샌드박스 환경**: 브라우저 기반 OAuth 인증 불가능

### 왜 `staging` 프로젝트로 배포하려고 할까?
- `.firebaserc`는 `makecallio`로 설정되어 있음
- Firebase CLI가 인증되지 않아 기본값으로 `staging` 사용
- 실제로는 `makecallio` 프로젝트에 배포해야 함

---

## ✅ 해결 방법 3가지

### 🎯 방법 1: Firebase Console 웹 UI (가장 간단 - 강력 추천)

Firebase Console에서 직접 코드를 업로드하여 배포합니다.

#### Step 1: functions.zip 다운로드
**파일 위치:** `/home/user/flutter_app/functions.zip` (92KB)

샌드박스에서 로컬 PC로 다운로드하세요.

#### Step 2: Firebase Console 접속
1. 브라우저에서 [Firebase Console](https://console.firebase.google.com/) 접속
2. Google 계정으로 로그인
3. **makecallio** 프로젝트 클릭

#### Step 3: Cloud Functions 페이지 이동
1. 왼쪽 메뉴에서 **"Functions"** 클릭
2. 함수 목록 페이지로 이동

#### Step 4: 소스 코드 배포
**옵션 A - 새로운 함수 추가 방식:**
1. **"함수 만들기"** 버튼 클릭
2. **"2nd gen"** 선택 (Firebase Functions v2)
3. 함수 이름 입력 (예: `sendIncomingCallNotification`)
4. 리전: **asia-east1** 선택
5. **"소스 코드"** 섹션에서 **"ZIP 업로드"** 선택
6. `functions.zip` 파일 업로드
7. 진입점: 함수 이름 입력 (예: `sendIncomingCallNotification`)
8. **"배포"** 버튼 클릭
9. 나머지 10개 함수도 반복

**옵션 B - Cloud Build 트리거 사용 (권장):**
1. 상단 **"소스 코드 업로드"** 또는 **"Cloud Build 설정"** 클릭
2. GitHub 또는 Cloud Source Repository 연결
3. 코드 푸시 시 자동 배포 설정

#### Step 5: 배포 확인
- 각 함수 옆에 ✅ 초록색 체크 확인
- 배포 시간: 약 3-5분 소요
- 11개 함수 모두 활성화 확인

---

### 🖥️ 방법 2: 로컬 PC에서 Firebase CLI 배포 (권장)

로컬 PC에 Firebase CLI를 설치하고 OAuth 인증 후 배포합니다.

#### 사전 준비
```bash
# Node.js 설치 확인
node --version

# Firebase CLI 설치
npm install -g firebase-tools

# 설치 확인
firebase --version
```

#### Step 1: functions.zip 다운로드 및 압축 해제
```bash
# 샌드박스에서 다운로드한 functions.zip
unzip functions.zip

# Flutter 프로젝트 디렉토리 준비
mkdir flutter_app
cd flutter_app

# functions 디렉토리 이동
mv ../functions ./
```

#### Step 2: Firebase 설정 파일 생성
**.firebaserc 생성:**
```json
{
  "projects": {
    "default": "makecallio"
  }
}
```

**firebase.json 생성:**
```json
{
  "functions": [
    {
      "source": "functions",
      "codebase": "default",
      "ignore": [
        "node_modules",
        ".git",
        "firebase-debug.log",
        "firebase-debug.*.log"
      ],
      "predeploy": [
        "npm --prefix \"$RESOURCE_DIR\" run lint"
      ]
    }
  ]
}
```

#### Step 3: Firebase 로그인
```bash
firebase login
```
- 브라우저가 자동으로 열림
- Google 계정으로 로그인
- Firebase 접근 권한 허용
- 터미널로 돌아와서 "Success!" 메시지 확인

#### Step 4: 프로젝트 선택 확인
```bash
# 현재 프로젝트 확인
firebase use

# 프로젝트 목록 확인
firebase projects:list

# makecallio 프로젝트 선택
firebase use makecallio
```

#### Step 5: Functions 배포
```bash
# 모든 함수 배포
firebase deploy --only functions

# 또는 특정 함수만 배포
firebase deploy --only functions:sendIncomingCallNotification,functions:remoteLogout

# 배포 진행 상황 확인
# 약 3-5분 소요
```

#### Step 6: 배포 완료 확인
```bash
# 배포된 함수 목록 확인
firebase functions:list

# 함수 로그 확인
firebase functions:log
```

---

### 🤖 방법 3: GitHub Actions 자동 배포 (CI/CD)

GitHub 저장소와 연동하여 자동 배포합니다.

#### Step 1: GitHub Repository 생성
1. [GitHub](https://github.com) 접속
2. 새 저장소 생성: `makecall-firebase-functions`
3. 프라이빗 저장소 권장

#### Step 2: 코드 업로드
```bash
# 로컬 PC에서
git init
git add .
git commit -m "Initial commit: Firebase Functions v2"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/makecall-firebase-functions.git
git push -u origin main
```

#### Step 3: Firebase Token 생성
```bash
# 로컬 PC에서
firebase login:ci
```
- 브라우저에서 Google 로그인
- 생성된 토큰 복사 (예: `1//0g...`)

#### Step 4: GitHub Secrets 설정
1. GitHub 저장소 페이지에서 **Settings** 클릭
2. 왼쪽 메뉴에서 **Secrets and variables** → **Actions** 클릭
3. **New repository secret** 버튼 클릭
4. Name: `FIREBASE_TOKEN`
5. Value: 복사한 토큰 붙여넣기
6. **Add secret** 버튼 클릭

#### Step 5: GitHub Actions Workflow 생성
**.github/workflows/deploy-functions.yml 파일 생성:**
```yaml
name: Deploy Firebase Functions

on:
  push:
    branches:
      - main
    paths:
      - 'functions/**'
  workflow_dispatch:

jobs:
  deploy:
    name: Deploy to Firebase
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: functions/package-lock.json
      
      - name: Install dependencies
        run: |
          cd functions
          npm ci
      
      - name: Run ESLint
        run: |
          cd functions
          npm run lint
      
      - name: Deploy to Firebase
        env:
          FIREBASE_TOKEN: ${{ secrets.FIREBASE_TOKEN }}
        run: |
          npm install -g firebase-tools
          firebase deploy --only functions --project makecallio --token "$FIREBASE_TOKEN"
```

#### Step 6: 자동 배포 실행
```bash
# 코드 변경 후 푸시
git add functions/
git commit -m "Update functions"
git push origin main

# GitHub Actions 자동 실행됨
# 진행 상황: https://github.com/YOUR_USERNAME/makecall-firebase-functions/actions
```

---

## 📋 배포 후 확인 사항

### 1. Firebase Console에서 확인
**URL:** https://console.firebase.google.com/project/makecallio/functions

**확인 항목:**
- ✅ 11개 함수 모두 초록색 상태
- ✅ 각 함수의 URL 생성됨
- ✅ 리전: asia-east1
- ✅ 트리거 타입: Firestore, Callable, HTTP

### 2. 함수 URL 확인
배포 완료 후 각 함수의 URL을 확인할 수 있습니다:

**Callable Functions:**
```
https://asia-east1-makecallio.cloudfunctions.net/remoteLogout
https://asia-east1-makecallio.cloudfunctions.net/cleanupExpiredTokens
https://asia-east1-makecallio.cloudfunctions.net/manualCleanupTokens
https://asia-east1-makecallio.cloudfunctions.net/sendGroupMessage
https://asia-east1-makecallio.cloudfunctions.net/processScheduledNotifications
https://asia-east1-makecallio.cloudfunctions.net/sendCustomNotification
https://asia-east1-makecallio.cloudfunctions.net/subscribeWebPush
https://asia-east1-makecallio.cloudfunctions.net/validateAllTokens
```

**HTTP Functions:**
```
https://asia-east1-makecallio.cloudfunctions.net/getNotificationStats
```

**Firestore Triggers:**
- `sendForceLogoutNotification` - URL 없음 (자동 실행)
- `sendIncomingCallNotification` - URL 없음 (자동 실행)
- `sendCallStatusNotification` - URL 없음 (자동 실행)

### 3. 함수 테스트
**HTTP Function 테스트:**
```bash
curl https://asia-east1-makecallio.cloudfunctions.net/getNotificationStats
```

**예상 응답:**
```json
{
  "activeTokens": 5,
  "processedLogouts": 12,
  "pendingScheduledNotifications": 0,
  "timestamp": "2025-11-10T04:51:23.456Z"
}
```

**Callable Function 테스트 (Flutter 앱):**
```dart
final callable = FirebaseFunctions.instance
    .httpsCallable('getNotificationStats');
final result = await callable.call();
print('통계: ${result.data}');
```

**Firestore Trigger 테스트:**
```dart
// incoming_calls 컬렉션에 문서 생성
await FirebaseFirestore.instance.collection('incoming_calls').add({
  'userId': 'user_123',
  'callerNumber': '010-1234-5678',
  'callerName': '홍길동',
  'extension': '1001',
  'timestamp': FieldValue.serverTimestamp(),
});
// → sendIncomingCallNotification 자동 실행
// → FCM 푸시 알림 전송
```

### 4. 로그 확인
**Firebase Console 로그:**
https://console.firebase.google.com/project/makecallio/functions/logs

**Cloud Logging:**
https://console.cloud.google.com/logs/query?project=makecallio

**필터 예시:**
```
resource.type="cloud_function"
resource.labels.function_name="sendIncomingCallNotification"
severity>=DEFAULT
```

---

## 🔧 트러블슈팅

### 문제 1: 403 Permission Denied
**증상:**
```
Error: HTTP Error: 403, The caller does not have permission
```

**해결 방법:**
1. Firebase 로그인 확인: `firebase login`
2. 프로젝트 권한 확인: Firebase Console → Settings → Users and permissions
3. 필요한 역할: Owner 또는 Editor

### 문제 2: 함수가 배포되지만 실행 실패
**증상:**
- 함수는 ✅ 초록색
- 실행 시 오류 발생

**확인 사항:**
1. **Firestore 규칙**: Functions가 데이터 읽기/쓰기 가능한지
2. **IAM 권한**: Cloud Functions 서비스 계정 권한
3. **환경 변수**: 필요한 환경 변수 설정

**해결 방법:**
```bash
# 로그 확인
firebase functions:log --only sendIncomingCallNotification

# 또는 Cloud Logging에서 확인
```

### 문제 3: 배포 시간이 너무 오래 걸림
**증상:**
- 배포가 10분 이상 소요

**해결 방법:**
```bash
# 변경된 함수만 배포
firebase deploy --only functions:sendIncomingCallNotification

# 또는 병렬 배포
firebase deploy --only functions --force
```

---

## 📊 배포 비교표

| 방법 | 난이도 | 시간 | 자동화 | 권장도 |
|------|--------|------|--------|--------|
| Firebase Console | ⭐ 쉬움 | 5분 | ❌ | ⭐⭐⭐⭐⭐ |
| 로컬 Firebase CLI | ⭐⭐ 보통 | 3분 | ✅ | ⭐⭐⭐⭐ |
| GitHub Actions | ⭐⭐⭐ 어려움 | 초기 10분 | ✅✅ | ⭐⭐⭐⭐⭐ |

---

## 💡 최종 추천

### 🥇 1순위: 로컬 PC에서 Firebase CLI (권장)
**장점:**
- ✅ 가장 빠르고 간단함 (3분)
- ✅ 한 번에 11개 함수 모두 배포
- ✅ 명령어 한 줄로 완료
- ✅ 로그 즉시 확인 가능

**단점:**
- ⚠️ Firebase CLI 설치 필요
- ⚠️ 로컬 PC에서 작업 필요

**명령어:**
```bash
firebase login
firebase deploy --only functions
```

### 🥈 2순위: Firebase Console 웹 UI
**장점:**
- ✅ 별도 설치 불필요
- ✅ 시각적으로 확인 가능
- ✅ 권한 문제 없음

**단점:**
- ⚠️ 함수마다 개별 업로드 필요 (시간 소요)
- ⚠️ ZIP 파일 수동 다운로드 필요

### 🥉 3순위: GitHub Actions (장기적 권장)
**장점:**
- ✅ 완전 자동화
- ✅ 코드 푸시 시 자동 배포
- ✅ CI/CD 파이프라인 구축

**단점:**
- ⚠️ 초기 설정 복잡함 (10분)
- ⚠️ GitHub 저장소 필요

---

## 📁 필요한 파일

**배포에 필요한 파일 목록:**
```
flutter_app/
├── functions.zip (92KB) ✅ 준비 완료
├── .firebaserc ✅ 준비 완료
├── firebase.json ✅ 준비 완료
└── functions/
    ├── index.js ✅ 준비 완료
    ├── package.json ✅ 준비 완료
    └── package-lock.json ✅ 준비 완료
```

**다운로드 위치:**
- `/home/user/flutter_app/functions.zip`

---

## ✅ 체크리스트

### 배포 전
- [x] Logger import 오류 수정
- [x] ESLint 검사 통과
- [x] JavaScript 문법 검사 통과
- [x] functions.zip 생성
- [ ] 배포 방법 선택 (Console / CLI / GitHub Actions)

### 배포 중
- [ ] Firebase 로그인 (CLI 사용 시)
- [ ] 프로젝트 선택: makecallio
- [ ] 배포 명령 실행
- [ ] 진행 상황 확인

### 배포 후
- [ ] 11개 함수 모두 ✅ 확인
- [ ] 함수 URL 확인
- [ ] 테스트 실행
- [ ] 로그 확인

---

**다음 단계:**
1. 배포 방법 선택 (로컬 CLI 권장)
2. `functions.zip` 다운로드
3. 배포 실행
4. 테스트 및 확인 ✅

모든 준비가 완료되었습니다! 🚀
