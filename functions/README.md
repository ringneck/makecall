# 📧 MAKECALL Firebase Cloud Functions

이메일 인증 및 FCM 푸시 알림을 위한 Firebase Cloud Functions 프로젝트입니다.

## 🌏 리전: asia-northeast3 (서울)

모든 Functions는 서울 리전에 배포됩니다.

## 📋 Functions 목록

### 1. **sendVerificationEmail** (Firestore Trigger)
- **트리거**: `email_verification_requests` 컬렉션 문서 생성
- **기능**: 새 기기 로그인 시 이메일 인증 코드 전송
- **사용**: Gmail SMTP

### 2. **sendApprovalNotification** (Firestore Trigger)
- **트리거**: `fcm_approval_notification_queue` 컬렉션 문서 생성
- **기능**: 기기 승인 요청 FCM 푸시 알림 전송
- **자동**: 무효 FCM 토큰 정리

### 3. **cleanupExpiredRequests** (Scheduled)
- **스케줄**: 매시간 실행
- **기능**: 만료된 이메일 인증 요청 및 기기 승인 요청 정리
- **타임아웃**: 5분

### 4. **sendIncomingCallNotification** (HTTPS)
- **타입**: HTTP POST 요청
- **기능**: 수신전화 FCM 푸시 알림 전송
- **호출**: DCMIWS Newchannel 이벤트 발생 시
- **URL**: `https://asia-northeast3-makecallio.cloudfunctions.net/sendIncomingCallNotification`

### 5. **cancelIncomingCallNotification** (Callable)
- **타입**: Firebase Callable Function
- **기능**: 한 기기에서 통화 수락/거부 시 다른 기기 알림 취소
- **호출**: Flutter 앱에서 직접 호출

## 🚀 빠른 시작

### 1. 환경 설정

```bash
# 1. functions 디렉토리로 이동
cd functions

# 2. npm 패키지 설치
npm install

# 3. .env 파일 생성
cp .env.example .env

# 4. .env 파일 편집 (Gmail 정보 입력)
nano .env
```

### 2. 배포

```bash
# Firebase Functions 배포
firebase deploy --only functions
```

자세한 배포 가이드는 [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)를 참고하세요.

## 📦 의존성

- **firebase-admin**: ^12.0.0
- **firebase-functions**: ^4.5.0
- **nodemailer**: ^6.9.7
- **dotenv**: ^16.3.1

## 🔧 개발 스크립트

```bash
# 로컬 에뮬레이터 실행
npm run serve

# Functions Shell 실행
npm run shell

# 배포
npm run deploy

# 로그 확인
npm run logs

# Lint 검사
npm run lint
```

## 🔐 환경 변수

환경 변수는 `functions/.env` 파일에서 관리합니다:

```env
GMAIL_EMAIL=your-email@gmail.com
GMAIL_PASSWORD=your-app-password
```

⚠️ **주의**: `.env` 파일은 절대 Git에 커밋하지 마세요!

## 📊 배포 후 확인

### Firebase Console
- Functions 메뉴에서 모든 Functions가 `asia-northeast3` 리전에 배포되었는지 확인
- Cloud Scheduler에서 `cleanupExpiredRequests` 스케줄 확인

### 로그 확인
```bash
# 전체 로그
firebase functions:log --region asia-northeast3

# 실시간 로그 스트리밍
firebase functions:log --region asia-northeast3 --follow
```

## 🧪 테스트

### 로컬 테스트
```bash
# 로컬 에뮬레이터 시작
npm run serve

# 다른 터미널에서 테스트
curl -X POST http://localhost:5001/makecallio/asia-northeast3/sendIncomingCallNotification \
  -H "Content-Type: application/json" \
  -d '{"callerNumber":"16682471","receiverNumber":"07045144801","linkedid":"test123"}'
```

### 프로덕션 테스트
1. **이메일 인증**: Flutter 앱에서 새 기기 로그인
2. **FCM 푸시**: 기기 승인 요청 또는 수신전화 테스트
3. **스케줄러**: Firebase Console에서 수동 실행

## 🔄 마이그레이션 내역

### ✅ 2024-11-14: dotenv 마이그레이션 완료
- `functions.config()` → `process.env` (dotenv)
- 2026년 3월 지원 종료 대비 완료

### ✅ 2024-11-14: 리전 변경 완료
- us-central1 → asia-northeast3 (서울)
- 레이턴시 약 80-90% 감소 예상

## 📚 문서

- [배포 가이드](./DEPLOYMENT_GUIDE.md)
- [Firebase Functions 공식 문서](https://firebase.google.com/docs/functions)
- [환경 변수 마이그레이션](https://firebase.google.com/docs/functions/config-env#migrate-to-dotenv)

## 🐛 문제 해결

문제 발생 시 [DEPLOYMENT_GUIDE.md의 문제 해결 섹션](./DEPLOYMENT_GUIDE.md#4-문제-해결)을 참고하세요.

---

**프로젝트**: MAKECALL  
**리전**: asia-northeast3 (서울)  
**Node.js**: 22  
**마지막 업데이트**: 2024-11-14
