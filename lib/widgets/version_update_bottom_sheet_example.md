# 버전 업데이트 BottomSheet 사용 가이드

## 📋 개요

`VersionUpdateBottomSheet`는 앱 버전 업데이트를 안내하는 다크모드 최적화 ModalBottomSheet입니다.

## ✨ 주요 기능

1. **새 버전 설치 안내**: 현재 버전 vs 최신 버전 비교 표시
2. **오늘 하루 보지 않기**: SharedPreferences를 사용한 일일 알림 제어
3. **우측 상단 닫기 버튼**: 선택적 업데이트 시 닫기 가능
4. **다크모드 최적화**: 라이트/다크 모드 모두 최적화된 UI/UX
5. **강제 업데이트 지원**: 최소 버전 미만일 때 닫기 불가능

## 🚀 사용 방법

### 1. MainScreen에서 버전 체크 추가

```dart
import 'package:flutter/material.dart';
import '../services/version_check_service.dart';
import '../widgets/version_update_bottom_sheet.dart';

class MainScreen extends StatefulWidget {
  // ... 기존 코드
}

class _MainScreenState extends State<MainScreen> {
  @override
  void initState() {
    super.initState();
    
    // 화면 렌더링 완료 후 버전 체크
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAppVersion();
    });
  }

  /// 앱 버전 체크 및 업데이트 안내
  Future<void> _checkAppVersion() async {
    try {
      final versionService = VersionCheckService();
      final result = await versionService.checkVersion();
      
      // 업데이트가 필요한 경우 BottomSheet 표시
      if (result.isUpdateAvailable && mounted) {
        await VersionUpdateBottomSheet.show(
          context,
          result,
          downloadUrl: 'https://play.google.com/store/apps/details?id=YOUR_PACKAGE_NAME',
          // iOS: 'https://apps.apple.com/app/idYOUR_APP_ID'
        );
      }
    } catch (e) {
      debugPrint('❌ [VERSION CHECK] Error: $e');
    }
  }
  
  // ... 기존 코드
}
```

### 2. Firestore 데이터 구조 설정

Firestore에서 다음 경로에 버전 정보를 생성하세요:

**경로**: `app_config/version_info`

**데이터 구조**:
```json
{
  "latest_version": "1.0.2",
  "minimum_version": "1.0.0",
  "update_message": "새로운 기능이 추가되었습니다!\n\n• 다크모드 지원\n• 성능 개선\n• 버그 수정",
  "force_update": false
}
```

**필드 설명**:
- `latest_version`: 최신 앱 버전
- `minimum_version`: 최소 지원 버전 (이보다 낮으면 강제 업데이트)
- `update_message`: 업데이트 내용 안내 (선택사항)
- `force_update`: 강제 업데이트 여부 (true: 닫기 불가)

### 3. 다운로드 URL 설정

#### Android (Play Store)
```dart
downloadUrl: 'https://play.google.com/store/apps/details?id=com.olssoo.makecall_app'
```

#### iOS (App Store)
```dart
downloadUrl: 'https://apps.apple.com/app/id123456789'
```

## 🎨 UI/UX 특징

### 다크모드 최적화
- **라이트 모드**: 밝은 배경 + 검정 텍스트
- **다크 모드**: 어두운 배경 + 흰색 텍스트
- 자동으로 시스템 테마에 맞춰 조정

### 버전 정보 표시
```
┌─────────────────────────────────┐
│  [아이콘] 새 버전 업데이트    [X] │
├─────────────────────────────────┤
│  ┌─────────────────────────┐   │
│  │  현재 버전    →  최신 버전  │   │
│  │    1.0.0        1.0.2    │   │
│  └─────────────────────────┘   │
├─────────────────────────────────┤
│  [i] 새로운 기능이 추가되었습니다! │
├─────────────────────────────────┤
│     [업데이트] 버튼             │
│     [오늘 하루 보지 않기]       │
└─────────────────────────────────┘
```

## ⚙️ 동작 방식

### 선택적 업데이트 (force_update: false)
1. 사용자가 "오늘 하루 보지 않기" 선택
2. SharedPreferences에 오늘 날짜 저장
3. 다음 앱 실행 시 오늘 날짜면 BottomSheet 표시 안 함
4. 다음 날이 되면 다시 표시

### 강제 업데이트 (force_update: true)
1. 닫기 버튼 표시 안 함
2. 스와이프로 닫기 불가
3. 업데이트 버튼만 제공
4. 사용자가 반드시 업데이트해야 함

## 📱 테스트 방법

### 1. Firestore에서 버전 설정
```
latest_version: "1.0.2"
minimum_version: "1.0.0"
```

### 2. 현재 앱 버전 확인
`pubspec.yaml`에서:
```yaml
version: 1.0.0+1
```

### 3. 앱 실행
- MainScreen 진입 시 자동으로 버전 체크
- 업데이트가 필요하면 BottomSheet 자동 표시

### 4. "오늘 하루 보지 않기" 테스트
1. "오늘 하루 보지 않기" 클릭
2. 앱 재시작
3. BottomSheet가 표시되지 않음
4. 날짜 변경 후 재시작하면 다시 표시

## 🛠️ 커스터마이징

### 색상 변경
```dart
// 주요 색상
- 업데이트 버튼: Color(0xFF1976D2) (파랑)
- 강제 업데이트: Color(0xFFEF5350) (빨강)
- 경고 메시지: Color(0xFFFF9800) (주황)
```

### 텍스트 변경
```dart
VersionUpdateBottomSheet.show(
  context,
  result,
  downloadUrl: '...',
  // 필요시 updateMessage에서 텍스트 커스터마이징
);
```

## 📦 필요한 패키지

`pubspec.yaml`에 다음 패키지 추가:
```yaml
dependencies:
  shared_preferences: 2.5.3
  url_launcher: 6.3.0
  package_info_plus: 8.1.0
  cloud_firestore: 5.4.3
```

## ⚠️ 주의사항

1. **다운로드 URL 설정**: Play Store 또는 App Store URL을 정확히 입력하세요
2. **Firestore 권한**: `app_config` 컬렉션 읽기 권한 필요
3. **버전 형식**: Semantic Versioning (X.Y.Z) 형식 사용
4. **강제 업데이트**: 신중하게 사용 (사용자가 앱 사용 불가)

## 🔧 트러블슈팅

### BottomSheet가 표시되지 않는 경우
1. Firestore 버전 정보 확인
2. `isUpdateAvailable` 값 확인 (디버그 로그)
3. SharedPreferences 날짜 확인

### 다운로드 URL이 작동하지 않는 경우
1. URL 형식 확인
2. `url_launcher` 패키지 설치 확인
3. Android/iOS 권한 설정 확인

## 📚 추가 리소스

- [SharedPreferences 문서](https://pub.dev/packages/shared_preferences)
- [URL Launcher 문서](https://pub.dev/packages/url_launcher)
- [Package Info Plus 문서](https://pub.dev/packages/package_info_plus)
