# MakeCall

Firebase 기반 통합 통화 관리 Flutter 앱

## 📱 지원 플랫폼

- ✅ **Android** (완벽 지원 - Android 5.0+)
- ✅ **iOS** (완벽 지원 - iOS 15.0+, 최신 iPhone/iPad 지원)
- ✅ **macOS** (완벽 지원 - macOS 12.0+, Apple Silicon & Intel)
- ✅ **Web** (브라우저 미리보기)

## 🎯 주요 기능

### 📞 통화 및 연락처 관리
- **통합 통화 관리**: 메인 번호, 연락처, 통화 이력 관리
- **단말번호 관리**: 사용자별 단말번호 조회 및 저장 (최대 개수 제한)
- **전화번호부**: Firebase 연락처 + 기기 연락처 통합 관리
- **통화 기록**: 수신/발신/부재중 통화 이력 추적

### 🔐 인증 및 사용자 관리
- **Firebase 인증**: 이메일/비밀번호 기반 사용자 인증
- **사용자 프로필**: 프로필 사진, 전화번호, 회사 정보 관리
- **권한 관리**: 기기 연락처 접근 권한 처리 (iOS/Android)

### ☁️ 데이터 동기화
- **Cloud Firestore**: 실시간 데이터 동기화
- **로컬 저장소**: Hive를 사용한 오프라인 지원
- **자동 업데이트**: 수동 새로고침 버튼으로 최신 정보 가져오기

### 🌐 API 통합
- **회사 정보**: 회사명 설정 및 표시
- **API 설정**: 동적 API Base URL 설정 및 PBX 연동
- **자동 포트**: HTTP(3500), HTTPS(3501) 자동 설정
- **인증 관리**: Company ID, App Key 기반 인증

### 🎨 UI/UX
- **Material Design 3**: 최신 디자인 가이드라인 적용
- **4-탭 구조**: Home, Call, Phonebook, Profile
- **반응형 디자인**: 모든 화면 크기 지원
- **다크 모드**: 시스템 테마 자동 감지
- **커스텀 아이콘**: 브랜드 아이덴티티 적용

## 🏗️ 기술 스택

### Core Framework
- **Flutter**: 3.35.4 (Stable)
- **Dart**: 3.9.2
- **Material Design**: 3

### Firebase (고정 버전 - Flutter 3.35.4 호환)
- **Firebase Core**: 3.6.0
- **Firebase Auth**: 5.3.1
- **Cloud Firestore**: 5.4.3
- **Firebase Messaging**: 15.1.3
- **Firebase Storage**: 12.3.2

### State Management & Storage
- **Provider**: 6.1.5+1 (상태 관리)
- **Hive**: 2.2.3 (로컬 문서 DB)
- **Hive Flutter**: 1.1.0
- **Shared Preferences**: 2.5.3 (키-값 저장소)

### Networking & API
- **HTTP**: 1.5.0 (REST API 클라이언트)
- **URL Launcher**: 6.3.1 (전화걸기 등)

### Device Features
- **Permission Handler**: 11.3.1 (권한 관리)
- **Flutter Contacts**: 1.1.9+2 (연락처 접근)
- **Image Picker**: 1.1.2 (사진 선택)

### UI Components
- **Flutter Slidable**: 3.1.1 (스와이프 액션)
- **Intl**: 0.19.0 (국제화/날짜 포맷)
- **Package Info Plus**: 8.1.2 (앱 정보)

### Development Tools
- **Flutter Launcher Icons**: 0.13.1 (앱 아이콘 생성)
- **Flutter Lints**: 5.0.0 (코드 품질)

## 📦 프로젝트 구조

```
lib/
├── main.dart                    # 앱 진입점
├── firebase_options.dart        # Firebase 설정 (Multi-platform)
├── models/                      # 데이터 모델
│   ├── user_model.dart         # 사용자 (maxExtensions, lastMaxExtensionsUpdate 포함)
│   ├── my_extension_model.dart # 단말번호
│   ├── contact_model.dart      # 연락처
│   └── call_history_model.dart # 통화 이력
├── screens/                     # UI 화면
│   ├── auth/                   # 인증 화면
│   │   ├── login_screen.dart
│   │   └── signup_screen.dart
│   ├── home/                   # 홈 탭
│   │   └── home_tab.dart
│   ├── call/                   # 통화 탭
│   │   ├── call_tab.dart
│   │   ├── dialpad_screen.dart
│   │   └── phonebook_tab.dart
│   └── profile/                # 프로필 탭
│       ├── profile_tab.dart
│       └── api_settings_dialog.dart  # 회사/API 설정
├── services/                   # 비즈니스 로직
│   ├── auth_service.dart      # 인증 (refreshUserModel 포함)
│   ├── database_service.dart  # Firestore DB
│   ├── api_service.dart       # PBX API
│   └── mobile_contacts_service.dart  # 기기 연락처
└── widgets/                    # 재사용 가능한 위젯
    ├── add_contact_dialog.dart
    └── call_method_dialog.dart

assets/
└── icons/
    └── app_icon.png           # 앱 아이콘 소스 (128x128)
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
- **중요**: Firestore Database 생성 필요 (Firebase Console)

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

**Android AAB (Google Play):**
```bash
flutter build appbundle --release
```
생성 위치: `build/app/outputs/bundle/release/app-release.aab`

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

**Web:**
```bash
flutter build web --release
```
생성 위치: `build/web/`

## 📝 플랫폼별 설정 정보

### Android
- **Package Name**: `com.olssoo.makecall_app`
- **App Name**: MakeCall
- **Target SDK**: 36 (Android 15)
- **Min SDK**: 21 (Android 5.0 Lollipop)
- **Permissions**: 
  - INTERNET (API 통신)
  - READ_CONTACTS / WRITE_CONTACTS (연락처 접근)
  - CALL_PHONE (전화 걸기)
  - CAMERA (카메라 촬영)
  - READ_EXTERNAL_STORAGE / WRITE_EXTERNAL_STORAGE (Android 12 이하)
  - READ_MEDIA_IMAGES (Android 13+)
  - POST_NOTIFICATIONS (푸시 알림)

### iOS
- **Bundle Identifier**: `com.olssoo.makecall`
- **App Name**: MakeCall
- **Deployment Target**: iOS 15.0+
- **Supported Devices**: iPhone, iPad (최신 기기 포함)
- **Orientations**: Portrait, Landscape
- **Permissions (Privacy Usage Descriptions)**:
  - Contacts (연락처 접근)
  - Camera (카메라 촬영 - 프로필 사진)
  - Photo Library (갤러리 접근 - 프로필 사진)
  - Photo Library Add (사진 저장)

### macOS
- **Bundle Identifier**: `com.olssoo.makecall`
- **App Name**: MakeCall
- **Deployment Target**: macOS 12.0 (Monterey)+
- **Architectures**: Apple Silicon (M1/M2/M3/M4) & Intel

### Web
- **Favicon**: 192x192, 512x512
- **PWA Support**: Maskable icons
- **Theme Color**: #2196F3 (파란색)

## 🎨 앱 아이콘

### 최신 UI/UX 가이드라인 적용
- **Android**: Material Design 3 준수
  - 적응형 아이콘 (Adaptive Icon)
  - 배경: #2196F3 (파란색)
  - 다양한 밀도 지원 (mdpi ~ xxxhdpi)
- **iOS**: Human Interface Guidelines 준수
  - App Store 1024x1024 아이콘
  - 모든 기기 해상도 지원
  - Alpha 채널 제거
- **Web**: PWA 표준 준수
  - Maskable icons
  - 192x192, 512x512 크기

## 🔧 회사 / API 설정

앱 내 프로필 탭에서 **회사 / API 설정** 가능:

### 회사 정보
- **회사명**: 홈 탭에 표시되는 회사 이름
- **필수 입력**: 회사명 미설정 시 경고 표시

### API 설정
- **API Base URL**: 서버 주소 (예: `api.example.com`)
- **HTTP Port**: 3500 (자동 설정)
- **HTTPS Port**: 3501 (자동 설정)
- **Company ID**: 회사 식별자
- **App Key**: API 인증 키
- **API Path**: `/api/v2` (자동 추가)

### 생성되는 엔드포인트
- HTTPS: `https://{baseUrl}:3501/api/v2`
- HTTP: `http://{baseUrl}:3500/api/v2`

## 👤 사용자 관리

### maxExtensions (단말번호 저장 제한)
- **DB 기반 제어**: Firestore의 `maxExtensions` 값이 기준
- **저장 제한**: 사용자는 maxExtensions 개수만큼만 저장 가능
- **관리자 제어**: Firebase Console에서 직접 값 변경
- **수동 새로고침**: 새로고침 버튼으로 최신 정보 업데이트

### lastMaxExtensionsUpdate (업데이트 시간)
- **자동 기록**: Firestore에서 데이터 로드 시 자동 설정
- **수동 업데이트**: 새로고침 버튼 클릭 시 현재 시간으로 갱신
- **타임스탬프 표시**:
  - "방금 업데이트됨" (< 1분)
  - "N분 전 업데이트" (< 1시간)
  - "N시간 전 업데이트" (< 24시간)
  - "YYYY년 M월 D일 오전/오후 H:MM 업데이트" (그 외)

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

### 앱 아이콘 재생성
```bash
flutter pub run flutter_launcher_icons
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
- **Apple Silicon**: MacBook Pro M1/M2/M3/M4, MacBook Air M1/M2/M3, iMac M1/M3/M4, Mac Studio M1/M2, Mac mini M1/M2/M4
- **Intel**: MacBook Pro (2017+), MacBook Air (2018+), iMac (2017+), Mac mini (2018+), Mac Pro (2019+)

### Android (Android 5.0+)
- 모든 Android 5.0 이상 기기 지원
- Pixel, Galaxy, OnePlus, Xiaomi 등 모든 제조사

## 📚 주요 변경사항

### 2024-10-31: 프로필 이미지 업로드 버그 수정
- ✅ **iOS hang 문제 해결**: 사진 선택 시 앱이 멈추는 문제 수정
- ✅ **Android 권한 추가**: CAMERA, READ_MEDIA_IMAGES 등 필수 권한 추가
- ✅ **iOS Privacy 설정**: 카메라, 갤러리 접근 권한 설명 추가
- ✅ **업로드 타임아웃**: 30초 타임아웃 및 에러 처리 개선
- ✅ **Firebase Storage Rules**: 보안 규칙 설정 스크립트 추가
- ✅ **진행 상황 로깅**: 업로드 진행 상황 디버그 로그 추가

### 2024-10-31: 앱 아이콘 및 사용자 관리 개선
- ✅ **앱 아이콘 업데이트**: 최신 iOS/Android 가이드라인 적용
- ✅ **회사 정보 추가**: 회사명 설정 기능
- ✅ **단말번호 제한**: DB 기반 maxExtensions 제어
- ✅ **수동 새로고침**: 사용자 데이터 수동 업데이트 버튼
- ✅ **타임스탬프 표시**: 마지막 업데이트 시간 표시
- ✅ **권한 처리 개선**: iOS/Android 연락처 권한 최적화

### 이전 변경사항
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
5. **Firestore Database**: Firebase Console에서 Database 생성 필요

## 🔐 Firebase 설정 가이드

### Android 설정
1. Firebase Console에서 Android 앱 추가
2. Package Name: `com.olssoo.makecall_app` 입력
3. `google-services.json` 다운로드
4. 파일을 `android/app/` 디렉토리에 추가

### iOS 설정
1. Firebase Console에서 iOS 앱 추가
2. Bundle ID: `com.olssoo.makecall` 입력
3. `GoogleService-Info.plist` 다운로드
4. 파일을 `ios/Runner/` 디렉토리에 추가
5. Xcode에서 프로젝트에 파일 추가 확인

### Firestore Database 생성
1. Firebase Console → Build → Firestore Database
2. "Create Database" 클릭
3. Production mode 또는 Test mode 선택
4. 지역 선택 (가까운 지역 권장)
5. Database 생성 완료

### Firebase Storage 설정 (프로필 이미지 업로드용)
1. Firebase Console → Build → Storage
2. "Get started" 클릭하여 Storage 활성화
3. 보안 규칙 설정:
   ```bash
   python3 setup_firebase_storage_rules.py
   ```
4. 출력된 보안 규칙을 Firebase Console → Storage → Rules에 복사
5. "게시" 버튼 클릭하여 규칙 적용

**보안 규칙 요약**:
- 프로필 이미지: 인증된 사용자가 자신의 이미지만 업로드/삭제 가능
- 모든 사용자가 프로필 이미지 조회 가능
- 기타 파일: 인증된 사용자만 접근 가능

## 📞 지원

문제가 발생하거나 질문이 있으시면 GitHub Issues를 통해 문의해주세요.

## 📄 라이선스

이 프로젝트는 비공개 프로젝트입니다.
