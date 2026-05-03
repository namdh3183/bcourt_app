const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();

// Lắng nghe collection fcm_send_queue — mỗi document mới sẽ trigger gửi FCM push
exports.sendFCMNotification = onDocumentCreated(
  'fcm_send_queue/{docId}',
  async (event) => {
    const data = event.data.data();
    const token = data.token;
    const title = data.title;
    const body = data.body;
    const extraData = data.data || {};

    if (!token) {
      console.log('Không có FCM token, bỏ qua document này');
      return null;
    }

    const message = {
      token,
      notification: { title, body },
      data: extraData,
      android: {
        priority: 'high',
        notification: {
          channelId: 'bcourt_notifications',
          sound: 'default',
        },
      },
      apns: {
        payload: {
          aps: { sound: 'default', badge: 1 },
        },
      },
    };

    try {
      await getMessaging().send(message);
      console.log(`Đã gửi FCM thành công tới token: ${token.substring(0, 20)}...`);
    } catch (error) {
      console.error('Lỗi gửi FCM:', error.message);
    }

    // Xóa document sau khi xử lý để dọn sạch hàng đợi
    return event.data.ref.delete();
  }
);
