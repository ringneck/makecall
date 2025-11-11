# iOS 빌드 오류 해결 가이드
## "Command PhaseScriptExecution failed with a nonzero exit code"

이 오류는 iOS 빌드 시 스크립트 실행 단계에서 발생하는 일반적인 오류입니다.

---

## 🔧 즉시 시도할 해결 방법 (순서대로)

### **1단계: Clean Build Folder (가장 효과적)**

**Xcode에서:**
1. `Product` → `Clean Build Folder` (또는 `Shift + Command + K`)
2. `ios` 폴더의 `Pods` 폴더 삭제
3. `ios` 폴더의 `Podfile.lock` 파일 삭제
4. 터미널에서 실행:
```bash
cd /path/to/flutter_app
flutter clean
cd ios
pod deintegrate
pod install
```

**또는 터미널에서 한번에:**
```bash
cd /path/to/flutter_app
flutter clean
rm -rf ios/Pods
rm -rf ios/Podfile.lock
rm -rf ios/.symlinks
rm -rf ios/Flutter/Flutter.framework
rm -rf ios/Flutter/Flutter.podspec
cd ios
pod install
cd ..
flutter pub get
```

---

### **2단계: User Script Sandboxing 비활성화 (이미 적용됨)**

**확인 방법:**
1. Xcode에서 프로젝트 열기
2. `Runner` 프로젝트 선택
3. `Build Settings` 탭
4. 검색: "User Script Sandboxing"
5. 값: **NO** (이미 Podfile에서 설정됨)

**만약 NO가 아니면:**
- `ENABLE_USER_SCRIPT_SANDBOXING = NO`로 변경

---

### **3단계: 빌드 스크립트 권한 확인**

**Xcode에서:**
1. `Runner` 프로젝트 선택
2. `Build Phases` 탭
3. 다음 스크립트들을 찾아서 확인:
   - `[CP] Check Pods Manifest.lock`
   - `[CP] Embed Pods Frameworks`
   - `[CP] Copy Pods Resources`
   - `Thin Binary`
   - `Run Script` (Flutter 관련)

**문제가 있는 스크립트 찾기:**
- 빌드 로그에서 어떤 스크립트가 실패했는지 확인
- 해당 스크립트의 쉘 경로 확인: `/bin/sh` 또는 `/bin/bash`

---

### **4단계: CocoaPods 캐시 정리**

```bash
# CocoaPods 캐시 삭제
pod cache clean --all

# CocoaPods 재설치 (필요시)
sudo gem install cocoapods

# 다시 설치
cd ios
pod install
```

---

### **5단계: Xcode 파생 데이터 삭제**

**Xcode에서:**
1. `Xcode` → `Preferences` (또는 `Settings`)
2. `Locations` 탭
3. `Derived Data` 경로 확인 (보통 `~/Library/Developer/Xcode/DerivedData`)
4. Finder에서 해당 폴더 열기
5. 프로젝트 관련 폴더 삭제

**또는 터미널에서:**
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/*
```

---

### **6단계: Rosetta 관련 문제 (Apple Silicon Mac)**

**M1/M2/M3 Mac을 사용 중이라면:**

```bash
# Rosetta로 터미널 실행 후
cd /path/to/flutter_app/ios
arch -x86_64 pod install

# 또는 CocoaPods를 Rosetta로 재설치
sudo gem uninstall cocoapods
arch -x86_64 sudo gem install cocoapods
```

---

## 🔍 구체적인 오류 메시지별 해결 방법

### **오류 1: "sandbox: bash(xxxxx) deny(1) file-read-data"**

**원인:** User Script Sandboxing 활성화
**해결:**
```ruby
# Podfile의 post_install에 추가 (이미 포함됨)
config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
```

---

### **오류 2: "Permission denied" 또는 "No such file or directory"**

**원인:** 스크립트 실행 권한 부족
**해결:**
```bash
# Flutter 관련 스크립트 권한 부여
cd ios
chmod +x Flutter/flutter_export_environment.sh
chmod +x Flutter/podhelper.rb
```

---

### **오류 3: "Command /bin/sh failed with exit code 1"**

**원인:** 빌드 스크립트 내부 오류
**해결:**
1. Xcode 빌드 로그 상세 보기
2. `Report navigator` (Command + 9)
3. 실패한 빌드 선택
4. 오류 메시지 전체 복사
5. 구체적인 오류 내용 확인

---

### **오류 4: Firebase 관련 스크립트 오류**

**원인:** Firebase 플러그인 설정 문제
**해결:**
```bash
# Firebase 관련 Pod 재설치
cd ios
pod deintegrate
rm Podfile.lock
pod install
```

---

## 🚀 전체 초기화 스크립트 (최후의 수단)

모든 방법이 실패하면 다음 스크립트를 실행하세요:

```bash
#!/bin/bash

echo "🧹 Flutter iOS 빌드 환경 완전 초기화 시작..."

cd /path/to/flutter_app

# 1. Flutter 정리
echo "1️⃣ Flutter 정리 중..."
flutter clean

# 2. iOS 관련 파일 삭제
echo "2️⃣ iOS 파일 삭제 중..."
rm -rf ios/Pods
rm -rf ios/Podfile.lock
rm -rf ios/.symlinks
rm -rf ios/Flutter/Flutter.framework
rm -rf ios/Flutter/Flutter.podspec
rm -rf ios/Runner.xcworkspace

# 3. Xcode 파생 데이터 삭제
echo "3️⃣ Xcode 파생 데이터 삭제 중..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# 4. CocoaPods 캐시 삭제
echo "4️⃣ CocoaPods 캐시 삭제 중..."
pod cache clean --all

# 5. Flutter 의존성 재설치
echo "5️⃣ Flutter 의존성 재설치 중..."
flutter pub get

# 6. CocoaPods 재설치
echo "6️⃣ CocoaPods 재설치 중..."
cd ios
pod install
cd ..

echo "✅ 초기화 완료!"
echo "📱 이제 Xcode에서 프로젝트를 다시 열고 빌드하세요."
```

---

## 📱 Xcode에서 빌드 시 추천 설정

### **빌드 전 체크리스트:**
- [ ] Clean Build Folder 실행됨
- [ ] 시뮬레이터 또는 실제 기기 선택됨
- [ ] Signing & Capabilities에서 Team 설정됨
- [ ] Bundle Identifier 올바르게 설정됨
- [ ] Deployment Target이 15.6 이상으로 설정됨

### **빌드 설정:**
1. **Product** → **Scheme** → **Edit Scheme**
2. **Run** → **Build Configuration**: **Debug** (개발용)
3. **Profile** → **Build Configuration**: **Release** (성능 테스트용)

---

## 🔍 빌드 로그 상세 보기

**Xcode에서:**
1. 빌드 실패 후 `Report Navigator` 열기 (Command + 9)
2. 실패한 빌드 선택
3. 오른쪽 상단 아이콘 클릭하여 로그 내보내기
4. 오류 메시지 검색:
   - "error:"
   - "failed"
   - "PhaseScriptExecution"

**중요한 로그 라인:**
```
PhaseScriptExecution [CP]\ Check\ Pods\ Manifest.lock ...
```
위 라인 다음에 나오는 오류 메시지가 실제 원인입니다.

---

## 💡 자주 묻는 질문

### **Q: "pod install" 실행 시 "command not found"**
**A:** CocoaPods 설치 필요
```bash
sudo gem install cocoapods
```

### **Q: Apple Silicon Mac에서 계속 오류 발생**
**A:** Rosetta 사용
```bash
arch -x86_64 pod install
```

### **Q: Firebase 관련 오류가 계속 발생**
**A:** 
1. `ios/Runner/GoogleService-Info.plist` 파일 존재 확인
2. Firebase Console에서 최신 파일 다운로드
3. Xcode에서 파일 참조 재설정

### **Q: Signing 오류 발생**
**A:**
1. Xcode → Runner → Signing & Capabilities
2. Automatically manage signing 체크
3. Team 선택
4. Bundle Identifier 고유하게 변경 (예: com.yourcompany.makecall)

---

## 🎯 마지막 팁

1. **항상 최신 Flutter 사용**: `flutter upgrade` (하지만 이 프로젝트는 3.35.4로 고정)
2. **Xcode 최신 버전 사용**: App Store에서 업데이트
3. **CocoaPods 최신 버전**: `sudo gem install cocoapods`
4. **macOS 업데이트**: 시스템 환경설정에서 확인

---

## 📞 추가 도움이 필요하면

1. Xcode 빌드 로그 전체 내용 복사
2. 오류 메시지 중 가장 중요한 부분 찾기
3. 구체적인 오류 메시지와 함께 질문하기

**로그에서 찾아야 할 키워드:**
- `error:`
- `fatal error:`
- `Command PhaseScriptExecution failed`
- 그 다음 라인의 구체적인 오류 내용
