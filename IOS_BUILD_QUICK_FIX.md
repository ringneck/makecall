# iOS 빌드 오류 빠른 해결 가이드

## 🚨 오류
```
Module 'audioplayers_darwin' not found
```

---

## ⚡ 빠른 해결 (로컬 Mac에서)

### 방법 1: 자동 수정 스크립트 (권장)

**실행 명령:**
```bash
# Flutter 프로젝트 루트 디렉토리에서
./ios_fix.sh
```

**스크립트가 자동으로 수행하는 작업:**
1. ✅ Flutter clean
2. ✅ Flutter pub get
3. ✅ 기존 Pods 삭제
4. ✅ Pod deintegrate
5. ✅ Pod install --repo-update
6. ✅ audioplayers_darwin 설치 확인
7. ✅ Derived Data 정리

**예상 소요 시간:** 3-5분

---

### 방법 2: 수동 해결 (5단계)

```bash
# 1. Flutter Clean
flutter clean
flutter pub get

# 2. iOS 디렉토리로 이동
cd ios

# 3. 기존 Pods 완전 삭제
rm -rf Pods Podfile.lock .symlinks

# 4. Pod 재설치
pod deintegrate
pod install --repo-update

# 5. Xcode에서 빌드
open Runner.xcworkspace
```

**Xcode에서:**
- Product → Clean Build Folder (Shift+Cmd+K)
- Product → Build (Cmd+B)

---

## 🔍 원인

**Module not found 오류의 일반적인 원인:**
1. ❌ Pod install 누락 또는 불완전
2. ❌ Podfile.lock 업데이트 안됨
3. ❌ Xcode 캐시 (Derived Data) 문제
4. ❌ .xcodeproj 파일로 열기 (❌ 잘못됨)
   - ✅ 올바른 방법: .xcworkspace 파일로 열기

---

## 📋 빌드 전 체크리스트

**필수 확인 사항:**
- [ ] `flutter pub get` 실행 완료
- [ ] `cd ios && pod install` 실행 완료
- [ ] Xcode에서 **Runner.xcworkspace** 열기 (⚠️ .xcodeproj 아님!)
- [ ] Podfile.lock에 audioplayers_darwin 존재 확인
- [ ] iOS 13.0 이상 타겟 설정

**확인 명령:**
```bash
# audioplayers_darwin 설치 확인
cat ios/Podfile.lock | grep audioplayers_darwin

# 예상 출력:
# - audioplayers_darwin (6.1.0)
```

---

## 🚨 자주 하는 실수

### 실수 1: .xcodeproj로 열기
```bash
❌ 잘못: open ios/Runner.xcodeproj
✅ 올바름: open ios/Runner.xcworkspace
```

### 실수 2: Pod install 누락
```bash
# pubspec.yaml 변경 후 반드시 실행
flutter pub get
cd ios
pod install
```

### 실수 3: Derived Data 미정리
```bash
# Xcode 캐시 정리
rm -rf ~/Library/Developer/Xcode/DerivedData
```

---

## 🔧 문제가 계속되면

### 추가 해결 방법 1: Pod 캐시 정리
```bash
cd ios
pod cache clean --all
pod repo update
pod install
```

### 추가 해결 방법 2: CocoaPods 재설치
```bash
# CocoaPods 최신 버전 설치
sudo gem install cocoapods

# Pod 재설치
cd ios
pod install
```

### 추가 해결 방법 3: 완전 초기화
```bash
# Flutter 프로젝트에서
flutter clean
rm -rf ios/Pods ios/Podfile.lock
flutter pub get
cd ios
pod install --repo-update
```

---

## 📊 성공 확인

**Xcode 콘솔에서 확인:**
```
✅ Build Succeeded
```

**audioplayers 작동 확인:**
```dart
import 'package:audioplayers/audioplayers.dart';

final player = AudioPlayer();
await player.play(UrlSource('audio_url'));
```

---

## 📁 생성된 파일

**1. ios_fix.sh** (자동 수정 스크립트)
- 위치: `/home/user/flutter_app/ios_fix.sh`
- 실행: `./ios_fix.sh`

**2. IOS_BUILD_ERROR_FIX.md** (상세 가이드)
- 위치: `/home/user/flutter_app/IOS_BUILD_ERROR_FIX.md`
- 내용: 모든 해결 방법 및 트러블슈팅

---

## 💡 예방 팁

**pubspec.yaml 변경 후:**
```bash
flutter pub get
cd ios
pod install
```

**Git pull 후:**
```bash
flutter clean
flutter pub get
cd ios
pod install
```

**iOS 빌드 전:**
```bash
cd ios
pod install
open Runner.xcworkspace
```

---

## 🎯 요약

**가장 빠른 해결 (3단계):**
```bash
# 1. 자동 스크립트 실행
./ios_fix.sh

# 2. Xcode 열기
cd ios
open Runner.xcworkspace

# 3. Clean & Build
# Xcode: Product → Clean Build Folder → Build
```

**수동 해결 (5단계):**
```bash
flutter clean && flutter pub get
cd ios
rm -rf Pods Podfile.lock
pod install --repo-update
open Runner.xcworkspace
```

**예상 소요 시간:** 3-5분

---

## 📞 추가 도움

**문제가 계속되면 확인:**
1. CocoaPods 버전: `pod --version`
2. Flutter 버전: `flutter --version`
3. Xcode 버전: Xcode → About Xcode
4. iOS Deployment Target: Xcode → Runner → Build Settings → iOS Deployment Target (13.0 이상)

**상세 가이드:**
- IOS_BUILD_ERROR_FIX.md
- [audioplayers 문서](https://pub.dev/packages/audioplayers)
- [CocoaPods 가이드](https://guides.cocoapods.org/)

---

**다음 단계:** 로컬 Mac에서 `./ios_fix.sh` 실행 후 Xcode에서 빌드!
