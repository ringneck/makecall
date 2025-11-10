# iOS 빌드 오류 해결: Module 'audioplayers_darwin' not found

## 🚨 오류 상황
```
Module 'audioplayers_darwin' not found
```

## 🔍 원인
- `audioplayers` 패키지의 iOS 네이티브 모듈이 제대로 설치되지 않음
- Podfile.lock이 업데이트되지 않았거나 Pod 캐시 문제

---

## ✅ 해결 방법 (로컬 Mac에서 실행)

### 방법 1: Pod 완전 재설치 (권장)

**터미널에서 실행:**
```bash
# 1. Flutter 프로젝트 디렉토리로 이동
cd /path/to/flutter_app

# 2. iOS 디렉토리로 이동
cd ios

# 3. 기존 Pod 완전 삭제
rm -rf Pods Podfile.lock .symlinks

# 4. Pod 캐시 정리
pod cache clean --all

# 5. Flutter 프로젝트로 돌아가서 클린
cd ..
flutter clean

# 6. Dependencies 재설치
flutter pub get

# 7. iOS 디렉토리로 돌아가서 Pod 재설치
cd ios
pod deintegrate  # 기존 통합 제거
pod install --repo-update  # 최신 repo로 재설치

# 8. Xcode에서 빌드
open Runner.xcworkspace
```

---

### 방법 2: Xcode에서 수동 수정

**Step 1: Derived Data 삭제**
```bash
# 터미널에서
rm -rf ~/Library/Developer/Xcode/DerivedData
```

**Step 2: Xcode 재빌드**
1. Xcode에서 `Runner.xcworkspace` 열기
2. **Product** → **Clean Build Folder** (Shift+Cmd+K)
3. **Product** → **Build** (Cmd+B)

---

### 방법 3: audioplayers 설정 확인

**pubspec.yaml 확인:**
```yaml
dependencies:
  audioplayers: ^6.1.0  # ✅ 현재 설치됨
```

**버전 호환성 확인:**
- Flutter 3.35.4 ✅
- audioplayers 6.1.0 ✅
- iOS 13.0+ ✅

---

## 🔧 추가 해결 방법

### 문제 A: Pod install 실패

**증상:**
```
[!] CocoaPods could not find compatible versions for pod "audioplayers_darwin"
```

**해결:**
```bash
# 1. CocoaPods 최신 버전으로 업데이트
sudo gem install cocoapods

# 2. Pod repo 업데이트
pod repo update

# 3. Pod 재설치
cd ios
rm -rf Pods Podfile.lock
pod install
```

---

### 문제 B: Module not found (빌드 시)

**증상:**
```
Module 'audioplayers_darwin' not found
```

**해결 1: Xcode에서 Framework Search Path 확인**
1. Xcode에서 Runner 타겟 선택
2. **Build Settings** 탭
3. **Framework Search Paths** 검색
4. 다음 경로가 포함되어 있는지 확인:
   ```
   $(inherited)
   $(PROJECT_DIR)/Pods
   $(FLUTTER_ROOT)/.pub-cache/hosted/pub.dev/audioplayers_darwin-*/ios
   ```

**해결 2: Xcode Clean & Rebuild**
```bash
# 터미널에서
cd ios
xcodebuild clean -workspace Runner.xcworkspace -scheme Runner
xcodebuild build -workspace Runner.xcworkspace -scheme Runner -configuration Debug
```

---

### 문제 C: Podfile.lock 충돌

**증상:**
```
[!] CocoaPods could not find compatible versions
```

**해결:**
```bash
cd ios

# 1. Podfile.lock 삭제
rm -rf Podfile.lock

# 2. Podfile 최신 버전으로 업데이트
# (파일 내용은 아래 "Podfile 권장 설정" 참조)

# 3. Pod 재설치
pod install --repo-update
```

---

## 📋 Podfile 권장 설정

**파일 위치:** `ios/Podfile`

**권장 내용:**
```ruby
# Uncomment this line to define a global platform for your project
platform :ios, '13.0'

# CocoaPods analytics sends network stats synchronously affecting flutter build latency.
ENV['COCOAPODS_DISABLE_STATS'] = 'true'

project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}

def flutter_root
  generated_xcode_build_settings_path = File.expand_path(File.join('..', 'Flutter', 'Generated.xcconfig'), __FILE__)
  unless File.exist?(generated_xcode_build_settings_path)
    raise "#{generated_xcode_build_settings_path} must exist. If you're running pod install manually, make sure flutter pub get is executed first"
  end

  File.foreach(generated_xcode_build_settings_path) do |line|
    matches = line.match(/FLUTTER_ROOT\=(.*)/)
    return matches[1].strip if matches
  end
  raise "FLUTTER_ROOT not found in #{generated_xcode_build_settings_path}. Try deleting Generated.xcconfig, then run flutter pub get"
end

require File.expand_path(File.join('packages', 'flutter_tools', 'bin', 'podhelper'), flutter_root)

flutter_ios_podfile_setup

target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
  
  # Firebase pods (자동 추가됨)
  # - Firebase/CoreOnly
  # - Firebase/Messaging
  
  # audioplayers pod (자동 추가됨)
  # - audioplayers_darwin
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    
    # iOS 13.0 이상 강제
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
    end
  end
end
```

---

## 🧪 테스트 방법

### 1. Pod 설치 확인
```bash
cd ios
pod install

# 성공 시 출력:
# ✅ Pod installation complete! There are X dependencies from the Podfile
```

### 2. audioplayers_darwin 설치 확인
```bash
cd ios
cat Podfile.lock | grep audioplayers

# 예상 출력:
# - audioplayers_darwin (6.1.0)
```

### 3. Xcode 빌드 테스트
```bash
cd ios
xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Debug -sdk iphonesimulator
```

---

## 📊 일반적인 Pod 문제 해결 순서

**순서대로 시도:**

1️⃣ **Flutter Clean**
```bash
flutter clean
flutter pub get
```

2️⃣ **Pod Deintegrate**
```bash
cd ios
pod deintegrate
pod install
```

3️⃣ **Pod 캐시 정리**
```bash
pod cache clean --all
pod repo update
pod install
```

4️⃣ **Derived Data 삭제**
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData
```

5️⃣ **Xcode Clean Build**
```
Xcode → Product → Clean Build Folder (Shift+Cmd+K)
Xcode → Product → Build (Cmd+B)
```

6️⃣ **완전 재설치**
```bash
cd ios
rm -rf Pods Podfile.lock .symlinks
cd ..
flutter clean
flutter pub get
cd ios
pod install --repo-update
```

---

## 🚨 자주 발생하는 오류 및 해결

### 오류 1: CocoaPods not installed
```bash
# 해결: CocoaPods 설치
sudo gem install cocoapods
```

### 오류 2: Permission denied
```bash
# 해결: sudo 사용
sudo gem install cocoapods
sudo pod install
```

### 오류 3: Incompatible version
```bash
# 해결: CocoaPods 업데이트
sudo gem install cocoapods --pre
pod repo update
```

### 오류 4: Framework not found
```bash
# 해결: Clean & Rebuild
flutter clean
cd ios
pod deintegrate
pod install
```

---

## 💡 예방 방법

**1. pubspec.yaml 변경 후 항상:**
```bash
flutter pub get
cd ios
pod install
```

**2. Git에서 pull 후:**
```bash
flutter clean
flutter pub get
cd ios
pod install
```

**3. iOS 빌드 전:**
```bash
cd ios
pod install
open Runner.xcworkspace  # .xcodeproj 아님!
```

---

## 📝 체크리스트

**iOS 빌드 전 확인:**
- [ ] `flutter pub get` 실행 완료
- [ ] `cd ios && pod install` 실행 완료
- [ ] `Podfile.lock`에 `audioplayers_darwin` 포함 확인
- [ ] `ios/Pods/` 디렉토리 존재 확인
- [ ] Xcode에서 `Runner.xcworkspace` 열기 (`.xcodeproj` 아님!)
- [ ] Xcode: Product → Clean Build Folder
- [ ] 실제 iOS 기기 또는 시뮬레이터 선택
- [ ] Xcode: Product → Build

**문제 발생 시:**
- [ ] Derived Data 삭제
- [ ] Pod 완전 재설치
- [ ] Flutter clean 실행
- [ ] Xcode 재시작

---

## 🔗 참고 자료

- [audioplayers 공식 문서](https://pub.dev/packages/audioplayers)
- [CocoaPods 트러블슈팅](https://guides.cocoapods.org/using/troubleshooting.html)
- [Flutter iOS Setup](https://docs.flutter.dev/get-started/install/macos#ios-setup)

---

## 📞 추가 도움

**문제가 계속되면:**
1. Xcode 콘솔에서 전체 오류 메시지 확인
2. `Podfile.lock` 파일 내용 확인
3. `flutter doctor -v` 실행 결과 확인
4. CocoaPods 버전 확인: `pod --version`

---

**다음 단계:**
1. 로컬 Mac에서 위 방법 중 하나 시도
2. Pod 재설치 완료 확인
3. Xcode에서 빌드 테스트
4. 성공 시 실제 기기에서 앱 실행

**예상 소요 시간:** 5-10분
