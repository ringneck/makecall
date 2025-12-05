# 🔥 Firestore Security Rules 추가 사항

## 📍 Firebase Console 바로가기
https://console.firebase.google.com/project/makecallio/firestore/rules

---

## ✅ 추가할 규칙 (복사하세요)

```javascript
// ✅ app_config 컬렉션: 모든 사용자가 읽기 가능 (버전 체크, 공지사항)
match /app_config/{document=**} {
  allow read: if true;  // 모든 사용자 읽기 가능 (로그인 전에도 접근 가능)
  allow write: if false; // 쓰기는 Firebase Console/Admin SDK만
}
```

---

## 📝 적용 방법

### 1단계: 현재 규칙 확인
Firebase Console → Firestore Database → 규칙(Rules) 탭

### 2단계: 위의 규칙을 기존 규칙에 추가
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ✅ 여기에 추가 ↓
    match /app_config/{document=**} {
      allow read: if true;
      allow write: if false;
    }
    // ✅ 여기까지 추가 ↑
    
    // ... 기존 규칙들 (그대로 유지) ...
    
  }
}
```

### 3단계: 게시 버튼 클릭
"게시(Publish)" 버튼을 눌러 규칙 적용

---

## 🎯 이 규칙이 해결하는 문제

### Before (에러 발생)
```
❌ PERMISSION_DENIED
❌ The caller does not have permission to execute the specified operation
```

### After (정상 작동)
```
✅ 로그인 전에도 버전 체크 가능
✅ 로그인 전에도 공지사항 조회 가능
✅ app_config 컬렉션 읽기 권한 허용
```

---

## 🔍 영향 받는 기능

- ✅ **LoginScreen 버전 체크**: 로그인 전에도 버전 확인 가능
- ✅ **MainScreen 공지사항**: 로그인 후 공지사항 조회 가능
- ✅ **app_config/version_info**: 버전 정보 읽기
- ✅ **app_config/announcements/items**: 공지사항 읽기

---

## 🛡️ 보안 설명

### 왜 안전한가?
- ✅ **읽기만 허용**: `allow read: if true`
- ✅ **쓰기 금지**: `allow write: if false`
- ✅ **공개 정보**: 버전과 공지사항은 공개 정보
- ✅ **제한된 범위**: `app_config` 컬렉션만 허용

### 다른 컬렉션은?
- ✅ **users 컬렉션**: 자신의 문서만 접근 (기존 규칙 유지)
- ✅ **기타 컬렉션**: 인증된 사용자만 접근 (기존 규칙 유지)

---

## ⏱️ 적용 시간
- **즉시 반영**: 게시 후 최대 1분 소요
- **앱 재시작**: 필요 (변경 사항 적용 확인)

---

## ✅ 적용 후 테스트

### 1. 앱 완전 종료 후 재시작
### 2. 로그 확인
```
✅ 성공 로그:
   🔄 [VERSION CHECK - LOGIN] Current: 1.0.1
   🔄 [VERSION CHECK - LOGIN] Latest: 1.0.2

❌ 실패 로그 (규칙 미적용):
   ❌ PERMISSION_DENIED
```

---

**끝!** 이 규칙만 추가하면 모든 권한 문제가 해결됩니다. 🎉
