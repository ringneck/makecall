# ✅ MaxDeviceLimit 플로우 검증 체크리스트

## 📋 전체 플로우 개요

MaxDeviceLimit 기능은 사용자가 설정한 최대 기기 수를 초과할 때 발동하며, 기존 기기에서 새 기기를 승인하는 방식으로 작동합니다.

### 주요 단계

1. **기기 제한 감지**: 로그인 시 최대 기기 수 초과 감지
2. **MaxDeviceLimitDialog 표시**: 사용자에게 기기 제한 상황 알림
3. **승인 요청 생성**: `device_approval_requests` 컬렉션에 승인 요청 저장
4. **알림 전송**: 기존 기기에 FCM 알림 전송
5. **승인 대기**: 새 기기는 승인 대기 화면 표시
6. **승인 처리**: 기존 기기에서 승인 → 새 기기 자동 로그인

---

## 🔍 최근 수정 사항 (2025-12-04)

### ✅ Firestore Security Rules V6.2 (FINAL)

**문제**: `device_approval_requests` 쿼리 리스닝 시 `permission-denied` 오류  
**원인**: `.doc().snapshots()` 호출 시 `resource == null`인데 규칙에서 `resource.data.userId` 접근  
**해결**: `allow read: if request.auth != null && (resource == null || resource.data.userId == request.auth.uid);`

**관련 파일**:
- ✅ `firestore.rules` (Line 91-93)
- ✅ `docs/FIRESTORE_SECURITY_RULES_V6.2_FINAL.md`
- ✅ Firebase Console 배포 완료

### 🔧 Web FCM 디버그 로깅 강화

**문제**: Web 플랫폼에서 더미 토큰(`web_dummy_token_...`) 생성  
**원인**: FCM 토큰 획득 실패 (VAPID Key 불일치, 알림 권한 거부 등)  
**해결**: 상세 진단 로그 추가, VAPID Key 가이드 문서 작성

**관련 파일**:
- ✅ `lib/services/fcm/fcm_web_config.dart`
- ✅ `lib/services/fcm_service.dart`
- ✅ `docs/WEB_FCM_VAPID_KEY_GUIDE.md`

---

## 📊 검증 체크리스트

### Phase 1: 사전 준비 ✅

#### 1.1 Firestore Security Rules 확인

- [ ] Firebase Console > Firestore Database > Rules
- [ ] V6.2 규칙 적용 확인 (2025-12-04)
- [ ] `device_approval_requests` 규칙 확인:
  ```javascript
  allow read: if request.auth != null 
              && (resource == null || resource.data.userId == request.auth.uid);
  ```

#### 1.2 Web FCM 설정 확인

- [ ] Firebase Console > Project Settings > Cloud Messaging
- [ ] Web Push certificates 확인
- [ ] VAPID Key가 `fcm_web_config.dart`와 일치하는지 확인

#### 1.3 테스트 환경 준비

- [ ] **테스트 계정**: ringneck@naver.com
- [ ] **iOS 기기**: iPhone 15 Pro (iOS 26.1)
- [ ] **Web 브라우저**: Chrome (권장)
- [ ] **사용자 설정**: maxDevices = 2

---

### Phase 2: Web 플랫폼 검증 (기존 기기) 🌐

#### 2.1 Web 로그인

- [ ] Chrome에서 https://[app-url] 접속
- [ ] ringneck@naver.com으로 로그인
- [ ] 브라우저 알림 권한 요청 팝업에서 **"허용"** 클릭

#### 2.2 Web FCM 토큰 확인

**브라우저 콘솔 (F12 → Console) 로그 확인**:

- [ ] `🌐 [FCM-WEB] 웹 FCM 토큰 요청 시작...`
- [ ] `   VAPID Key: BM2qgTRRwT-mG4shg...` (VAPID Key 출력)
- [ ] `✅ [FCM-WEB] 웹 FCM 토큰 획득 성공`
- [ ] `   토큰 길이: 152` (실제 FCM 토큰 길이)
- [ ] `🔔 [FCM-WEB] 알림 권한: AuthorizationStatus.authorized`
- [ ] `✅ [FCM-WEB] 웹 FCM 토큰 획득 성공 - 알림 수신 가능`

**❌ 실패 시 확인할 로그**:

- [ ] `⚠️ [FCM-WEB] 웹 FCM 토큰이 null입니다`
- [ ] `   가능한 원인: ...` (진단 메시지)
- [ ] `⚠️ [FCM-WEB] ❌ 감지됨: 더미 토큰 사용 시 FCM 알림 수신 불가!`

**실패 시 조치**: `docs/WEB_FCM_VAPID_KEY_GUIDE.md` 참조

#### 2.3 Firestore fcm_tokens 확인

Firebase Console > Firestore Database > `fcm_tokens`:

- [ ] Web 기기 문서 존재 확인 (`userId_deviceId_Web`)
- [ ] `fcmToken` 필드가 실제 FCM 토큰인지 확인 (길이 150+)
  - ✅ 정상: `eKGjlw8xRqGm3F7j8Q9P2V...`
  - ❌ 비정상: `web_dummy_token_1764856164056`
- [ ] `isApproved: true`, `isActive: true` 확인

---

### Phase 3: iOS 기기 승인 플로우 검증 (새 기기) 📱

#### 3.1 iOS 로그인 시도

- [ ] iPhone 15 Pro에서 앱 실행
- [ ] ringneck@naver.com으로 로그인 시도

#### 3.2 MaxDeviceLimitDialog 표시

**iOS 콘솔 로그 확인**:

- [ ] `📊 [FCM-DEVICE] 현재 사용자 기기 수: 1` (기존 Web 기기)
- [ ] `⚠️ [FCM-DEVICE] 최대 기기 수(2) 초과, MaxDeviceLimitDialog 표시`
- [ ] `📱 새 기기 승인 필요: iPhone 15 Pro`
- [ ] `🔍 [FCM-DEVICE] 사용 중인 기기 목록: [...]`

**iOS 화면 확인**:

- [ ] `MaxDeviceLimitDialog` 팝업 표시
- [ ] "새 기기 승인 필요" 제목
- [ ] 기존 기기 목록 표시 (safari on MacIntel (Web))
- [ ] "승인 요청 보내기" 버튼
- [ ] "취소" 버튼

#### 3.3 승인 요청 생성

**iOS 콘솔 로그**:

- [ ] `📝 [FCM-DEVICE] 승인 요청 생성 중...`
- [ ] `✅ [FCM-DEVICE] 승인 요청 생성 완료: [approvalRequestId]`
- [ ] `🔔 [FCM-DEVICE] 승인 알림 큐 등록 완료`
- [ ] `⏳ [FCM-WAIT] 기기 승인 대기 시작`

**Firestore 확인**:

- [ ] `device_approval_requests` 컬렉션에 새 문서 생성
  - `userId`: ringneck@naver.com의 UID
  - `deviceId`: iOS 기기 ID
  - `deviceName`: "iPhone 15 Pro"
  - `platform`: "ios"
  - `status`: "pending"
  - `createdAt`: 현재 시간

- [ ] `fcm_approval_notification_queue` 컬렉션에 알림 큐 등록
  - `userId`: ringneck@naver.com의 UID
  - `targetToken`: Web FCM 토큰 (실제 토큰, 더미 아님!)
  - `type`: "device_approval"
  - `deviceName`: "iPhone 15 Pro"
  - `platform`: "ios"

#### 3.4 승인 대기 화면 표시

**iOS 화면 확인**:

- [ ] `ApprovalWaitingScreen` 화면 전환
- [ ] "기기 승인 대기 중..." 제목
- [ ] "기존 기기에서 승인을 기다리고 있습니다" 안내 메시지
- [ ] 타이머 표시 (5분)
- [ ] "취소" 버튼

**iOS 콘솔 로그**:

- [ ] `📡 [FCM-WAIT] 승인 요청 리스닝 시작`
- [ ] `📊 [FCM-WAIT] 승인 요청 ID: [approvalRequestId]`

**❌ 실패 시 확인할 로그** (V6.1에서 발생했던 오류):

- [ ] `⚠️ device_approval_requests 쿼리 리슨 중 에러: [cloud_firestore/permission-denied]`

**→ V6.2에서 해결됨**: `resource == null` 체크 추가

---

### Phase 4: Web 알림 수신 및 승인 처리 🔔

#### 4.1 Web FCM 알림 수신

**Web 브라우저 확인**:

- [ ] FCM 알림 수신 (브라우저 알림 팝업)
  - 제목: "새 기기 승인 요청"
  - 내용: "iPhone 15 Pro (iOS)에서 로그인 시도"
  - 버튼: "승인하기"

**브라우저 콘솔 로그**:

- [ ] `🔔 [FCM] FCM 메시지 수신: {...}`
- [ ] `📱 [FCM-DEVICE-APPROVAL] 기기 승인 알림 수신`

**❌ 알림 미수신 시 확인**:

1. **Web FCM 토큰이 더미 토큰인 경우**:
   - Firestore `fcm_tokens` 확인
   - 더미 토큰이면 → Web 로그아웃 후 재로그인
   - `docs/WEB_FCM_VAPID_KEY_GUIDE.md` 참조

2. **Firebase Console에서 알림 전송 실패 로그 확인**:
   - Cloud Firestore > `fcm_approval_notification_queue` 문서
   - `error` 필드 확인
   - `errorCode: "messaging/invalid-argument"` → 더미 토큰 문제

#### 4.2 승인 화면 표시

**알림 클릭 후**:

- [ ] 앱으로 이동
- [ ] `DeviceApprovalScreen` 표시
- [ ] 승인 요청 정보 표시:
  - 기기 이름: "iPhone 15 Pro"
  - 플랫폼: "iOS"
  - 요청 시간
- [ ] "승인" 버튼
- [ ] "거부" 버튼

#### 4.3 승인 처리

**"승인" 버튼 클릭**:

**Web 콘솔 로그**:

- [ ] `✅ [FCM-DEVICE] 기기 승인 처리 시작`
- [ ] `📝 [FCM-DEVICE] device_approval_requests 업데이트: approved`
- [ ] `📝 [FCM-DEVICE] fcm_tokens 업데이트: isApproved=true, isActive=true`
- [ ] `✅ [FCM-DEVICE] 기기 승인 완료`

**Firestore 확인**:

- [ ] `device_approval_requests` 문서 업데이트
  - `status: "approved"`
  - `approvedAt`: 현재 시간
  
- [ ] `fcm_tokens` 문서 업데이트 (iOS 기기)
  - `isApproved: true`
  - `isActive: true`

---

### Phase 5: iOS 자동 로그인 완료 ✅

#### 5.1 승인 감지

**iOS 콘솔 로그**:

- [ ] `📡 [FCM-WAIT] 승인 상태 변경 감지: approved`
- [ ] `✅ [FCM-WAIT] 기기 승인 완료!`

#### 5.2 자동 로그인

**iOS 콘솔 로그**:

- [ ] `🔑 [AUTH] 자동 로그인 시작`
- [ ] `✅ [AUTH] 로그인 성공`
- [ ] `🏠 [NAV] MainScreen으로 이동`

**iOS 화면 확인**:

- [ ] `ApprovalWaitingScreen` 닫힘
- [ ] `MainScreen` 표시
- [ ] 정상 로그인 상태

---

## 🚨 문제 해결 가이드

### 문제 1: Web에서 더미 토큰 생성

**증상**:
```
⚠️ [FCM-WEB] FCM 토큰 없음 - 더미 토큰으로 기기 정보 저장
```

**해결**:
1. `docs/WEB_FCM_VAPID_KEY_GUIDE.md` 참조
2. VAPID Key 확인 및 업데이트
3. 브라우저 알림 권한 허용
4. Web 로그아웃 후 재로그인

---

### 문제 2: iOS 승인 대기 화면에서 permission-denied 오류

**증상** (V6.1):
```
⚠️ device_approval_requests 쿼리 리슨 중 에러: [cloud_firestore/permission-denied]
```

**해결** (V6.2):
- ✅ Firestore Security Rules V6.2 배포 완료
- ✅ `resource == null` 체크 추가
- ✅ `.doc().snapshots()` 리스너 정상 작동

**검증**:
- Firebase Console > Firestore Database > Rules
- Line 91-93 확인

---

### 문제 3: Web 알림 미수신

**증상**:
- iOS에서 승인 요청 전송 완료
- Web에서 알림 안 옴

**원인**:
1. Web FCM 토큰이 더미 토큰
2. 브라우저 알림 권한 거부
3. FCM 서비스 중단

**해결**:
1. Firestore `fcm_tokens` 확인 (더미 토큰 여부)
2. Firebase Console > `fcm_approval_notification_queue` 확인 (전송 실패 로그)
3. 브라우저 알림 권한 확인
4. Web 재로그인

---

### 문제 4: iOS 로그인 시 MaxDeviceLimitDialog 미표시

**증상**:
- iOS에서 로그인 시도
- MaxDeviceLimitDialog가 표시되지 않음
- 로그인 화면으로 바로 돌아감

**원인**:
1. `maxDevices` 값이 잘못 설정됨
2. 기존 기기 수 계산 오류
3. MaxDeviceLimitDialog 표시 로직 버그

**해결**:
1. Firestore `users` 문서 확인 (`maxDevices` 필드)
2. Firestore `fcm_tokens` 컬렉션 확인 (활성 기기 수)
3. iOS 콘솔 로그 확인:
   ```
   📊 [FCM-DEVICE] 현재 사용자 기기 수: [N]
   ⚠️ [FCM-DEVICE] 최대 기기 수([M]) 초과, MaxDeviceLimitDialog 표시
   ```

---

## 📈 전체 플로우 시퀀스 다이어그램

```
┌─────────────────────────────────────────────────────────────────────┐
│                     MaxDeviceLimit 플로우                            │
└─────────────────────────────────────────────────────────────────────┘

Web (기존 기기)                      iOS (새 기기)
─────────────                        ─────────────

1. 로그인 완료
   ├─ FCM 토큰 획득 (✅ 실제 토큰)
   └─ fcm_tokens 저장                    2. 로그인 시도
                                          ├─ 최대 기기 수 초과 감지
                                          └─ MaxDeviceLimitDialog 표시

                                       3. "승인 요청 보내기" 클릭
                                          ├─ device_approval_requests 생성
                                          └─ fcm_approval_notification_queue 등록

4. FCM 알림 수신 🔔
   ├─ "새 기기 승인 요청"
   └─ 알림 클릭                           5. ApprovalWaitingScreen 표시
                                          ├─ 승인 대기 리스너 시작
5. DeviceApprovalScreen 표시              └─ 타이머 5분
   ├─ 기기 정보 표시
   └─ "승인" 버튼 클릭

6. 승인 처리
   ├─ device_approval_requests 업데이트
   │  └─ status: "approved"
   └─ fcm_tokens 업데이트                 7. 승인 감지 ✅
       └─ isApproved: true                   ├─ 리스너에서 상태 변경 감지
                                             └─ 자동 로그인 시작

                                          8. 로그인 완료 🏠
                                             └─ MainScreen 표시

```

---

## 📚 관련 문서

1. **Firestore Security Rules**:
   - `docs/FIRESTORE_SECURITY_RULES_V6.2_FINAL.md`
   - `firestore.rules`

2. **Web FCM 설정**:
   - `docs/WEB_FCM_VAPID_KEY_GUIDE.md`
   - `lib/services/fcm/fcm_web_config.dart`

3. **FCM Device Approval Service**:
   - `lib/services/fcm/fcm_device_approval_service.dart`

4. **MaxDeviceLimit UI**:
   - `lib/screens/auth/max_device_limit_dialog.dart`
   - `lib/screens/auth/approval_waiting_screen.dart`
   - `lib/screens/auth/device_approval_screen.dart`

---

## ✅ 최종 검증 결과 (테스트 시 작성)

### 테스트 일시: _______________

### 테스트 계정: ringneck@naver.com

### Phase 1: 사전 준비
- [ ] Firestore Rules V6.2 확인
- [ ] Web FCM VAPID Key 확인
- [ ] 테스트 환경 준비

### Phase 2: Web 플랫폼
- [ ] Web 로그인 성공
- [ ] Web FCM 토큰 획득 (✅ 실제 / ❌ 더미)
- [ ] fcm_tokens 정상 저장

### Phase 3: iOS 승인 플로우
- [ ] MaxDeviceLimitDialog 표시
- [ ] 승인 요청 생성
- [ ] ApprovalWaitingScreen 표시
- [ ] permission-denied 오류 없음

### Phase 4: Web 알림 및 승인
- [ ] FCM 알림 수신
- [ ] DeviceApprovalScreen 표시
- [ ] 승인 처리 완료

### Phase 5: iOS 자동 로그인
- [ ] 승인 감지
- [ ] 자동 로그인 성공
- [ ] MainScreen 표시

### 전체 평가

- [ ] **✅ 모든 단계 성공**
- [ ] **⚠️ 일부 문제 발생** (아래 기록)
- [ ] **❌ 주요 문제로 실패** (아래 기록)

### 발생한 문제 및 해결 방법

```
(테스트 시 발생한 문제 및 해결 방법 기록)
```

---

**작성일**: 2025-12-04  
**작성자**: Ringneck Flutter Developer  
**버전**: V6.2 (Firestore Rules) + Web FCM Debug  
**다음 업데이트**: 실제 테스트 완료 후
