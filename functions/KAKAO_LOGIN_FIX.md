# 카카오 로그인 Firebase Functions 오류 해결 가이드

## 🚨 현재 오류
```
Error: Invalid request, unable to process.
Request has invalid method. GET
```

## 🔍 문제 원인
Firebase Functions `createCustomTokenForKakao`가 다음 중 하나의 이유로 실패하고 있습니다:
1. Functions가 배포되지 않음
2. Functions region이 잘못 설정됨
3. Functions 권한 설정 문제
4. Firebase 프로젝트 설정 문제

## ✅ 해결 방법

### 1단계: Firebase Functions 배포 확인

로컬 터미널에서 다음 명령어를 실행하여 Functions가 배포되었는지 확인:

```bash
cd functions
firebase functions:list
```

예상 출력:
```
✔ functions: asia-northeast3-createCustomTokenForKakao
```

만약 함수가 보이지 않으면, 배포 필요:

```bash
firebase deploy --only functions:createCustomTokenForKakao
```

### 2단계: Firebase Console에서 확인

1. Firebase Console 접속: https://console.firebase.google.com/
2. 프로젝트 선택
3. **Functions** 메뉴로 이동
4. `createCustomTokenForKakao` 함수 확인
   - Region: `asia-northeast3`
   - Trigger: `HTTPS`
   - Status: `Active`

### 3단계: Functions 권한 확인

Functions가 배포되어 있다면, 권한 문제일 수 있습니다.

**Firebase Console에서:**
1. Functions > createCustomTokenForKakao 선택
2. **권한** 탭 클릭
3. `allUsers` 또는 인증된 사용자에게 `Cloud Functions Invoker` 권한 부여

**gcloud CLI로 권한 설정:**
```bash
gcloud functions add-iam-policy-binding createCustomTokenForKakao \
  --region=asia-northeast3 \
  --member=allUsers \
  --role=roles/cloudfunctions.invoker
```

### 4단계: Functions 재배포 (권장)

최신 코드로 Functions를 재배포:

```bash
cd /path/to/flutter_app/functions
firebase deploy --only functions:createCustomTokenForKakao --force
```

### 5단계: Flutter 앱에서 테스트

Functions 배포 후 Flutter 앱을 재시작하고 카카오 로그인 테스트:

1. 앱 완전 종료
2. 앱 재시작
3. 카카오 로그인 시도
4. 로그 확인:
   ```
   ✅ [Kakao] Firebase Custom Token 생성 완료
   ✅ [Kakao] Firebase 로그인 완료
   ```

## 🔧 로컬 개발 환경 설정 (선택사항)

로컬에서 Functions 에뮬레이터를 사용하려면:

```bash
# Firebase 에뮬레이터 설치
npm install -g firebase-tools

# 에뮬레이터 시작
cd functions
firebase emulators:start
```

Flutter 코드에서 로컬 에뮬레이터 사용:
```dart
// main.dart 또는 초기화 코드에 추가
if (kDebugMode) {
  FirebaseFunctions.instanceFor(region: 'asia-northeast3')
      .useFunctionsEmulator('localhost', 5001);
}
```

## 📊 트러블슈팅

### 오류: "CORS policy"
Functions에 CORS 헤더 추가 필요. `index.js`에서:
```javascript
const cors = require('cors')({origin: true});

exports.createCustomTokenForKakao = functions
    .region('asia-northeast3')
    .https.onRequest((req, res) => {
      cors(req, res, async () => {
        // 기존 코드...
      });
    });
```

### 오류: "UNAUTHENTICATED"
Firebase App Check 활성화 여부 확인:
1. Firebase Console > App Check
2. Flutter 앱 등록
3. App Check 토큰 사용

### 오류: "INTERNAL"
Functions 로그 확인:
```bash
firebase functions:log --only createCustomTokenForKakao
```

또는 Firebase Console > Functions > Logs 탭에서 확인

## 📝 현재 Functions 설정

**Region**: `asia-northeast3` (서울)  
**Runtime**: Node.js 18  
**Function Name**: `createCustomTokenForKakao`  
**Trigger Type**: HTTPS Callable  

**입력 파라미터**:
- `kakaoUid` (필수): 카카오 사용자 ID
- `email` (선택): 카카오 계정 이메일
- `displayName` (선택): 카카오 닉네임
- `photoUrl` (선택): 카카오 프로필 이미지

**출력**:
- `customToken`: Firebase Custom Token 문자열

## 🚀 빠른 해결 체크리스트

- [ ] Firebase Functions 배포 확인 (`firebase functions:list`)
- [ ] Functions region 확인 (`asia-northeast3`)
- [ ] Functions 권한 확인 (allUsers invoker 권한)
- [ ] Firebase Console에서 함수 상태 확인
- [ ] Functions 로그 확인 (`firebase functions:log`)
- [ ] Flutter 앱 재시작 및 재테스트
- [ ] 필요시 Functions 재배포 (`firebase deploy --only functions --force`)

## 📞 추가 지원

문제가 계속되면 다음을 확인:
1. Firebase Console의 Functions 로그
2. Flutter 앱의 디버그 로그
3. Firebase 프로젝트 설정 (결제, 할당량 등)

---

**참고 문서**:
- [Firebase Functions 배포](https://firebase.google.com/docs/functions/get-started)
- [Callable Functions](https://firebase.google.com/docs/functions/callable)
- [Functions 권한 관리](https://cloud.google.com/functions/docs/securing/managing-access-iam)
