# MAKECALL 성능 최적화 가이드

## 이미 구현된 최적화

### 1. 코드 레벨 최적화
- ✅ **const 생성자**: 불변 위젯에 const 사용
- ✅ **ListView.builder**: 대용량 리스트에 lazy loading
- ✅ **StreamBuilder**: 실시간 데이터 효율적 구독
- ✅ **Premium 상태 캐싱**: 반복 접근 방지

### 2. 리소스 최적화
- ✅ **폰트 Tree-shaking**: 99%+ 크기 감소
- ✅ **이미지 압축**: 적절한 해상도 사용
- ✅ **APK 크기**: 55MB (최적화됨)

### 3. 네트워크 최적화
- ✅ **Firebase 연결 풀링**: 재사용
- ✅ **캐시 전략**: SharedPreferences 활용

## 추가 최적화 권장사항

### 빌드 최적화

#### 1. Release 빌드 설정
```bash
# APK 빌드 (최적화됨)
flutter build apk --release --shrink --split-per-abi

# AAB 빌드 (Google Play 최적화)
flutter build appbundle --release

# 빌드 크기 분석
flutter build apk --release --analyze-size
```

#### 2. ProGuard 설정 (android/app/build.gradle.kts)
```kotlin
buildTypes {
    release {
        isMinifyEnabled = true
        isShrinkResources = true
        proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),
            "proguard-rules.pro"
        )
    }
}
```

### 위젯 최적화

#### 1. RepaintBoundary 사용
```dart
// 복잡한 위젯을 격리하여 불필요한 재렌더링 방지
RepaintBoundary(
  child: ComplexWidget(),
)
```

#### 2. AutomaticKeepAliveClientMixin
```dart
// 탭 전환 시 상태 유지
class MyTab extends StatefulWidget {
  @override
  _MyTabState createState() => _MyTabState();
}

class _MyTabState extends State<MyTab> 
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  
  @override
  Widget build(BuildContext context) {
    super.build(context); // 필수!
    return Container();
  }
}
```

#### 3. Selector 사용 (Provider 최적화)
```dart
// 전체 rebuild 대신 특정 값만 감시
Selector<AuthService, String?>(
  selector: (_, service) => service.currentUser?.email,
  builder: (_, email, __) {
    return Text(email ?? '');
  },
)
```

### 이미지 최적화

#### 1. CachedNetworkImage
```yaml
dependencies:
  cached_network_image: ^3.3.0
```

```dart
CachedNetworkImage(
  imageUrl: imageUrl,
  placeholder: (context, url) => CircularProgressIndicator(),
  errorWidget: (context, url, error) => Icon(Icons.error),
  memCacheWidth: 200, // 메모리 절약
  maxWidthDiskCache: 400, // 디스크 캐시 최적화
)
```

#### 2. 이미지 압축
```dart
Image.asset(
  'assets/image.png',
  cacheWidth: 200, // 표시 크기에 맞춰 디코딩
  cacheHeight: 200,
)
```

### 메모리 관리

#### 1. dispose() 패턴
```dart
@override
void dispose() {
  // 컨트롤러 정리
  _controller.dispose();
  _textController.dispose();
  
  // 스트림 구독 취소
  _subscription?.cancel();
  
  // 포커스 정리
  _focusNode.dispose();
  
  super.dispose();
}
```

#### 2. Stream 관리
```dart
late final StreamSubscription _subscription;

@override
void initState() {
  super.initState();
  _subscription = stream.listen((data) {
    // 처리
  });
}

@override
void dispose() {
  _subscription.cancel();
  super.dispose();
}
```

### Firebase 최적화

#### 1. 쿼리 최적화
```dart
// ❌ BAD - 모든 데이터 가져오기
final docs = await collection.get();
final filtered = docs.where((d) => d['status'] == 'active');

// ✅ GOOD - 서버 측 필터링
final docs = await collection
    .where('status', isEqualTo: 'active')
    .limit(10)
    .get();
```

#### 2. 오프라인 지속성
```dart
// 앱 시작 시 한 번만 설정
await FirebaseFirestore.instance.settings = Settings(
  persistenceEnabled: true,
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
);
```

#### 3. 배치 작업
```dart
// ❌ BAD - 개별 쓰기
for (var doc in documents) {
  await collection.doc(doc.id).set(doc.data);
}

// ✅ GOOD - 배치 쓰기
final batch = FirebaseFirestore.instance.batch();
for (var doc in documents) {
  batch.set(collection.doc(doc.id), doc.data);
}
await batch.commit();
```

## 프로파일링 도구

### Flutter DevTools 사용

#### 1. DevTools 실행
```bash
# 앱 실행 후
flutter pub global activate devtools
flutter pub global run devtools
```

#### 2. 성능 프로파일링
- **Performance**: 프레임 렌더링 분석
- **Memory**: 메모리 사용량 추적
- **Network**: 네트워크 요청 모니터링
- **App Size**: 앱 크기 분석

### 프로파일 모드 빌드
```bash
# 프로파일 모드로 실행 (성능 측정용)
flutter run --profile

# 프로파일 APK 빌드
flutter build apk --profile
```

### 성능 측정 코드
```dart
import 'dart:developer' as developer;

// 특정 작업 시간 측정
final stopwatch = Stopwatch()..start();
await performHeavyOperation();
stopwatch.stop();
developer.log('작업 시간: ${stopwatch.elapsedMilliseconds}ms');

// Timeline 이벤트
developer.Timeline.startSync('heavyOperation');
await performHeavyOperation();
developer.Timeline.finishSync();
```

## 성능 체크리스트

### 빌드 시간
- [ ] Release 빌드에서 60fps 유지
- [ ] 앱 시작 시간 < 3초
- [ ] 화면 전환 < 300ms

### 메모리
- [ ] 메모리 누수 없음
- [ ] 이미지 캐시 적절한 크기
- [ ] dispose() 제대로 구현

### 네트워크
- [ ] API 응답 < 2초
- [ ] 오프라인 모드 지원
- [ ] 적절한 로딩 인디케이터

### 앱 크기
- [ ] APK 크기 < 100MB
- [ ] 불필요한 리소스 제거
- [ ] ProGuard 활성화

## 성능 모니터링

### 1. Firebase Performance
```yaml
dependencies:
  firebase_performance: ^0.10.0+7
```

```dart
final trace = FirebasePerformance.instance.newTrace('api_call');
await trace.start();

try {
  await apiCall();
  trace.setMetric('success', 1);
} catch (e) {
  trace.setMetric('error', 1);
} finally {
  await trace.stop();
}
```

### 2. 커스텀 메트릭
```dart
class PerformanceMonitor {
  static final Map<String, Stopwatch> _timers = {};
  
  static void startTimer(String name) {
    _timers[name] = Stopwatch()..start();
  }
  
  static void stopTimer(String name) {
    final timer = _timers[name];
    if (timer != null) {
      timer.stop();
      debugPrint('$name: ${timer.elapsedMilliseconds}ms');
      _timers.remove(name);
    }
  }
}
```

## 참고 자료

- [Flutter Performance Best Practices](https://docs.flutter.dev/perf/best-practices)
- [Flutter Performance Profiling](https://docs.flutter.dev/perf/ui-performance)
- [Firebase Performance Monitoring](https://firebase.google.com/docs/perf-mon)
