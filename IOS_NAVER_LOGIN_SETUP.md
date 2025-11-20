# 🍎 iOS Naver 로그인 설정 가이드

## 🎯 문제

iOS에서 Naver 로그인 시 다음 오류 발생:
```
MissingPluginException: No implementation found for method logIn on channel flutter_naver_login
```

**원인**: iOS 네이티브 플러그인이 설치되지 않음 (CocoaPods 의존성 미설치)

---

## ✅ 해결 방법 (macOS 환경 필수)

### 1️⃣ CocoaPods 설치 확인

```bash
# CocoaPods 버전 확인
pod --version

# 설치 안 되어 있다면 설치
sudo gem install cocoapods
```

### 2️⃣ iOS 의존성 설치

```bash
cd ios
pod install
```

**예상 출력:**
```
Analyzing dependencies
Downloading dependencies
Installing flutter_naver_login (2.1.0)
Installing naveridlogin-sdk-ios (5.0.0)
...
Pod installation complete! XX pods installed.
```

### 3️⃣ Xcode에서 확인

1. `ios/Runner.xcworkspace` 열기 (⚠️ `.xcodeproj` 아님!)
2. Product → Scheme → Runner 선택
3. Product → Build 실행
4. 빌드 성공 확인

### 4️⃣ Flutter 앱 재시작

```bash
# Flutter 앱 재시작 (iOS 시뮬레이터 또는 실제 기기)
cd /path/to/flutter_app
flutter run
```

---

## 🔍 iOS Info.plist 설정 확인

현재 `ios/Runner/Info.plist`에 이미 포함됨:

```xml
<!-- 🟢 Naver Login Configuration -->
<key>NidClientId</key>
<string>Wl4fP6XbiTRQQMpbC5a9</string>
<key>NidClientSecret</key>
<string>gr2MvANyr8</string>
<key>NidClientName</key>
<string>MAKECALL</string>
<key>NidUrlScheme</key>
<string>naverWl4fP6XbiTRQQMpbC5a9</string>

<!-- URL Schemes -->
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>naverWl4fP6XbiTRQQMpbC5a9</string>
    </array>
  </dict>
</array>

<!-- LSApplicationQueriesSchemes -->
<key>LSApplicationQueriesSchemes</key>
<array>
  <string>naversearchapp</string>
  <string>naversearchthirdlogin</string>
  <string>navercafe</string>
</array>
```

✅ **이미 설정 완료됨 - 추가 작업 불필요**

---

## 🔧 iOS Podfile 설정 확인

`ios/Podfile`도 이미 올바르게 설정됨:

```ruby
platform :ios, '15.6'

target 'Runner' do
  use_frameworks!
  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
end
```

✅ **이미 설정 완료됨 - 추가 작업 불필요**

---

## 📱 테스트

### iOS 시뮬레이터에서 테스트:
```bash
flutter run -d <device_id>
```

### Naver 로그인 시도:
1. 로그인 화면에서 "Naver로 시작하기" 버튼 클릭
2. Naver 웹 로그인 화면 표시
3. 로그인 완료 후 앱으로 복귀

---

## 🚨 예상 로그

**성공 시:**
```
flutter: 🟢 [Naver] 로그인 시작
flutter: 🔄 [Naver] FlutterNaverLogin.logIn() 호출 중...
flutter: ✅ [Naver] 로그인 성공
flutter: 🔄 [Naver] AccessToken: naver_xxx...
flutter: ✅ [Naver] Firebase Custom Token 생성 완료
```

**실패 시 (pod install 안 한 경우):**
```
flutter: ❌ [Naver] 로그인 호출 중 Exception 발생
flutter:    - Error Type: MissingPluginException
flutter:    - Error: No implementation found for method logIn
```

---

## 📦 패키지 버전 정보

현재 사용 중인 버전:
- `flutter_naver_login: 2.1.0` (최신: 2.1.1)
- Naver iOS SDK: `5.0.0`
- iOS 최소 버전: `15.6`

---

## 🆘 문제 해결

### Pod install 실패 시:

```bash
# Podfile.lock 삭제 후 재시도
cd ios
rm Podfile.lock
rm -rf Pods
pod install
```

### Xcode 빌드 실패 시:

```bash
# Flutter clean 후 재빌드
cd /path/to/flutter_app
flutter clean
flutter pub get
cd ios
pod install
cd ..
flutter run
```

### 여전히 MissingPluginException 발생 시:

1. **Runner.xcworkspace로 열었는지 확인** (⚠️ `.xcodeproj` 아님!)
2. **Xcode에서 Clean Build Folder** (Cmd + Shift + K)
3. **Derived Data 삭제**:
   - Xcode → Preferences → Locations
   - Derived Data 경로로 이동
   - 폴더 전체 삭제
4. **Flutter 앱 완전 재빌드**

---

## 📝 참고 자료

- [flutter_naver_login pub.dev](https://pub.dev/packages/flutter_naver_login)
- [Naver Login iOS SDK (GitHub)](https://github.com/naver/naveridlogin-sdk-ios-swift)
- [Flutter iOS 플랫폼 설정](https://docs.flutter.dev/deployment/ios)

---

## ✅ 체크리스트

- [ ] CocoaPods 설치됨
- [ ] `pod install` 성공
- [ ] `Runner.xcworkspace`로 Xcode 프로젝트 열림
- [ ] Xcode 빌드 성공
- [ ] Flutter 앱 재시작
- [ ] Naver 로그인 테스트 성공
