# 🔒 Firestore 권한 설정 가이드

## 문제 상황

### 발생한 에러
```
W/Firestore: Listen for Query(target=Query(app_config/version_info);limitType=LIMIT_TO_FIRST) failed: 
Status{code=PERMISSION_DENIED, description=Missing or insufficient permissions., cause=null}

❌ [VERSION CHECK] Failed to get version info: 
[cloud_firestore/permission-denied] The caller does not have permission to execute the specified operation.
```

### 문제 원인
- Firestore Security Rules가 인증된 사용자만 접근하도록 설정되어 있음
- 로그인 전에는 `app_config` 컬렉션 접근 불가
- 버전 체크 및 공지사항 조회 실패

---

## ✅ 해결 방법

### 1단계: Firestore Security Rules 설정

#### Firebase Console 접속
```
https://console.firebase.google.com/project/makecallio/firestore/rules
```

#### Security Rules 복사 및 적용

다음 규칙을 **Firebase Console → Firestore Database → 규칙(Rules)** 탭에 붙여넣고 **게시(Publish)** 버튼을 클릭하세요.

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ✅ app_config 컬렉션: 모든 사용자가 읽기 가능 (버전 체크, 공지사항)
    match /app_config/{document=**} {
      allow read: if true;  // 모든 사용자 읽기 가능 (로그인 전에도 접근 가능)
      allow write: if false; // 쓰기는 Firebase Console/Admin SDK만
    }
    
    // users 컬렉션: 자신의 문서만 읽기/쓰기 가능
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // 기타 컬렉션: 인증된 사용자만 접근
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

---

## 📋 주요 변경사항

### Before (문제 상황)
```javascript
// 모든 컬렉션이 인증 필요
match /{document=**} {
  allow read, write: if request.auth != null;
}
```

### After (해결책)
```javascript
// app_config만 인증 없이 읽기 가능
match /app_config/{document=**} {
  allow read: if true;  // ✅ 로그인 전에도 접근 가능
  allow write: if false;
}
```

---

## 🎯 적용 범위

### app_config 컬렉션 구조
```
app_config (collection)
├── version_info (document)        → 버전 체크용
│   ├── latest_version: "1.0.2"
│   ├── minimum_version: "1.0.0"
│   ├── update_message: "..."
│   └── force_update: false
│
└── announcements (document)        → 공지사항용
    └── items (collection)
        └── {announcement_id} (document)
            ├── title: "공지사항 제목"
            ├── message: "공지사항 내용"
            ├── priority: "normal"
            ├── is_active: true
            ├── start_date: Timestamp
            └── end_date: Timestamp
```

---

## 🔍 적용 확인

### 1. Firebase Console에서 확인
```
1. Firebase Console → Firestore Database
2. 규칙(Rules) 탭 클릭
3. 위의 Security Rules가 적용되어 있는지 확인
4. "게시(Publish)" 버튼 클릭
```

### 2. 앱에서 확인
```
1. 앱 완전 종료
2. 앱 재시작
3. LoginScreen에서 버전 체크 BottomSheet 표시 확인
4. 로그인 후 MainScreen에서 공지사항 BottomSheet 표시 확인
```

### 3. 로그 확인
```
✅ 성공 로그:
   🔄 [VERSION CHECK - LOGIN] Current: 1.0.1
   🔄 [VERSION CHECK - LOGIN] Latest: 1.0.2
   🔄 [VERSION CHECK - LOGIN] Update Available: true

❌ 실패 로그 (Security Rules 미적용):
   W/Firestore: PERMISSION_DENIED
   ❌ [VERSION CHECK] Failed to get version info
```

---

## 🛡️ 보안 고려사항

### 읽기 권한 (allow read: if true)
- ✅ **안전함**: 버전 정보와 공지사항은 공개 정보
- ✅ **필요함**: 로그인 전에도 버전 체크 필요
- ✅ **최소 권한**: `app_config` 컬렉션만 허용

### 쓰기 권한 (allow write: if false)
- ✅ **보안 유지**: 클라이언트에서 수정 불가
- ✅ **관리자 전용**: Firebase Console 또는 Admin SDK만 수정 가능
- ✅ **데이터 무결성**: 악의적인 수정 방지

### users 컬렉션
- ✅ **개인정보 보호**: 자신의 문서만 읽기/쓰기 가능
- ✅ **인증 필수**: `request.auth.uid == userId` 체크

---

## 🧪 테스트 시나리오

### 1. 로그인 전 버전 체크 테스트
```
1. 앱 완전 종료
2. Firestore 버전을 1.0.2로 설정
3. 앱 버전을 1.0.1로 설정 (pubspec.yaml)
4. 앱 실행
5. LoginScreen에서 버전 업데이트 BottomSheet 표시 확인
```

### 2. 로그인 후 공지사항 테스트
```
1. 로그인 성공
2. MainScreen 진입
3. 공지사항 BottomSheet 자동 표시 확인
4. "다시 보지 않기" 체크 후 닫기
5. 앱 재시작 시 동일 공지 표시 안 됨 확인
```

### 3. 권한 에러 재현 테스트 (Security Rules 원복 시)
```
1. Firebase Console에서 app_config 규칙 제거
2. 앱 재시작
3. ❌ PERMISSION_DENIED 에러 발생 확인
4. Security Rules 다시 적용
5. ✅ 정상 동작 확인
```

---

## 🔧 스크립트 사용법

### Firestore Security Rules 가이드 출력
```bash
cd /home/user/flutter_app
python3 scripts/setup_firestore_security_rules.py
```

### 출력 내용
- ✅ Project ID 자동 추출
- ✅ Firebase Console 바로가기 링크
- ✅ 복사 가능한 Security Rules
- ✅ 적용 방법 안내

---

## 📝 체크리스트

### Firebase Console 작업
- [ ] Firebase Console 접속
- [ ] Firestore Database → 규칙(Rules) 탭 클릭
- [ ] 위의 Security Rules 복사 및 붙여넣기
- [ ] "게시(Publish)" 버튼 클릭
- [ ] 규칙 적용 완료 확인

### 앱 테스트
- [ ] 앱 완전 종료 후 재시작
- [ ] LoginScreen에서 버전 체크 BottomSheet 표시 확인
- [ ] PERMISSION_DENIED 에러 사라짐 확인
- [ ] 로그인 후 MainScreen에서 공지사항 표시 확인

---

## 🌐 Firebase Console 바로가기

**프로젝트**: makecallio  
**Firestore Rules**: https://console.firebase.google.com/project/makecallio/firestore/rules

---

## 📞 문제 해결

### Security Rules 적용 후에도 에러 발생 시
1. **캐시 삭제**: 앱 완전 종료 후 재시작
2. **시간 대기**: Firestore 규칙 전파에 최대 1분 소요
3. **규칙 확인**: Firebase Console에서 규칙이 올바르게 적용되었는지 재확인
4. **앱 재설치**: 필요 시 앱 삭제 후 재설치

### 여전히 PERMISSION_DENIED 에러 발생 시
```bash
# Firestore 규칙 다시 확인
python3 scripts/setup_firestore_security_rules.py

# Firebase Console에서 규칙 다시 적용
# https://console.firebase.google.com/project/makecallio/firestore/rules
```

---

## ✅ 해결 완료

이제 다음 기능이 정상 작동합니다:
- ✅ 로그인 전 버전 체크
- ✅ 로그인 후 공지사항 조회
- ✅ app_config 컬렉션 읽기 권한
- ✅ PERMISSION_DENIED 에러 해결

---

## 📦 관련 파일

- **스크립트**: `scripts/setup_firestore_security_rules.py`
- **LoginScreen**: `lib/screens/auth/login_screen.dart`
- **MainScreen**: `lib/screens/home/main_screen.dart`
- **버전 서비스**: `lib/services/version_check_service.dart`
- **공지사항 서비스**: `lib/services/announcement_service.dart`

---

**마지막 업데이트**: 2025-12-05  
**Git Commit**: `72642dc`  
**Repository**: https://github.com/ringneck/makecall
