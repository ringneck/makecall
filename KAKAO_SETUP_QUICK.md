# 🚨 안드로이드 카카오 로그인 오류 해결

## 현재 상황

```
I/flutter: ⚠️ [Kakao] 카카오톡 앱 로그인 실패, 웹뷰로 전환: 
{error: invalid_request, error_description: Android keyHash validation failed.}
```

## ✅ 해결 방법 (2분 소요)

### 1️⃣ 카카오 개발자 콘솔 접속
- URL: **https://developers.kakao.com**
- 로그인 → **내 애플리케이션** 선택

### 2️⃣ Android 플랫폼 설정
1. 좌측 메뉴: **앱 설정** → **플랫폼**
2. **Android 플랫폼 등록** (또는 기존 Android 수정)

### 3️⃣ 키해시 등록 (복사해서 붙여넣기)

**패키지명:**
```
com.olssoo.makecall_app
```

**디버그 키해시 (개발/테스트용):**
```
S2YA/GyMTkXRL75qlsJ0DFzVrIQ=
```

**릴리즈 키해시 (배포용):**
```
GB7JD7zR/QQ4D+F6b42zKSDMrKY=
```

### 4️⃣ 저장 및 테스트
- **저장** 버튼 클릭
- **1~2분 대기** (서버 반영 시간)
- 앱 재시작 후 카카오 로그인 테스트

## 🔍 등록 확인 방법

등록 후 다음과 같은 로그가 나오면 성공:
```
I/flutter: ✅ [Kakao] 카카오톡 앱 로그인 성공
I/flutter: ✅ [Kakao] 로그인 완료: 사용자ID=1234567890
```

## 📱 문제가 계속되면?

1. **패키지명 확인**: `com.olssoo.makecall_app`가 정확한지 확인
2. **키해시 공백 확인**: 복사 시 앞뒤 공백 없이 정확하게
3. **앱 재시작**: 완전히 종료 후 재시작
4. **1~2분 대기**: 카카오 서버 반영 시간 필요

## 🔗 상세 가이드

더 자세한 내용은 다음 문서 참조:
- `docs/KAKAO_KEYHASH_SETUP.md`
- 스크립트: `bash scripts/get_kakao_keyhash.sh`

---

**마지막 업데이트**: 2025-11-21
