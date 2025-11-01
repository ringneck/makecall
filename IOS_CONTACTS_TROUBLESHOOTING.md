# iOS 연락처 권한 문제 해결 가이드

## 🔍 문제 상황

**증상**: iOS 설정 → 개인정보 보호 → 연락처 목록에 "MakeCall" 앱이 나타나지 않음

---

## ✅ 해결 방법

### 방법 1: 앱 완전 삭제 후 재설치 (필수)

Info.plist에 `NSContactsUsageDescription`을 추가한 후에는 **반드시 앱을 완전히 삭제하고 재설치**해야 합니다.

**iOS 앱 완전 삭제 방법**:

1. **홈 화면에서 앱 삭제**:
   - MakeCall 앱 아이콘을 길게 누름
   - "앱 제거" 선택
   - "앱 삭제" 선택

2. **설정에서도 삭제 확인**:
   ```
   iOS 설정 → 일반 → iPhone 저장 공간 → MakeCall
   → "앱 삭제" 선택
   ```

3. **iOS 기기 재시작** (선택사항이지만 권장):
   - 전원 버튼 + 볼륨 버튼 길게 누름
   - "슬라이드하여 전원 끄기"
   - 다시 전원 켜기

4. **Xcode에서 Clean Build** (개발자):
   ```
   Xcode → Product → Clean Build Folder (⇧⌘K)
   ```

5. **앱 재빌드 및 설치**:
   ```bash
   cd /home/user/flutter_app
   flutter clean
   flutter pub get
   flutter build ios --release
   # 또는 Xcode에서 Archive
   ```

6. **앱 재설치 후 테스트**:
   - 통화 탭 → 연락처 메뉴 클릭
   - "장치 연락처" 버튼 클릭
   - ✅ 권한 요청 팝업 표시 확인

---

### 방법 2: Info.plist 수정 확인

**현재 Info.plist 설정 확인**:

```bash
cd /home/user/flutter_app
grep -A 2 "NSContactsUsageDescription" ios/Runner/Info.plist
```

**올바른 설정**:
```xml
<key>NSContactsUsageDescription</key>
<string>장치 연락처를 불러오기 위해 연락처 접근 권한이 필요합니다.</string>
```

---

### 방법 3: Flutter Contacts 패키지 확인

**pubspec.yaml 확인**:
```bash
cd /home/user/flutter_app
grep "flutter_contacts" pubspec.yaml
```

**현재 버전**: `flutter_contacts: 1.1.9+2`

**패키지 재설치**:
```bash
flutter pub get
cd ios && pod install && cd ..
```

---

### 방법 4: iOS Podfile 업데이트 (필요 시)

**Podfile 확인**:
```bash
cat ios/Podfile
```

**Pod 캐시 삭제 및 재설치**:
```bash
cd ios
rm -rf Pods Podfile.lock
pod cache clean --all
pod install
cd ..
```

---

## 🧪 테스트 절차

### 1. 권한 요청 테스트

1. **앱 완전 삭제 후 재설치**
2. 앱 실행
3. 통화 탭 이동
4. "연락처" 메뉴 선택
5. "장치 연락처" 버튼 클릭
6. **예상 결과**: 권한 요청 팝업 표시
   ```
   "MakeCall"이(가) 연락처에 접근하려고 합니다
   
   장치 연락처를 불러오기 위해 연락처 접근 권한이 필요합니다.
   
   [허용 안 함]  [확인]
   ```

### 2. iOS 설정 확인

**권한 허용 후**:
```
iOS 설정 → 개인정보 보호 → 연락처
```

**예상 결과**:
- MakeCall 앱이 목록에 표시됨
- 토글 스위치가 "켜짐" 상태

### 3. 연락처 목록 표시 확인

1. 앱에서 "장치 연락처" 버튼 다시 클릭
2. **예상 결과**: 기기에 저장된 연락처 목록 표시

---

## 🐛 여전히 문제가 있다면

### 시나리오 1: 권한 요청 팝업이 나타나지 않음

**원인**: 
- Info.plist 변경사항이 적용되지 않음
- 앱이 완전히 삭제되지 않음

**해결**:
1. iOS 기기에서 앱 완전 삭제 (홈 화면 + 설정)
2. iOS 기기 재시작
3. Xcode Clean Build (⇧⌘K)
4. 앱 재빌드 및 설치

### 시나리오 2: 권한을 허용했는데도 연락처가 표시되지 않음

**원인**:
- flutter_contacts 패키지 문제
- iOS 시스템 버그

**해결**:
```bash
# Flutter 패키지 재설치
flutter clean
flutter pub get

# iOS Pod 재설치
cd ios
rm -rf Pods Podfile.lock .symlinks
pod install
cd ..

# 앱 재빌드
flutter build ios --release
```

### 시나리오 3: iOS 설정에 여전히 앱이 나타나지 않음

**원인**:
- 앱이 한 번도 연락처 권한을 요청하지 않음

**해결**:
1. 앱에서 "장치 연락처" 버튼을 최소 1회 클릭해야 함
2. 권한 요청 팝업이 나타나면 iOS 설정에 앱이 등록됨
3. Info.plist 설정 확인
4. 앱 재빌드

---

## 📋 체크리스트

### 개발자 체크리스트
- [x] Info.plist에 NSContactsUsageDescription 추가 확인
- [x] Git에 커밋 및 푸시 완료
- [ ] Xcode Clean Build 실행
- [ ] 앱 완전 삭제
- [ ] 앱 재빌드 및 설치
- [ ] "장치 연락처" 버튼 클릭
- [ ] 권한 요청 팝업 확인
- [ ] iOS 설정에서 앱 확인

### iOS 실기기 테스트 체크리스트
- [ ] 앱 완전 삭제 (홈 화면 + 설정)
- [ ] iOS 기기 재시작
- [ ] 앱 재설치
- [ ] 통화 탭 → 연락처 이동
- [ ] "장치 연락처" 버튼 클릭
- [ ] 권한 요청 팝업 표시 확인
- [ ] "확인" 선택
- [ ] iOS 설정 → 개인정보 보호 → 연락처 확인
- [ ] MakeCall 앱 목록에 표시 확인
- [ ] 앱에서 연락처 목록 표시 확인

---

## 🔧 디버깅 방법

### Xcode Console 로그 확인

앱 실행 중 Xcode Console에서 다음 로그 확인:

```
📱 Requesting contacts permission...
📱 Contacts permission result: PermissionStatus.granted
📱 Fetching device contacts...
✅ Found 50 device contacts
✅ Converted 50 contacts with phone numbers
```

**에러 로그**:
```
❌ Contacts permission not granted
❌ Error fetching device contacts: [에러 메시지]
```

### Flutter 로그 확인

```bash
flutter logs --device-id [iOS 기기 ID]
```

---

## 💡 중요 참고사항

### Info.plist 변경 시 필수 사항

1. **앱 완전 삭제 필수**
   - Info.plist 변경사항은 앱 업데이트로는 적용되지 않음
   - 반드시 앱을 완전히 삭제하고 재설치해야 함

2. **Clean Build 필수**
   - Xcode → Product → Clean Build Folder
   - 또는 `flutter clean` 실행

3. **Pod 재설치 권장**
   - iOS CocoaPods 의존성 재설치
   - `cd ios && pod install`

### iOS 권한 요청 타이밍

- iOS는 권한이 처음 요청될 때만 팝업을 표시
- 이후에는 iOS 설정에서 직접 변경해야 함
- 권한을 한 번 거부하면 앱에서 다시 요청할 수 없음

---

## 📞 추가 지원

문제가 계속되면:

1. GitHub Issues에 리포트: https://github.com/ringneck/makecall/issues
2. 다음 정보 포함:
   - iOS 버전
   - Xcode 버전
   - Flutter 버전
   - 에러 로그 (Xcode Console)
   - Info.plist 설정 스크린샷

---

## ✅ 최종 확인

**Info.plist 설정 확인**:
```bash
cd /home/user/flutter_app
tail -20 ios/Runner/Info.plist
```

**예상 출력**:
```xml
<!-- Contacts Privacy Description -->
<key>NSContactsUsageDescription</key>
<string>장치 연락처를 불러오기 위해 연락처 접근 권한이 필요합니다.</string>
</dict>
</plist>
```

**Git 상태 확인**:
```bash
cd /home/user/flutter_app
git log --oneline -5
```

**예상 출력**:
```
2ac4993 Add iOS contacts permission fix documentation
03ebfa3 Add iOS contacts permission (NSContactsUsageDescription)
c37e6c5 Add comprehensive profile image fix documentation
...
```

---

## 🎉 성공!

위의 단계를 모두 수행하면 iOS 설정 → 개인정보 보호 → 연락처에 MakeCall 앱이 나타나고, 장치 연락처를 정상적으로 불러올 수 있습니다!
