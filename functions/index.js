/**
 * Firebase Cloud Functions for MAKECALL App
 *
 * 기능:
 * 1. 중복 로그인 방지 - FCM 푸시 알림 전송
 * 2. 원격 로그아웃 - 특정 기기 강제 로그아웃
 */

const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {logger} = require("firebase-functions/v2/logger");
const admin = require("firebase-admin");

// Firebase Admin 초기화
admin.initializeApp();

/**
 * 강제 로그아웃 FCM 메시지 전송
 *
 * fcm_force_logout_queue 컬렉션에 새 문서가 생성되면 자동 실행됩니다.
 * 중복 로그인 감지 시 기존 기기에 강제 로그아웃 알림을 전송합니다.
 */
exports.sendForceLogoutNotification = onDocumentCreated(
    "fcm_force_logout_queue/{queueId}",
    async (event) => {
      const snapshot = event.data;
      if (!snapshot) {
        logger.error("No data associated with the event");
        return;
      }

      const data = snapshot.data();

      // 이미 처리된 메시지는 스킵
      if (data.processed) {
        logger.info("Message already processed, skipping...");
        return;
      }

      logger.info("=".repeat(60));
      logger.info("📤 강제 로그아웃 FCM 메시지 전송 시작");
      logger.info("=".repeat(60));
      logger.info(`Target Token: ${data.targetToken.substring(0, 30)}...`);
      logger.info(`New Device: ${data.newDeviceName} (${data.newPlatform})`);

      try {
        // FCM 메시지 구성
        const message = {
          token: data.targetToken,
          notification: {
            title: data.message.title,
            body: data.message.body,
          },
          data: {
            type: "force_logout",
            newDeviceName: data.newDeviceName,
            newPlatform: data.newPlatform,
          },
          // 높은 우선순위 설정 (즉시 전달)
          android: {
            priority: "high",
          },
          apns: {
            headers: {
              "apns-priority": "10",
            },
          },
        };

        // FCM 메시지 전송
        const response = await admin.messaging().send(message);
        logger.info(`✅ FCM 메시지 전송 성공: ${response}`);

        // 처리 완료 플래그 업데이트
        await snapshot.ref.update({
          processed: true,
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
          response: response,
        });

        logger.info("✅ 강제 로그아웃 알림 전송 완료");
        logger.info("=".repeat(60));
      } catch (error) {
        logger.error("❌ FCM 메시지 전송 실패:", error);

        // 에러 정보 저장
        await snapshot.ref.update({
          processed: true,
          error: error.message,
          errorCode: error.code,
          failedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // 토큰이 유효하지 않은 경우 fcm_tokens에서 제거
        if (error.code === "messaging/invalid-registration-token" ||
            error.code === "messaging/registration-token-not-registered") {
          logger.warn("⚠️  유효하지 않은 FCM 토큰 감지, 자동 삭제 처리");

          // fcm_tokens 컬렉션에서 해당 토큰 검색 및 삭제
          const tokensSnapshot = await admin.firestore()
              .collection("fcm_tokens")
              .where("fcmToken", "==", data.targetToken)
              .get();

          const batch = admin.firestore().batch();
          tokensSnapshot.docs.forEach((doc) => {
            batch.delete(doc.ref);
          });
          await batch.commit();

          logger.info("✅ 유효하지 않은 FCM 토큰 삭제 완료");
        }
      }
    },
);

/**
 * 원격 로그아웃 함수 (Callable Function)
 *
 * 클라이언트에서 호출하여 특정 기기를 원격으로 로그아웃시킵니다.
 * 활성 세션 관리 UI에서 사용됩니다.
 *
 * @param {Object} data - 요청 데이터
 * @param {string} data.targetDeviceId - 로그아웃할 기기 ID
 * @param {string} data.targetUserId - 대상 사용자 ID
 * @return {Promise<Object>} 결과 객체
 */
exports.remoteLogout = onCall(async (request) => {
  const {data, auth} = request;

  // 인증 확인
  if (!auth) {
    throw new HttpsError("unauthenticated", "인증이 필요합니다.");
  }

  logger.info("=".repeat(60));
  logger.info("🔐 원격 로그아웃 요청 수신");
  logger.info("=".repeat(60));
  logger.info(`Caller UID: ${auth.uid}`);
  logger.info(`Target User ID: ${data.targetUserId}`);
  logger.info(`Target Device ID: ${data.targetDeviceId}`);

  // 권한 확인: 본인의 기기만 로그아웃 가능
  if (auth.uid !== data.targetUserId) {
    logger.warn("❌ 권한 없음: 다른 사용자의 기기를 로그아웃할 수 없습니다.");
    throw new HttpsError(
        "permission-denied",
        "본인의 기기만 로그아웃할 수 있습니다.",
    );
  }

  try {
    // 대상 기기의 FCM 토큰 조회
    const tokenDoc = await admin.firestore()
        .collection("fcm_tokens")
        .doc(`${data.targetUserId}_${data.targetDeviceId}`)
        .get();

    if (!tokenDoc.exists) {
      logger.warn("⚠️  대상 기기를 찾을 수 없습니다.");
      throw new HttpsError(
          "not-found",
          "대상 기기를 찾을 수 없습니다.",
      );
    }

    const tokenData = tokenDoc.data();
    logger.info(`Target Device: ${tokenData.deviceName} (${tokenData.platform})`);
    logger.info(`Target Token: ${tokenData.fcmToken.substring(0, 30)}...`);

    // FCM 메시지 전송
    const message = {
      token: tokenData.fcmToken,
      notification: {
        title: "원격 로그아웃",
        body: "다른 위치에서 이 기기를 로그아웃했습니다.",
      },
      data: {
        type: "force_logout",
        reason: "remote_logout",
        newDeviceName: "다른 기기",
        newPlatform: "unknown",
      },
      android: {
        priority: "high",
      },
      apns: {
        headers: {
          "apns-priority": "10",
        },
      },
    };

    const response = await admin.messaging().send(message);
    logger.info(`✅ FCM 메시지 전송 성공: ${response}`);

    // FCM 토큰 삭제
    await tokenDoc.ref.delete();
    logger.info("✅ FCM 토큰 삭제 완료");

    logger.info("✅ 원격 로그아웃 완료");
    logger.info("=".repeat(60));

    return {
      success: true,
      message: "원격 로그아웃이 완료되었습니다.",
      deviceName: tokenData.deviceName,
    };
  } catch (error) {
    logger.error("❌ 원격 로그아웃 실패:", error);

    // Firebase 에러가 아닌 경우 일반 에러로 변환
    if (error instanceof HttpsError) {
      throw error;
    }

    throw new HttpsError(
        "internal",
        `원격 로그아웃 처리 중 오류가 발생했습니다: ${error.message}`,
    );
  }
});

/**
 * 만료된 FCM 토큰 정리 (예약 함수)
 *
 * 매일 자정에 실행되어 30일 이상 사용되지 않은 FCM 토큰을 자동 삭제합니다.
 *
 * 배포 후 Firebase Console에서 스케줄 설정:
 * - Schedule: every day 00:00
 * - Time zone: Asia/Seoul
 */
exports.cleanupExpiredTokens = onCall(async (request) => {
  const {auth} = request;

  // 관리자 권한 확인 (선택사항)
  if (!auth) {
    throw new HttpsError("unauthenticated", "인증이 필요합니다.");
  }

  logger.info("=".repeat(60));
  logger.info("🧹 만료된 FCM 토큰 정리 시작");
  logger.info("=".repeat(60));

  try {
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const expiredTokens = await admin.firestore()
        .collection("fcm_tokens")
        .where("lastActiveAt", "<", admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
        .get();

    logger.info(`발견된 만료 토큰: ${expiredTokens.size}개`);

    if (expiredTokens.empty) {
      logger.info("✅ 만료된 토큰이 없습니다.");
      return {success: true, deletedCount: 0};
    }

    // 배치 삭제
    const batch = admin.firestore().batch();
    expiredTokens.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });
    await batch.commit();

    logger.info(`✅ ${expiredTokens.size}개의 만료된 토큰 삭제 완료`);
    logger.info("=".repeat(60));

    return {
      success: true,
      deletedCount: expiredTokens.size,
    };
  } catch (error) {
    logger.error("❌ 토큰 정리 실패:", error);
    throw new HttpsError(
        "internal",
        `토큰 정리 중 오류가 발생했습니다: ${error.message}`,
    );
  }
});
