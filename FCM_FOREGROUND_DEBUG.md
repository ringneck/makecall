# 🔍 포그라운드 푸시 디버깅 가이드

## 📋 증상

**로그 확인**:
```
D/FLTFireMsgReceiver(680): broadcast received for message
W/FirebaseMessaging(680): Unable to log event: analytics library is missing
```

**문제**: Flutter 로그가 전혀 출력되지 않음 (`📨 포그라운드 메시지` 등)

---

## 🔍 진단 체크리스트

### 1️⃣ **로그인 상태 확인** (가장 중요!)

**확인 방법**:
```bash
adb logcat | grep -E "(AUTH|로그인|FCM 초기화)"
```

**예상 로그**:
```
✅ 로그인 성공 시:
I/flutter: 🔔 [AUTH] 로그인 성공 - FCM 초기화 시작...
I/flutter: 🔔 [FCM] 초기화 시작
I/flutter: 🤖 [FCM] Android: flutter_local_notifications 초기화 중...
I/flutter: ✅ [FCM] flutter_local_notifications 초기화 완료
I/flutter: ✅ [FCM] 토큰 생성 완료!

❌ 로그아웃 상태:
(FCM 초기화 로그 없음)
```

**해결**: 앱에서 로그인을 수행해야 합니다!

---

### 2️⃣ **FCM 초기화 로그 확인**

**확인 명령어**:
```bash
adb logcat -c  # 로그 초기화
adb logcat | grep -E "FCM"
```

**로그인 직후 확인해야 할 로그**:
```
I/flutter: 🔔 [FCM] 초기화 시작
I/flutter:    User ID: [사용자ID]
I/flutter:    Platform: android
I/flutter: 🤖 [FCM] Android: flutter_local_notifications 초기화 중...
I/flutter: ✅ [FCM] flutter_local_notifications 초기화 완료
I/flutter: 🤖 [FCM] Android: 알림 채널 생성 중...
I/flutter: ✅ [FCM] Android: 알림 채널 생성 완료
I/flutter: 📱 [FCM] 알림 권한 요청 중...
I/flutter: ✅ [FCM] 알림 권한 응답: AuthorizationStatus.authorized
I/flutter: 🔑 [FCM] 토큰 요청 시작...
I/flutter: 📱 [FCM] 모바일 플랫폼: 일반 토큰 요청
I/flutter: ✅ [FCM] 토큰 생성 완료!
I/flutter: 💾 [FCM] Firestore 저장 시작...
I/flutter: ✅ [FCM] Firestore 저장 완료
```

**이 로그가 없다면**: FCM이 초기화되지 않았으므로 푸시를 받을 수 없습니다!

---

### 3️⃣ **앱 크래시 확인**

**확인 방법**:
```bash
adb logcat | grep -E "(FATAL|AndroidRuntime|CRASH)"
```

**크래시 발생 시**:
- 스택 트레이스 확인
- `lib/services/fcm_service.dart` 관련 오류 확인

---

## 🎯 해결 절차

### **STEP 1: 앱 재시작 및 로그인**

```bash
# 1. 로그 모니터링 시작
adb logcat -c
adb logcat | grep -E "(flutter|FCM|AUTH)" > fcm_debug.log

# 2. 앱 실행
# 3. 로그인 수행
# 4. FCM 초기화 로그 확인 (위의 2️⃣ 참고)
```

---

### **STEP 2: 로그인 후 푸시 전송**

**FCM 초기화가 완료된 후**:
```bash
# Firebase Console에서 푸시 전송
# 또는 curl 명령어 사용
```

**예상 로그**:
```
I/flutter: 📨 포그라운드 메시지: MAKECALL
I/flutter: 📨 메시지 데이터: {...}
I/flutter: 🔔 [FCM] 안드로이드 알림 표시 시작
I/flutter:    제목: MAKECALL
I/flutter:    내용: 새로운 전화가 수신되었습니다
I/flutter: ✅ [FCM] 안드로이드 알림 표시 완료
I/flutter: 📞 [FCM] 수신 전화 화면 표시 시작...
I/flutter: ✅ [FCM] Context 확인 완료 (setContext 사용)
I/flutter: 📞 [FCM] 수신 전화 화면 표시:
I/flutter:    발신자: 홍길동 (테스트)
I/flutter:    번호: 010-1234-5678
```

---

### **STEP 3: 로그 분석**

**케이스 A: FCM 초기화 로그가 없음**
```
원인: 로그인하지 않음
해결: 앱에서 로그인 수행
```

**케이스 B: FCM 초기화 로그는 있지만 푸시 수신 로그 없음**
```
원인: onMessage 리스너 등록 실패
확인: FCM 초기화 로그에서 "✅ [FCM] Firestore 저장 완료" 확인
해결: 앱 재시작 또는 재로그인
```

**케이스 C: 푸시 수신 로그는 있지만 IncomingCallScreen 미표시**
```
원인: Context 설정 문제
확인: "✅ [FCM] Context 확인 완료" 로그 확인
해결: main.dart의 FCMService.setContext() 확인
```

---

## 🧪 완전한 테스트 시퀀스

```bash
# === 터미널 1: 로그 모니터링 ===
adb logcat -c
adb logcat | grep -E "(flutter|FCM|AUTH|IncomingCall)"

# === 기기에서 수행 ===
# 1. 앱 실행
# 2. 로그인 수행
# 3. 로그 확인: FCM 초기화 완료 메시지
# 4. Firebase Console에서 푸시 전송
# 5. 로그 확인: 포그라운드 메시지 수신 및 IncomingCallScreen 표시

# === 예상 로그 흐름 ===
I/flutter: 🔓 Auth 상태 변경: 로그인
I/flutter: 🔔 [AUTH] 로그인 성공 - FCM 초기화 시작...
I/flutter: 🔔 [FCM] 초기화 시작
I/flutter: 🤖 [FCM] Android: flutter_local_notifications 초기화 중...
I/flutter: ✅ [FCM] flutter_local_notifications 초기화 완료
I/flutter: ✅ [FCM] 토큰 생성 완료!
I/flutter: ✅ [FCM] Firestore 저장 완료

[푸시 전송]

I/flutter: 📨 포그라운드 메시지: MAKECALL
I/flutter: 🔔 [FCM] 안드로이드 알림 표시 시작
I/flutter: ✅ [FCM] 안드로이드 알림 표시 완료
I/flutter: 📞 [FCM] 수신 전화 화면 표시 시작...
I/flutter: ✅ [FCM] Context 확인 완료
I/flutter: 📞 [FCM] 수신 전화 화면 표시:
I/flutter:    발신자: 홍길동 (테스트)
I/flutter: ✅ [FCM] 수신 전화 화면 표시 완료
```

---

## 🚨 일반적인 문제

### **문제 1: "Unable to log event: analytics library is missing"**
```
설명: Firebase Analytics가 설치되지 않음 (경고)
영향: 푸시 기능에는 영향 없음
해결: 무시 가능 (또는 firebase_analytics 패키지 추가)
```

---

### **문제 2: WorkSource 관련 경고**
```
W/oo.makecall_ap: Accessing hidden method ...
설명: Android 시스템 내부 API 접근 경고
영향: 푸시 기능에는 영향 없음
해결: 무시 가능
```

---

### **문제 3: 로그인 후에도 FCM 초기화 안됨**
```
원인: auth_service.dart의 signIn() 함수에서 FCM 초기화 실패
확인: 
  adb logcat | grep -E "(FCM 초기화 오류|Stack trace)"
해결: 오류 로그 공유 필요
```

---

## 📝 트러블슈팅 체크리스트

- [ ] 앱 실행됨
- [ ] 로그인 수행함
- [ ] "🔔 [FCM] 초기화 시작" 로그 확인됨
- [ ] "✅ [FCM] 토큰 생성 완료!" 로그 확인됨
- [ ] Firebase Console에서 푸시 전송함
- [ ] "📨 포그라운드 메시지" 로그 확인됨
- [ ] IncomingCallScreen 표시됨

**모든 체크가 ✅ 되면 정상 작동**  
**어디선가 ❌ 가 발생하면 해당 단계의 로그를 공유**

---

## 💡 빠른 해결 팁

**증상**: `D/FLTFireMsgReceiver: broadcast received` 로그만 있고 Flutter 로그 없음

**99% 확률**: 로그인하지 않음

**해결**:
1. 앱에서 로그인 수행
2. "✅ [FCM] 토큰 생성 완료!" 로그 확인
3. 푸시 재전송
4. "📨 포그라운드 메시지" 로그 확인

---

**작성일**: 2025-11-10  
**버전**: 1.0
