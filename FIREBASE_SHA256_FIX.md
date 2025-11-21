# 🔑 Firebase SHA-256 인증서 지문 업데이트 가이드

## 🚨 문제
Google 로그인 실패: `ApiException: 12500` (SIGN_IN_FAILED)
→ SHA-256 인증서 지문 불일치

## ✅ 올바른 SHA-256 지문
```
EF:6E:7E:3F:AA:91:B7:FB:1E:46:81:55:CD:76:FA:F6:E5:85:1A:50:7D:6E:D5:23:01:E0:CE:04:AB:A5:F9:71
```

## 📝 Firebase Console 업데이트 단계

### 1. Firebase Console 접속
https://console.firebase.google.com/project/makecall-e81bb/settings/general

### 2. Android 앱 설정
1. **프로젝트 설정** → **일반** 탭
2. **내 앱** 섹션에서 Android 앱 찾기
3. **SHA 인증서 지문** 섹션으로 스크롤

### 3. SHA-256 지문 추가
**중요:** 기존 지문을 삭제하지 말고 **새 지문을 추가**하세요!

1. **"지문 추가"** 버튼 클릭
2. 다음 값 입력:
   ```
   EF:6E:7E:3F:AA:91:B7:FB:1E:46:81:55:CD:76:FA:F6:E5:85:1A:50:7D:6E:D5:23:01:E0:CE:04:AB:A5:F9:71
   ```
3. **저장** 클릭

### 4. google-services.json 다운로드 (선택사항)
새 SHA-256이 추가되면 Firebase에서 자동으로 업데이트됨
필요시 새 `google-services.json` 다운로드 후 `android/app/` 에 교체

### 5. 변경사항 적용 대기
- Firebase 설정 변경 후 **최대 5분** 대기
- Google 서버에 변경사항 전파되는 시간 필요

## 🧪 테스트

### 앱 재빌드 및 테스트
```bash
# APK 빌드 (release 모드)
flutter build apk --release

# 디바이스에 설치
adb install -r build/app/outputs/flutter-apk/app-release.apk

# Google 로그인 테스트
```

### 성공 로그 확인
```
I/flutter: 🔵 [Google] 로그인 시작
I/flutter: ✅ [Google] Google 계정 선택 완료
I/flutter: ✅ [Google] Firebase 로그인 성공
```

## 📱 추가 확인 사항

### SHA-1 지문도 추가 (선택사항)
일부 Google 서비스는 SHA-1도 필요할 수 있음:
```bash
keytool -list -v -keystore android/release-key.jks \
  -alias release \
  -storepass 'ehySFRmG16vf@NLeaJf0' \
  | grep -i "sha1"
```

### Debug 빌드용 SHA-256
개발 중에는 debug 키스토어의 SHA-256도 추가:
```bash
keytool -list -v -keystore ~/.android/debug.keystore \
  -alias androiddebugkey \
  -storepass android \
  -keypass android \
  | grep -i "sha256"
```

## 🔗 참고 링크
- [Firebase 인증서 지문 가이드](https://developers.google.com/android/guides/client-auth)
- [Google Sign-In 문제 해결](https://developers.google.com/identity/sign-in/android/troubleshooting)
