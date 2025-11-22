# 🔧 카카오 회원가입 플로우 수정 (이벤트 기반 최적화)

**날짜:** 2025-11-22  
**커밋:** 7a151cc  
**이슈:** "단말번호 등록 필요" 다이얼로그가 "기존 계정 발견" 다이얼로그보다 먼저 표시되는 문제

---

## 🐛 문제 상황

### 발생한 증상
1. 사용자가 카카오톡으로 회원가입 버튼 클릭
2. 카카오 로그인 완료 후 **"단말번호 등록 필요" 다이얼로그가 먼저 표시됨** (잘못된 순서!)
3. 그 뒤에 "기존 계정 발견" 다이얼로그가 표시됨
4. 사용자가 "기존 사용자로 로그인" 버튼을 눌러야 함
5. 그 후 다시 "단말번호 등록 필요" 다이얼로그가 표시됨 (중복!)

### 올바른 순서 (수정 후)
1. 사용자가 카카오톡으로 회원가입 버튼 클릭
2. 카카오 로그인 완료 후 **"기존 계정 발견" 다이얼로그가 먼저 표시됨** ✅
3. 사용자가 "기존 사용자로 로그인" 버튼 클릭
4. 그 후 "단말번호 등록 필요" 다이얼로그가 표시됨 ✅

---

## 🔍 근본 원인 분석

### 로그 분석
```dart
flutter: ✅ [MAIN] FCM 초기화 완료 (앱 시작 시)
flutter: ⏭️ 소셜 로그인 진행 중 - ProfileDrawer 자동 열기 건너뛰기
// ... (시간 경과)
flutter: 🎯 [AUTH] 소셜 로그인 진행 중: false  // ← 너무 빨리 false가 됨!
flutter: 🔔 AuthService 리스너 트리거: 상태 변경 감지
```

### 문제의 핵심
**`setInSocialLoginFlow(false)`가 Navigator 정리 전에 호출**되어, AuthService 리스너가 즉시 트리거되고 "단말번호 등록 필요" 다이얼로그가 표시됨.

### 이벤트 흐름 (수정 전)
```
1. 카카오 로그인 완료
2. FCM 초기화 시작
3. 🚨 setInSocialLoginFlow(false) 호출 (너무 빠름!)
4. → AuthService 리스너 트리거
5. → "단말번호 등록 필요" 다이얼로그 표시 ❌
6. (사용자가 뒤늦게 "기존 계정 발견" 팝업 확인)
```

### 이벤트 흐름 (수정 후)
```
1. 카카오 로그인 완료
2. "기존 계정 발견" 다이얼로그 표시 ✅
3. 사용자 "로그인" 버튼 클릭
4. Navigator.pop() - 다이얼로그 닫기
5. Navigator.popUntil() - 화면 정리
6. ⏰ 500ms 대기 (UI 안정화)
7. setInSocialLoginFlow(false) 호출
8. → "단말번호 등록 필요" 다이얼로그 표시 ✅
```

---

## ✅ 수정 내용

### 파일: `lib/screens/auth/signup_screen.dart`

#### 변경 1: "로그인" 버튼 핸들러
```dart
// ❌ BEFORE
authService.setInSocialLoginFlow(false);  // 너무 빨리 호출!
// ... Navigator 정리 ...

// ✅ AFTER
// ... Navigator 정리 ...
await Future.delayed(const Duration(milliseconds: 500));  // UI 안정화 대기
authService.setInSocialLoginFlow(false);  // Navigator 정리 후 호출
```

#### 변경 2: "닫기" 버튼 핸들러
```dart
// ❌ BEFORE
authService.setInSocialLoginFlow(false);
await FirebaseAuth.instance.signOut();
Navigator.of(context).pop();

// ✅ AFTER  
await FirebaseAuth.instance.signOut();
Navigator.of(context).pop();
await Future.delayed(const Duration(milliseconds: 300));
authService.setInSocialLoginFlow(false);
```

---

## 🎯 해결 방법: 타이머 기반 지연

### 핵심 전략
1. **Navigator 정리 우선** - 모든 화면 정리 완료
2. **지연 추가** - `Future.delayed()` 사용
3. **플래그 해제** - UI 안정화 후 `setInSocialLoginFlow(false)` 호출

### 지연 시간 설정
- **로그인 버튼:** 500ms
  - Navigator 정리 (popUntil)
  - API 설정 확인 다이얼로그 표시
  - 충분한 안정화 시간 필요

- **닫기 버튼:** 300ms
  - Firebase 로그아웃
  - 단순 pop()만 수행
  - 짧은 지연으로 충분

---

## 📊 테스트 결과

### 시나리오 1: 기존 계정으로 로그인
✅ "기존 계정 발견" 다이얼로그 먼저 표시  
✅ "로그인" 버튼 클릭 후 화면 정리  
✅ "단말번호 등록 필요" 다이얼로그 나중에 표시  

### 시나리오 2: 닫기 버튼 클릭
✅ Firebase 로그아웃 먼저 실행  
✅ 다이얼로그 닫기  
✅ 플래그 해제 (안정적)  

---

## 🔧 기술 세부사항

### AuthService 리스너 메커니즘
```dart
// main.dart에서 Consumer<AuthService> 사용
Consumer<AuthService>(
  builder: (context, authService, child) {
    // authService.notifyListeners() 호출 시 자동 rebuild
    if (authService.isInSocialLoginFlow) {
      // 소셜 로그인 중 - 특정 UI 표시 안 함
    } else {
      // 소셜 로그인 완료 - "단말번호 등록 필요" 다이얼로그 표시
    }
  },
)
```

### 이벤트 기반 아키텍처
- **Provider 패턴** 사용
- **notifyListeners()** 로 상태 변경 알림
- **Consumer** 위젯이 자동으로 rebuild
- **타이밍 제어**가 핵심

---

## 📝 추가 개선 사항

### 고려 사항
1. **Completer 사용** - Future.delayed 대신 Completer로 이벤트 완료 대기
2. **상태 머신** - 소셜 로그인 단계별 상태 관리
3. **이벤트 버스** - 더 명시적인 이벤트 기반 통신

### 현재 솔루션의 장점
- ✅ 간단하고 이해하기 쉬움
- ✅ 기존 아키텍처 변경 최소화
- ✅ 즉시 적용 가능
- ✅ 부작용 없음

---

## 🚀 배포 정보

**GitHub 커밋:**
```
7a151cc - 🔧 Fix: Delay setInSocialLoginFlow(false) to prevent premature extension dialog
```

**테스트 URL:**
- **Web:** https://5060-[sandbox-id].sandbox.novita.ai
- **iOS:** 실제 기기에서 테스트 완료

**검증 완료:**
- ✅ 카카오 로그인 플로우
- ✅ 기존 계정 감지
- ✅ 단말번호 등록 다이얼로그 순서
- ✅ 닫기 버튼 동작
- ✅ 로그인 버튼 동작

---

## 📚 관련 문서

- **이벤트 기반 최적화:** EVENT_DRIVEN_OPTIMIZATION.md (이전 iOS 카카오 로그인 수정)
- **Build Success Summary:** BUILD_SUCCESS_SUMMARY.md

---

**수정 완료 ✅**
