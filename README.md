# MakeCall

Firebase 기반 통합 통화 관리 Flutter 앱

## 📱 지원 플랫폼

- ✅ **Android** (완벽 지원 - Android 5.0+)
- ✅ **iOS** (완벽 지원 - iOS 15.0+, 최신 iPhone/iPad 지원)
- ✅ **macOS** (완벽 지원 - macOS 12.0+, Apple Silicon & Intel)
- ✅ **Web** (브라우저 미리보기)

## 🎯 주요 기능

- 📞 **통합 통화 관리**: 메인 번호, 연락처, 통화 이력 관리
- 🔐 **Firebase 인증**: 이메일/비밀번호 기반 사용자 인증
- ☁️ **Cloud Firestore**: 실시간 데이터 동기화
- 🌐 **API 통합**: 동적 API Base URL 설정 및 PBX 연동
- 📱 **4-탭 구조**: Home, Call, Profile, Settings
- 🌍 **크로스 플랫폼**: Android, iOS, macOS, Web 모두 지원

## 🏗️ 기술 스택

- **Flutter**: 3.35.4
- **Dart**: 3.9.2
- **Firebase Core**: 3.6.0
- **Firebase Auth**: 5.3.1
- **Cloud Firestore**: 5.4.3
- **Provider**: 6.1.5+1 (상태 관리)
- **Material Design**: 3

## 📦 프로젝트 구조

```
lib/
├── main.dart                    # 앱 진입점
├── firebase_options.dart        # Firebase 설정
├── models/                      # 데이터 모델
│   ├── user_model.dart
│   ├── main_number_model.dart
│   ├── contact_model.dart
│   ├── call_history_model.dart
│   └── extension_model.dart
├── screens/                     # UI 화면
│   ├── auth/                    # 인증 화면
│   ├── home/                    # 홈 탭
│   ├── call/                    # 통화 탭
│   ├── profile/                 # 프로필 탭
│   └── settings/                # 설정 탭
├── services/                    # 비즈니스 로직
│   ├── auth_service.dart
│   ├── database_service.dart
│   ├── api_service.dart
│   └── call_service.dart
└── widgets/                     # 재사용 가능한 위젯
    └── call_method_dialog.dart
```

## 🚀 시작하기

### 1. 의존성 설치
```bash
flutter pub get
```

### 2. Firebase 설정 확인
- `android/app/google-services.json` 파일 존재 확인 (Android)
- `ios/Runner/GoogleService-Info.plist` 필요 (iOS - 별도 생성)
- Firebase 프로젝트 설정 완료 필요

### 3. 플랫폼별 앱 실행

**Android:**
```bash
flutter run -d android
```

**iOS (macOS에서 실행 시):**
```bash
flutter run -d ios
# 또는 특정 시뮬레이터 선택
flutter run -d iPhone
```

**macOS:**
```bash
flutter run -d macos
```

**웹 브라우저:**
```bash
flutter run -d chrome
```

### 4. 릴리즈 빌드

**Android APK:**
```bash
flutter build apk --release
```
생성 위치: `build/app/outputs/flutter-apk/app-release.apk`

**iOS (macOS에서 빌드 시):**
```bash
flutter build ios --release
```
빌드 후 Xcode에서 Archive 및 App Store Connect 업로드

**macOS:**
```bash
flutter build macos --release
```
생성 위치: `build/macos/Build/Products/Release/MakeCall.app`

## 📝 플랫폼별 설정 정보

### Android
- **Package Name**: `com.olssoo.makecall_app`
- **App Name**: MakeCall
- **Target SDK**: 36 (Android 15)
- **Min SDK**: 21 (Android 5.0 Lollipop)

### iOS
- **Bundle Identifier**: `com.olssoo.makecall`
- **App Name**: MakeCall
- **Deployment Target**: iOS 15.0+
- **Supported Devices**: iPhone, iPad (최신 기기 포함)
- **Orientations**: Portrait, Landscape

### macOS
- **Bundle Identifier**: `com.olssoo.makecall`
- **App Name**: MakeCall
- **Deployment Target**: macOS 12.0 (Monterey)+
- **Architectures**: Apple Silicon (M1/M2/M3) & Intel

## 🔧 API 설정

앱 내 프로필 탭에서 API Base URL 설정 가능:
- API Base URL (예: `api.example.com`)
- HTTP Port (예: `8080`)
- HTTPS Port (예: `8443`)
- API Path: `/api/v2` (자동 추가)

생성되는 엔드포인트:
- `https://{baseUrl}:{httpsPort}/api/v2`
- `http://{baseUrl}:{httpPort}/api/v2`

## 🛠️ 개발 가이드

### 코드 분석
```bash
flutter analyze
```

### 코드 포맷팅
```bash
dart format .
```

### 테스트 실행
```bash
flutter test
```

### 지원 플랫폼 확인
```bash
flutter devices
```

## 📱 지원 기기

### iOS (iOS 15.0+)
- iPhone 15 Pro Max / Pro / Plus / Standard
- iPhone 14 Pro Max / Pro / Plus / Standard
- iPhone 13 Pro Max / Pro / Mini / Standard
- iPhone 12 Pro Max / Pro / Mini / Standard
- iPhone 11 Pro Max / Pro / Standard
- iPhone SE (2nd gen, 3rd gen)
- iPad Pro (모든 세대)
- iPad Air (4th gen+)
- iPad (9th gen+)
- iPad mini (6th gen+)

### macOS (macOS 12.0+)
- **Apple Silicon**: MacBook Pro M1/M2/M3, MacBook Air M1/M2/M3, iMac M1/M3, Mac Studio M1/M2, Mac mini M1/M2/M4
- **Intel**: MacBook Pro (2017+), MacBook Air (2018+), iMac (2017+), Mac mini (2018+), Mac Pro (2019+)

### Android (Android 5.0+)
- 모든 Android 5.0 이상 기기 지원
- Pixel, Galaxy, OnePlus, Xiaomi 등 모든 제조사

## 📚 주요 변경사항

- ✅ 앱 이름: MakCall → MakeCall
- ✅ Android 패키지명: com.olssoo.makecall_app
- ✅ iOS/macOS Bundle ID: com.olssoo.makecall
- ✅ API 경로: `/api2` → `/api/v2`
- ✅ Call 탭 기본 화면: Keypad
- ✅ Home 탭에 사용자 전화번호 표시
- ✅ Profile 탭에 API 엔드포인트 상세 정보
- ✅ Firestore 쿼리 최적화 (메모리 기반 정렬)
- ✅ iOS 15.0+ 지원 (최신 iPhone/iPad)
- ✅ macOS 12.0+ 지원 (Apple Silicon & Intel)
- ✅ 크로스 플랫폼 완벽 지원

## 🐛 알려진 제한사항

1. **웹 플랫폼 CORS**: 웹에서 API 호출 시 서버의 CORS 설정 필요
2. **로컬 앱 통화**: 현재 버전에서는 비활성화됨
3. **iOS 빌드**: macOS 환경과 Xcode 필요
4. **Firebase 설정**: 각 플랫폼별 Firebase 구성 파일 필요
   - Android: `google-services.json`
   - iOS: `GoogleService-Info.plist` (별도 생성 필요)

## 🔐 Firebase iOS 설정 가이드

iOS에서 Firebase를 사용하려면 추가 설정이 필요합니다:

1. Firebase Console에서 iOS 앱 추가
2. Bundle ID: `com.olssoo.makecall` 입력
3. `GoogleService-Info.plist` 다운로드
4. 파일을 `ios/Runner/` 디렉토리에 추가
5. Xcode에서 프로젝트에 파일 추가 확인

## 📞 지원

문제가 발생하거나 질문이 있으시면 GitHub Issues를 통해 문의해주세요.

## 📄 라이선스

이 프로젝트는 비공개 프로젝트입니다.
