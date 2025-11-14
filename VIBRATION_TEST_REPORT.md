# 📳 진동 기능 분석 리포트

## 📋 현재 구현 상태

### ✅ 구현된 기능

#### 1. **Vibration 패키지 설치**
- 패키지: `vibration: 2.1.0`
- 플랫폼 인터페이스: `vibration_platform_interface: 0.0.3`
- pubspec.yaml 위치: line 78

#### 2. **진동 트리거 경로**

```
FCM 푸시 알림 수신
  ↓
FCMService._showIncomingCallScreen()
  ↓
IncomingCallScreen (shouldVibrate: true/false)
  ↓
_startRingtoneAndVibration()
  ↓
Vibration.hasVibrator() 확인
  ↓
_vibrateRepeatedly() 반복 실행
```

#### 3. **진동 패턴**
```dart
// 진동 패턴: 500ms 진동 → 200ms 정지 → 500ms 진동 → 1000ms 정지 (반복)
await Vibration.vibrate(duration: 500);
await Future.delayed(const Duration(milliseconds: 200));
await Vibration.vibrate(duration: 500);
await Future.delayed(const Duration(milliseconds: 1000));
```

#### 4. **사용자 설정**
- 진동 설정 경로: FCMService에서 `vibrationEnabled` 확인
- 기본값: `true` (진동 활성화)
- 설정 위치: lib/services/fcm_service.dart:1134, 1248

### 🔍 iOS 진동 작동 여부 확인

#### iOS에서 진동이 작동하는 조건:

✅ **1. 기기 진동 지원**
```dart
final hasVibrator = await Vibration.hasVibrator();
// iOS 기기는 대부분 true 반환
```

✅ **2. 앱 권한**
- iOS에서는 진동 사용에 별도 권한 불필요
- Info.plist에 추가 설정 불필요

✅ **3. 기기 설정**
- **중요**: iOS 기기의 "무음 모드" 스위치 확인 필요
- 무음 모드가 켜져 있으면 진동이 작동하지 않음 (iOS 기본 동작)

✅ **4. 진동 모터 상태**
- 기기의 진동 모터가 정상 작동하는지 확인
- 설정 > 사운드 및 햅틱 > 진동 설정 확인

### 🔧 iOS 진동이 작동하지 않는 경우

#### 가능한 원인:

❌ **1. iOS 무음 모드 (Silent Mode)**
- iOS 기기 측면의 무음 스위치가 켜져 있음
- 해결: 무음 스위치를 끄고 테스트

❌ **2. iOS 방해금지 모드 (Do Not Disturb)**
- 방해금지 모드가 활성화되어 있음
- 해결: 설정 > 집중 모드 > 방해금지 모드 해제

❌ **3. iOS 시스템 진동 설정 비활성화**
- 설정 > 사운드 및 햅틱 > 진동 설정이 꺼져 있음
- 해결: 진동 설정 활성화

❌ **4. vibration 패키지 iOS 호환성 문제**
- vibration 2.1.0 패키지가 최신 iOS와 호환되지 않을 수 있음
- 해결: 대안 패키지 사용 고려

### 🔄 대안: flutter_vibrate 패키지

iOS에서 더 안정적인 진동을 위해 `flutter_vibrate` 패키지 사용 가능:

```yaml
dependencies:
  flutter_vibrate: ^1.3.0  # iOS에서 더 안정적
```

**장점:**
- iOS의 Haptic Feedback 지원
- 더 세밀한 진동 패턴 제어
- iOS와 Android 모두 안정적

**사용 예시:**
```dart
import 'package:flutter_vibrate/flutter_vibrate.dart';

// 진동 가능 여부 확인
bool canVibrate = await Vibrate.canVibrate;

// 기본 진동
if (canVibrate) {
  Vibrate.feedback(FeedbackType.medium);
}

// 패턴 진동
final Iterable<Duration> pauses = [
  const Duration(milliseconds: 500),
  const Duration(milliseconds: 200),
  const Duration(milliseconds: 500),
  const Duration(milliseconds: 1000),
];
Vibrate.vibrateWithPauses(pauses);
```

### 📱 테스트 체크리스트

#### iOS 기기에서 테스트 시 확인 사항:

- [ ] 무음 모드 스위치가 꺼져 있는가?
- [ ] 방해금지 모드가 비활성화되어 있는가?
- [ ] 설정 > 사운드 및 햅틱 > 진동 설정이 활성화되어 있는가?
- [ ] 앱 알림 설정에서 진동이 활성화되어 있는가?
- [ ] FCM 푸시 알림이 정상적으로 수신되는가?
- [ ] 디버그 로그에 "📳 [VIBRATION] 진동 시작" 메시지가 출력되는가?
- [ ] `Vibration.hasVibrator()` 결과가 `true`인가?

### 🔍 디버그 로그 확인

진동이 작동하는지 확인하려면 다음 로그를 확인:

```
✅ 정상 작동:
📳 [VIBRATION] 기기 진동 지원: true
✅ [VIBRATION] 진동 시작 (반복 패턴)

❌ 진동 미지원:
📳 [VIBRATION] 기기 진동 지원: false
⚠️ [VIBRATION] 기기가 진동을 지원하지 않음

❌ 진동 오류:
❌ [VIBRATION] 진동 시작 실패: [오류 메시지]
❌ [VIBRATION] 진동 오류: [오류 메시지]
```

### 💡 권장 사항

#### 1. **iOS 기기 설정 확인**
가장 먼저 iOS 기기의 무음 모드와 진동 설정을 확인하세요.

#### 2. **디버그 모드에서 테스트**
Xcode를 통해 iOS 기기에 직접 연결하여 디버그 로그를 확인하세요:
```bash
flutter run --debug -d [iOS_DEVICE_ID]
```

#### 3. **실제 iOS 기기에서 테스트**
iOS 시뮬레이터는 진동을 지원하지 않으므로 반드시 실제 기기에서 테스트하세요.

#### 4. **대안 패키지 고려**
현재 `vibration` 패키지로 문제가 해결되지 않으면 `flutter_vibrate` 패키지로 교체 고려

### 📝 결론

현재 구현된 진동 기능은 **iOS와 Android 모두 지원**하도록 되어 있습니다.

**iOS에서 진동이 작동하지 않는 경우:**
1. 먼저 iOS 기기의 무음 모드와 시스템 진동 설정을 확인
2. 디버그 로그를 통해 `Vibration.hasVibrator()` 결과 확인
3. 문제가 지속되면 `flutter_vibrate` 패키지로 교체 고려

**코드 위치:**
- 진동 구현: `lib/screens/call/incoming_call_screen.dart` (line 159-227)
- 진동 설정: `lib/services/fcm_service.dart` (line 1134, 1248)
- 패키지 설정: `pubspec.yaml` (line 78)
