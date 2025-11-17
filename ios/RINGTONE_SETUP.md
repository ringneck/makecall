# iOS Ringtone 설정 가이드

## 📋 개요

착신전환 푸시 알림에서 사용자 지정 ringtone을 재생하기 위한 iOS 설정 가이드입니다.

## 🎵 Ringtone 파일 준비

### 1. 지원 형식
- **권장**: `.caf` (Core Audio Format)
- **대체**: `.wav`, `.aiff`
- **⚠️ 지원 안 됨**: `.mp3` (iOS 알림 사운드로 직접 사용 불가)

### 2. 파일 요구사항
- **최대 길이**: 30초
- **샘플레이트**: 16kHz ~ 48kHz
- **비트 깊이**: 16bit 권장
- **채널**: 모노 또는 스테레오

## 🔄 MP3 → CAF 변환

### macOS/Linux 환경:

```bash
# afconvert 사용 (macOS 기본 제공)
afconvert -f caff -d LEI16 assets/audio/ringtone.mp3 ios/Runner/ringtone.caf

# 또는 ffmpeg 사용
ffmpeg -i assets/audio/ringtone.mp3 -ar 16000 -ac 1 ios/Runner/ringtone.caf
```

### Windows 환경:

```bash
# ffmpeg 사용 (설치 필요)
ffmpeg -i assets\audio\ringtone.mp3 -ar 16000 -ac 1 ios\Runner\ringtone.caf
```

## 📁 파일 배치

### 1. 사운드 파일 위치
```
ios/Runner/
├── ringtone.caf           # 기본 벨소리
├── ringtone2.caf          # 사용자 지정 벨소리 1
└── ringtone3.caf          # 사용자 지정 벨소리 2
```

### 2. Xcode 프로젝트에 추가

1. **Xcode 실행**
2. **Runner** 프로젝트 선택
3. **File** → **Add Files to "Runner"**
4. `ringtone.caf` 파일 선택
5. ✅ **Copy items if needed** 체크
6. ✅ **Create groups** 선택
7. ✅ **Target: Runner** 체크
8. **Add** 클릭

### 3. Build Phases 확인

**Runner** → **Build Phases** → **Copy Bundle Resources**에 사운드 파일이 포함되어 있는지 확인:

```
Runner/
└── ringtone.caf
└── ringtone2.caf
└── ringtone3.caf
```

## 🔧 Firebase Firestore 설정

사용자 DB에 `ringtone` 필드 추가:

```json
{
  "uid": "user123",
  "email": "user@example.com",
  "ringtone": "ringtone2",  // ← .caf 확장자 제외
  "created_at": "2024-01-01T00:00:00Z"
}
```

## 🧪 테스트

### 1. 사운드 파일 확인

```bash
# 사운드 파일 존재 확인
ls -l ios/Runner/*.caf

# 사운드 파일 재생 테스트 (macOS)
afplay ios/Runner/ringtone.caf
```

### 2. 앱 테스트

1. **앱 재빌드**:
   ```bash
   cd /home/user/flutter_app
   flutter clean
   flutter build ios
   ```

2. **착신전환 알림 전송**
3. **사운드 재생 확인**

## 🔍 트러블슈팅

### 사운드가 재생되지 않음

**원인 1**: 사운드 파일이 Bundle에 포함되지 않음
```bash
# 해결: Xcode에서 파일을 다시 추가하고 "Copy items if needed" 체크
```

**원인 2**: 파일 형식 호환성 문제
```bash
# 해결: .caf 형식으로 재변환
afconvert -f caff -d LEI16 input.mp3 output.caf
```

**원인 3**: 파일 이름 불일치
```swift
// AppDelegate.swift에서 파일 이름 확인
content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: "ringtone.caf"))
```

**원인 4**: iOS 무음 모드
```
# 해결: 기기의 무음 모드 해제 확인
```

### Firebase ringtone 필드가 없음

```dart
// lib/services/fcm/fcm_call_forward_service.dart에서 로그 확인
🎵 [FCM-CallForward] 사용자 ringtone: 없음 (기본 벨소리 사용)
```

**해결**: Firestore users 컬렉션에 `ringtone` 필드 추가

## 📚 참고 자료

- [Apple Developer - UNNotificationSound](https://developer.apple.com/documentation/usernotifications/unnotificationsound)
- [Apple Developer - Audio Session](https://developer.apple.com/documentation/avfaudio/avaudiosession)
- [iOS Human Interface Guidelines - Playing Sound](https://developer.apple.com/design/human-interface-guidelines/playing-audio)
