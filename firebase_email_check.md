# 🔍 Firebase 비밀번호 재설정 이메일 미도착 체크리스트

## 1. Firebase Console 확인사항

### ✅ Authentication 활성화 확인
1. Firebase Console → Authentication → Sign-in method
2. "Email/Password" 제공업체가 **활성화**되어 있는지 확인

### ✅ 이메일 템플릿 설정 확인
1. Firebase Console → Authentication → Templates
2. "비밀번호 재설정" 템플릿 클릭
3. **발신자 이름**과 **발신자 이메일** 설정 확인
   - 기본값: `noreply@makecallio.firebaseapp.com`
   - 커스텀 도메인 설정 시: 도메인 인증 필요

### ✅ 사용자 존재 확인
1. Firebase Console → Authentication → Users
2. 테스트하는 이메일 주소가 **실제 등록된 사용자**인지 확인
3. 존재하지 않는 이메일은 전송되지 않음 (보안상 에러 메시지 동일)

## 2. 일반적인 이메일 미도착 원인

### 🔴 스팸 메일함 확인
- Gmail, Naver, Daum 등 스팸함 확인
- Firebase 발신 이메일은 종종 스팸으로 분류됨

### 🔴 이메일 주소 오타
- 입력한 이메일 주소가 정확한지 재확인
- 공백 문자나 특수문자 확인

### 🔴 이메일 발송 지연
- Firebase 이메일은 최대 **5-10분** 지연 가능
- 즉시 도착하지 않을 수 있음

### 🔴 Firebase 프로젝트 할당량 초과
- 무료 플랜: 하루 100건 제한
- 많은 테스트로 할당량 소진 가능

### 🔴 이메일 제공업체 차단
- 일부 기업 이메일은 Firebase 발신자 차단
- Gmail, Naver 개인 이메일로 테스트 권장

## 3. Firebase Console에서 직접 테스트

### 방법 1: Firebase Console에서 직접 전송
```
1. Firebase Console → Authentication → Users
2. 사용자 선택 → "Actions" → "Send password reset email"
3. 이 방법으로도 안 오면 Firebase 설정 문제
```

### 방법 2: Firebase CLI로 테스트
```bash
# Firebase CLI 로그인
firebase login

# 프로젝트 선택
firebase use makecallio

# Auth 설정 확인
firebase auth:export users.json --format=JSON
```

## 4. 코드에서 상세 로그 추가

### 현재 코드 개선 (이미 적용됨)
```dart
✅ 성공 로그: "비밀번호 재설정 이메일 전송 성공: user@example.com"
✅ 실패 로그: "비밀번호 재설정 이메일 전송 실패: {에러코드}"
```

### 추가 확인사항
- 로그에 **"전송 성공"**이 출력되면 Firebase는 이메일을 발송함
- Firebase에서 성공 응답 후 이메일 도착 실패는 **이메일 서버 문제**

## 5. 해결 방법

### 🎯 즉시 시도 가능한 방법
1. **다른 이메일 주소로 테스트** (Gmail 권장)
2. **스팸함 확인**
3. **5-10분 대기** 후 다시 확인
4. **Firebase Console에서 직접 전송** 테스트

### 🎯 Firebase 설정 확인
1. Firebase Console → Authentication → Settings
2. "Authorized domains" 확인
3. 앱 도메인이 허용 목록에 있는지 확인

### 🎯 커스텀 이메일 설정 (선택사항)
- Gmail SMTP 연동
- SendGrid, Mailgun 등 외부 이메일 서비스 연동
- 이 경우 Cloud Functions 필요

## 6. Cloud Functions 관련

### ❌ 기본 비밀번호 재설정: Cloud Functions 불필요
- Firebase Auth가 자동으로 처리
- `sendPasswordResetEmail()` API만으로 충분

### ✅ Cloud Functions가 필요한 경우
- 커스텀 이메일 템플릿
- 외부 이메일 서비스 (SendGrid 등)
- 발송 로그 저장
- 이메일 발송 전 추가 로직

## 7. 디버깅 팁

### Firebase Console에서 확인 가능한 정보
- 이메일 발송 성공/실패 여부
- 발송 시간
- 수신자 이메일
- 에러 메시지 (있는 경우)

### 앱에서 추가 로깅
```dart
try {
  await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
  print('✅ Firebase sendPasswordResetEmail 호출 성공');
  print('   이메일: $email');
  print('   시간: ${DateTime.now()}');
} catch (e) {
  print('❌ 에러: $e');
}
```

## 📞 문제 지속 시 확인사항
1. Firebase 프로젝트 결제 상태 (무료 할당량 확인)
2. Firebase 서비스 상태: https://status.firebase.google.com/
3. 이메일 제공업체 SMTP 로그 (Gmail 설정 → 전달 및 POP/IMAP)
