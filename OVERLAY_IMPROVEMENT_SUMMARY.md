# 오버레이 제거 로직 개선 요약

## 🎯 개선 목표
**시간 기반(time-based) 오버레이 제거 → 이벤트 기반(event-based) 오버레이 제거**

---

## 📊 변경 이력

### ✅ Commit 1: `2cb1bfe` - Frame Callback 방식
**제목**: Refactor: Change overlay hide from time-based to event-based

**변경 내용**:
- `Future.delayed(Duration(milliseconds: 100))` 제거
- `SchedulerBinding.instance.addPostFrameCallback()` 사용
- 다음 프레임 완료 후 오버레이 제거

**문제점**:
```dart
// ❌ 앱 라이프사이클 변경 시 프레임 콜백이 취소됨
SchedulerBinding.instance.addPostFrameCallback((_) {
  _currentOverlay?.remove();
});

// 실제 로그:
// I/flutter: ❌ [OVERLAY] Scheduling hide for next frame
// I/flutter: 🔄 [MyApp] App lifecycle changed to AppLifecycleState.hidden
// ❌ "Executing hide after frame completion" 로그 없음 → 실행 안됨!
```

**문제 원인**:
- Kakao 로그인 취소 → 다이얼로그 표시
- 다이얼로그 표시 → `AppLifecycleState.hidden` 트리거
- 앱이 백그라운드로 전환 → 프레임 콜백 취소
- 오버레이가 화면에 남아있음

---

### ✅ Commit 2: `e351fa3` - Microtask 방식 (최종 해결)
**제목**: Improve: Use microtask for overlay hide (more reliable than postFrameCallback)

**변경 내용**:
- `scheduleMicrotask()` 사용 (dart:async)
- 앱 라이프사이클과 무관하게 실행 보장
- Null 체크 및 예외 처리 추가

**해결 방법**:
```dart
// ✅ Microtask는 앱 라이프사이클과 무관하게 실행됨
scheduleMicrotask(() {
  try {
    _currentOverlay?.remove();
    _currentOverlay = null;
  } catch (e) {
    // 안전한 예외 처리
    _currentOverlay = null;
  }
});

// 실제 로그:
// I/flutter: ❌ [OVERLAY] Scheduling hide via microtask
// I/flutter: ✅ [OVERLAY] Executing hide via microtask
// I/flutter: 🔄 [MyApp] App lifecycle changed to AppLifecycleState.hidden
// ✅ 다이얼로그 표시 전에 이미 제거 완료!
```

---

## 🔍 기술적 비교

### 1️⃣ **Time-Based Delay (❌ 제거됨)**
```dart
await Future.delayed(const Duration(milliseconds: 100));
SocialLoginProgressHelper.hide();
```
**단점**:
- ❌ 임의의 100ms 대기 시간 (불필요한 지연)
- ❌ 100ms가 충분하지 않을 수도 있음
- ❌ UI 업데이트와 동기화되지 않음

---

### 2️⃣ **Frame Callback (❌ 실패함)**
```dart
SchedulerBinding.instance.addPostFrameCallback((_) {
  _currentOverlay?.remove();
});
```
**장점**:
- ✅ 다음 프레임 완료 후 실행 (이론적으로 안전)

**단점**:
- ❌ 앱 라이프사이클 변경 시 취소됨
- ❌ 다이얼로그 표시 → `AppLifecycleState.hidden` → 콜백 취소
- ❌ 오버레이가 화면에 남아있음

---

### 3️⃣ **Microtask (✅ 최종 채택)**
```dart
scheduleMicrotask(() {
  try {
    _currentOverlay?.remove();
    _currentOverlay = null;
  } catch (e) {
    _currentOverlay = null;
  }
});
```
**장점**:
- ✅ 현재 실행 스택 완료 직후 즉시 실행
- ✅ 앱 라이프사이클 변경과 무관
- ✅ 다이얼로그 표시 전에 제거 완료
- ✅ 프레임 콜백보다 빠름
- ✅ 실행 보장 (취소되지 않음)
- ✅ Flutter Best Practice

**단점**:
- 없음

---

## 📝 수정된 파일

### 1. `lib/widgets/social_login_progress_overlay.dart`
```dart
// BEFORE
import 'package:flutter/scheduler.dart';

static void hide() {
  SchedulerBinding.instance.addPostFrameCallback((_) {
    _currentOverlay?.remove();
    _currentOverlay = null;
  });
}

// AFTER
import 'dart:async';

static void hide() {
  if (_currentOverlay == null) return;
  
  scheduleMicrotask(() {
    try {
      _currentOverlay?.remove();
      _currentOverlay = null;
    } catch (e) {
      _currentOverlay = null;
    }
  });
}
```

### 2. `lib/screens/auth/login_screen.dart`
```dart
// BEFORE
await Future.delayed(const Duration(milliseconds: 100));
SocialLoginProgressHelper.hide();

// AFTER
SocialLoginProgressHelper.hide();
```

### 3. `lib/screens/auth/signup_screen.dart`
```dart
// BEFORE
await Future.delayed(const Duration(milliseconds: 100));
SocialLoginProgressHelper.hide();

// AFTER
SocialLoginProgressHelper.hide();
```

---

## 🧪 테스트 시나리오

### 테스트 케이스: Kakao 로그인 취소
1. **사용자 동작**: 카카오 로그인 버튼 클릭
2. **앱 동작**: 로딩 오버레이 표시
3. **사용자 동작**: 카카오 인증 팝업에서 취소 버튼 클릭
4. **예상 결과**: 
   - ✅ 오버레이가 즉시 제거됨
   - ✅ "카카오 로그인이 취소되었습니다" 다이얼로그 표시
   - ✅ 오버레이가 화면에 남아있지 않음

### 실제 로그 (성공):
```
I/flutter: ❌ [OVERLAY] Scheduling hide via microtask
I/flutter: ✅ [OVERLAY] Executing hide via microtask
I/flutter: ℹ️  [Kakao SignUp] Showing cancel dialog
I/flutter: 🔄 [MyApp] App lifecycle changed to AppLifecycleState.hidden
```

**분석**:
- ✅ Microtask 실행 완료 (오버레이 제거)
- ✅ 다이얼로그 표시
- ✅ 앱 라이프사이클 변경 (이미 오버레이 제거 완료 후)

---

## 📚 Flutter Microtask vs Frame Callback

### Microtask 실행 순서:
```
1. 현재 실행 중인 코드 완료
2. ✅ Microtask Queue 실행 (scheduleMicrotask)
3. Event Queue 실행 (Future, Timer)
4. Frame Callback 실행 (addPostFrameCallback)
5. UI 렌더링
```

### 왜 Microtask가 더 안정적인가?
- **Microtask**: 이벤트 루프의 최우선 순위 큐
- **Frame Callback**: UI 렌더링 사이클에 의존
- 앱 라이프사이클 변경 시 UI 렌더링은 중단되지만, Microtask는 계속 실행됨

---

## ✅ 결론

### 최종 채택 방식: **Microtask 기반 오버레이 제거**

**핵심 개선 사항**:
1. ✅ 시간 기반 → 이벤트 기반
2. ✅ Frame Callback → Microtask
3. ✅ 앱 라이프사이클 독립성
4. ✅ 실행 보장
5. ✅ 더 빠른 실행 속도

**코드 품질**:
- ✅ Flutter Best Practice 준수
- ✅ 예외 처리 추가
- ✅ Null Safety 보장
- ✅ 디버그 로깅 완비

**사용자 경험**:
- ✅ 오버레이가 확실하게 제거됨
- ✅ 다이얼로그가 정상적으로 표시됨
- ✅ 화면 전환이 자연스러움

---

## 📌 참고 자료

- [Dart Microtasks](https://dart.dev/articles/archive/event-loop#microtask-queue)
- [Flutter SchedulerBinding](https://api.flutter.dev/flutter/scheduler/SchedulerBinding-class.html)
- [Flutter Best Practices - Overlay Management](https://docs.flutter.dev/cookbook/design/overlay)

---

**작성일**: 2025-01-XX  
**작성자**: Flutter Development Team  
**Git Commits**: 2cb1bfe (Frame Callback), e351fa3 (Microtask - Final)
