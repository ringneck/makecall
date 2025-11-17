# iOS Google Sign-In Keychain Error 해결 가이드

## 🔴 에러 메시지
```
keychain-error - An error occurred when accessing the keychain.
```

이 에러는 iOS에서 Google Sign-In을 사용할 때 Keychain 접근 권한이 없거나 OAuth 클라이언트 설정이 누락되어 발생합니다.

---

## ✅ 해결 방법

### 1️⃣ Keychain Sharing 추가 (이미 완료됨)

**파일**: `ios/Runner/Runner.entitlements`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<!-- 기존 설정들... -->
	
	<!-- ✅ Keychain Sharing (Google Sign-In 필수) -->
	<key>keychain-access-groups</key>
	<array>
		<string>$(AppIdentifierPrefix)com.olssoo.makecall</string>
	</array>
</dict>
</plist>
```

**✅ 완료**: 이미 추가되었습니다.

---

### 2️⃣ Firebase Console에서 iOS OAuth 클라이언트 설정

**현재 문제**: `GoogleService-Info.plist`에 `REVERSED_CLIENT_ID`가 없습니다!

#### **단계 1**: Firebase Console 접속
- URL: https://console.firebase.google.com/project/makecallio/settings/general/ios:com.olssoo.makecall

#### **단계 2**: iOS 앱 확인
- **프로젝트 설정** → **iOS 앱** 탭
- Bundle ID: `com.olssoo.makecall` (현재 설정값)
- 앱이 등록되어 있는지 확인

#### **단계 3**: 최신 GoogleService-Info.plist 다운로드
1. Firebase Console → iOS 앱 → **GoogleService-Info.plist** 다운로드
2. 다운로드한 파일을 확인하여 **REVERSED_CLIENT_ID** 키가 있는지 확인:

```xml
<key>REVERSED_CLIENT_ID</key>
<string>com.googleusercontent.apps.793164633643-xxxxxxxxxxxxxxxxxx</string>
```

3. 만약 없다면, Google Cloud Console에서 OAuth 클라이언트를 생성해야 합니다.

#### **단계 4**: Google Cloud Console에서 OAuth 클라이언트 생성

**URL**: https://console.cloud.google.com/apis/credentials?project=makecallio

1. **사용자 인증 정보** → **+ 사용자 인증 정보 만들기** → **OAuth 클라이언트 ID**
2. 애플리케이션 유형: **iOS**
3. 이름: `MAKECALL iOS`
4. Bundle ID: `com.olssoo.makecall`
5. 생성 완료 후 클라이언트 ID 확인

#### **단계 5**: Firebase Console에서 GoogleService-Info.plist 재다운로드
- OAuth 클라이언트 생성 후 Firebase Console에서 다시 다운로드
- 이제 `REVERSED_CLIENT_ID`가 포함되어야 함

#### **단계 6**: GoogleService-Info.plist 교체
```bash
# 다운로드한 파일을 프로젝트에 복사
cp ~/Downloads/GoogleService-Info.plist /home/user/flutter_app/ios/Runner/GoogleService-Info.plist
```

---

### 3️⃣ Info.plist에 URL Scheme 추가

GoogleService-Info.plist에서 `REVERSED_CLIENT_ID` 값을 복사하여 Info.plist에 추가합니다.

**파일**: `ios/Runner/Info.plist`

```xml
<dict>
	<!-- 기존 설정들... -->
	
	<!-- ✅ Google Sign-In URL Scheme -->
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleTypeRole</key>
			<string>Editor</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<!-- GoogleService-Info.plist의 REVERSED_CLIENT_ID 값 -->
				<string>com.googleusercontent.apps.793164633643-xxxxxxxxxxxxxxxxxx</string>
			</array>
		</dict>
	</array>
</dict>
```

**⚠️ CRITICAL**: `REVERSED_CLIENT_ID` 값은 GoogleService-Info.plist에서 정확히 복사해야 합니다!

---

### 4️⃣ Xcode에서 Keychain Sharing Capability 확인

Xcode를 사용할 수 있다면:

1. `ios/Runner.xcworkspace` 열기
2. **Runner** 프로젝트 선택
3. **Signing & Capabilities** 탭
4. **+ Capability** 클릭
5. **Keychain Sharing** 추가
6. Keychain Groups에 `$(AppIdentifierPrefix)com.olssoo.makecall` 자동 추가됨

---

### 5️⃣ Pod 재설치 및 Clean Build

```bash
# iOS 디렉토리로 이동
cd /home/user/flutter_app/ios

# Pod 캐시 삭제
rm -rf Pods Podfile.lock

# Pod 재설치
pod install

# Flutter Clean
cd /home/user/flutter_app
flutter clean
flutter pub get

# iOS 앱 재빌드
flutter run -d ios
```

---

## 🧪 테스트 방법

### 시뮬레이터 테스트
```bash
flutter run -d "iPhone 15 Pro"
```

Google Sign-In 버튼 클릭 시:
- ✅ Safari 웹뷰가 열리고 Google 로그인 화면 표시
- ✅ 로그인 성공 후 앱으로 돌아옴
- ✅ Firebase Authentication에 사용자 등록

### 실제 기기 테스트 (권장)
```bash
# 연결된 기기 확인
flutter devices

# 실제 기기에 설치
flutter run --release -d [DEVICE_ID]
```

---

## 🔍 디버깅 팁

### 에러 1: "keychain-error"
**원인**: Keychain Sharing Capability가 없음  
**해결**: Runner.entitlements에 keychain-access-groups 추가 (위 참조)

### 에러 2: "No application was found"
**원인**: Info.plist에 URL Scheme이 없음  
**해결**: CFBundleURLTypes에 REVERSED_CLIENT_ID 추가 (위 참조)

### 에러 3: "Invalid client ID"
**원인**: Bundle ID와 OAuth 클라이언트 ID 불일치  
**해결**: Google Cloud Console에서 Bundle ID 확인 및 OAuth 클라이언트 재생성

### 에러 4: "REVERSED_CLIENT_ID not found"
**원인**: GoogleService-Info.plist에 OAuth 설정 누락  
**해결**: Firebase Console에서 최신 파일 다운로드 또는 Google Cloud Console에서 OAuth 클라이언트 생성

---

## 📚 참고 자료

- **Google Sign-In iOS Setup**: https://developers.google.com/identity/sign-in/ios/start-integrating
- **Firebase iOS Setup**: https://firebase.google.com/docs/ios/setup
- **Google Cloud Console**: https://console.cloud.google.com/apis/credentials?project=makecallio
- **Firebase Console**: https://console.firebase.google.com/project/makecallio/settings/general/ios:com.olssoo.makecall

---

## ✅ 완료 체크리스트

설정 완료 후 아래 항목들을 확인하세요:

- [ ] `Runner.entitlements`에 keychain-access-groups 추가됨
- [ ] `GoogleService-Info.plist`에 REVERSED_CLIENT_ID 존재
- [ ] `Info.plist`에 CFBundleURLTypes 추가됨
- [ ] REVERSED_CLIENT_ID 값이 GoogleService-Info.plist와 일치
- [ ] `pod install` 실행 완료
- [ ] `flutter clean && flutter pub get` 실행
- [ ] 시뮬레이터/실제 기기에서 테스트 성공

---

**문서 버전**: 1.0  
**최종 업데이트**: 2025-01-29  
**작성자**: MAKECALL Development Team
