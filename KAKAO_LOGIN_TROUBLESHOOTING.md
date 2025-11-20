# 카카오 로그인 문제 해결 가이드

## 🚨 현재 오류 증상

카카오 로그인 시 다음과 같은 오류가 발생:
```
Error: Invalid request, unable to process.
Request has invalid method. GET
Function: createCustomTokenForKakao
Region: asia-northeast3
```

## 🔍 원인 분석

이 오류는 Firebase Functions `createCustomTokenForKakao`가 제대로 배포되지 않았거나, 잘못된 설정으로 인해 발생합니다.

### 가능한 원인들:
1. ❌ Firebase Functions가 배포되지 않음
2. ❌ Functions region이 일치하지 않음
3. ❌ Functions 권한이 올바르게 설정되지 않음
4. ❌ Firebase 프로젝트 설정 문제 (결제, 할당량 등)

## ✅ 해결 방법

### 방법 1: 빠른 배포 스크립트 사용 (권장)

```bash
cd functions
./deploy-kakao-function.sh
```

이 스크립트는 자동으로:
- ✅ 의존성 확인 및 설치
- ✅ 코드 검사 (ESLint)
- ✅ createCustomTokenForKakao 함수만 배포
- ✅ 배포 결과 확인

### 방법 2: 수동 배포

```bash
# 1. functions 디렉토리로 이동
cd functions

# 2. 의존성 설치 (첫 배포 시에만)
npm install

# 3. Firebase 로그인 확인
firebase login

# 4. 현재 프로젝트 확인
firebase use

# 5. 함수 배포
firebase deploy --only functions:createCustomTokenForKakao --force
```

### 방법 3: Firebase Console에서 확인

1. **Firebase Console 접속**: https://console.firebase.google.com/
2. **프로젝트 선택**: makecallio
3. **Functions 메뉴**: 좌측 메뉴에서 "Functions" 클릭
4. **함수 확인**:
   - 함수 이름: `createCustomTokenForKakao`
   - Region: `asia-northeast3` (서울)
   - Trigger: `HTTPS`
   - Status: `Active` (녹색)

만약 함수가 보이지 않으면, 위의 배포 방법으로 배포 필요.

## 🔧 권한 설정 확인

Functions가 배포되어 있다면, 권한 문제일 수 있습니다.

### Firebase Console에서 권한 설정:

1. Functions > `createCustomTokenForKakao` 클릭
2. **권한 (Permissions)** 탭 선택
3. **주 구성원 추가** 클릭
4. 다음 중 하나 선택:
   - `allUsers` (모든 사용자 허용)
   - 또는 특정 서비스 계정
5. 역할: `Cloud Functions 호출자 (Cloud Functions Invoker)`
6. 저장

### gcloud CLI로 권한 설정:

```bash
gcloud functions add-iam-policy-binding createCustomTokenForKakao \
  --region=asia-northeast3 \
  --member=allUsers \
  --role=roles/cloudfunctions.invoker \
  --project=makecallio
```

## 📊 배포 확인

배포 후 다음 명령어로 확인:

```bash
# 배포된 함수 목록
firebase functions:list

# 특정 함수 상세 정보
gcloud functions describe createCustomTokenForKakao \
  --region=asia-northeast3 \
  --project=makecallio
```

예상 출력:
```
✔ functions: asia-northeast3-createCustomTokenForKakao
  Status: ACTIVE
  Trigger: HTTPS
  URL: https://asia-northeast3-makecallio.cloudfunctions.net/createCustomTokenForKakao
```

## 🧪 테스트

### 1. Firebase Console에서 테스트

1. Functions > `createCustomTokenForKakao` 클릭
2. **테스트** 탭 선택
3. 테스트 데이터 입력:
```json
{
  "kakaoUid": "test123",
  "email": "test@example.com",
  "displayName": "테스트사용자",
  "photoUrl": "https://example.com/photo.jpg"
}
```
4. **테스트 실행** 클릭
5. 결과 확인: `{ "customToken": "..." }` 형식의 응답

### 2. Flutter 앱에서 테스트

```bash
# Flutter 앱 재시작
flutter run

# 카카오 로그인 시도
# 디버그 로그 확인:
# ✅ [Kakao] Firebase Custom Token 생성 완료
# ✅ [Kakao] Firebase 로그인 완료
```

## 📝 로그 확인

문제가 계속되면 로그를 확인:

```bash
# 최근 로그 확인
firebase functions:log --only createCustomTokenForKakao

# 실시간 로그 스트리밍
firebase functions:log --only createCustomTokenForKakao --follow
```

또는 Firebase Console > Functions > Logs 탭에서 확인

## 🔄 재배포가 필요한 경우

다음과 같은 경우 재배포 필요:

1. Functions 코드 변경
2. Node.js 버전 변경
3. 의존성 업데이트
4. Region 변경

```bash
# 강제 재배포
firebase deploy --only functions:createCustomTokenForKakao --force
```

## 💡 로컬 개발 (선택사항)

로컬에서 Functions 에뮬레이터 사용:

```bash
# 에뮬레이터 시작
cd functions
firebase emulators:start

# Flutter 앱에서 로컬 에뮬레이터 사용
# lib/main.dart 또는 초기화 코드에 추가:
```

```dart
import 'package:flutter/foundation.dart';

void main() async {
  // ... Firebase 초기화 ...
  
  // 로컬 에뮬레이터 사용 (디버그 모드에서만)
  if (kDebugMode) {
    FirebaseFunctions.instanceFor(region: 'asia-northeast3')
        .useFunctionsEmulator('localhost', 5001);
  }
  
  runApp(MyApp());
}
```

## 🚨 일반적인 오류 해결

### "CORS policy" 오류
- Functions에 CORS 설정 추가 필요
- 현재 코드는 이미 CORS 지원 (`https.onCall` 사용)

### "UNAUTHENTICATED" 오류
- App Check 설정 확인
- Functions 권한 확인

### "INTERNAL" 오류
- Functions 로그 확인
- Firestore 권한 확인
- Admin SDK 초기화 확인

### "DEADLINE_EXCEEDED" 오류
- Functions 타임아웃 설정 확인 (기본 60초)
- 네트워크 연결 확인

## 📞 추가 지원

문제가 계속되면:
1. `functions/KAKAO_LOGIN_FIX.md` 참조
2. Firebase Console의 Functions 로그 확인
3. Flutter 앱의 디버그 로그 확인
4. Firebase 프로젝트 결제 및 할당량 확인

---

## 📋 체크리스트

배포 전 확인사항:

- [ ] Firebase CLI 설치 (`npm install -g firebase-tools`)
- [ ] Firebase 로그인 (`firebase login`)
- [ ] 올바른 프로젝트 선택 (`firebase use makecallio`)
- [ ] Node.js 22 버전 사용 (`node --version`)
- [ ] functions 디렉토리에 node_modules 존재

배포 후 확인사항:

- [ ] Functions 목록에서 함수 확인 (`firebase functions:list`)
- [ ] Firebase Console에서 함수 상태 확인 (Active)
- [ ] Functions 권한 설정 확인 (allUsers invoker)
- [ ] Flutter 앱 재시작
- [ ] 카카오 로그인 테스트
- [ ] 로그 확인 (오류 없음)

---

**마지막 업데이트**: 2025-11-20  
**Firebase 프로젝트**: makecallio  
**Functions Region**: asia-northeast3 (서울)
