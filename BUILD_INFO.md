# MAKECALL APK Build Information

## 📱 최신 빌드 정보

**빌드 날짜**: 2025-01-11  
**빌드 타입**: Release (프로덕션)  
**APK 크기**: 55 MB  

---

## 📦 APK 상세 정보

### 버전 정보
- **앱 버전**: 1.0.0
- **빌드 번호**: 1
- **패키지명**: `com.olssoo.makecall_app`
- **Target SDK**: Android 36 (최신)
- **Min SDK**: Android 21 (Lollipop 5.0 이상)

### 빌드 설정
- **서명**: 릴리즈 키스토어로 서명 완료 ✅
- **난독화**: ProGuard/R8 활성화 ✅
- **최적화**: 릴리즈 모드 최적화 적용 ✅
- **권한**: 필요한 Android 권한 포함 ✅

---

## 📥 설치 방법

### Android 기기에 직접 설치

1. **APK 다운로드**
   - 위의 다운로드 링크에서 `app-release.apk` 다운로드

2. **알 수 없는 출처 허용**
   - 설정 → 보안 → 알 수 없는 출처 허용
   - (Android 8.0 이상: 설치 시 자동으로 권한 요청)

3. **APK 설치**
   - 다운로드한 APK 파일 실행
   - 설치 진행

4. **앱 실행**
   - 홈 화면 또는 앱 서랍에서 MAKECALL 아이콘 클릭

### ADB를 통한 설치

```bash
# USB 디버깅 활성화 후
adb install app-release.apk

# 기존 앱 덮어쓰기 설치
adb install -r app-release.apk
```

---

## ✨ 주요 기능

### 1. 멀티 디바이스 관리
- ✅ 여러 기기에서 동시 로그인 가능
- ✅ 기기별 승인 시스템
- ✅ 실시간 기기 상태 동기화

### 2. 보안 기능
- ✅ 새 기기 로그인 시 기존 기기 승인 필요
- ✅ 이메일 인증 코드 시스템
- ✅ 5분 타임아웃 보안
- ✅ Firebase 인증 통합

### 3. 알림 시스템
- ✅ FCM 푸시 알림
- ✅ 기기 승인 요청 알림
- ✅ 포그라운드/백그라운드 알림 지원
- ✅ 수신 전화 알림

### 4. 통화 관리
- ✅ 실시간 수신 전화 알림
- ✅ 통화 기록 관리
- ✅ Asterisk PBX 통합
- ✅ WebSocket 실시간 통신

---

## 🔧 기술 스택

### Frontend
- **Flutter**: 3.35.4
- **Dart**: 3.9.2
- **상태 관리**: Provider
- **로컬 저장소**: Hive + shared_preferences

### Backend
- **Firebase Authentication**: 사용자 인증
- **Cloud Firestore**: 실시간 데이터베이스
- **Firebase Cloud Messaging**: 푸시 알림
- **Cloud Functions**: 서버리스 백엔드

### 통합
- **Asterisk PBX**: VoIP 통화 시스템
- **WebSocket**: 실시간 이벤트 수신
- **REST API**: DCMIWS 통화 제어

---

## 📋 권한 설명

APK가 요청하는 권한:

| 권한 | 용도 |
|------|------|
| INTERNET | Firebase 및 API 통신 |
| ACCESS_NETWORK_STATE | 네트워크 상태 확인 |
| RECEIVE_BOOT_COMPLETED | 부팅 시 알림 서비스 시작 |
| VIBRATE | 알림 진동 |
| WAKE_LOCK | FCM 알림 처리 |
| FOREGROUND_SERVICE | 백그라운드 알림 서비스 |
| POST_NOTIFICATIONS | Android 13+ 알림 권한 |

---

## 🧪 테스트 항목

### 빌드 전 테스트
- ✅ Flutter analyze 통과
- ✅ 모든 기능 정상 동작 확인
- ✅ Firebase 연동 테스트
- ✅ 기기 승인 플로우 테스트
- ✅ FCM 알림 수신 테스트

### 설치 후 확인사항
- [ ] 앱 정상 설치 확인
- [ ] Firebase 로그인 테스트
- [ ] 기기 등록 및 승인 테스트
- [ ] 푸시 알림 수신 테스트
- [ ] 통화 기능 테스트

---

## 🚀 배포 준비사항

### Google Play Store 배포 (선택)

1. **Google Play Console 계정 필요**
2. **앱 등록 및 메타데이터 작성**
3. **AAB(App Bundle) 빌드 권장**:
   ```bash
   flutter build appbundle --release
   ```
4. **내부 테스트 → 비공개 테스트 → 프로덕션 단계 진행**

### 직접 배포 (현재)

- ✅ APK 서명 완료
- ✅ 프로덕션 빌드 준비 완료
- ✅ 내부 배포 또는 테스트용으로 사용 가능

---

## 🔄 업데이트 이력

### v1.0.0 (2025-01-11)
- 🎉 초기 릴리즈
- ✅ 멀티 디바이스 로그인 시스템
- ✅ 기기 승인 보안 시스템
- ✅ FCM 푸시 알림
- ✅ 수신 전화 알림
- ✅ 이메일 인증 시스템
- ✅ Asterisk PBX 통합
- ✅ Cloud Functions 토큰 정리 로직

### Cloud Functions 업데이트 필요
- ⏳ `sendApprovalNotification` 함수 배포 대기
- ⏳ FCM 토큰 자동 정리 기능 활성화

---

## 🐛 알려진 이슈

### 해결됨 ✅
- ~~포그라운드 알림 표시 안 됨~~ → 해결 완료
- ~~백그라운드 알림 탭 시 다이얼로그 미표시~~ → 해결 완료
- ~~새 기기 승인 없이 로그인 가능~~ → 보안 수정 완료
- ~~FCM 토큰 축적 문제~~ → 자동 정리 로직 추가

### 진행 중 ⏳
- Cloud Functions 배포 대기 (사용자 수동 배포 필요)

---

## 📞 지원 및 문의

- **이메일**: help@makecall.io
- **GitHub**: https://github.com/ringneck/makecall
- **Issues**: https://github.com/ringneck/makecall/issues

---

## 📝 빌드 명령어

```bash
# APK 빌드 (현재 빌드)
flutter build apk --release

# AAB 빌드 (Google Play Store용)
flutter build appbundle --release

# 디버그 빌드
flutter build apk --debug

# 빌드 정리
flutter clean && flutter pub get
```

---

**마지막 업데이트**: 2025-01-11  
**빌드 상태**: ✅ 프로덕션 준비 완료  
**APK 위치**: `build/app/outputs/flutter-apk/app-release.apk`
