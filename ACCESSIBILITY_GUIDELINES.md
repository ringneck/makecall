# MAKECALL 접근성 가이드라인

## 이미 구현된 접근성 기능

### 1. 색상 대비
- ✅ **Primary Blue (#2196F3)**: WCAG AA 기준 충족
- ✅ **텍스트 대비**: 흰색/검은색 배경에 충분한 대비
- ✅ **다크 모드**: 시스템 설정에 따라 자동 전환

### 2. 터치 타겟 크기
- ✅ **최소 48x48dp**: 모든 버튼과 터치 요소
- ✅ **적절한 간격**: 요소 간 충분한 여백

### 3. 텍스트 가독성
- ✅ **최소 폰트 크기**: 12sp 이상
- ✅ **적절한 행간**: 1.4-1.6 line height
- ✅ **명확한 계층**: 제목, 본문, 캡션 구분

## 권장 개선사항

### 스크린 리더 지원 (추가 구현 필요)

#### 1. Semantics 위젯 사용
```dart
// 로그인 버튼 예시
Semantics(
  button: true,
  label: '로그인',
  hint: '이메일과 비밀번호로 로그인합니다',
  child: ElevatedButton(
    onPressed: _handleLogin,
    child: const Text('로그인'),
  ),
)
```

#### 2. 이미지 설명
```dart
Semantics(
  label: 'MAKECALL 로고',
  child: Image.asset('assets/images/app_logo.png'),
)
```

#### 3. 폼 입력 필드
```dart
TextFormField(
  controller: _emailController,
  decoration: InputDecoration(
    labelText: '이메일',
    semanticsLabel: '이메일 입력 필드',
  ),
)
```

### 고대비 모드 (추가 구현 필요)

#### 1. MediaQuery 활용
```dart
final highContrast = MediaQuery.of(context).highContrast;

Container(
  decoration: BoxDecoration(
    border: Border.all(
      color: highContrast ? Colors.black : Colors.grey[300]!,
      width: highContrast ? 2 : 1,
    ),
  ),
)
```

#### 2. 색상 조정
```dart
// 고대비 모드용 색상 팔레트
class A11yColors {
  static Color primary(bool highContrast) =>
      highContrast ? const Color(0xFF0D47A1) : const Color(0xFF2196F3);
      
  static Color text(bool highContrast) =>
      highContrast ? Colors.black : Colors.grey[800]!;
}
```

### 키보드 내비게이션

#### 1. Focus 관리
```dart
final FocusNode _emailFocus = FocusNode();
final FocusNode _passwordFocus = FocusNode();

// Tab으로 이동
TextFormField(
  focusNode: _emailFocus,
  onFieldSubmitted: (_) {
    _passwordFocus.requestFocus();
  },
)
```

#### 2. 단축키 지원
```dart
Shortcuts(
  shortcuts: {
    LogicalKeySet(LogicalKeyboardKey.enter): SubmitIntent(),
  },
  child: Actions(
    actions: {
      SubmitIntent: CallbackAction<SubmitIntent>(
        onInvoke: (_) => _handleLogin(),
      ),
    },
    child: Form(...),
  ),
)
```

### 모션 감소 (Reduced Motion)

```dart
final reducedMotion = MediaQuery.of(context).disableAnimations;

AnimatedContainer(
  duration: reducedMotion 
      ? Duration.zero 
      : const Duration(milliseconds: 300),
  child: content,
)
```

## 테스트 체크리스트

### 스크린 리더 테스트
- [ ] Android TalkBack으로 모든 화면 탐색
- [ ] iOS VoiceOver로 모든 화면 탐색
- [ ] 모든 버튼에 명확한 레이블
- [ ] 이미지에 적절한 설명
- [ ] 폼 에러 메시지 읽기 가능

### 시각적 테스트
- [ ] 고대비 모드에서 모든 텍스트 읽기 가능
- [ ] 다크 모드에서 적절한 대비
- [ ] 최소 200% 확대 시 레이아웃 유지
- [ ] 색각 이상자 시뮬레이션 테스트

### 상호작용 테스트
- [ ] 키보드만으로 모든 기능 사용 가능
- [ ] 터치 타겟 크기 48x48dp 이상
- [ ] 제스처에 대한 대안 제공
- [ ] 적절한 포커스 순서

## 참고 자료

- [Flutter Accessibility](https://docs.flutter.dev/development/accessibility-and-localization/accessibility)
- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [Material Design Accessibility](https://m3.material.io/foundations/accessible-design/overview)
