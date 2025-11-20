# 🔥 CRITICAL FIX: Service Account Key 직접 사용

## 문제 원인
IAM 권한은 추가했지만, Firebase Functions가 올바른 Service Account를 사용하지 못하고 있었습니다.

## 해결 방법
Service Account Key 파일을 **직접** Functions에서 사용하도록 변경했습니다.

---

## 변경 사항

### 1. Service Account Key 파일 추가
```bash
# /opt/flutter/firebase-admin-sdk.json → functions/serviceAccountKey.json
```

### 2. Functions 초기화 코드 변경
```javascript
// ❌ 이전 (자동 감지 - 실패)
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
});

// ✅ 변경 후 (직접 지정 - 확실함)
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});
```

### 3. .gitignore 업데이트
```
serviceAccountKey.json  ← GitHub에 업로드 방지
```

---

## 🚀 배포 방법 (필수!)

### 중요: Service Account Key가 포함되도록 배포해야 함

```bash
cd /home/user/flutter_app/functions

# Service Account Key 파일 확인
ls -lh serviceAccountKey.json

# 배포
firebase deploy --only functions
```

---

## ✅ 배포 후 확인

### 1. Firebase Console 확인
https://console.firebase.google.com/project/makecallio/functions

**확인 사항:**
- `createCustomTokenForKakao` 버전 업데이트
- `createCustomTokenForNaver` 버전 업데이트
- 배포 시간이 최신

### 2. 앱 테스트
```bash
# 앱 재시작
flutter run

# Kakao/Naver 로그인 시도
```

### 3. Functions 로그 확인
```bash
firebase functions:log
```

**예상 로그:**
```
🔐 [KAKAO] Creating custom token for user: kakao_xxxxx
✅ [KAKAO] Custom token created successfully
```

---

## 🎯 예상 결과

### Flutter 앱 로그 (성공 시)
```
🟡 [Kakao] 로그인 시작
🔄 [Kakao] 웹뷰 로그인 시도...
✅ [Kakao] 웹뷰 로그인 성공
✅ [Kakao] OAuth 토큰 획득 완료
🔄 [Kakao] 사용자 정보 조회 중...
✅ [Kakao] 사용자 정보 조회 완료
🔄 [Kakao] Firebase Custom Token 생성 요청 중...
✅ [Kakao] Firebase Custom Token 생성 완료  ← 이제 성공!
🔄 [Kakao] Firebase 로그인 중...
✅ [Kakao] Firebase 로그인 완료
✅ [Kakao] 전체 로그인 프로세스 성공
```

---

## 💡 왜 이 방법이 확실한가?

1. **직접 지정**: Service Account Key를 명시적으로 지정
2. **IAM 권한 확실**: Key 파일에 이미 올바른 권한이 포함됨
3. **환경 독립적**: 배포 환경에 관계없이 동일하게 작동

---

## 📋 배포 체크리스트

- [ ] 1. `functions/serviceAccountKey.json` 파일 존재 확인
- [ ] 2. `functions/index.js` 코드 변경 확인
- [ ] 3. `firebase deploy --only functions` 실행
- [ ] 4. Firebase Console에서 배포 확인
- [ ] 5. 앱 재시작 후 Kakao 로그인 테스트
- [ ] 6. Functions 로그에서 성공 메시지 확인

---

## ⚠️ 주의사항

### Service Account Key 보안
- ✅ `.gitignore`에 추가됨 (GitHub 업로드 방지)
- ✅ Firebase 배포 시에만 포함됨
- ⚠️ 절대 공개 저장소에 커밋하지 말 것

### 배포 시 포함됨
Firebase Functions 배포 시 `serviceAccountKey.json`이 자동으로 포함되어 배포됩니다.

---

## 🚨 여전히 오류 시

1. **Service Account Key 파일 내용 확인**
   ```bash
   cat functions/serviceAccountKey.json | grep project_id
   ```
   예상 출력: `"project_id": "makecallio"`

2. **Functions 로그 상세 확인**
   ```bash
   firebase functions:log --limit 100 | grep -A 20 "KAKAO"
   ```

3. **완전 재배포**
   ```bash
   cd functions
   firebase functions:delete createCustomTokenForKakao --force
   firebase functions:delete createCustomTokenForNaver --force
   sleep 10
   firebase deploy --only functions
   ```

---

## 📞 지원

이 방법으로도 해결되지 않으면:
1. Functions 로그 전체 내용 공유
2. `serviceAccountKey.json`의 project_id 확인
3. Firebase Console에서 배포 상태 스크린샷 공유

