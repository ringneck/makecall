# 이메일 회원가입 처리: 타이밍 기반 → 이벤트 기반 리팩토링

## 📋 개요
이메일 회원가입 후 MainScreen으로 전환되지 않는 문제를 **근본적으로 해결**하기 위해 타이밍 의존적인 조건을 제거하고 완전한 이벤트 기반 아키텍처로 전환했습니다.

## 🔍 문제 분석

### 기존 문제점 (타이밍 기반)
```dart
// ❌ 타이밍에 의존하는 조건
if ((_authService?.isInEmailSignupFlow ?? false) && !_hasCheckedSettings) {
  // 이메일 회원가입 이벤트 처리
}
```

**문제**:
- `_hasCheckedSettings`는 타이밍에 따라 이미 `true`일 수 있음
- `initState` 실행 시점에 따라 조건이 통과되지 않을 수 있음
- 이벤트가 발생했지만 처리되지 않는 경우 발생

### 근본 원인
- **타이밍 의존성**: 조건이 실행 순서와 타이밍에 의존
- **상태 변수의 이중 목적**: `_hasCheckedSettings`가 설정 체크와 이벤트 처리를 모두 담당
- **비결정적 동작**: 같은 상황에서도 타이밍에 따라 다른 결과 발생

## 🎯 해결 방안: 이벤트 기반 아키텍처

### 핵심 개선사항
1. **타이밍 조건 제거**: `_hasCheckedSettings` 조건 삭제
2. **전용 이벤트 플래그 도입**: `_hasProcessedEmailSignupEvent`
3. **한 번만 실행 보장**: 이벤트 처리 후 플래그 설정

### 새로운 구조 (이벤트 기반)
```dart
// ✅ 이벤트 발생 여부로만 판단
bool _hasProcessedEmailSignupEvent = false;

if ((_authService?.isInEmailSignupFlow ?? false) && !_hasProcessedEmailSignupEvent) {
  // 🔒 이벤트 처리 완료 플래그 설정 (중복 방지)
  _hasProcessedEmailSignupEvent = true;
  
  // 이메일 회원가입 이벤트 처리
  _authService?.setInEmailSignupFlow(false);
  // ... 성공 메시지 + 설정 안내
}
```

## 📦 변경 내용

### 1. 이벤트 처리 플래그 추가
```dart
// 🎯 이벤트 기반 플래그: 이메일 회원가입 이벤트 처리 완료 여부
// 타이밍에 의존하지 않고 이벤트 발생 시 한 번만 처리하도록 보장
bool _hasProcessedEmailSignupEvent = false;
```

**특징**:
- 타이밍과 무관하게 이벤트 발생 여부만 추적
- 이벤트 처리 후 즉시 `true`로 설정
- 중복 실행 완전 차단

### 2. initState 로직 개선
```dart
// 🎯 CRITICAL: 이벤트 기반 이메일 회원가입 처리
// 타이밍이 아닌 이벤트 발생 여부로 판단 (한 번만 실행 보장)
if ((_authService?.isInEmailSignupFlow ?? false) && !_hasProcessedEmailSignupEvent) {
  if (kDebugMode) {
    debugPrint('🔔 [initState] 이메일 회원가입 이벤트 감지 → 성공 메시지 + 설정 안내');
  }
  
  // 🔒 이벤트 처리 완료 플래그 설정 (중복 방지)
  _hasProcessedEmailSignupEvent = true;
  
  // 이메일 회원가입 플래그 해제
  _authService?.setInEmailSignupFlow(false);
  
  // 성공 메시지 + 설정 안내 순차적 실행
  Future.microtask(() async {
    if (!mounted) return;
    
    // ✅ STEP 1: 성공 메시지 표시 (MainScreen에서)
    await DialogUtils.showSuccess(
      context,
      '🎉 회원가입이 완료되었습니다',
    );
    
    if (!mounted) return;
    
    // ✅ STEP 2: 설정 안내 다이얼로그 표시 (MainScreen에서)
    await _checkSettingsAndShowGuide();
  });
}
```

### 3. AuthService 리스너 로직 개선
```dart
// 4️⃣ 이메일 회원가입 이벤트 감지 (완전한 이벤트 기반 처리)
// 타이밍이 아닌 이벤트 발생 여부로 판단 (한 번만 실행 보장)
if ((_authService?.isInEmailSignupFlow ?? false) && !_hasProcessedEmailSignupEvent) {
  if (kDebugMode) {
    debugPrint('🔔 [리스너-이벤트] 이메일 회원가입 이벤트 감지 → 성공 메시지 + 설정 안내');
  }
  
  // 🔒 이벤트 처리 완료 플래그 설정 (중복 방지)
  _hasProcessedEmailSignupEvent = true;
  
  // 이메일 회원가입 플래그 해제
  _authService?.setInEmailSignupFlow(false);
  
  // 성공 메시지 + 설정 안내 순차적 실행
  Future.microtask(() async {
    if (!mounted) return;
    
    // ✅ STEP 1: 성공 메시지 표시 (MainScreen에서)
    await DialogUtils.showSuccess(
      context,
      '🎉 회원가입이 완료되었습니다',
    );
    
    if (!mounted) return;
    
    // ✅ STEP 2: 설정 안내 다이얼로그 표시 (MainScreen에서)
    await _checkSettingsAndShowGuide();
  });
}
```

## 🔄 이벤트 처리 흐름

### 시나리오 1: initState에서 먼저 처리
```
1. CallTab 생성 (initState 실행)
2. isInEmailSignupFlow = true 감지
3. _hasProcessedEmailSignupEvent = false 확인
4. ✅ 이벤트 처리 실행
5. _hasProcessedEmailSignupEvent = true 설정
6. 이후 리스너 호출되어도 중복 방지됨
```

### 시나리오 2: 리스너에서 먼저 처리
```
1. AuthService 상태 변경 (리스너 트리거)
2. isInEmailSignupFlow = true 감지
3. _hasProcessedEmailSignupEvent = false 확인
4. ✅ 이벤트 처리 실행
5. _hasProcessedEmailSignupEvent = true 설정
6. 이후 initState 체크에서도 중복 방지됨
```

## ✅ 기대 효과

### 1. 타이밍 이슈 완전 제거
- ✅ 실행 순서와 무관하게 정확히 한 번만 실행
- ✅ `_hasCheckedSettings` 타이밍 의존성 제거
- ✅ 결정적(deterministic) 동작 보장

### 2. 이벤트 중복 방지
- ✅ initState와 리스너가 모두 같은 플래그 공유
- ✅ 어느 쪽에서 먼저 처리해도 중복 방지
- ✅ 이벤트 처리 후 즉시 플래그 설정

### 3. 명확한 이벤트 처리
- ✅ 성공 메시지가 MainScreen에서 정확히 한 번만 표시
- ✅ 설정 안내가 MainScreen에서 정확히 한 번만 표시
- ✅ 사용자 경험 일관성 보장

## 🎓 아키텍처 패턴

### 이벤트 기반 설계 원칙
1. **Idempotency (멱등성)**: 같은 이벤트를 여러 번 처리해도 결과 동일
2. **Event Sourcing**: 상태가 아닌 이벤트 발생 여부로 판단
3. **Once-and-Only-Once Processing**: 정확히 한 번만 처리 보장
4. **Decoupling**: 타이밍과 실행 순서에서 독립

### 플래그 역할 분리
| 플래그 | 목적 | 범위 |
|--------|------|------|
| `_hasCheckedSettings` | 설정 체크 완료 여부 | 설정 체크 로직 |
| `_hasProcessedEmailSignupEvent` | 이메일 회원가입 이벤트 처리 완료 | 이메일 회원가입 이벤트 |

**Single Responsibility Principle (단일 책임 원칙) 적용**

## 🧪 테스트 시나리오

### 테스트 1: 정상 이메일 회원가입
```
예상 로그:
🏳️ [SIGNUP] 이메일 회원가입 플래그 설정 (FCM 이벤트 차단)
✅ [SIGNUP] FCM 초기화 완료 - MainScreen으로 자동 전환됨
🚀 [SIGNUP] MainScreen 전환 대기 중
🔔 [initState] 이메일 회원가입 이벤트 감지 → 성공 메시지 + 설정 안내
(성공 메시지 다이얼로그 표시)
(설정 안내 다이얼로그 표시)
```

### 테스트 2: 리스너가 먼저 트리거되는 경우
```
예상 로그:
🏳️ [SIGNUP] 이메일 회원가입 플래그 설정 (FCM 이벤트 차단)
🔔 [리스너-이벤트] 이메일 회원가입 이벤트 감지 → 성공 메시지 + 설정 안내
(성공 메시지 다이얼로그 표시)
(설정 안내 다이얼로그 표시)
```

**두 경우 모두 성공 메시지와 설정 안내가 정확히 한 번만 표시되어야 함**

## 🔧 변경된 파일
- `lib/screens/call/call_tab.dart`
  - 이벤트 처리 플래그 추가: `_hasProcessedEmailSignupEvent`
  - initState 로직 개선: 타이밍 조건 제거
  - 리스너 로직 개선: 이벤트 기반 조건 적용

## 📅 변경 이력
- **Commit f272919**: `Refactor: 이메일 회원가입 처리를 타이밍 기반에서 이벤트 기반으로 전환`
  - 타이밍 의존 조건(_hasCheckedSettings) 제거
  - 이벤트 기반 플래그(_hasProcessedEmailSignupEvent) 도입
  - 이메일 회원가입 이벤트를 한 번만 처리하도록 보장

## 🎯 결론
타이밍 기반 조건을 이벤트 기반 플래그로 전환하여 **결정적이고 예측 가능한 동작**을 보장합니다. 이제 이메일 회원가입 후 MainScreen 전환과 메시지 표시가 타이밍과 무관하게 정확히 한 번만 실행됩니다.

---
*작성일: 2025-01-XX*
*작성자: Flutter Development Team*
