# 🌐 Web FCM VAPID Key 설정 가이드

## 📌 문제 상황

Web 플랫폼에서 로그인 시 FCM 토큰 획득에 실패하여 더미 토큰(`web_dummy_token_...`)이 생성되고, 이로 인해 기기 승인 알림을 받을 수 없는 문제가 발생합니다.

### 🚨 증상

```
⚠️ [FCM-WEB] FCM 토큰 없음 - 더미 토큰으로 기기 정보 저장
⚠️ [FCM-WEB] ❌ 감지됨: 더미 토큰 사용 시 FCM 알림 수신 불가!
```

Firebase Console에서 `fcm_approval_notification_queue` 로그 확인 시:
```json
{
  "error": "The registration token is not a valid FCM registration token",
  "errorCode": "messaging/invalid-argument",
  "targetToken": "web_dummy_token_1764856164056"
}
```

---

## 🔍 원인 분석

Web FCM 토큰 획득 실패의 주요 원인:

1. **❌ VAPID Key 불일치**: Firebase Console의 VAPID Key와 코드의 VAPID Key 불일치
2. **❌ 브라우저 알림 권한 거부**: 사용자가 브라우저 알림 권한을 거부한 경우
3. **❌ Service Worker 미등록**: Flutter Web 빌드 시 Service Worker 문제
4. **❌ 브라우저 호환성**: Safari 등 일부 브라우저의 제한적인 FCM 지원

---

## 🔧 해결 방법

### 방법 A: Firebase Console에서 VAPID Key 확인 및 업데이트 (권장)

#### Step 1: Firebase Console에서 VAPID Key 확인

1. **Firebase Console 접속**: https://console.firebase.google.com/
2. **프로젝트 선택**: MAKECALL
3. **Project Settings (톱니바퀴 아이콘)** 클릭
4. **Cloud Messaging 탭** 선택
5. **Web Push certificates** 섹션으로 스크롤

#### Step 2: VAPID Key 복사

- **Web Push certificates** 섹션에서 **Key pair** 확인
- 만약 없다면 **Generate key pair** 버튼 클릭하여 생성
- 생성된 Key pair를 복사 (예: `BM2qgTRRwT-mG4shgKLDr7...`)

#### Step 3: 코드에 VAPID Key 적용

`lib/services/fcm/fcm_web_config.dart` 파일 열기:

```dart
class FCMWebConfig {
  // 🔑 Firebase Cloud Messaging VAPID Key (Web Push)
  // Firebase Console > Project Settings > Cloud Messaging > Web Push certificates
  static const String vapidKey = 'BM2qgTRRwT-mG4shgKLDr7CnVf5-xVs3DqNNcqY7zzHZXd5P5xWqvCLn8BxGnqJ3YKj0zcY6Kp0YwQ_Zr8vK2jM';  // ← 여기 업데이트!
```

**⚠️ 주의**: 전체 Key를 복사하여 정확하게 붙여넣기!

#### Step 4: 앱 재빌드 및 재배포

```bash
cd /home/user/flutter_app

# Web 빌드
flutter build web --release

# 서버 재시작 (포트 5060)
python3 -m http.server 5060 --directory build/web --bind 0.0.0.0
```

---

### 방법 B: 브라우저 알림 권한 확인 (즉시 실행 가능)

#### Step 1: 브라우저 설정 확인

**Chrome 기준**:
1. 주소창 왼쪽 **자물쇠 아이콘** 클릭
2. **사이트 설정** 클릭
3. **알림** 설정이 **허용**으로 되어 있는지 확인
   - 차단됨 → **허용**으로 변경

**Safari 기준**:
- Safari는 FCM 지원이 제한적입니다
- Chrome 또는 Firefox 사용 권장

#### Step 2: 로그아웃 후 재로그인

1. **Web에서 로그아웃**
2. **브라우저 캐시 삭제** (선택사항)
3. **다시 로그인**
4. **알림 권한 요청 팝업이 나오면 '허용' 클릭**

---

## ✅ 검증 방법

### 1. 브라우저 콘솔 로그 확인 (F12 → Console 탭)

#### 성공 시:
```
🌐 [FCM-WEB] 웹 FCM 토큰 요청 시작...
   VAPID Key: BM2qgTRRwT-mG4shg...
✅ [FCM-WEB] 웹 FCM 토큰 획득 성공
   토큰 길이: 152
   토큰 일부: eKGjlw8xRqGm3F7j8Q9P2V...
🔔 [FCM-WEB] 알림 권한: AuthorizationStatus.authorized
✅ [FCM-WEB] 웹 FCM 토큰 획득 성공 - 알림 수신 가능
```

#### 실패 시:
```
⚠️ [FCM-WEB] 웹 FCM 토큰이 null입니다
   가능한 원인:
   1. 브라우저 알림 권한 거부됨
   2. VAPID Key 불일치
   3. Service Worker 등록 실패
   4. 브라우저 호환성 문제 (Safari 등)
❌ [FCM-WEB] ❌ 감지됨: 더미 토큰 사용 시 FCM 알림 수신 불가!
```

### 2. Firestore `fcm_tokens` 컬렉션 확인

Firebase Console > Firestore Database > `fcm_tokens` 컬렉션:

#### ✅ 정상 토큰:
```json
{
  "fcmToken": "eKGjlw8xRqGm3F7j8Q9P2V1...",  // 실제 FCM 토큰 (길이 150+)
  "platform": "Web",
  "isApproved": true,
  "isActive": true
}
```

#### ❌ 더미 토큰:
```json
{
  "fcmToken": "web_dummy_token_1764856164056",  // 더미 토큰
  "platform": "Web",
  "isApproved": true,
  "isActive": true
}
```

### 3. iOS 기기 승인 테스트

1. **Web에서 로그인** (ringneck@naver.com)
2. **iOS에서 로그인 시도** (iPhone 15 Pro)
3. **MaxDeviceLimitException 발생** → "기기 승인 대기" 화면
4. **Web 브라우저에 알림 도착** ✅
   - 알림이 오지 않으면 → 더미 토큰 문제 ❌
5. **알림 클릭** → 승인 화면
6. **승인 버튼 클릭**
7. **iOS 자동 로그인 완료** ✅

---

## 🔄 긴급 임시 조치 (테스트용)

VAPID Key 확인/업데이트 전까지 임시로 기기 승인을 테스트하려면:

### 수동 승인 방법 (Firebase Console 사용)

1. **Firebase Console > Firestore Database**
2. **`device_approval_requests` 컬렉션** 찾기
3. **대기 중인 승인 요청 문서** 클릭
4. **`status` 필드를 `'approved'`로 수정**
5. **저장**
6. **iOS 기기 자동 로그인 확인**

---

## 📊 현재 상태 (2025-12-04)

### ✅ 완료된 사항

1. **Firestore Security Rules V6.2 배포 완료**
   - `device_approval_requests` permission-denied 오류 수정
   - `resource == null` 체크 추가
   
2. **Web FCM 디버그 로깅 강화**
   - VAPID Key 진단 로그 추가
   - 알림 권한 상태 확인 로그 추가
   - 더미 토큰 감지 경고 추가

### 🔧 진행 중

1. **Web FCM VAPID Key 검증 및 업데이트**
   - Firebase Console에서 실제 VAPID Key 확인 필요
   - 코드의 VAPID Key와 일치 여부 확인 필요

### ⏳ 대기 중

1. **iOS 실제 기기 승인 플로우 재검증**
   - Web FCM 정상화 후 전체 플로우 테스트 필요
   - ringneck@naver.com / iPhone 15 Pro 테스트 대기

---

## 📚 관련 문서

- **Firestore Security Rules V6.2**: `docs/FIRESTORE_SECURITY_RULES_V6.2_FINAL.md`
- **Firebase 배포 가이드**: `docs/FIREBASE_DEPLOY_GUIDE_V6.2.md`
- **FCM Device Approval Service**: `lib/services/fcm/fcm_device_approval_service.dart`
- **Web FCM Config**: `lib/services/fcm/fcm_web_config.dart`

---

## 🆘 문제 해결 FAQ

### Q1: VAPID Key를 어디서 확인하나요?

**A**: Firebase Console > Project Settings > Cloud Messaging > Web Push certificates

### Q2: 알림 권한은 어떻게 확인하나요?

**A**: Chrome 주소창 왼쪽 자물쇠 아이콘 → 사이트 설정 → 알림

### Q3: Safari에서 FCM이 작동하나요?

**A**: Safari는 FCM 지원이 제한적입니다. Chrome, Firefox, Edge 사용 권장

### Q4: 더미 토큰을 삭제하려면?

**A**: 
1. Firestore Database > `fcm_tokens` 컬렉션
2. 더미 토큰 문서 찾기 (`fcmToken: web_dummy_token_...`)
3. 문서 삭제
4. Web에서 로그아웃 후 재로그인

---

## ✨ 다음 단계

1. ✅ **VAPID Key 확인 및 업데이트** (Firebase Console)
2. ✅ **Web 재빌드 및 배포**
3. ✅ **브라우저 알림 권한 허용**
4. ✅ **Web 로그아웃 후 재로그인**
5. ✅ **iOS 기기 승인 플로우 재검증**

---

**마지막 업데이트**: 2025-12-04  
**작성자**: Ringneck Flutter Developer  
**관련 이슈**: MaxDeviceLimitException / Web FCM Token 획득 실패
