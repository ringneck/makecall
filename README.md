# MakeCall

Firebase 기반 통합 통화 관리 Flutter 앱

## 📱 지원 플랫폼

- ✅ **Android** (완벽 지원)
- ✅ **Web** (브라우저 미리보기)
- ❌ **iOS** (지원하지 않음)

## ⚠️ 중요 안내

**iOS 플랫폼은 지원하지 않습니다.**

VSCode에서 `flutter run -d ios` 명령 실행 시 에러가 발생합니다.
iOS 관련 디렉토리(ios/, macos/)는 프로젝트에서 제거되었습니다.

**지원되는 실행 방법:**
```bash
# Android 디바이스/에뮬레이터
flutter run -d android

# 웹 브라우저
flutter run -d chrome
flutter run -d web-server

# Release APK 빌드
flutter build apk --release
```

## 🎯 주요 기능

- 📞 **통합 통화 관리**: 메인 번호, 연락처, 통화 이력 관리
- 🔐 **Firebase 인증**: 이메일/비밀번호 기반 사용자 인증
- ☁️ **Cloud Firestore**: 실시간 데이터 동기화
- 🌐 **API 통합**: 동적 API Base URL 설정 및 PBX 연동
- 📱 **4-탭 구조**: Home, Call, Profile, Settings

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
- `android/app/google-services.json` 파일 존재 확인
- Firebase 프로젝트 설정 완료 필요

### 3. 앱 실행

**Android:**
```bash
flutter run -d android
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

생성된 APK 위치: `build/app/outputs/flutter-apk/app-release.apk`

## 📝 설정 정보

### Android 패키지 정보
- **Package Name**: `com.olssoo.makecall_app`
- **App Name**: MakeCall
- **Target SDK**: 36 (Android 15)

### API 설정
앱 내 프로필 탭에서 API Base URL 설정 가능:
- API Base URL (예: `api.example.com`)
- HTTP Port (예: `8080`)
- HTTPS Port (예: `8443`)
- API Path: `/api/v2` (자동 추가)

생성되는 엔드포인트:
- `https://{baseUrl}:{httpsPort}/api/v2`
- `http://{baseUrl}:{httpPort}/api/v2`

## 🔧 개발 가이드

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

## 📚 주요 변경사항

- ✅ 앱 이름: MakCall → MakeCall
- ✅ 패키지명: com.olssoo.makecall_app
- ✅ API 경로: `/api2` → `/api/v2`
- ✅ Call 탭 기본 화면: Keypad
- ✅ Home 탭에 사용자 전화번호 표시
- ✅ Profile 탭에 API 엔드포인트 상세 정보
- ✅ Firestore 쿼리 최적화 (메모리 기반 정렬)
- ✅ iOS/macOS 지원 제거 (Android 전용)

## 🐛 알려진 제한사항

1. **iOS 미지원**: iOS 플랫폼은 지원하지 않습니다
2. **웹 플랫폼 CORS**: 웹에서 API 호출 시 서버의 CORS 설정 필요
3. **로컬 앱 통화**: 현재 버전에서는 비활성화됨

## 📞 지원

문제가 발생하거나 질문이 있으시면 GitHub Issues를 통해 문의해주세요.

## 📄 라이선스

이 프로젝트는 비공개 프로젝트입니다.
