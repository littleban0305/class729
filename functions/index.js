const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');
const https = require('https');
const { buildReply } = require('./server');

admin.initializeApp();

const DEFAULT_CLASS_ID = (process.env.LINE_DEFAULT_CLASS_ID || process.env.CLASS_ID || '729').trim();
const LINE_ACCESS_TOKEN = process.env.LINE_CHANNEL_ACCESS_TOKEN || '';

function sendLineReply(replyToken, replyText) {
    if (!LINE_ACCESS_TOKEN || !replyToken) {
        console.log('[LINE] reply skipped', { replyToken: !!replyToken, replyText });
        return Promise.resolve();
    }

    const payload = JSON.stringify({
        replyToken,
        messages: [{ type: 'text', text: replyText }],
    });

    return new Promise((resolve, reject) => {
        const request = https.request({
            hostname: 'api.line.me',
            path: '/v2/bot/message/reply',
            method: 'POST',
            headers: {
                Authorization: `Bearer ${LINE_ACCESS_TOKEN}`,
                'Content-Type': 'application/json; charset=utf-8',
                'Content-Length': Buffer.byteLength(payload, 'utf8'),
            },
        }, (response) => {
            let responseText = '';
            response.on('data', (chunk) => responseText += chunk);
            response.on('end', () => {
                if (response.statusCode >= 200 && response.statusCode < 300) {
                    resolve();
                    return;
                }
                reject(new Error(`LINE reply failed: ${response.statusCode} ${responseText}`));
            });
        });
        request.on('error', reject);
        request.write(payload);
        request.end();
    });
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
        const reply = await buildReply(userMessage, DEFAULT_CLASS_ID, payload.userId || null);

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
            const userId = event.source?.userId || null;
            const replyText = await buildReply(text, DEFAULT_CLASS_ID, userId);

            await admin.firestore().collection('line_replies').add({
                userId,
                replyText,
                originalText: text,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            if (replyText && event.replyToken) {
                await sendLineReply(event.replyToken, replyText);
            }
        }

        return res.status(200).json({ ok: true });
    } catch (error) {
        console.error('[lineWebhook] failed', error);
        return res.status(500).json({ ok: false, message: 'line webhook failed' });
    }
});
