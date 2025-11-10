# 🔧 iOS Deployment Target 버전 불일치 수정

## 📋 문제 상황

**오류 메시지:**
```
Compiling for iOS 15.0, but module 'FirebaseStorage' has a minimum deployment target of iOS 15.6
```

**원인:**
- Podfile은 iOS 15.6으로 설정되어 있음
- Xcode 프로젝트 설정(project.pbxproj)은 iOS 15.0으로 설정되어 있음
- Firebase 모듈들이 iOS 15.6 이상을 요구함

---

## ✅ 수행한 작업

### 1. Xcode 프로젝트 설정 파일 수정

**파일**: `ios/Runner.xcodeproj/project.pbxproj`

**수정 내용**: 3개의 Build Configuration에서 IPHONEOS_DEPLOYMENT_TARGET을 15.0 → 15.6으로 변경

#### A. Debug Configuration (Line 608)
```diff
- IPHONEOS_DEPLOYMENT_TARGET = 15.0;
+ IPHONEOS_DEPLOYMENT_TARGET = 15.6;
```

#### B. Release Configuration (Line 659)
```diff
- IPHONEOS_DEPLOYMENT_TARGET = 15.0;
+ IPHONEOS_DEPLOYMENT_TARGET = 15.6;
```

#### C. Profile Configuration (Line 475)
```diff
- IPHONEOS_DEPLOYMENT_TARGET = 15.0;
+ IPHONEOS_DEPLOYMENT_TARGET = 15.6;
```

---

## 🎯 확인 방법

### 방법 1: 명령어로 확인
```bash
cd ~/makecall/flutter_app
grep "IPHONEOS_DEPLOYMENT_TARGET" ios/Runner.xcodeproj/project.pbxproj
```

**예상 출력:**
```
IPHONEOS_DEPLOYMENT_TARGET = 15.6;
IPHONEOS_DEPLOYMENT_TARGET = 15.6;
IPHONEOS_DEPLOYMENT_TARGET = 15.6;
```

### 방법 2: Xcode에서 확인
```
1. Xcode에서 Runner.xcworkspace 열기
2. 좌측에서 "Runner" 프로젝트 클릭
3. "Build Settings" 탭
4. 검색창에 "iOS Deployment Target" 입력
5. 모든 Configuration에서 "iOS 15.6" 확인
```

---

## 🚀 다음 단계

### 1️⃣ 로컬 Mac에서 최신 코드 받기
```bash
cd ~/makecall/flutter_app
git pull origin main
```

### 2️⃣ CocoaPods 재설치 (필수)
```bash
cd ios
rm -rf Pods Podfile.lock
pod install
```

또는 자동화 스크립트 사용:
```bash
cd ~/makecall/flutter_app
./ios_fix.sh
```

### 3️⃣ Xcode에서 Clean Build
```
1. Xcode 열기: open ios/Runner.xcworkspace
2. Product → Clean Build Folder (Cmd+Shift+K)
3. DerivedData 삭제:
   rm -rf ~/Library/Developer/Xcode/DerivedData
```

### 4️⃣ 빌드 재시도
```
Xcode에서 Cmd+B (빌드) 또는 Cmd+R (실행)
```

---

## 🔍 Firebase 모듈 최소 요구 버전

현재 프로젝트의 Firebase 모듈들과 최소 iOS 버전:

| Firebase 모듈 | 버전 | 최소 iOS 버전 |
|--------------|------|---------------|
| firebase_core | 3.6.0 | iOS 13.0+ |
| firebase_auth | 5.3.1 | iOS 13.0+ |
| firebase_messaging | 15.1.3 | iOS 13.0+ |
| firebase_storage | 12.3.2 | **iOS 15.6+** ⚠️ |
| cloud_firestore | 5.4.3 | iOS 13.0+ |
| cloud_functions | 5.1.3 | iOS 13.0+ |

**결론**: firebase_storage가 iOS 15.6 이상을 요구하므로, 프로젝트 전체를 iOS 15.6으로 설정해야 합니다.

---

## 📊 설정 파일 요약

### ✅ Podfile (이미 올바름)
```ruby
platform :ios, '15.6'

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.6'
    end
  end
end
```

### ✅ project.pbxproj (수정 완료)
```
IPHONEOS_DEPLOYMENT_TARGET = 15.6;  # Debug
IPHONEOS_DEPLOYMENT_TARGET = 15.6;  # Release
IPHONEOS_DEPLOYMENT_TARGET = 15.6;  # Profile
```

### ✅ Xcode 프로젝트 설정 (자동 반영됨)
- Runner Target → Build Settings → iOS Deployment Target = 15.6
- RunnerTests Target → Build Settings → iOS Deployment Target = 15.6

---

## ⚠️ 중요 참고사항

### 1. iOS 15.6 요구사항
iOS 15.6은 2022년 7월 20일에 출시되었습니다. 대부분의 iOS 기기가 이 버전 이상을 지원합니다.

**지원 기기:**
- iPhone 6s 이상 (2015년 이후 출시 기기)
- iPad Air 2 이상
- iPad mini 4 이상
- iPod touch (7th generation)

**비지원 기기:**
- iPhone 6 이하 (iOS 12.5.7이 최종 버전)
- iPad Air (1st generation)
- iPad mini 2, 3

### 2. 버전 변경 시 주의사항

iOS Deployment Target을 변경하면:
- ✅ 프로젝트가 더 최신 iOS API를 사용할 수 있음
- ✅ Firebase 등 최신 라이브러리 호환성 향상
- ⚠️ 구형 iOS 기기에서 앱 설치 불가 (iOS 15.6 미만)
- ⚠️ App Store 호환 기기 목록 업데이트 필요

### 3. Build Configuration 종류

| Configuration | 용도 |
|--------------|------|
| Debug | Xcode에서 직접 실행 시 사용 (개발용) |
| Release | App Store 배포용 최적화 빌드 |
| Profile | 성능 프로파일링용 빌드 |

**모든 Configuration을 동일한 버전으로 설정**해야 빌드 문제를 방지할 수 있습니다.

---

## 🆘 문제 해결

### 문제 1: 여전히 iOS 15.0 오류 발생

**해결 방법:**
```bash
# 1. DerivedData 완전 삭제
rm -rf ~/Library/Developer/Xcode/DerivedData

# 2. Xcode 캐시 삭제
rm -rf ~/Library/Caches/com.apple.dt.Xcode

# 3. CocoaPods 완전 재설치
cd ~/makecall/flutter_app/ios
rm -rf Pods Podfile.lock .symlinks
pod deintegrate
pod install --repo-update

# 4. Flutter 클린
cd ..
flutter clean
flutter pub get

# 5. Xcode 재시작
killall Xcode
```

### 문제 2: Xcode에서 여전히 15.0으로 표시

**원인**: Xcode가 캐시된 설정을 사용 중

**해결 방법:**
```bash
# 프로젝트 파일 재생성
cd ~/makecall/flutter_app
flutter clean
rm -rf ios/Runner.xcworkspace ios/Pods ios/Podfile.lock
flutter pub get
cd ios
pod install
```

### 문제 3: 다른 Firebase 모듈 버전 오류

**확인 방법:**
```bash
cd ~/makecall/flutter_app/ios
grep "minimum deployment target" Pods/*/README.md
```

**해결책**: 가장 높은 최소 버전으로 설정하거나, 해당 Firebase 모듈 버전을 다운그레이드

---

## ✅ 완료 확인

다음 단계가 모두 성공하면 수정 완료:

### 1. 설정 확인
```bash
grep "IPHONEOS_DEPLOYMENT_TARGET" ios/Runner.xcodeproj/project.pbxproj
# 모두 15.6으로 출력되어야 함
```

### 2. 빌드 성공
```
Xcode에서 Cmd+B 실행 시:
✅ "Build Succeeded" 메시지
❌ Deployment Target 관련 오류 없음
```

### 3. 실행 성공
```
Xcode에서 Cmd+R 실행 시:
✅ 앱이 기기/시뮬레이터에서 정상 실행
✅ Firebase 모듈 정상 초기화
```

---

## 📝 변경 이력

| 날짜 | 변경 내용 |
|------|----------|
| 2025-01-XX | iOS Deployment Target을 15.0 → 15.6으로 변경 |
| | Firebase Storage 12.3.2 호환성 확보 |
| | project.pbxproj 3개 Configuration 모두 수정 |

---

## 🔗 관련 문서

- [Apple iOS Version Distribution](https://developer.apple.com/support/app-store/)
- [Firebase iOS Setup](https://firebase.google.com/docs/ios/setup)
- [Flutter iOS Deployment](https://docs.flutter.dev/deployment/ios)

---

## 📞 추가 지원

이 수정으로 문제가 해결되지 않으면:

1. **오류 메시지 전체 복사**
2. **Xcode 빌드 로그 확인**: Product → Show Build Transcript
3. **pod install 출력 확인**: 경고나 오류 메시지 체크
4. **Firebase 모듈 버전 확인**: pubspec.yaml의 버전이 올바른지 확인

문제가 지속되면 구체적인 오류 메시지를 공유해 주세요! 🚀
