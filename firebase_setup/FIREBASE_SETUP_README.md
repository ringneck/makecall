# 📧 MAKECALL Firebase 이메일 인증 시스템 설치 가이드

## 🚀 빠른 시작

### 1. 자동 설치 (추천)
```bash
cd /home/user
./setup_firebase_functions.sh
```

### 2. 배포
```bash
cd /home/user/flutter_app
firebase deploy --only functions,firestore:rules
```

---

## 📋 준비물

### 1. Gmail 앱 비밀번호 생성
1. Google 계정 (https://myaccount.google.com/) 접속
2. **보안** → **2단계 인증** 활성화
3. **앱 비밀번호** 생성:
   - 앱: 메일
   - 기기: 기타(사용자 설정 이름)
   - 이름: "MAKECALL Email"
4. **16자리 앱 비밀번호** 복사 저장

### 2. Firebase 프로젝트
- Firebase Console에서 프로젝트 생성
- Firestore Database 생성 (프로덕션 모드)
- Firebase CLI 로그인 완료

---

## 📁 생성된 파일

```
/home/user/
├── setup_firebase_functions.sh      # 자동 설치 스크립트
├── firebase_functions_setup.md      # 상세 설치 가이드
├── functions_index.js               # Cloud Functions 코드
├── functions_package.json           # npm 패키지 설정
└── firestore.rules                  # Firestore 보안 규칙

/home/user/flutter_app/
└── functions/                       # 배포 후 생성
    ├── index.js                     # (복사됨)
    ├── package.json                 # (복사됨)
    └── node_modules/                # (자동 생성)
```

---

## 🔧 수동 설치 (자동 설치 실패 시)

### Step 1: Firebase CLI 설치
```bash
npm install -g firebase-tools
firebase login
```

### Step 2: Functions 초기화
```bash
cd /home/user/flutter_app
firebase init functions
```

### Step 3: 파일 복사
```bash
cp /home/user/functions_package.json /home/user/flutter_app/functions/package.json
cp /home/user/functions_index.js /home/user/flutter_app/functions/index.js
cp /home/user/firestore.rules /home/user/flutter_app/firestore.rules
```

### Step 4: npm 패키지 설치
```bash
cd /home/user/flutter_app/functions
npm install
```

### Step 5: Gmail 환경 변수 설정
```bash
firebase functions:config:set gmail.email="your-email@gmail.com"
firebase functions:config:set gmail.password="your-16-digit-app-password"
```

### Step 6: 배포
```bash
cd /home/user/flutter_app
firebase deploy --only functions,firestore:rules
```

---

## 🧪 테스트 방법

### 로컬 테스트 (Emulator)
```bash
cd /home/user/flutter_app
firebase emulators:start
```

### 프로덕션 테스트
1. Flutter 앱 실행
2. 로그인 시도 (새 기기)
3. "이메일 인증 코드 받기" 클릭
4. Gmail 확인 (1-3분 소요)
5. 6자리 코드 입력
6. 승인 완료 확인

---

## 📊 배포된 Functions

### 1. sendVerificationEmail
- **트리거**: Firestore `email_verification_requests` 문서 생성
- **기능**: Gmail SMTP로 6자리 인증 코드 이메일 전송
- **실행 시간**: 평균 2-3초

### 2. sendApprovalNotification
- **트리거**: Firestore `fcm_approval_notification_queue` 문서 생성
- **기능**: FCM 푸시 알림 전송 (기기 승인 요청)
- **실행 시간**: 평균 1-2초

### 3. cleanupExpiredRequests
- **트리거**: Pub/Sub 스케줄 (매시간)
- **기능**: 만료된 인증 요청 정리
- **실행 시간**: 평균 5-10초

---

## 💰 비용 예상

### Firebase Functions (Spark Plan - 무료)
- 호출: 2,000,000회/월
- 컴퓨팅: 400,000 GB-초/월
- 네트워크: 5GB/월

### Gmail SMTP
- **완전 무료** (하루 500통 제한)

### 예상 사용량 (월 10,000 사용자)
- 이메일 인증: ~20,000회
- FCM 푸시: ~50,000회
- 정리 작업: ~720회
- **총 비용: $0 (무료 범위 내)**

---

## ⚠️ 주의사항

### Gmail 전송 제한
- **하루 500통 제한** (Gmail 무료 계정)
- 초과 시 24시간 전송 차단
- 대량 사용자: SendGrid/Mailgun 고려

### 보안
- Gmail 앱 비밀번호 절대 코드에 하드코딩 금지
- Firebase Functions Config 사용 필수
- `.env` 파일 사용 금지

### Functions 콜드 스타트
- 첫 호출 시 3-5초 지연 가능
- Blaze Plan에서 최소 인스턴스 설정 가능

---

## 🔍 로그 확인

### Firebase Console
1. Firebase Console → Functions → 로그 탭
2. 실시간 로그 확인 가능

### CLI
```bash
# 실시간 로그 스트리밍
firebase functions:log --follow

# 특정 함수 로그만 보기
firebase functions:log --only sendVerificationEmail
```

---

## 🐛 트러블슈팅

### 문제 1: "Invalid login" 오류
**원인**: Gmail 앱 비밀번호 오류
**해결**:
```bash
firebase functions:config:set gmail.password="새-비밀번호"
firebase deploy --only functions
```

### 문제 2: 이메일 전송 안 됨
**원인**: Cloud Functions 트리거 안 됨
**해결**:
1. Firebase Console → Functions → 로그 확인
2. Firestore 컬렉션 이름 확인
3. Functions 배포 상태 확인

### 문제 3: FCM 푸시 안 됨
**원인**: 잘못된 FCM 토큰
**해결**:
1. Flutter 앱에서 FCM 토큰 로그 확인
2. Firestore `fcm_tokens` 컬렉션 확인
3. Firebase Console → Cloud Messaging → 테스트 메시지

---

## 📚 추가 자료

- [Firebase Cloud Functions 공식 문서](https://firebase.google.com/docs/functions)
- [Nodemailer Gmail 가이드](https://nodemailer.com/usage/using-gmail/)
- [Firebase Functions Config](https://firebase.google.com/docs/functions/config-env)
- [Gmail SMTP 설정](https://support.google.com/mail/answer/7126229)

---

## ✅ 배포 후 확인 사항

- [ ] Functions 배포 성공
- [ ] Firestore 보안 규칙 배포 성공
- [ ] Gmail 환경 변수 설정 완료
- [ ] 테스트 이메일 전송 성공
- [ ] FCM 푸시 알림 테스트 성공
- [ ] Flutter 앱에서 전체 플로우 테스트 완료

---

## 📞 지원

문제가 있으신가요?
- GitHub Issues: [프로젝트 저장소]
- 이메일: support@makecall.com
- 상세 가이드: `/home/user/firebase_functions_setup.md`

---

**🎉 설치 완료! Flutter 앱에서 자동으로 작동합니다.**
