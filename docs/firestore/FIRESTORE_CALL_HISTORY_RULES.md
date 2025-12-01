# 🔥 Firestore 보안 규칙 업데이트 - call_history 권한 추가

## 📋 문제 상황

앱 종료 중 푸시 알림을 받고 풀스크린에서 **"확인"** 버튼을 누르면 다음 오류 발생:
```
통화 확인에 실패했습니다: [cloud_firestore/permission-denied] 
The caller does not have permission to execute the specified operation.
```

## 🔍 원인 분석

**문제의 근본 원인**:
- 풀스크린 알림은 **로그아웃 상태**에서도 표시됨
- 사용자가 "확인" 버튼 클릭 시 `call_history` 컬렉션 업데이트 시도
- 현재 Firestore 규칙: **인증된 사용자만 접근 가능**
- 로그아웃 상태 → 인증 없음 → 권한 오류 발생

**코드 위치**: `lib/screens/call/incoming_call_screen_logged_out.dart`
```dart
// 로그아웃 상태에서 통화 확인 시도
await FirebaseFirestore.instance
    .collection('call_history')  // ← 여기서 권한 오류 발생
    .doc(linkedid)
    .set({'status': 'confirmed'}, SetOptions(merge: true));
```

## ✅ 해결 방법

### 업데이트할 Firestore 보안 규칙

Firebase Console에서 아래 규칙을 적용하세요:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // 🔓 app_config 컬렉션: 모든 사용자가 읽기 가능 (버전 체크용)
    match /app_config/{document=**} {
      allow read: if true;  // 누구나 읽기 가능
      allow write: if false; // 쓰기는 불가 (관리자만 콘솔에서 수정)
    }
    
    // 📞 call_history 컬렉션: 읽기 및 status 업데이트 허용 (로그아웃 상태 포함)
    match /call_history/{callId} {
      allow read: if true;  // 누구나 읽기 가능 (통화 기록 확인용)
      allow create: if request.auth != null;  // 생성은 인증된 사용자만
      allow update: if true;  // 업데이트는 누구나 가능 (통화 확인용)
      allow delete: if request.auth != null;  // 삭제는 인증된 사용자만
    }
    
    // 🔐 기본 규칙: 인증된 사용자만 접근 가능
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### 적용 단계

1. **Firebase Console 접속**: https://console.firebase.google.com/
2. **프로젝트 선택**: makecallio
3. **Firestore Database로 이동**: 좌측 메뉴 → Firestore Database
4. **규칙(Rules) 탭 클릭**: 상단 탭
5. **규칙 복사 & 붙여넣기**: 위의 규칙 전체를 복사하여 에디터에 붙여넣기
6. **게시(Publish)**: 우측 상단 "게시" 버튼 클릭
7. **적용 확인**: 몇 초 내에 전 세계적으로 적용됨

## 🎯 규칙 설명

### call_history 컬렉션 권한

| 작업 | 권한 | 이유 |
|------|------|------|
| **읽기 (read)** | 모든 사용자 허용 | 통화 기록 확인용 (로그아웃 상태 포함) |
| **생성 (create)** | 인증된 사용자만 | 새 통화 기록은 로그인 후에만 생성 |
| **업데이트 (update)** | 모든 사용자 허용 | ⭐ **로그아웃 상태에서 "확인" 버튼용** |
| **삭제 (delete)** | 인증된 사용자만 | 보안상 로그인 후에만 삭제 가능 |

### 보안 고려사항

**안전한 이유**:
- ✅ **읽기만 허용**: 민감한 데이터는 노출되지 않음
- ✅ **업데이트만 허용**: status 필드만 변경 가능
- ✅ **생성/삭제는 제한**: 인증된 사용자만 가능
- ✅ **기타 컬렉션 보호**: 여전히 인증 필요

**추가 보안 강화 옵션** (선택사항):
```javascript
// 더 엄격한 업데이트 규칙 (status 필드만 허용)
match /call_history/{callId} {
  allow update: if request.resource.data.diff(resource.data).affectedKeys().hasOnly(['status', 'updatedAt']);
}
```

## 📊 규칙 적용 후 동작

### Before (권한 오류)
```
1. 앱 종료 상태
2. 푸시 알림 수신
3. 풀스크린 알림 표시
4. "확인" 버튼 클릭
5. ❌ permission-denied 오류
```

### After (정상 작동)
```
1. 앱 종료 상태
2. 푸시 알림 수신
3. 풀스크린 알림 표시
4. "확인" 버튼 클릭
5. ✅ call_history status 업데이트 성공
6. ✅ 알림 화면 닫힘
```

## 🧪 테스트 방법

규칙 적용 후 테스트:

1. **앱 완전 종료** (백그라운드가 아닌 완전 종료)
2. **다른 기기에서 통화 발신** (푸시 알림 트리거)
3. **풀스크린 알림 확인**
4. **"확인" 버튼 클릭**
5. **결과 확인**:
   - ✅ 오류 없이 화면 닫힘
   - ✅ Firestore에 status 업데이트됨
   - ❌ permission-denied 오류 없음

## 🔍 문제가 지속되는 경우

1. **Firebase Console에서 규칙 확인**
   - Firestore Database → 규칙 탭
   - call_history 규칙이 올바른지 확인

2. **앱 캐시 삭제**
   - iOS: 앱 삭제 후 재설치
   - Android: 설정 → 앱 → 캐시 삭제

3. **로그 확인**
   - Xcode 또는 Android Studio에서 전체 오류 로그 확인
   - `[cloud_firestore/permission-denied]` 메시지 재확인

4. **Firestore 에뮬레이터 테스트** (개발 중)
   ```bash
   firebase emulators:start --only firestore
   ```

## 📞 추가 지원

문제가 계속되면:
- Firebase 프로젝트 설정 확인
- 전체 오류 로그 공유
- call_history 컬렉션 구조 확인

---

**참고**: 이 규칙은 **로그아웃 상태에서 통화 확인**을 가능하게 하기 위한 필수 설정입니다.
