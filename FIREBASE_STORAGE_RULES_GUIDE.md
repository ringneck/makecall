# Firebase Storage 보안 규칙 다운로드 가이드

## 📥 파일 다운로드

Firebase Storage 보안 규칙이 **`firebase_storage_rules.txt`** 파일로 생성되었습니다!

### 다운로드 링크

**파일 위치**: `/home/user/flutter_app/firebase_storage_rules.txt`  
**파일 크기**: 2.3KB

**다운로드 방법**:

#### 방법 1: 직접 다운로드 (브라우저)
```
파일 경로: /home/user/flutter_app/firebase_storage_rules.txt
```

#### 방법 2: GitHub에서 다운로드
```
https://github.com/ringneck/makecall/blob/main/firebase_storage_rules.txt
```

#### 방법 3: 스크립트 재실행
```bash
cd /home/user/flutter_app
python3 setup_firebase_storage_rules.py
```
실행하면 자동으로 `firebase_storage_rules.txt` 파일이 생성됩니다.

---

## 📋 파일 내용

`firebase_storage_rules.txt` 파일에는 다음 내용이 포함되어 있습니다:

1. **Firebase 프로젝트 정보**
   - 프로젝트 ID: `makecallio`
   - Firebase Console 링크

2. **보안 규칙 전체 코드**
   - 복사해서 Firebase Console에 바로 붙여넣을 수 있는 형식
   - `rules_version = '2';`부터 마지막 `}`까지

3. **단계별 설정 방법**
   - Firebase Console 접속 방법
   - 보안 규칙 복사 및 붙여넣기 방법
   - 게시 버튼 클릭 안내

4. **보안 규칙 상세 설명**
   - 프로필 이미지 규칙 설명
   - 기타 파일 접근 규칙 설명

---

## 🔧 Firebase Storage 설정 방법

### 1단계: 파일 열기

다운로드한 `firebase_storage_rules.txt` 파일을 텍스트 에디터로 엽니다.

### 2단계: 보안 규칙 복사

파일에서 다음 부분을 **전체 복사**합니다:

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // 프로필 이미지: 인증된 사용자만 자신의 이미지 업로드/삭제 가능
    match /profile_images/{userId}.jpg {
      allow read: if true;
      allow write: if request.auth != null && request.auth.uid == userId;
      allow delete: if request.auth != null && request.auth.uid == userId;
    }
    
    // 기타 파일: 인증된 사용자만 접근 가능
    match /{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### 3단계: Firebase Console 접속

1. 브라우저에서 Firebase Console 열기:
   ```
   https://console.firebase.google.com/project/makecallio/storage/rules
   ```

2. Storage → Rules 탭으로 이동

### 4단계: 보안 규칙 붙여넣기

1. Firebase Console의 Rules 에디터에서 **기존 규칙을 모두 삭제**
2. 복사한 보안 규칙을 **붙여넣기**
3. **"게시"** 버튼 클릭

### 5단계: 확인

보안 규칙이 성공적으로 적용되었는지 확인:
- "규칙이 성공적으로 게시되었습니다" 메시지 확인
- 앱에서 프로필 이미지 업로드 테스트

---

## 📊 보안 규칙 설명

### 프로필 이미지 규칙

**경로**: `profile_images/{userId}.jpg`

**규칙**:
- ✅ **읽기 (read)**: 모든 사용자 가능 (`if true`)
  - 다른 사용자의 프로필 이미지도 볼 수 있음
  
- ✅ **쓰기 (write)**: 인증된 사용자가 자신의 이미지만 가능
  - `request.auth != null`: 로그인 필수
  - `request.auth.uid == userId`: 본인 확인
  
- ✅ **삭제 (delete)**: 인증된 사용자가 자신의 이미지만 가능
  - `request.auth != null`: 로그인 필수
  - `request.auth.uid == userId`: 본인 확인

**예시**:
```
사용자 A (UID: abc123):
✅ 자신의 이미지 업로드 가능: profile_images/abc123.jpg
✅ 자신의 이미지 삭제 가능: profile_images/abc123.jpg
✅ 다른 사용자 이미지 조회 가능: profile_images/xyz789.jpg
❌ 다른 사용자 이미지 수정 불가: profile_images/xyz789.jpg
```

### 기타 파일 규칙

**경로**: `/{allPaths=**}` (모든 경로)

**규칙**:
- ✅ **읽기/쓰기**: 인증된 사용자만 가능
  - `request.auth != null`: 로그인 필수

**예시**:
```
인증된 사용자:
✅ 파일 업로드 가능
✅ 파일 조회 가능
✅ 파일 삭제 가능

비인증 사용자:
❌ 모든 작업 불가
```

---

## 🔍 트러블슈팅

### 문제 1: 파일을 찾을 수 없음

**원인**: 스크립트를 실행하지 않았거나 다른 디렉토리에서 실행

**해결**:
```bash
cd /home/user/flutter_app
python3 setup_firebase_storage_rules.py
ls -l firebase_storage_rules.txt
```

### 문제 2: Firebase Console에 붙여넣기 후 에러

**원인**: 보안 규칙 형식 오류

**해결**:
1. 파일에서 `rules_version = '2';`부터 마지막 `}`까지 **전체** 복사했는지 확인
2. 중간에 누락된 부분이 없는지 확인
3. Firebase Console에서 오류 메시지 확인

### 문제 3: 프로필 이미지 업로드 여전히 실패

**원인**: 
- 보안 규칙이 제대로 적용되지 않음
- 앱에서 인증되지 않은 사용자

**해결**:
1. Firebase Console → Storage → Rules에서 규칙 확인
2. 앱에서 로그인 상태 확인
3. Firebase Storage가 활성화되어 있는지 확인
4. 앱 재시작 후 다시 시도

---

## 📱 앱에서 테스트

### 1. 프로필 이미지 업로드 테스트

1. 앱 실행 및 로그인
2. 프로필 탭 이동
3. 프로필 사진 아이콘 클릭
4. 카메라 촬영 또는 갤러리 선택
5. ✅ 업로드 성공 확인

### 2. 다른 사용자 프로필 이미지 조회 테스트

1. 다른 사용자의 프로필 조회
2. ✅ 프로필 이미지 표시 확인

### 3. 권한 거부 테스트

1. 로그아웃 상태에서 이미지 업로드 시도
2. ❌ "unauthorized" 에러 확인 (예상된 동작)

---

## 🎯 체크리스트

설정 완료 확인:
- [ ] `firebase_storage_rules.txt` 파일 다운로드 완료
- [ ] Firebase Console 접속
- [ ] Storage 활성화 확인
- [ ] 보안 규칙 복사 및 붙여넣기
- [ ] "게시" 버튼 클릭
- [ ] 게시 성공 메시지 확인
- [ ] 앱에서 프로필 이미지 업로드 테스트
- [ ] 업로드 성공 확인

---

## 📚 관련 문서

1. **setup_firebase_storage_rules.py**
   - 보안 규칙 생성 스크립트
   - `python3 setup_firebase_storage_rules.py` 실행

2. **PROFILE_IMAGE_FIX_SUMMARY.md**
   - 프로필 이미지 업로드 문제 수정 요약
   - Firebase Storage 설정 가이드 포함

3. **IOS_CONTACTS_PERMISSION_FIX.md**
   - iOS 연락처 권한 설정 가이드

4. **IOS_CONTACTS_TROUBLESHOOTING.md**
   - iOS 연락처 권한 문제 해결 가이드

---

## 🔗 빠른 링크

- **Firebase Console**: https://console.firebase.google.com/project/makecallio/storage
- **Storage Rules**: https://console.firebase.google.com/project/makecallio/storage/rules
- **GitHub Repository**: https://github.com/ringneck/makecall
- **파일 다운로드**: `/home/user/flutter_app/firebase_storage_rules.txt`

---

## ✅ 완료!

`firebase_storage_rules.txt` 파일을 다운로드하고 Firebase Console에 적용하면 프로필 이미지 업로드가 정상 작동합니다!

**다음 단계**:
1. 파일 다운로드
2. Firebase Console에 보안 규칙 적용
3. 앱에서 프로필 이미지 업로드 테스트

문제가 발생하면 위의 트러블슈팅 섹션을 참고하거나 GitHub Issues에 리포트해주세요!
