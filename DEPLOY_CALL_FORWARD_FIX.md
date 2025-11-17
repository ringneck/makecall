# iOS 착신전환 푸시 알림 수신 문제 해결 가이드

## 🚨 문제 상황
- Android: 착신전환 푸시 알림 정상 수신 ✅
- iOS: 착신전환 푸시 알림 수신 안됨 ❌

## 🔍 원인 분석

### 정상 동작하는 수신전화 푸시 (iOS)
```javascript
apns: {
  payload: {
    aps: {
      sound: "default",
      badge: 1,          // ← iOS에 필수!
    },
  },
},
```

### 문제가 있던 착신전환 푸시 (iOS)
```javascript
apns: {
  payload: {
    aps: {
      sound: "default",
      contentAvailable: true,  // ← 이것만으로는 부족!
    },
  },
},
```

**핵심 문제:**
- iOS에서 포그라운드 푸시 알림을 받으려면 **`badge` 또는 `alert`가 필수**
- `contentAvailable: true`만으로는 백그라운드 데이터 업데이트만 가능
- 수신전화 푸시는 `badge: 1`이 있어서 정상 동작
- 착신전환 푸시는 `badge`가 없어서 iOS에서 알림이 표시되지 않음

## ✅ 해결 방법

### 수정된 착신전환 푸시 (iOS)
```javascript
apns: {
  payload: {
    aps: {
      sound: "default",
      badge: 1,          // ← 추가됨!
    },
  },
},
```

**변경 사항:**
- `contentAvailable: true` 제거
- `badge: 1` 추가 (수신전화 푸시와 동일)

## 🚀 배포 방법

### 1️⃣ Firebase Functions 배포

**로컬 환경에서 배포 (권장):**

```bash
# 1. functions 디렉토리로 이동
cd /path/to/flutter_app/functions

# 2. 특정 함수만 배포 (빠름)
firebase deploy --only functions:sendCallForwardNotification

# 또는 모든 functions 배포
firebase deploy --only functions
```

**배포 예상 시간:**
- 단일 함수 배포: 약 30초 ~ 1분
- 전체 함수 배포: 약 2분 ~ 3분

### 2️⃣ 배포 후 확인

**Cloud Functions 로그 확인:**

```bash
# 실시간 로그 확인
firebase functions:log --only sendCallForwardNotification

# 또는 Firebase Console에서 확인
# https://console.firebase.google.com/ > Functions > Logs
```

### 3️⃣ 테스트 방법

**iOS 기기에서 테스트:**

1. **두 개의 iOS 기기 준비**
   - 기기 A: 착신전환 설정을 변경할 기기
   - 기기 B: 푸시 알림을 받을 기기

2. **기기 A에서 착신전환 설정 변경**
   - 앱 실행 → 홈 화면 → 착신전환 카드
   - 착신전환 토글 ON/OFF
   - 또는 착신전환 번호 변경

3. **기기 B에서 푸시 알림 확인**
   - ✅ 알림 배너가 표시되어야 함
   - ✅ 알림 센터에 알림이 쌓여야 함
   - ✅ 앱 아이콘에 배지(숫자)가 표시되어야 함

**예상 알림 메시지:**
```
착신전환 설정
착신전환 사용이 설정되었습니다.

착신전환 해제
착신전환 사용이 해제되었습니다.

착신전환 번호 변경
착신전환 번호가 변경되었습니다. 010-1234-5678
```

## 📋 수정 전후 비교

### Before (수정 전)
```javascript
// iOS에서 알림 표시 안됨 ❌
apns: {
  payload: {
    aps: {
      sound: "default",
      contentAvailable: true,
    },
  },
}
```

### After (수정 후)
```javascript
// iOS에서 알림 정상 표시 ✅
apns: {
  payload: {
    aps: {
      sound: "default",
      badge: 1,
    },
  },
}
```

## 🔧 추가 확인 사항

### iOS 알림 권한 확인
```swift
// 앱에서 알림 권한이 허용되어 있는지 확인
설정 > MAKECALL > 알림 > 허용 (ON)
```

### FCM 토큰 확인
```dart
// Flutter 앱에서 FCM 토큰이 정상적으로 등록되었는지 확인
// Firestore > fcm_tokens 컬렉션 확인
// - platform: "iOS" 
// - isActive: true
// - fcmToken: "..." (값 존재)
```

### Firebase Console에서 확인
1. **Firestore Database**
   ```
   fcm_notifications 컬렉션
   - status: "sent" (성공)
   - status: "failed" (실패 - 원인 확인)
   ```

2. **Cloud Functions 로그**
   ```
   🔔 [FCM-CallForward] 착신전환 알림 요청 수신
   ✅ [FCM-CallForward] FCM 알림 전송 완료
   ```

## 🐛 문제 해결

### 문제 1: 배포 후에도 iOS에서 알림이 오지 않음

**확인 사항:**
1. Firebase Functions 배포가 정상 완료되었는지 확인
2. Cloud Functions 로그에서 에러 확인
3. iOS 기기의 알림 권한 확인
4. FCM 토큰이 유효한지 확인

**해결 방법:**
```bash
# 1. Functions 로그 확인
firebase functions:log

# 2. 앱 완전 재시작 (iOS)
# 앱 종료 → 재실행

# 3. FCM 토큰 재등록
# 앱 로그아웃 → 다시 로그인
```

### 문제 2: Android에서도 알림이 안옴

**확인 사항:**
1. Android 알림 채널 설정 확인
2. Android 알림 권한 확인
3. FCM 토큰 유효성 확인

**해결 방법:**
```dart
// Android 알림 채널 확인
// lib/services/fcm_service.dart
// - call_forward_channel 생성 확인
```

### 문제 3: 특정 기기에서만 알림이 안옴

**확인 사항:**
1. 해당 기기의 FCM 토큰 확인
2. Firestore fcm_tokens 컬렉션에서 isActive 상태 확인
3. 네트워크 연결 상태 확인

**해결 방법:**
```bash
# Firestore에서 해당 기기 토큰 삭제
# 앱에서 로그아웃 → 다시 로그인하여 토큰 재생성
```

## 📚 참고 자료

### Apple APNS 공식 문서
- [APNS Payload 구조](https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server/generating_a_remote_notification)
- [Badge와 Alert 설정](https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server/pushing_updates_to_your_app_silently)

### Firebase Cloud Messaging
- [FCM iOS 설정](https://firebase.google.com/docs/cloud-messaging/ios/client)
- [FCM 메시지 구조](https://firebase.google.com/docs/cloud-messaging/concept-options)

### Flutter Firebase Messaging
- [flutter_firebase_messaging 패키지](https://pub.dev/packages/firebase_messaging)

## ✅ 배포 체크리스트

- [ ] `functions/index.js` 파일 수정 완료
- [ ] GitHub에 변경사항 푸시 완료
- [ ] Firebase Functions 배포 완료
- [ ] Cloud Functions 로그에서 배포 확인
- [ ] iOS 기기 A에서 착신전환 설정 변경
- [ ] iOS 기기 B에서 푸시 알림 수신 확인
- [ ] Android 기기에서도 정상 동작 확인
- [ ] 알림 센터에 알림 쌓이는지 확인
- [ ] 앱 아이콘 배지 표시 확인

---

## 🎯 요약

**문제:** iOS에서 착신전환 푸시 알림이 표시되지 않음

**원인:** APNS payload에 `badge` 또는 `alert` 없이 `contentAvailable`만 사용

**해결:** 수신전화 푸시와 동일하게 `badge: 1` 추가

**배포:** `firebase deploy --only functions:sendCallForwardNotification`

**결과:** ✅ iOS에서 착신전환 푸시 알림 정상 수신

---

배포 후 테스트해보시고 문제가 있으면 말씀해주세요! 🎉
