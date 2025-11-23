# 🔑 Kakao Android KeyHash 설정 가이드

## 📋 목차
1. [KeyHash란?](#keyhash란)
2. [자동 추출 방법](#자동-추출-방법)
3. [카카오 개발자 콘솔 등록](#카카오-개발자-콘솔-등록)
4. [문제 해결](#문제-해결)

---

## 🔍 KeyHash란?

**Android KeyHash**는 앱의 서명 인증서에서 추출한 해시값입니다. 카카오 SDK는 보안을 위해 이 KeyHash를 검증합니다.

### Debug vs Release KeyHash

| 구분 | 설명 | 용도 |
|------|------|------|
| **Debug KeyHash** | `~/.android/debug.keystore`에서 생성 | 개발/테스트 중 사용 (`flutter run`) |
| **Release KeyHash** | `android/release-key.jks`에서 생성 | 프로덕션 배포용 (`flutter build apk --release`) |

⚠️ **중요**: Debug와 Release KeyHash는 **다릅니다**! 둘 다 카카오 개발자 콘솔에 등록해야 합니다.

---

## 🚀 자동 추출 방법

### 방법 1: 스크립트 실행 (권장)

```bash
# Flutter 프로젝트 루트에서 실행
./scripts/get_kakao_keyhash.sh
```

**출력 예시**:
```
🔑 Debug KeyHash:
   S2YA/GyMTkXRL75qlsJ0DFzVrIQ=

🔑 Release KeyHash:
   GB7JD7zR/QQ4D+F6b42zKSDMrKY=

📄 KeyHash가 파일로 저장되었습니다: kakao_keyhash.txt
```

### 방법 2: Flutter 앱 실행 중 자동 출력

```bash
# 디버그 모드로 실행
flutter run -d YOUR_DEVICE_ID

# 카카오 로그인 버튼 클릭
# 터미널 로그에서 KeyHash 확인:
🔑 ========== [Kakao] Android KeyHash ==========
   KeyHash: S2YA/GyMTkXRL75qlsJ0DFzVrIQ=
================================================
```

---

## 🌐 카카오 개발자 콘솔 등록

### 1단계: 콘솔 접속
👉 **https://developers.kakao.com/console/app**

### 2단계: 앱 설정
1. **내 애플리케이션** 선택
2. **앱 설정** → **플랫폼** → **Android** 클릭

### 3단계: 패키지명 확인/등록
```
Package Name: com.olssoo.makecall_app
```

### 4단계: 키 해시 등록

스크립트에서 추출한 **두 개의 KeyHash**를 모두 등록:

```
Debug KeyHash:   S2YA/GyMTkXRL75qlsJ0DFzVrIQ=
Release KeyHash: GB7JD7zR/QQ4D+F6b42zKSDMrKY=
```

**등록 화면**:
```
┌─────────────────────────────────────────┐
│ 키 해시                                 │
├─────────────────────────────────────────┤
│ S2YA/GyMTkXRL75qlsJ0DFzVrIQ=            │  ← Debug
│ GB7JD7zR/QQ4D+F6b42zKSDMrKY=            │  ← Release
│                                         │
│ [+ 키 해시 추가]                        │
└─────────────────────────────────────────┘
```

### 5단계: 저장
**저장** 버튼 클릭 → 완료!

---

## 🧪 테스트

### KeyHash 등록 전
```
❌ Android keyHash validation failed
→ 웹뷰로 폴백 → 매번 로그인 필요
```

### KeyHash 등록 후
```
✅ 카카오톡 앱 로그인 성공
✅ 자동 로그인 (로그인 화면 없음!)
```

### 테스트 방법
```bash
# 1. 앱 실행
flutter run -d YOUR_DEVICE_ID

# 2. 카카오 로그인 버튼 클릭

# 3. 로그 확인
✅ [Kakao] 카카오톡 앱 로그인 성공
✅ [Kakao] 기존 토큰 유효 (만료: 3600초 후)
```

**성공 시**: 카카오톡 앱이 잠깐 열렸다가 바로 닫히고 자동 로그인됨

---

## 🐛 문제 해결

### 문제 1: KeyHash validation failed

**증상**:
```
⚠️  Android keyHash validation failed
```

**원인**: KeyHash가 카카오 콘솔에 등록되지 않음

**해결**:
1. 스크립트 실행: `./scripts/get_kakao_keyhash.sh`
2. Debug/Release KeyHash 복사
3. 카카오 콘솔에 등록
4. 앱 재시작

---

### 문제 2: 스크립트 실행 오류

**증상**:
```bash
./scripts/get_kakao_keyhash.sh: Permission denied
```

**해결**:
```bash
chmod +x scripts/get_kakao_keyhash.sh
./scripts/get_kakao_keyhash.sh
```

---

### 문제 3: Debug keystore를 찾을 수 없음

**증상**:
```
❌ Debug keystore를 찾을 수 없습니다
```

**해결**:
```bash
# Flutter 프로젝트를 한 번 빌드하면 자동 생성됨
flutter build apk --debug
```

---

### 문제 4: Release KeyHash가 다름

**원인**: Release 빌드 시 다른 keystore 사용

**확인**:
```bash
# Release 빌드 후 KeyHash 확인
flutter build apk --release
./scripts/get_kakao_keyhash.sh

# 또는 Release 모드로 실행
flutter run -d YOUR_DEVICE_ID --release
# 카카오 로그인 시도 → 로그에서 KeyHash 확인
```

---

## 📚 추가 자료

- [Kakao Developers - 키 해시](https://developers.kakao.com/docs/latest/ko/getting-started/app#keyhash)
- [Flutter Android 빌드](https://docs.flutter.dev/deployment/android)
- [Android 키 관리](https://developer.android.com/studio/publish/app-signing)

---

## 🎯 현재 프로젝트 설정

### Package Name
```
com.olssoo.makecall_app
```

### KeyHash (추출됨)
```
Debug:   S2YA/GyMTkXRL75qlsJ0DFzVrIQ=
Release: GB7JD7zR/QQ4D+F6b42zKSDMrKY=
```

### 등록 상태
- [ ] Debug KeyHash 등록
- [ ] Release KeyHash 등록

**👉 위의 KeyHash를 복사해서 지금 바로 등록하세요!**

---

**작성일**: 2025-11-23  
**최종 수정**: 2025-11-23
