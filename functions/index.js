const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');

admin.initializeApp();

const KEYWORDS = [
    {
        key: ['課表', 'schedule', 'class schedule'],
        reply: '目前課表已更新在班級公告欄，請以最新公告為準。',
    },
    {
        key: ['報名', 'register', 'signup', '加入'],
        reply: '請至班級公告欄或聯絡老師，完成報名與確認流程。',
    },
    {
        key: ['價格', 'price', '費用', 'cost'],
        reply: '費用資訊請以老師公告為主，若需要細節請聯絡班級老師。',
    },
    {
        key: ['聯絡', 'contact', '客服', 'help'],
        reply: '請直接聯絡班級老師，或使用聯絡簿/聯絡資訊頁面。',
    },
    {
        key: ['你好', 'hi', 'hello', '哈囉'],
        reply: '您好，歡迎使用 729 班級助手。輸入「課表」、「報名」、「價格」或「聯絡」即可查詢。',
    },
];

function buildReply(message) {
    const text = (message || '').toString().trim();
    if (!text) {
        return '請輸入關鍵字，例如：課表、報名、價格、聯絡我們。';
    }

    const normalized = text.toLowerCase();
    for (const item of KEYWORDS) {
        const matched = item.key.some((keyword) => normalized.includes(keyword.toLowerCase()));
        if (matched) {
            return item.reply;
        }
    }

    return '目前沒有對應的關鍵字，請輸入：課表、報名、價格、聯絡、你好。';
}

exports.lineKeywordReply = functions.https.onRequest(async (req, res) => {
    const method = req.method || 'GET';
    if (method !== 'POST') {
        return res.status(405).json({
            ok: false,
            message: 'Only POST is allowed.',
        });
    }

    try {
        const payload = req.body || {};
        const userMessage = (payload.message || '').toString();
        const reply = buildReply(userMessage);

        return res.status(200).json({
            ok: true,
            trigger: userMessage,
            reply,
            timestamp: new Date().toISOString(),
        });
    } catch (error) {
        console.error('[lineKeywordReply] failed', error);
        return res.status(500).json({
            ok: false,
            message: 'line keyword handler failed',
            error: error.message,
        });
    }
});

exports.lineWebhook = functions.https.onRequest(async (req, res) => {
    if (req.method !== 'POST') {
        return res.status(405).json({ ok: false, message: 'Only POST is allowed.' });
    }

    try {
        const events = Array.isArray(req.body?.events) ? req.body.events : [];

        for (const event of events) {
            if (event.type !== 'message' || event.message?.type !== 'text') {
                continue;
            }

            const text = event.message.text || '';
            const replyText = buildReply(text);

            await admin.firestore().collection('line_replies').add({
                userId: event.source?.userId || null,
                replyText,
                originalText: text,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            // 這裡表示：將來你可以把 replyText 透過 LINE Messaging API 回送給使用者。
            // 你需要額外補上 LINE_CHANNEL_ACCESS_TOKEN 以及 Messaging API 呼叫。
            console.log('[lineWebhook] replyText=', replyText);
        }

        return res.status(200).json({ ok: true });
    } catch (error) {
        console.error('[lineWebhook] failed', error);
        return res.status(500).json({ ok: false, message: 'line webhook failed' });
    }
});
