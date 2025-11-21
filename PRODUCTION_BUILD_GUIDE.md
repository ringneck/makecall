# 🚀 MAKECALL 프로덕션 빌드 가이드

> **버전**: 1.0.0+1  
> **패키지**: com.olssoo.makecall_app  
> **최종 업데이트**: 2024-11-21

---

## 📋 목차

1. [사전 준비사항](#사전-준비사항)
2. [Android APK/AAB 빌드](#-android-apkaab-빌드)
3. [iOS IPA 빌드](#-ios-ipa-빌드)
4. [Windows 데스크톱 빌드](#-windows-데스크톱-빌드)
5. [macOS 데스크톱 빌드](#-macos-데스크톱-빌드)
6. [Web 프로덕션 빌드](#-web-프로덕션-빌드)
7. [빌드 후 체크리스트](#-빌드-후-체크리스트)
8. [문제 해결](#-문제-해결)

---

## 사전 준비사항

### ✅ 필수 확인 사항

```bash
# Flutter 버전 확인
flutter --version
# Flutter 3.35.4 • Dart 3.9.2

# Flutter Doctor 실행
flutter doctor -v

# 의존성 업데이트
cd /home/user/flutter_app
flutter pub get
flutter pub upgrade

# 코드 분석 (에러 없어야 함)
flutter analyze

# 테스트 실행 (선택사항)
flutter test
```

### 📝 버전 정보 확인

**현재 설정된 버전**:
- **Version Name**: 1.0.0
- **Build Number**: 1
- **패키지 ID**: com.olssoo.makecall_app

**버전 변경 방법**:
```yaml
# pubspec.yaml 파일 수정
version: 1.0.0+1  # {major}.{minor}.{patch}+{buildNumber}
```

---

## 📱 Android APK/AAB 빌드

### 1️⃣ 서명 키 확인

```bash
# 서명 키 파일 확인
ls -la android/release-key.jks
ls -la android/key.properties
```

**key.properties 내용**:
```properties
storePassword=makecall2024!@
keyPassword=makecall2024!@
keyAlias=release
storeFile=release-key.jks
```

### 2️⃣ Firebase 설정 확인

```bash
# google-services.json 파일 확인 (Android)
ls -la android/app/google-services.json

# 패키지 ID 일치 확인
grep "package_name" android/app/google-services.json
# 출력: "package_name": "com.olssoo.makecall_app"
```

### 3️⃣ APK 빌드 (단일 파일 배포용)

```bash
# Release APK 빌드
flutter build apk --release

# Split APK 빌드 (ABI별 분리 - 파일 크기 최적화)
flutter build apk --split-per-abi --release

# 빌드 결과물 위치
# build/app/outputs/flutter-apk/app-release.apk (약 40-50MB)
# build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk (약 20MB)
# build/app/outputs/flutter-apk/app-arm64-v8a-release.apk (약 25MB)
# build/app/outputs/flutter-apk/app-x86_64-release.apk (약 25MB)
```

**APK 다운로드**:
```bash
# APK 파일 위치 확인
ls -lh build/app/outputs/flutter-apk/*.apk
```

### 4️⃣ AAB 빌드 (Google Play Store 배포용)

```bash
# Release AAB 빌드
flutter build appbundle --release

# 빌드 결과물 위치
# build/app/outputs/bundle/release/app-release.aab (약 35-45MB)
```

**AAB 다운로드**:
```bash
# AAB 파일 위치 확인
ls -lh build/app/outputs/bundle/release/app-release.aab
```

### 5️⃣ 빌드 옵션 (고급)

```bash
# 난독화 활성화 (코드 보호)
flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols

# 특정 버전으로 빌드
flutter build apk --release --build-name=1.0.1 --build-number=2

# 성능 프로파일 포함
flutter build apk --release --profile
```

### 6️⃣ Google Play Store 업로드 준비

**필요한 정보**:
1. **App Bundle (AAB)**: `app-release.aab`
2. **앱 설명**: MAKECALL - 한국어 개인정보보호법 준수 통신 앱
3. **스크린샷**: 최소 2개 (휴대전화, 태블릿)
4. **앱 아이콘**: `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`
5. **개인정보처리방침 URL**: https://app.makecall.io/privacy_policy.html
6. **이용약관 URL**: https://app.makecall.io/terms_of_service.html

**Play Console 업로드 단계**:
1. Google Play Console (https://play.google.com/console) 로그인
2. "앱 만들기" 또는 기존 앱 선택
3. "프로덕션" → "새 버전 만들기"
4. `app-release.aab` 파일 업로드
5. 버전 정보 입력 (1.0.0+1)
6. 출시 노트 작성
7. "검토" → "프로덕션으로 출시"

---

## 🍎 iOS IPA 빌드

### ⚠️ 사전 요구사항

- **macOS 시스템 필요**
- **Xcode 15.0 이상** 설치
- **Apple Developer Account** (유료, $99/년)
- **Code Signing Certificate** 및 **Provisioning Profile**

### 1️⃣ Firebase 설정 확인

```bash
# GoogleService-Info.plist 파일 확인 (iOS)
ls -la ios/Runner/GoogleService-Info.plist

# Bundle ID 확인
grep "BUNDLE_IDENTIFIER" ios/Runner.xcodeproj/project.pbxproj
# 출력: PRODUCT_BUNDLE_IDENTIFIER = com.olssoo.makecall_app;
```

### 2️⃣ Xcode에서 서명 설정

```bash
# Xcode 프로젝트 열기
open ios/Runner.xcworkspace

# Xcode에서 수동 설정:
# 1. Runner 선택
# 2. "Signing & Capabilities" 탭
# 3. Team 선택 (Apple Developer Account)
# 4. Bundle Identifier 확인: com.olssoo.makecall_app
# 5. Signing Certificate 선택
# 6. Provisioning Profile 선택
```

### 3️⃣ iOS 빌드 (macOS에서 실행)

```bash
# Release IPA 빌드
flutter build ios --release

# Archive 생성 (Xcode 필요)
flutter build ipa --release

# 빌드 결과물 위치
# build/ios/ipa/flutter_app.ipa
```

### 4️⃣ TestFlight / App Store 배포

**TestFlight (베타 테스트)**:
```bash
# Xcode에서 Archive 업로드
# 1. Xcode → Product → Archive
# 2. Organizer 창에서 "Distribute App"
# 3. "TestFlight & App Store" 선택
# 4. 업로드 완료 후 TestFlight에서 확인
```

**App Store 출시**:
1. App Store Connect (https://appstoreconnect.apple.com) 로그인
2. "나의 앱" → "+" → "새로운 앱"
3. 앱 정보 입력
   - **이름**: MAKECALL
   - **Bundle ID**: com.olssoo.makecall_app
   - **SKU**: com.olssoo.makecall_app
4. "버전" → "빌드" → TestFlight 빌드 선택
5. 앱 설명, 스크린샷, 개인정보처리방침 URL 입력
6. "심사 제출"

### 5️⃣ iOS 필수 설정 (info.plist)

```xml
<!-- ios/Runner/Info.plist -->
<key>NSCameraUsageDescription</key>
<string>프로필 사진 촬영을 위해 카메라 접근이 필요합니다.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>프로필 사진 선택을 위해 사진 라이브러리 접근이 필요합니다.</string>

<key>NSMicrophoneUsageDescription</key>
<string>통화 기능을 위해 마이크 접근이 필요합니다.</string>

<key>NSContactsUsageDescription</key>
<string>연락처 동기화를 위해 연락처 접근이 필요합니다.</string>
```

---

## 🪟 Windows 데스크톱 빌드

### ⚠️ 사전 요구사항

- **Windows 10/11** 시스템
- **Visual Studio 2022** (Desktop development with C++ 워크로드)
- **Flutter Windows Desktop 지원** 활성화

### 1️⃣ Windows Desktop 활성화

```bash
# Windows Desktop 지원 확인
flutter config --enable-windows-desktop

# 의존성 확인
flutter doctor -v
# [✓] Visual Studio - develop for Windows
```

### 2️⃣ Windows 빌드

```bash
# Release 빌드
flutter build windows --release

# 빌드 결과물 위치
# build/windows/x64/runner/Release/
```

**빌드 결과 구조**:
```
build/windows/x64/runner/Release/
├── flutter_app.exe          # 실행 파일 (약 15MB)
├── flutter_windows.dll       # Flutter 런타임
├── data/                     # 리소스 파일
│   ├── icudtl.dat
│   └── flutter_assets/
└── *.dll                     # 기타 의존성 DLL
```

### 3️⃣ 설치 프로그램 만들기 (선택사항)

**Inno Setup 사용**:
```bash
# Inno Setup 다운로드: https://jrsoftware.org/isdl.php

# setup.iss 스크립트 작성
[Setup]
AppName=MAKECALL
AppVersion=1.0.0
DefaultDirName={pf}\MAKECALL
DefaultGroupName=MAKECALL
OutputDir=installer
OutputBaseFilename=MAKECALL-Setup-1.0.0

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs

[Icons]
Name: "{group}\MAKECALL"; Filename: "{app}\flutter_app.exe"
Name: "{commondesktop}\MAKECALL"; Filename: "{app}\flutter_app.exe"
```

### 4️⃣ 배포 방법

**방법 1: 압축 파일 배포**:
```bash
# Release 폴더 전체 압축
cd build/windows/x64/runner/
7z a MAKECALL-Windows-1.0.0.zip Release/
```

**방법 2: Microsoft Store 배포**:
1. Windows 앱 인증 (WACK) 테스트
2. MSIX 패키지 생성
3. Partner Center에서 앱 등록
4. 심사 제출

---

## 🍎 macOS 데스크톱 빌드

### ⚠️ 사전 요구사항

- **macOS 11.0 (Big Sur) 이상**
- **Xcode 13.0 이상**
- **Apple Developer Account** (Mac App Store 배포 시)

### 1️⃣ macOS Desktop 활성화

```bash
# macOS Desktop 지원 확인
flutter config --enable-macos-desktop

# 의존성 확인
flutter doctor -v
# [✓] Xcode - develop for macOS
```

### 2️⃣ macOS 빌드

```bash
# Release 빌드
flutter build macos --release

# 빌드 결과물 위치
# build/macos/Build/Products/Release/flutter_app.app
```

### 3️⃣ 코드 서명 (Code Signing)

```bash
# Xcode에서 서명 설정
open macos/Runner.xcworkspace

# Xcode 설정:
# 1. Runner 선택
# 2. "Signing & Capabilities" 탭
# 3. Team 선택
# 4. Bundle Identifier 확인: com.olssoo.makecall_app
# 5. "Hardened Runtime" 활성화
# 6. Entitlements 확인
```

### 4️⃣ DMG 설치 파일 만들기

```bash
# create-dmg 도구 사용
brew install create-dmg

# DMG 파일 생성
create-dmg \
  --volname "MAKECALL Installer" \
  --volicon "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --icon "flutter_app.app" 200 190 \
  --hide-extension "flutter_app.app" \
  --app-drop-link 600 185 \
  "MAKECALL-macOS-1.0.0.dmg" \
  "build/macos/Build/Products/Release/flutter_app.app"
```

### 5️⃣ Mac App Store 배포

**Notarization (공증) 필수**:
```bash
# 앱 공증 (Apple에서 보안 검사)
xcrun notarytool submit \
  build/macos/Build/Products/Release/flutter_app.app \
  --apple-id "your-apple-id@email.com" \
  --password "app-specific-password" \
  --team-id "YOUR_TEAM_ID" \
  --wait

# 공증 완료 후 스테이플링
xcrun stapler staple build/macos/Build/Products/Release/flutter_app.app
```

**App Store Connect 업로드**:
```bash
# Xcode → Product → Archive
# Organizer → Distribute App → Mac App Store
```

---

## 🌐 Web 프로덕션 빌드

### 1️⃣ Web 빌드

```bash
# Production Web 빌드
flutter build web --release

# 빌드 결과물 위치
# build/web/
```

**빌드 옵션**:
```bash
# 최적화된 빌드 (권장)
flutter build web --release \
  --web-renderer canvaskit \
  --dart-define=flutter.inspector.structuredErrors=false

# CanvasKit + HTML 자동 선택
flutter build web --release --web-renderer auto

# HTML 렌더러 (더 빠른 로딩)
flutter build web --release --web-renderer html
```

### 2️⃣ 빌드 결과 구조

```
build/web/
├── index.html                # 메인 HTML
├── main.dart.js              # 컴파일된 Dart 코드
├── flutter.js                # Flutter 부트로더
├── favicon.png               # 파비콘
├── manifest.json             # PWA 매니페스트
├── assets/                   # 리소스 파일
│   ├── fonts/
│   ├── images/
│   └── AssetManifest.json
└── canvaskit/                # CanvasKit 렌더러
    ├── canvaskit.js
    └── canvaskit.wasm
```

### 3️⃣ Firebase Hosting 배포

```bash
# Firebase CLI 설치
npm install -g firebase-tools

# Firebase 로그인
firebase login

# Firebase 프로젝트 초기화
firebase init hosting

# 설정 선택:
# - Public directory: build/web
# - Single-page app: Yes
# - Automatic builds with GitHub: No

# 배포
firebase deploy --only hosting

# 배포 URL 확인
# https://your-project-id.web.app
```

**firebase.json 설정**:
```json
{
  "hosting": {
    "public": "build/web",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ],
    "headers": [
      {
        "source": "**/*.@(jpg|jpeg|gif|png|svg|webp)",
        "headers": [
          {
            "key": "Cache-Control",
            "value": "max-age=31536000"
          }
        ]
      },
      {
        "source": "**/*.@(js|css)",
        "headers": [
          {
            "key": "Cache-Control",
            "value": "max-age=31536000"
          }
        ]
      }
    ]
  }
}
```

### 4️⃣ 일반 웹 서버 배포

**Nginx 설정**:
```nginx
server {
    listen 80;
    server_name app.makecall.io;
    root /var/www/makecall/build/web;
    index index.html;

    # SPA 라우팅
    location / {
        try_files $uri $uri/ /index.html;
    }

    # 캐싱 설정
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Gzip 압축
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/json;
}
```

**Apache 설정**:
```apache
<VirtualHost *:80>
    ServerName app.makecall.io
    DocumentRoot /var/www/makecall/build/web
    
    <Directory /var/www/makecall/build/web>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
        
        # SPA 라우팅
        RewriteEngine On
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteCond %{REQUEST_FILENAME} !-d
        RewriteRule ^ index.html [L]
    </Directory>
</VirtualHost>
```

### 5️⃣ PWA 설정 (Progressive Web App)

**manifest.json 확인**:
```json
{
  "name": "MAKECALL",
  "short_name": "MAKECALL",
  "description": "MAKECALL - 통신 앱",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#FFFFFF",
  "theme_color": "#2196F3",
  "icons": [
    {
      "src": "icons/Icon-192.png",
      "sizes": "192x192",
      "type": "image/png"
    },
    {
      "src": "icons/Icon-512.png",
      "sizes": "512x512",
      "type": "image/png"
    }
  ]
}
```

**Service Worker 활성화**:
```html
<!-- web/index.html -->
<script>
  if ('serviceWorker' in navigator) {
    window.addEventListener('load', function () {
      navigator.serviceWorker.register('/flutter_service_worker.js');
    });
  }
</script>
```

### 6️⃣ 성능 최적화

```bash
# 코드 분할 (Code Splitting)
flutter build web --release --split-debug-info=build/web/debug_info

# Tree Shaking (미사용 코드 제거)
flutter build web --release --tree-shake-icons

# 소스맵 생성 (디버깅용, 프로덕션에서는 비활성화)
flutter build web --release --source-maps
```

---

## ✅ 빌드 후 체크리스트

### Android APK/AAB
- [ ] APK/AAB 파일 생성 확인
- [ ] 파일 크기 확인 (APK: ~40-50MB, AAB: ~35-45MB)
- [ ] 실제 기기에서 설치 테스트
- [ ] 소셜 로그인 테스트 (Google, Kakao, Apple)
- [ ] Firebase 연동 테스트
- [ ] 개인정보보호법 동의 UI 확인
- [ ] 권한 요청 정상 작동 확인
- [ ] ProGuard 난독화 확인 (선택)

### iOS IPA
- [ ] IPA 파일 생성 확인
- [ ] TestFlight 업로드 성공
- [ ] 베타 테스터 초대 및 테스트
- [ ] 소셜 로그인 테스트 (특히 Apple Sign In)
- [ ] Push Notification 테스트
- [ ] 개인정보 보호 설명 확인
- [ ] App Store 스크린샷 준비

### Windows Desktop
- [ ] EXE 실행 파일 정상 작동
- [ ] 모든 DLL 파일 포함 확인
- [ ] 다른 Windows PC에서 실행 테스트
- [ ] 바이러스 백신 오탐지 확인
- [ ] 설치 프로그램 테스트 (Inno Setup)

### macOS Desktop
- [ ] .app 번들 정상 작동
- [ ] 코드 서명 확인
- [ ] 공증(Notarization) 완료
- [ ] DMG 설치 파일 테스트
- [ ] 다른 Mac에서 설치 테스트
- [ ] Gatekeeper 경고 없음 확인

### Web
- [ ] 빌드 파일 생성 확인
- [ ] 로컬 서버에서 테스트
- [ ] 모바일 브라우저 테스트
- [ ] PWA 설치 가능 확인
- [ ] Firebase Hosting 배포 성공
- [ ] HTTPS 적용 확인
- [ ] 페이지 로딩 속도 확인 (Lighthouse)

---

## 🔧 문제 해결

### Android 빌드 오류

**문제 1: "Keystore not found"**
```bash
# 해결: 키스토어 경로 확인
ls -la android/release-key.jks
ls -la android/key.properties
```

**문제 2: "Execution failed for task ':app:lintVitalRelease'"**
```bash
# 해결: Lint 검사 비활성화
# android/app/build.gradle.kts에 추가
android {
    lintOptions {
        checkReleaseBuilds = false
    }
}
```

**문제 3: "Google Services plugin error"**
```bash
# 해결: google-services.json 확인
ls -la android/app/google-services.json
grep "package_name" android/app/google-services.json
```

### iOS 빌드 오류

**문제 1: "No matching provisioning profiles found"**
```bash
# 해결: Xcode에서 Team 설정
open ios/Runner.xcworkspace
# Signing & Capabilities → Team 선택
```

**문제 2: "CocoaPods not installed"**
```bash
# 해결: CocoaPods 설치
sudo gem install cocoapods
cd ios
pod install
```

### Web 빌드 오류

**문제 1: "CanvasKit initialization failed"**
```bash
# 해결: HTML 렌더러 사용
flutter build web --release --web-renderer html
```

**문제 2: "Failed to load asset"**
```bash
# 해결: pubspec.yaml에 assets 선언 확인
flutter:
  assets:
    - assets/images/
```

### Windows 빌드 오류

**문제 1: "Visual Studio not found"**
```bash
# 해결: Visual Studio 2022 설치
# Desktop development with C++ 워크로드 포함
```

**문제 2: "Missing DLL files"**
```bash
# 해결: Release 폴더 전체 복사
cp -r build/windows/x64/runner/Release/* destination/
```

---

## 📊 빌드 결과물 크기 비교

| 플랫폼 | 파일 형식 | 예상 크기 |
|--------|-----------|-----------|
| Android | APK (Universal) | 40-50 MB |
| Android | APK (Split) | 20-25 MB |
| Android | AAB | 35-45 MB |
| iOS | IPA | 45-60 MB |
| Windows | EXE + DLLs | 30-40 MB |
| macOS | .app | 35-45 MB |
| Web | Static Files | 10-15 MB |

---

## 🎯 배포 플랫폼별 추천 전략

### Google Play Store (Android)
- **필수**: AAB 형식 사용
- **권장**: 내부 테스트 → 비공개 테스트 → 공개 테스트 → 프로덕션
- **소요 시간**: 첫 심사 3-7일, 업데이트 몇 시간

### Apple App Store (iOS)
- **필수**: TestFlight 베타 테스트
- **권장**: 스크린샷 최소 5개, App Preview 동영상
- **소요 시간**: 첫 심사 1-3일, 업데이트 1-2일

### Microsoft Store (Windows)
- **권장**: MSIX 패키지 형식
- **대안**: 직접 배포 (웹사이트, GitHub Releases)

### Mac App Store (macOS)
- **필수**: 공증(Notarization)
- **권장**: DMG 파일로 직접 배포 옵션 제공

### Web Hosting
- **권장**: Firebase Hosting (무료, CDN, HTTPS 자동)
- **대안**: Vercel, Netlify, AWS S3 + CloudFront

---

## 📞 지원 및 문의

- **개발자 문서**: https://docs.flutter.dev/deployment
- **Firebase 문서**: https://firebase.google.com/docs
- **Google Play Console**: https://play.google.com/console
- **App Store Connect**: https://appstoreconnect.apple.com

---

**© 2024 MAKECALL. All rights reserved.**
