# 카카오 SDK 설정 가이드

이 디렉토리는 카카오 로그인 API 키 설정을 관리합니다.

## 📁 파일 구조

```
lib/config/
├── kakao_config.dart    # 카카오 API 키 설정 파일
└── README.md           # 이 파일
```

## 🔑 API 키 설정 방법

### 1. 카카오 개발자 콘솔 접속

1. 카카오 개발자 콘솔 접속: https://developers.kakao.com
2. **내 애플리케이션** 선택
3. **앱 설정** → **앱 키** 메뉴 이동

### 2. Native App Key (필수)

**현재 설정됨**: `737f26c4d0d81077b35b8f0313ec3536`

- Android/iOS 앱에서 카카오 로그인 사용
- 이미 설정되어 있으므로 변경 불필요

### 3. JavaScript Key (웹 로그인용 - 선택사항)

**현재 상태**: 미설정 (`YOUR_KAKAO_JAVASCRIPT_KEY`)

웹 플랫폼에서 카카오 로그인을 사용하려면:

1. **JavaScript 키 복사**
   - 카카오 개발자 콘솔 > 앱 설정 > 앱 키 > **JavaScript 키** 복사

2. **kakao_config.dart 파일 수정**
   ```dart
   // 이전
   static const String javaScriptAppKey = 'YOUR_KAKAO_JAVASCRIPT_KEY';
   
   // 수정 후 (실제 키로 교체)
   static const String javaScriptAppKey = 'abcdef123456789abcdef123456789ab';
   ```

3. **웹 플랫폼 도메인 등록**
   - 카카오 개발자 콘솔 > 내 애플리케이션 > **플랫폼** > **Web 플랫폼 등록**
   - 사이트 도메인 추가:
     - 개발: `http://localhost:5060`
     - 프로덕션: `https://makecallio.web.app`

4. **Redirect URI 설정**
   - 카카오 개발자 콘솔 > 제품 설정 > **카카오 로그인** > **Redirect URI**
   - URI 추가:
     - 개발: `http://localhost:5060/auth/callback`
     - 프로덕션: `https://makecallio.web.app/auth/callback`

## 🔒 보안 주의사항

### Git 커밋 제외 (권장)

실제 API 키를 설정한 후에는 Git에 커밋하지 않는 것을 권장합니다:

```bash
# .gitignore에 추가
lib/config/kakao_config.dart
```

### 환경별 설정 관리

프로덕션 배포 시 권장사항:

1. **개발 환경**
   - 로컬 파일에 개발용 키 저장
   - Git에 커밋하지 않음

2. **프로덕션 환경**
   - 환경 변수 또는 secure storage 사용
   - CI/CD 파이프라인에서 빌드 시 주입

## ✅ 설정 확인 방법

앱을 실행하면 디버그 콘솔에서 설정 상태를 확인할 수 있습니다:

```
✅ 카카오 SDK 초기화 완료
카카오 SDK 설정 정보:
- Native App Key: 737f26c4d0...
- JavaScript Key: 설정됨 (abcdef1234...) 또는 미설정 (웹 로그인 비활성화)
- 웹 로그인 가능: ✅ 또는 ❌
- Redirect URI: https://makecallio.web.app/auth/callback
```

## 🎯 현재 상태

- ✅ **Native App Key**: 설정됨 (모바일 앱 로그인 가능)
- ❌ **JavaScript Key**: 미설정 (웹 로그인 비활성화)

웹에서 카카오 로그인을 사용하려면 위의 "JavaScript Key 설정 방법"을 따라주세요.

## 📚 참고 문서

- [카카오 로그인 가이드](https://developers.kakao.com/docs/latest/ko/kakaologin/common)
- [Flutter 카카오 SDK](https://pub.dev/packages/kakao_flutter_sdk)
- [웹 플랫폼 설정](https://developers.kakao.com/docs/latest/ko/kakaologin/js)
