# Firestore 보안 규칙 관리

이 디렉토리에는 Firestore 보안 규칙 관리를 위한 스크립트와 문서가 포함되어 있습니다.

## 📁 파일 목록

### 📄 문서
- **FIRESTORE_CALL_HISTORY_RULES.md** - call_history 권한 오류 해결 가이드
  - 문제 상황 및 원인 분석
  - 보안 규칙 설명
  - 적용 방법 및 테스트 절차

### 🔧 스크립트
- **apply_firestore_rules.py** - 보안 규칙 자동 적용 스크립트
  - Firebase REST API 사용
  - Ruleset 생성 및 릴리즈
  - 실행: `python3 apply_firestore_rules.py`

- **update_firestore_call_history_rules.py** - 규칙 표시 스크립트
  - 적용할 규칙 출력
  - 수동 적용 가이드 제공
  - 실행: `python3 update_firestore_call_history_rules.py`

## 🔥 Firestore 보안 규칙 개요

### 현재 적용된 규칙

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // 🔓 app_config: 모든 사용자 읽기 가능
    match /app_config/{document=**} {
      allow read: if true;
      allow write: if false;
    }
    
    // 📞 call_history: 읽기 및 업데이트 허용 (로그아웃 상태 포함)
    match /call_history/{callId} {
      allow read: if true;
      allow create: if request.auth != null;
      allow update: if true;  // ⭐ 로그아웃 상태 포함
      allow delete: if request.auth != null;
    }
    
    // 🔐 기본 규칙: 인증 필요
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### 규칙 설명

| 컬렉션 | 읽기 | 생성 | 업데이트 | 삭제 |
|--------|------|------|----------|------|
| **app_config** | ✅ 모두 | ❌ 불가 | ❌ 불가 | ❌ 불가 |
| **call_history** | ✅ 모두 | 🔒 인증 | ✅ 모두 | 🔒 인증 |
| **기타** | 🔒 인증 | 🔒 인증 | 🔒 인증 | 🔒 인증 |

## 🚀 빠른 시작

### 방법 1: Firebase Console (권장)

1. Firebase Console 접속: https://console.firebase.google.com/
2. 프로젝트 선택: makecallio
3. Firestore Database → 규칙(Rules) 탭
4. 위의 규칙 복사 & 붙여넣기
5. 게시(Publish) 클릭

### 방법 2: Python 스크립트

```bash
# 의존성 설치
pip3 install firebase-admin google-auth requests

# 규칙 표시 (수동 적용용)
python3 docs/firestore/update_firestore_call_history_rules.py

# 자동 적용 시도 (실험적)
python3 docs/firestore/apply_firestore_rules.py
```

## ⚠️ 중요 사항

### 왜 이 규칙이 필요한가?

**문제**: 앱 종료 중 푸시 알림의 "확인" 버튼 클릭 시 권한 오류 발생

**원인**: 
- 풀스크린 알림은 로그아웃 상태에서도 표시됨
- `call_history` 업데이트 시도 → 권한 없음 → 오류

**해결**: 
- `call_history`의 `update` 권한을 모든 사용자에게 허용
- 보안은 유지 (생성/삭제는 인증 필요)

### 보안 고려사항

**안전한 이유**:
- ✅ 읽기만 허용 (민감 데이터 보호)
- ✅ 생성/삭제는 인증 필요
- ✅ 다른 컬렉션은 여전히 보호됨
- ✅ 업데이트는 status 필드만 변경

## 🧪 테스트

규칙 적용 후:

1. 앱 완전 종료
2. 다른 기기에서 통화 발신
3. 풀스크린 알림 확인
4. "확인" 버튼 클릭
5. 결과: ✅ 오류 없이 화면 닫힘

## 📞 지원

문제가 발생하면:
- `FIRESTORE_CALL_HISTORY_RULES.md` 참고
- Firebase Console에서 규칙 확인
- 전체 오류 로그 공유

---

**마지막 업데이트**: 2024-12-01  
**버전**: 1.0.2+13
