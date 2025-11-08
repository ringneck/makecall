# iOS / macOS 빌드 가이드

## 📋 목차
- [시스템 요구사항](#시스템-요구사항)
- [초기 설정](#초기-설정)
- [빌드 방법](#빌드-방법)
- [트러블슈팅](#트러블슈팅)
- [최적화 설정](#최적화-설정)

---

## 🔧 시스템 요구사항

### macOS 개발 환경
- **macOS**: 11.0 (Big Sur) 이상
- **Xcode**: 14.0 이상
- **CocoaPods**: 1.11.0 이상
- **Flutter**: 3.35.4 (고정 버전)
- **Dart**: 3.9.2 (고정 버전)

### 설치 확인
```bash
# Xcode 버전 확인
xcodebuild -version

# CocoaPods 설치 확인
pod --version

# Flutter 버전 확인 (고정 버전 사용)
flutter --version

# Flutter doctor 실행
flutter doctor -v
```

---

## ⚙️ 초기 설정

### 1. CocoaPods 설치 (없는 경우)
```bash
sudo gem install cocoapods
```

### 2. Xcode Command Line Tools 설치
```bash
xcode-select --install
```

### 3. Flutter Dependencies 설치
```bash
flutter pub get
```

### 4. iOS Pods 설치
```bash
cd ios
pod install
cd ..
```

### 5. macOS Pods 설치
```bash
cd macos
pod install
cd ..
```

---

## 🚀 빌드 방법

### iOS 빌드

#### 방법 1: 빌드 스크립트 사용 (권장)
```bash
# Release 빌드 (기본값)
./scripts/build_ios.sh

# Debug 빌드
./scripts/build_ios.sh debug
```

#### 방법 2: Flutter CLI 사용
```bash
# Release 빌드 (코드 서명 없이)
flutter build ios --release --no-codesign

# Debug 빌드
flutter build ios --debug --no-codesign
```

#### 방법 3: Xcode에서 직접 빌드
1. Xcode에서 `ios/Runner.xcworkspace` 열기
2. Product → Scheme → Runner 선택
3. Product → Build (⌘B)
4. Product → Run (⌘R)

---

### macOS 빌드

#### 방법 1: 빌드 스크립트 사용 (권장)
```bash
# Release 빌드 (기본값)
./scripts/build_macos.sh

# Debug 빌드
./scripts/build_macos.sh debug
```

#### 방법 2: Flutter CLI 사용
```bash
# Release 빌드
flutter build macos --release

# Debug 빌드
flutter build macos --debug
```

#### 방법 3: Xcode에서 직접 빌드
1. Xcode에서 `macos/Runner.xcworkspace` 열기
2. Product → Scheme → Runner 선택
3. Product → Build (⌘B)
4. Product → Run (⌘R)

---

## 🧹 빌드 캐시 정리

### 전체 정리
```bash
./scripts/clean_build.sh all
```

### iOS만 정리
```bash
./scripts/clean_build.sh ios
```

### macOS만 정리
```bash
./scripts/clean_build.sh macos
```

### 정리 후 재설정
```bash
flutter pub get
cd ios && pod install && cd ..
cd macos && pod install && cd ..
```

---

## 🔍 트러블슈팅

### 문제 0: 디바이스/시뮬레이터를 찾을 수 없음
**에러 메시지:**
```
Unable to find a destination matching the provided destination specifier
```

**해결 방법:**
```bash
# 1. 사용 가능한 시뮬레이터 확인
xcrun simctl list devices available

# 2. Flutter 디바이스 목록 확인
flutter devices

# 3. 시뮬레이터용으로 빌드
flutter build ios --simulator

# 4. 특정 시뮬레이터로 실행
flutter run -d "iPhone 15 Pro"

# 5. Xcode에서 직접 빌드 (권장)
open ios/Runner.xcworkspace
# Xcode에서 디바이스/시뮬레이터 선택 후 빌드
```

### 문제 1: CocoaPods 설정 충돌
**에러 메시지:**
```
CocoaPods did not set the base configuration of your project because your project 
already has a custom config set. In order for CocoaPods integration to work at all, 
please either set the base configurations of the target `Runner` to 
`Target Support Files/Pods-Runner/Pods-Runner.profile.xcconfig` or include the 
`Target Support Files/Pods-Runner/Pods-Runner.profile.xcconfig` in your build 
configuration (`Flutter/Release.xcconfig`).
```

**원인:**
- `Profile.xcconfig` 파일이 누락됨
- CocoaPods가 Profile 빌드 구성을 찾을 수 없음

**해결 방법:**
```bash
# iOS Profile.xcconfig 생성 (이미 생성되어 있음)
# ios/Flutter/Profile.xcconfig

# macOS Profile.xcconfig 생성 (이미 생성되어 있음)
# macos/Flutter/Flutter-Profile.xcconfig

# Pods 재설치
cd ios && pod install && cd ..
cd macos && pod install && cd ..
```

### 문제 2: CocoaPods 의존성 오류
```bash
# Pods 완전 재설치
cd ios
rm -rf Pods Podfile.lock
pod install --repo-update
cd ..
```

### 문제 3: Xcode 빌드 실패
```bash
# Xcode 파생 데이터 정리
rm -rf ~/Library/Developer/Xcode/DerivedData

# Flutter 캐시 정리
flutter clean
flutter pub get
```

### 문제 4: Apple Silicon (M1/M2) 호환성 문제
```bash
# Rosetta 환경에서 CocoaPods 설치
sudo arch -x86_64 gem install ffi
cd ios && arch -x86_64 pod install && cd ..
```

### 문제 5: 코드 서명 오류
```bash
# 코드 서명 없이 빌드 (개발용)
flutter build ios --release --no-codesign
```

### 문제 6: Firebase 관련 오류
- `google-services.json` (Android) 확인
- `GoogleService-Info.plist` (iOS) 확인
- Firebase 패키지 버전 확인 (고정 버전 사용)

---

## ⚡ 최적화 설정

### Podfile 최적화 (이미 적용됨)

**iOS** (`ios/Podfile`):
```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      # 빌드 속도 향상
      config.build_settings['ENABLE_BITCODE'] = 'NO'
      config.build_settings['COMPILER_INDEX_STORE_ENABLE'] = 'NO'
      config.build_settings['GCC_OPTIMIZATION_LEVEL'] = '0'
      config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone'
      
      # 미사용 코드 제거
      config.build_settings['DEAD_CODE_STRIPPING'] = 'YES'
      config.build_settings['STRIP_INSTALLED_PRODUCT'] = 'YES'
      
      # 아키텍처 최적화
      config.build_settings['ONLY_ACTIVE_ARCH'] = 'YES'
    end
  end
end
```

**macOS** (`macos/Podfile`):
```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      # 빌드 속도 향상
      config.build_settings['COMPILER_INDEX_STORE_ENABLE'] = 'NO'
      config.build_settings['GCC_OPTIMIZATION_LEVEL'] = '0'
      config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone'
      
      # 미사용 코드 제거
      config.build_settings['DEAD_CODE_STRIPPING'] = 'YES'
      
      # Universal Binary 지원
      config.build_settings['ARCHS'] = 'x86_64 arm64'
    end
  end
end
```

---

## 📱 최소 버전 요구사항

- **iOS**: 15.6 이상
- **macOS**: 11.0 (Big Sur) 이상

---

## 🔐 권한 설정

### iOS (`ios/Runner/Info.plist`)
```xml
<!-- 카메라 권한 -->
<key>NSCameraUsageDescription</key>
<string>프로필 사진을 촬영하기 위해 카메라 접근 권한이 필요합니다.</string>

<!-- 사진 라이브러리 권한 -->
<key>NSPhotoLibraryUsageDescription</key>
<string>프로필 사진을 선택하기 위해 사진 라이브러리 접근 권한이 필요합니다.</string>

<!-- 연락처 권한 -->
<key>NSContactsUsageDescription</key>
<string>장치 연락처를 불러오기 위해 연락처 접근 권한이 필요합니다.</string>
```

---

## 📦 빌드 출력 위치

### iOS
```
build/ios/iphoneos/Runner.app
```

### macOS
```
build/macos/Build/Products/Release/MAKECALL.app
```

---

## 🆘 추가 도움말

### 공식 문서
- [Flutter iOS 배포](https://docs.flutter.dev/deployment/ios)
- [Flutter macOS 배포](https://docs.flutter.dev/deployment/macos)
- [CocoaPods 가이드](https://guides.cocoapods.org/)

### 커뮤니티
- [Flutter GitHub Issues](https://github.com/flutter/flutter/issues)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/flutter)

---

## ✅ 체크리스트

빌드 전 확인사항:
- [ ] Xcode 최신 버전 설치
- [ ] CocoaPods 설치 확인
- [ ] Flutter dependencies 업데이트 (`flutter pub get`)
- [ ] iOS/macOS Pods 설치 (`pod install`)
- [ ] Firebase 설정 파일 확인
- [ ] 권한 설정 확인 (Info.plist)
- [ ] 최소 버전 요구사항 충족

---

**⚠️ 중요 사항**
- Flutter 3.35.4 및 Dart 3.9.2 고정 버전 사용 (업데이트 금지)
- 모든 빌드는 코드 서명 없이 진행 (`--no-codesign`)
- Release 빌드 권장 (성능 최적화)
- 빌드 문제 발생 시 캐시 정리 후 재시도
