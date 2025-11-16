# 🍎 Firebase iOS 인증 설정 가이드

## iOS는 SHA 인증서가 아닌 다른 방식 사용!

Android와 달리 iOS는 **SHA 인증서를 사용하지 않습니다**. 대신 다음을 사용합니다:

---

## 📱 iOS Firebase 인증 방법

### 1️⃣ **Bundle Identifier (필수)**

iOS 앱은 **Bundle ID**로 Firebase와 연결됩니다.

#### 확인 방법:
```bash
# ios/Runner.xcodeproj/project.pbxproj 파일에서 확인
cd /home/user/flutter_app
grep -A 5 "PRODUCT_BUNDLE_IDENTIFIER" ios/Runner.xcodeproj/project.pbxproj | head -10
```

또는:

```bash
# ios/Runner/Info.plist에서 확인
grep -A 1 "CFBundleIdentifier" ios/Runner/Info.plist
```

#### Firebase Console 설정:
```
1. Firebase Console → Project Settings (⚙️)
2. iOS 앱 선택 (없으면 추가)
3. Bundle ID 확인/입력
4. GoogleService-Info.plist 다운로드
5. ios/Runner/ 폴더에 배치
```

---

### 2️⃣ **APNs 인증 키/인증서 (푸시 알림용)**

Firebase Cloud Messaging (FCM)을 iOS에서 사용하려면 필요.

#### Apple Developer 설정:
```
1. Apple Developer Console: https://developer.apple.com/account/
2. Certificates, Identifiers & Profiles 메뉴
3. Keys 섹션 → "+" 버튼
4. "Apple Push Notifications service (APNs)" 체크
5. 키 다운로드 (.p8 파일)
```

#### Firebase Console에 등록:
```
1. Firebase Console → Project Settings (⚙️)
2. Cloud Messaging 탭
3. iOS app configuration 섹션
4. "Upload" 버튼 클릭
5. APNs 인증 키 (.p8) 업로드
   - Key ID 입력
   - Team ID 입력
```

---

### 3️⃣ **GoogleService-Info.plist (필수)**

iOS용 Firebase 설정 파일입니다.

#### 다운로드 위치:
```
Firebase Console → Project Settings → iOS 앱 → GoogleService-Info.plist
```

#### 배치 위치:
```
ios/Runner/GoogleService-Info.plist
```

#### ⚠️ 중요:
- Xcode에서 프로젝트에 추가 필요
- "Copy items if needed" 체크
- Target: "Runner" 선택

---

## 🔐 iOS에서 reCAPTCHA 처리

### iOS는 자동으로 reCAPTCHA 처리!

Android와 달리 iOS는 **별도 설정 없이** Firebase가 자동으로 reCAPTCHA를 처리합니다.

#### 이유:
- iOS App Store 심사 과정에서 앱 신원 확인
- Apple의 엄격한 앱 서명 시스템
- Firebase가 Bundle ID로 앱 신원 자동 검증

#### 따라서:
- ✅ SHA 인증서 등록 불필요
- ✅ reCAPTCHA 토큰 수동 처리 불필요
- ✅ Bundle ID와 GoogleService-Info.plist만 정확하면 OK

---

## 📋 iOS 비밀번호 재설정 이메일 체크리스트

### ✅ 필수 확인사항

1. **Bundle ID 일치 확인**
   ```
   Firebase Console의 Bundle ID == ios/Runner.xcodeproj의 PRODUCT_BUNDLE_IDENTIFIER
   ```

2. **GoogleService-Info.plist 배치**
   ```
   위치: ios/Runner/GoogleService-Info.plist
   Xcode에서 프로젝트에 추가되어 있는지 확인
   ```

3. **Firebase Authentication 활성화**
   ```
   Firebase Console → Authentication → Sign-in method
   Email/Password 활성화 확인
   ```

4. **iOS 빌드 및 실행**
   ```bash
   flutter clean
   flutter pub get
   flutter run -d <iOS_DEVICE_ID>
   ```

5. **비밀번호 재설정 테스트**
   - 이메일 입력 → 재설정 이메일 보내기
   - 로그 확인: iOS는 reCAPTCHA 경고 없음
   - 이메일 도착 확인

---

## 🔧 iOS 설정 파일 확인 명령어

### Bundle ID 확인:
```bash
cd /home/user/flutter_app
grep -A 5 "PRODUCT_BUNDLE_IDENTIFIER" ios/Runner.xcodeproj/project.pbxproj
```

### GoogleService-Info.plist 존재 확인:
```bash
ls -la ios/Runner/GoogleService-Info.plist
```

### Firebase 설정 확인:
```bash
cat ios/Runner/GoogleService-Info.plist | grep -E "BUNDLE_ID|PROJECT_ID|CLIENT_ID"
```

---

## 🚨 iOS 흔한 문제 및 해결

### 1. "No Firebase App '[DEFAULT]' has been created"
**원인**: GoogleService-Info.plist 누락 또는 잘못 배치

**해결**:
```bash
# 파일 존재 확인
ls -la ios/Runner/GoogleService-Info.plist

# 없으면 Firebase Console에서 다운로드 후 배치
# Xcode에서 프로젝트에 추가 (Copy items if needed 체크)
```

### 2. Bundle ID 불일치
**원인**: Firebase Console의 Bundle ID ≠ Xcode의 Bundle ID

**해결**:
```bash
# Xcode Bundle ID 확인
grep -A 5 "PRODUCT_BUNDLE_IDENTIFIER" ios/Runner.xcodeproj/project.pbxproj

# Firebase Console에서 동일한 Bundle ID로 설정
```

### 3. 이메일 미도착 (iOS에서도)
**원인**: Firebase 설정 문제 또는 이메일 서버 문제

**해결**:
1. 스팸함 확인
2. 5-10분 대기
3. Firebase Console → Authentication → Templates 확인
4. 다른 이메일 주소로 테스트
5. Firebase Console에서 직접 전송 테스트

---

## 🎯 iOS vs Android 비교

| 구분 | Android | iOS |
|------|---------|-----|
| **인증 방식** | SHA-1/SHA-256 인증서 | Bundle Identifier |
| **설정 파일** | google-services.json | GoogleService-Info.plist |
| **파일 위치** | android/app/ | ios/Runner/ |
| **reCAPTCHA** | 수동 설정 필요 | 자동 처리 |
| **추가 인증** | SHA 등록 필수 | Bundle ID만 필요 |
| **푸시 알림** | FCM 자동 | APNs 키 필요 |

---

## 📱 iOS 시뮬레이터 vs 실제 기기

### 시뮬레이터:
- ✅ 비밀번호 재설정 이메일 테스트 가능
- ✅ Firebase Auth 모든 기능 사용 가능
- ❌ 푸시 알림 수신 불가 (APNs 필요)
- ❌ 전화/SMS 관련 기능 제한

### 실제 기기:
- ✅ 모든 기능 사용 가능
- ✅ 푸시 알림 수신 가능
- ⚠️ Apple Developer 계정 필요 (유료)
- ⚠️ Provisioning Profile 설정 필요

---

## 🔐 프로덕션 배포 시 iOS 필수사항

### 1. Apple Developer 계정 ($99/년)
- App Store Connect 접근
- 프로비저닝 프로파일 생성
- APNs 인증 키 발급

### 2. APNs 인증 키 등록
- Firebase Console에 .p8 파일 업로드
- Key ID, Team ID 설정

### 3. App Store Connect 설정
- Bundle ID 등록
- 앱 정보 입력
- 앱 심사 제출

### 4. Firebase 프로덕션 설정
- reCAPTCHA Enterprise 활성화
- App Check 설정 (선택)
- 보안 규칙 강화

---

## 💡 빠른 시작 (iOS)

가장 빠르게 iOS에서 비밀번호 재설정 이메일을 테스트하는 방법:

```bash
# 1. Bundle ID 확인
cd /home/user/flutter_app
grep -A 5 "PRODUCT_BUNDLE_IDENTIFIER" ios/Runner.xcodeproj/project.pbxproj

# 2. Firebase Console에서 iOS 앱 추가 (Bundle ID 입력)

# 3. GoogleService-Info.plist 다운로드

# 4. 파일 배치
# ios/Runner/GoogleService-Info.plist

# 5. Xcode에서 프로젝트에 추가

# 6. 앱 빌드 및 실행
flutter clean
flutter pub get
flutter run

# 7. 비밀번호 재설정 테스트
# 이메일 입력 → 재설정 이메일 보내기
# iOS는 reCAPTCHA 경고 없이 정상 작동!
```

---

## 📞 추가 도움이 필요하면

- Firebase iOS 공식 문서: https://firebase.google.com/docs/ios/setup
- Apple Developer 문서: https://developer.apple.com/documentation/
- Flutter Firebase 가이드: https://firebase.flutter.dev/docs/overview/
