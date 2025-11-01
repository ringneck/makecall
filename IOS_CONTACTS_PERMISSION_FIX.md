# iOS 연락처 권한 문제 수정 완료

## 🐛 발견된 문제

**증상**: 
- iOS에서 통화 탭 → 연락처 메뉴 → "장치 연락처" 클릭 시 권한 오류 발생
- 장치 연락처 목록이 표시되지 않음
- 권한 요청 팝업이 나타나지 않음

**원인**:
- `Info.plist`에 `NSContactsUsageDescription` (연락처 접근 권한 설명) 누락
- iOS 14+ 에서 연락처 접근 시 Privacy Usage Description 필수

---

## ✅ 적용된 수정사항

### 1. iOS Privacy Usage Description 추가 (`ios/Runner/Info.plist`)

**추가된 권한 설명**:
```xml
<!-- Contacts Privacy Description -->
<key>NSContactsUsageDescription</key>
<string>장치 연락처를 불러오기 위해 연락처 접근 권한이 필요합니다.</string>
```

**전체 iOS 권한 목록** (Info.plist):
```xml
<!-- Camera & Photo Library Privacy Descriptions -->
<key>NSCameraUsageDescription</key>
<string>프로필 사진을 촬영하기 위해 카메라 접근 권한이 필요합니다.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>프로필 사진을 선택하기 위해 사진 라이브러리 접근 권한이 필요합니다.</string>

<key>NSPhotoLibraryAddUsageDescription</key>
<string>촬영한 사진을 저장하기 위해 사진 라이브러리 접근 권한이 필요합니다.</string>

<!-- Contacts Privacy Description -->
<key>NSContactsUsageDescription</key>
<string>장치 연락처를 불러오기 위해 연락처 접근 권한이 필요합니다.</string>
```

---

## 📱 iOS 권한 요청 흐름

### 1. 앱 최초 실행 시
1. 사용자가 "장치 연락처" 버튼 클릭
2. iOS 시스템이 권한 요청 팝업 표시:
   ```
   "MakeCall"이(가) 연락처에 접근하려고 합니다
   
   장치 연락처를 불러오기 위해 연락처 접근 권한이 필요합니다.
   
   [허용 안 함]  [확인]
   ```
3. 사용자가 "확인" 선택 시 연락처 접근 허용

### 2. 권한 거부 시
- 앱에서 연락처 목록 표시 불가
- 사용자는 iOS 설정에서 수동으로 권한 허용 가능:
  ```
  설정 → 개인정보 보호 → 연락처 → MakeCall → 허용
  ```

### 3. 권한 허용 후
- 장치 연락처 목록 정상 표시
- Firebase 연락처와 함께 통합 관리

---

## 🧪 테스트 시나리오

### iOS 테스트 (필수)

**1. 권한 요청 테스트**:
1. 앱 삭제 후 재설치 (권한 초기화)
2. 통화 탭 → 연락처 메뉴 클릭
3. "장치 연락처" 버튼 클릭
4. ✅ 권한 요청 팝업 표시 확인
5. "확인" 선택
6. ✅ 장치 연락처 목록 표시 확인

**2. 권한 거부 테스트**:
1. 앱 삭제 후 재설치
2. 통화 탭 → 연락처 메뉴 클릭
3. "장치 연락처" 버튼 클릭
4. 권한 요청 팝업에서 "허용 안 함" 선택
5. ✅ 에러 메시지 또는 안내 표시 확인
6. iOS 설정에서 수동 권한 허용
7. 앱 재시작
8. ✅ 장치 연락처 목록 표시 확인

**3. 기존 권한 유지 테스트**:
1. 권한이 이미 허용된 상태
2. 통화 탭 → 연락처 메뉴 클릭
3. "장치 연락처" 버튼 클릭
4. ✅ 추가 권한 요청 없이 바로 연락처 목록 표시

---

## 📋 체크리스트

### 개발자 체크리스트
- [x] iOS Info.plist에 NSContactsUsageDescription 추가
- [x] 한글 권한 설명 문구 작성
- [x] Git 커밋 및 GitHub 푸시
- [x] README 권한 목록 확인 (이미 올바름)
- [ ] iOS 실기기/시뮬레이터에서 테스트
- [ ] 권한 요청 팝업 확인
- [ ] 장치 연락처 목록 표시 확인

### 사용자/테스터 체크리스트
- [ ] iOS 실기기에 최신 빌드 설치
- [ ] 통화 탭에서 장치 연락처 접근 테스트
- [ ] 권한 요청 팝업 문구 확인
- [ ] 권한 허용 후 연락처 목록 확인
- [ ] 권한 거부 시 동작 확인

---

## 🔧 Git 커밋 정보

**커밋**: `03ebfa3` - Add iOS contacts permission (NSContactsUsageDescription)

**변경 파일**:
- `ios/Runner/Info.plist` (+4 lines)

**GitHub**: ✅ 푸시 완료
- Repository: https://github.com/ringneck/makecall
- Branch: main

---

## 📚 관련 문서

### Apple 공식 문서
- [Requesting Access to Contacts](https://developer.apple.com/documentation/contacts/requesting_access_to_contacts)
- [NSContactsUsageDescription](https://developer.apple.com/documentation/bundleresources/information_property_list/nscontactsusagedescription)

### Flutter 패키지
- [flutter_contacts](https://pub.dev/packages/flutter_contacts) - 앱에서 사용 중인 연락처 패키지
- [permission_handler](https://pub.dev/packages/permission_handler) - 권한 관리 패키지

---

## 🎯 iOS 권한 전체 목록 (Info.plist)

현재 앱에서 요청하는 iOS 권한:

| 권한 키 | 설명 | 용도 |
|--------|------|------|
| `NSCameraUsageDescription` | 카메라 접근 | 프로필 사진 촬영 |
| `NSPhotoLibraryUsageDescription` | 사진 라이브러리 읽기 | 프로필 사진 선택 |
| `NSPhotoLibraryAddUsageDescription` | 사진 라이브러리 저장 | 촬영한 사진 저장 |
| `NSContactsUsageDescription` | 연락처 접근 | 장치 연락처 불러오기 |

---

## 💡 트러블슈팅

### 문제: 권한 요청 팝업이 나타나지 않음
**원인**: 
- 이전에 권한을 거부한 상태
- Info.plist가 올바르게 적용되지 않음

**해결**:
1. 앱 완전 삭제 (설정에서도 삭제)
2. Xcode에서 Clean Build Folder (⇧⌘K)
3. 앱 재빌드 및 설치
4. 권한 요청 다시 확인

### 문제: 권한을 허용했는데도 연락처가 표시되지 않음
**원인**:
- 앱 권한 설정이 올바르지 않음
- iOS 시스템 버그

**해결**:
1. iOS 설정 → 개인정보 보호 → 연락처 확인
2. MakeCall 권한이 "켜짐" 상태인지 확인
3. 권한 끄기 → 다시 켜기
4. 앱 재시작

### 문제: 권한 설정 후에도 에러 발생
**원인**:
- 앱 캐시 문제
- 권한이 제대로 적용되지 않음

**해결**:
1. 앱 완전 종료 (백그라운드에서도 종료)
2. iOS 기기 재시작
3. 앱 재실행
4. 연락처 접근 재시도

---

## 🎉 완료!

iOS 연락처 접근 권한이 정상적으로 추가되었습니다!

**다음 단계**:
1. iOS 실기기 또는 시뮬레이터에서 빌드
2. 통화 탭 → 연락처 → 장치 연락처 테스트
3. 권한 요청 팝업 및 연락처 목록 확인

**문제 발생 시**: 
- 위의 트러블슈팅 섹션 참고
- GitHub Issues에 리포트

---

## 📊 관련 변경사항 (2024-10-31 ~ 11-01)

1. ✅ **프로필 이미지 업로드 수정**
   - iOS hang 문제 해결
   - Android Firebase Storage 권한 추가
   - 카메라, 갤러리 권한 추가

2. ✅ **iOS 연락처 권한 추가** (현재)
   - NSContactsUsageDescription 추가
   - 장치 연락처 접근 가능

3. 📋 **완료된 iOS 권한**:
   - ✅ 카메라 (NSCameraUsageDescription)
   - ✅ 갤러리 읽기 (NSPhotoLibraryUsageDescription)
   - ✅ 갤러리 저장 (NSPhotoLibraryAddUsageDescription)
   - ✅ 연락처 (NSContactsUsageDescription)

모든 필수 iOS 권한이 정상적으로 설정되었습니다! 🎉
