const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

// ✅ 마이그레이션: functions.config() → process.env (dotenv)
// Firebase Cloud Functions는 자동으로 .env 파일을 로드합니다 (Node.js 18+)
const gmailEmail = process.env.GMAIL_EMAIL;
const gmailPassword = process.env.GMAIL_PASSWORD;

// 환경 변수 검증 (배포 시 오류 방지)
if (!gmailEmail || !gmailPassword) {
  throw new Error(
      "❌ Gmail 환경 변수가 설정되지 않았습니다. " +
    "functions/.env 파일에 GMAIL_EMAIL과 GMAIL_PASSWORD를 설정하세요.",
  );
}

admin.initializeApp();

const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: gmailEmail,
    pass: gmailPassword,
  },
});

/**
 * 이메일 인증 코드 전송 Cloud Function
 *
 * Firestore 'email_verification_requests' 컬렉션에 새 문서가 생성되면
 * 자동으로 이메일을 전송합니다.
 */
exports.sendVerificationEmail = functions.firestore
    .document("email_verification_requests/{requestId}")
    .onCreate(async (snap, context) => {
      try {
        const requestId = context.params.requestId;
        const data = snap.data();

        const userId = data.userId;
        const code = data.code;
        // const createdAt = data.createdAt; // 현재 미사용

        console.log(`📧 이메일 인증 요청 수신: ${requestId}`);
        console.log(`   User ID: ${userId}`);
        console.log(`   인증 코드: ${code}`);

        // Firestore에서 사용자 이메일 가져오기
        const userDoc = await admin.firestore().collection("users").doc(userId).get();

        if (!userDoc.exists) {
          console.error(`❌ 사용자 문서 없음: ${userId}`);
          return;
        }

        const userData = userDoc.data();
        const userEmail = userData.email;

        if (!userEmail) {
          console.error(`❌ 사용자 이메일 없음: ${userId}`);
          return;
        }

        console.log(`   받는 사람: ${userEmail}`);

        // 이메일 전송
        const mailOptions = {
          from: `MAKECALL <${gmailEmail}>`,
          to: userEmail,
          subject: "🔐 MAKECALL 새 기기 로그인 인증 코드",
          html: `
          <!DOCTYPE html>
          <html>
          <head>
            <meta charset="utf-8">
            <style>
              body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
              .container { max-width: 600px; margin: 0 auto; padding: 20px; }
              .header {
                background: #2196F3;
                color: white;
                padding: 20px;
                text-align: center;
                border-radius: 8px 8px 0 0;
              }
              .content { padding: 30px; background: #f9f9f9; }
              .code-box { 
                background: white; 
                border: 2px solid #2196F3; 
                padding: 20px; 
                text-align: center; 
                margin: 20px 0;
                border-radius: 8px;
              }
              .code { 
                font-size: 32px; 
                font-weight: bold; 
                letter-spacing: 8px; 
                color: #2196F3; 
              }
              .footer { padding: 20px; text-align: center; color: #666; font-size: 12px; }
              .warning {
                background: #fff3cd;
                border: 1px solid #ffc107;
                padding: 15px;
                margin: 15px 0;
                border-radius: 8px;
              }
            </style>
          </head>
          <body>
            <div class="container">
              <div class="header">
                <h1>🔐 새 기기 로그인 인증</h1>
              </div>
              
              <div class="content">
                <p>안녕하세요,</p>
                <p>새 기기에서 로그인을 시도하고 있습니다. 본인이 맞다면 아래 인증 코드를 입력하세요.</p>
                
                <div class="code-box">
                  <p style="margin: 0; font-size: 14px; color: #666;">인증 코드</p>
                  <div class="code">${code}</div>
                </div>
                
                <div class="warning">
                  <strong>⚠️ 주의사항:</strong>
                  <ul style="margin: 10px 0;">
                    <li>이 코드는 <strong>5분간</strong> 유효합니다.</li>
                    <li>본인이 아닌 경우 이 이메일을 무시하세요.</li>
                    <li>MAKECALL은 절대 이메일로 비밀번호를 요청하지 않습니다.</li>
                  </ul>
                </div>
                
                <p style="margin-top: 20px; color: #666;">
                  문제가 있으신가요? support@makecall.com으로 문의하세요.
                </p>
              </div>
              
              <div class="footer">
                <p>© 2024 MAKECALL. All rights reserved.</p>
                <p>이 이메일은 MAKECALL 새 기기 로그인 인증을 위해 자동으로 발송되었습니다.</p>
              </div>
            </div>
          </body>
          </html>
        `,
          text: `
MAKECALL 새 기기 로그인 인증 코드

인증 코드: ${code}

이 코드는 5분간 유효합니다.
본인이 아닌 경우 이 이메일을 무시하세요.

문의: support@makecall.com
        `.trim(),
        };

        await transporter.sendMail(mailOptions);

        console.log(`✅ 이메일 전송 완료: ${userEmail}`);

        // 전송 완료 표시 (선택사항)
        await snap.ref.update({
          emailSent: true,
          emailSentAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (error) {
        console.error("❌ 이메일 전송 오류:", error);
        throw error;
      }
    });

/**
 * FCM 기기 승인 알림 전송 Cloud Function
 *
 * Firestore 'fcm_approval_notification_queue' 컬렉션에 새 문서가 생성되면
 * 자동으로 FCM 푸시 알림을 전송합니다.
 */
exports.sendApprovalNotification = functions.firestore
    .document("fcm_approval_notification_queue/{queueId}")
    .onCreate(async (snap, context) => {
      try {
        const queueId = context.params.queueId;
        const data = snap.data();

        const targetToken = data.targetToken;
        const message = data.message;
        const approvalRequestId = data.approvalRequestId;
        const newDeviceName = data.newDeviceName;
        const newPlatform = data.newPlatform;

        console.log(`🔔 FCM 승인 알림 요청 수신: ${queueId}`);
        console.log(`   Target Token: ${targetToken.substring(0, 20)}...`);
        console.log(`   New Device: ${newDeviceName} (${newPlatform})`);

        // FCM 푸시 알림 전송
        const fcmMessage = {
          token: targetToken,
          notification: {
            title: message.title,
            body: message.body,
          },
          data: {
            type: message.type,
            approvalRequestId: approvalRequestId,
            newDeviceName: newDeviceName,
            newPlatform: newPlatform,
          },
          android: {
            priority: "high",
            notification: {
              channelId: "high_importance_channel",
              priority: "high",
              sound: "default",
            },
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
                contentAvailable: true,
              },
            },
          },
        };

        await admin.messaging().send(fcmMessage);

        console.log(`✅ FCM 알림 전송 완료: ${targetToken.substring(0, 20)}...`);

        // 처리 완료 표시
        await snap.ref.update({
          processed: true,
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (error) {
        console.error("❌ FCM 알림 전송 오류:", error);

        // 오류 정보 저장
        await snap.ref.update({
          processed: false,
          error: error.message,
          errorAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    });

/**
 * 만료된 인증 요청 정리 Cloud Function (스케줄링)
 *
 * 매시간 실행되어 5분 이상 경과한 미처리 인증 요청을 삭제합니다.
 */
exports.cleanupExpiredRequests = functions.pubsub
    .schedule("every 1 hours")
    .onRun(async (context) => {
      try {
        console.log("🧹 만료된 인증 요청 정리 시작");

        const now = admin.firestore.Timestamp.now();
        const fiveMinutesAgo = new Date(now.toDate().getTime() - 5 * 60 * 1000);

        // 만료된 이메일 인증 요청 삭제
        const expiredEmailRequests = await admin.firestore()
            .collection("email_verification_requests")
            .where("createdAt", "<", fiveMinutesAgo)
            .where("used", "==", false)
            .get();

        const emailBatch = admin.firestore().batch();
        expiredEmailRequests.docs.forEach((doc) => {
          emailBatch.delete(doc.ref);
        });
        await emailBatch.commit();

        console.log(`✅ 만료된 이메일 인증 요청 ${expiredEmailRequests.size}개 삭제`);

        // 만료된 기기 승인 요청 정리
        const expiredApprovalRequests = await admin.firestore()
            .collection("device_approval_requests")
            .where("expiresAt", "<", now)
            .where("status", "==", "pending")
            .get();

        const approvalBatch = admin.firestore().batch();
        expiredApprovalRequests.docs.forEach((doc) => {
          approvalBatch.update(doc.ref, {status: "expired"});
        });
        await approvalBatch.commit();

        console.log(`✅ 만료된 기기 승인 요청 ${expiredApprovalRequests.size}개 업데이트`);
      } catch (error) {
        console.error("❌ 정리 작업 오류:", error);
      }
    });
