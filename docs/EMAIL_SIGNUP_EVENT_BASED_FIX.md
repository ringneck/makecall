# 이메일 회원가입 이벤트 기반 처리 (시니어 개발자 패턴)

## 📋 요약

이메일 회원가입 시 발생하는 여러 UX 문제를 **이벤트 기반 아키텍처**로 해결했습니다.

---

## 🐛 문제 분석

사용자 로그를 통해 발견된 3가지 핵심 문제:

### 1. 메인 스크린 전환 지연 ⏱️
```dart
// ❌ 문제: 200ms delay로 인한 지연
await Future.delayed(const Duration(milliseconds: 200));
await DialogUtils.showSuccess(context, '회원가입이 완료되었습니다');
```

**증상:**
- SignupScreen이 닫힌 후 즉시 MainScreen으로 전환되지 않음
- 사용자가 뒤로가기 버튼 클릭 시 이미 로그인된 MainScreen 발견
- 혼란스러운 UX

### 2. '초기 등록 필요' 메시지 중복 표시 (2회) 🔂
```dart
// ❌ 문제: isInSocialLoginFlow가 이메일 회원가입도 감지
if (!(_authService?.isInSocialLoginFlow ?? true) && !_hasCheckedSettings) {
  await _checkSettingsAndShowGuide();  // 이메일 가입도 실행됨!
}
```

**증상:**
- 로그: `"초기 등록 필요" 메시지가 2번 표시됨`
- 소셜 로그인용 플래그가 이메일 회원가입도 감지

### 3. 안내 다이얼로그가 SignupScreen에서 표시됨 📱
```dart
// ❌ 문제: SignupScreen이 닫히기 전에 메시지 표시
if (mounted) {
  await DialogUtils.showSuccess(context, '회원가입이 완료되었습니다');
}
Navigator.pop(context);  // 메시지 표시 후 닫기
```

**증상:**
- 성공 메시지가 SignupScreen context에서 표시됨
- 사용자 요구사항: "메인 화면 이동 후 모든 안내 다이얼로그 표시"

---

## 🎯 해결 방법 (이벤트 기반 아키텍처)

### 핵심 아이디어: **이벤트 플래그 분리**

**소셜 로그인**과 **이메일 회원가입**을 별도의 이벤트로 처리:

```dart
// ✅ 해결: 이벤트 플래그 분리
bool _isInSocialLoginFlow = false;     // 소셜 로그인 전용
bool _isInEmailSignupFlow = false;     // 이메일 회원가입 전용
```

---

## 🔧 구현 세부사항

### 1. AuthService - 이메일 회원가입 플래그 추가

**파일:** `lib/services/auth_service.dart`

```dart
// 🎯 이메일 회원가입 진행 중 플래그 (이벤트 기반)
// SignupScreen에서 이메일 회원가입이 완료된 직후 true
bool _isInEmailSignupFlow = false;
bool get isInEmailSignupFlow => _isInEmailSignupFlow;

/// 이메일 회원가입 진행 중 상태 설정
/// SignupScreen에서 이메일 회원가입 완료 직후 호출
void setInEmailSignupFlow(bool inFlow) {
  _isInEmailSignupFlow = inFlow;
  notifyListeners();  // 이벤트 발생 → call_tab이 감지
}
```

**설계 원칙:**
- ✅ **Single Responsibility**: 이메일 회원가입 상태만 관리
- ✅ **Event-Driven**: `notifyListeners()`로 관찰자 패턴 구현
- ✅ **Separation of Concerns**: 소셜 로그인과 완전 분리

---

### 2. SignupScreen - 즉시 닫기 + 플래그 설정

**파일:** `lib/screens/auth/signup_screen.dart`

#### AS-IS (문제 코드):
```dart
// ❌ 문제: SignupScreen에서 메시지 표시
Navigator.pop(context);
await Future.delayed(const Duration(milliseconds: 200));
await DialogUtils.showSuccess(context, '회원가입이 완료되었습니다');
```

#### TO-BE (개선 코드):
```dart
// ✅ 해결: 이메일 회원가입 플래그 설정 (이벤트 기반 처리)
authService.setInEmailSignupFlow(true);

// ✅ 해결: SignupScreen 즉시 닫기 (delay 제거)
if (mounted && Navigator.canPop(context)) {
  print('🔙 [SIGNUP] SignupScreen 즉시 닫기 (메인 화면 전환 시작)');
  Navigator.pop(context);
}

// MainScreen으로 자동 전환 (AuthService의 authStateChanges가 처리)
// 성공 메시지 및 안내 다이얼로그는 call_tab에서 이벤트 기반으로 처리
print('🚀 [SIGNUP] MainScreen 전환 대기 중 (authStateChanges 처리)');
```

**개선 효과:**
- ✅ **즉시 화면 전환**: delay 제거로 즉각 반응
- ✅ **이벤트 발행**: `setInEmailSignupFlow(true)` → `call_tab`이 감지
- ✅ **책임 분리**: 메시지 표시는 MainScreen에서 처리

---

### 3. CallTab - 이메일 회원가입 이벤트 처리

**파일:** `lib/screens/call/call_tab.dart`

#### 이벤트 리스너 추가:
```dart
/// AuthService 상태 변경 감지 (이벤트 기반)
void _onAuthServiceStateChanged() {
  // ... (기존 로직) ...
  
  // 4️⃣ 이메일 회원가입 플래그 감지 (이벤트 기반 처리)
  if ((_authService?.isInEmailSignupFlow ?? false) && !_hasCheckedSettings) {
    if (kDebugMode) {
      debugPrint('🔔 [이벤트] 이메일 회원가입 완료 감지 → 성공 메시지 + 설정 안내');
    }
    
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
}
```

**구현 원칙:**
- ✅ **Event-Driven**: `isInEmailSignupFlow` 플래그 감지
- ✅ **MainScreen Context**: 모든 다이얼로그를 MainScreen에서 표시
- ✅ **Sequential Execution**: `Future.microtask()`로 순차 실행
- ✅ **Idempotent**: `_hasCheckedSettings` 플래그로 중복 방지
- ✅ **Safety**: `!mounted` 체크로 메모리 누수 방지

---

## 🎊 최종 흐름 (AS-IS → TO-BE)

### AS-IS (문제 있는 흐름):
```
1. [SignupScreen] 이메일 회원가입 성공
2. [SignupScreen] FCM 초기화
3. [SignupScreen] Navigator.pop()
4. [SignupScreen] 200ms delay ⏱️
5. [SignupScreen] 성공 메시지 표시 ❌ (잘못된 context)
6. [LoginScreen] 복귀
7. [CallTab] isInSocialLoginFlow 감지 (잘못된 플래그)
8. [CallTab] '초기 등록 필요' 표시 (1회차) 🔂
9. [MainScreen] 자동 전환 (지연됨)
10. [CallTab] '초기 등록 필요' 표시 (2회차) 🔂
```

**문제점:**
- ❌ 메인 스크린 전환 지연
- ❌ 메시지 중복 표시 (2회)
- ❌ 잘못된 context에서 다이얼로그 표시

### TO-BE (개선된 흐름):
```
1. [SignupScreen] 이메일 회원가입 성공
2. [SignupScreen] FCM 초기화
3. [SignupScreen] authService.setInEmailSignupFlow(true) 🎯 (이벤트 발행)
4. [SignupScreen] Navigator.pop() ⚡ (즉시 닫기)
5. [LoginScreen] 복귀
6. [main.dart] authStateChanges 감지 → MainScreen 자동 전환
7. [CallTab] isInEmailSignupFlow 감지 🎯 (정확한 플래그)
8. [CallTab] authService.setInEmailSignupFlow(false) (플래그 해제)
9. [CallTab → MainScreen] 성공 메시지 표시 ✅ (올바른 context)
10. [CallTab → MainScreen] '초기 등록 필요' 표시 ✅ (1회만)
```

**개선 효과:**
- ✅ 즉시 메인 스크린 전환 (지연 없음)
- ✅ 메시지 1회만 표시 (중복 제거)
- ✅ 메인 화면에서 모든 안내 표시 (올바른 context)

---

## 📊 비교표

| 항목 | AS-IS (문제) | TO-BE (개선) |
|------|--------------|--------------|
| **메인 화면 전환** | 200ms delay ⏱️ | 즉시 전환 ⚡ |
| **성공 메시지 표시 위치** | SignupScreen ❌ | MainScreen ✅ |
| **'초기 등록 필요' 표시** | 2회 🔂 | 1회 ✅ |
| **이벤트 플래그** | `isInSocialLoginFlow` (공용) | `isInEmailSignupFlow` (전용) 🎯 |
| **코드 복잡도** | 혼재 | 명확히 분리 ✅ |

---

## 🎯 시니어 개발자 패턴 적용

### 1. Event-Driven Architecture
```dart
// 이벤트 발행
authService.setInEmailSignupFlow(true);
authService.notifyListeners();

// 이벤트 수신
_authService?.addListener(_onAuthServiceStateChanged);
```

### 2. Separation of Concerns
- **SignupScreen**: 회원가입 + 플래그 설정
- **AuthService**: 상태 관리 + 이벤트 발행
- **CallTab**: 이벤트 수신 + UI 업데이트

### 3. Single Responsibility Principle
```dart
setInSocialLoginFlow()  // 소셜 로그인만
setInEmailSignupFlow()  // 이메일 회원가입만
```

### 4. Idempotent Operations
```dart
if (!_hasCheckedSettings) {
  // 최초 1회만 실행
  await _checkSettingsAndShowGuide();
}
```

### 5. Safety First
```dart
if (!mounted) return;  // 메모리 누수 방지
```

---

## 🧪 테스트 시나리오

### ✅ 테스트 케이스 1: 이메일 회원가입
```
1. SignupScreen에서 이메일 회원가입
2. SignupScreen 즉시 닫힘 확인
3. MainScreen 자동 전환 확인
4. 성공 메시지 표시 확인 (MainScreen context)
5. '초기 등록 필요' 1회만 표시 확인
```

### ✅ 테스트 케이스 2: 소셜 로그인
```
1. SignupScreen에서 소셜 로그인
2. 기존 플래그 동작 확인 (isInSocialLoginFlow)
3. 이메일 회원가입 플래그와 독립적 확인
```

### ✅ 테스트 케이스 3: 중복 방지
```
1. 이메일 회원가입 후 call_tab 이벤트 처리
2. _hasCheckedSettings 플래그 확인
3. 안내 메시지 중복 표시 방지 확인
```

---

## 🚀 배포 정보

**Git Commit:** `7a0e539`
```bash
Fix: 이메일 회원가입 이벤트 기반 처리 (시니어 개발자 패턴)
```

**변경 파일:**
- `lib/services/auth_service.dart` - 이메일 회원가입 플래그 추가
- `lib/screens/auth/signup_screen.dart` - 즉시 닫기 + 플래그 설정
- `lib/screens/call/call_tab.dart` - 이벤트 처리 로직 추가

**Flutter Web 미리보기:**
- https://5060-ijpqhzty575rh093zweuw-3844e1b6.sandbox.novita.ai

**GitHub Repository:**
- https://github.com/ringneck/makecall

---

## 📝 결론

이메일 회원가입 시 발생하던 3가지 UX 문제를:
1. **이벤트 기반 아키텍처**로 명확히 분리
2. **즉시 화면 전환**으로 사용자 경험 개선
3. **MainScreen context**에서 모든 안내 표시

**시니어 개발자 패턴 적용:**
- Event-Driven Architecture
- Separation of Concerns
- Single Responsibility Principle
- Idempotent Operations
- Safety First

이를 통해 **안정적이고 직관적인 회원가입 흐름**을 구현했습니다. 🎉
