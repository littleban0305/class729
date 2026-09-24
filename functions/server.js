const express = require('express');
const https = require('https');
const admin = require('firebase-admin');

const app = express();
const PORT = process.env.PORT || 3000;

const LINE_ACCESS_TOKEN = process.env.LINE_CHANNEL_ACCESS_TOKEN || '';
const LINE_SECRET = process.env.LINE_CHANNEL_SECRET || '';
const DEFAULT_CLASS_ID = (process.env.LINE_DEFAULT_CLASS_ID || process.env.CLASS_ID || '729').trim();
const LINE_USER_COLLECTION = 'lineUsers';
const DAY_NAMES = ['一', '二', '三', '四', '五', '六', '日'];

const ARG_COMMANDS = [
    '查看聯絡簿',
    '查看課表',
    '查看分數',
    '查看今日簽到時間',
    '查看被記',
];

const KEYWORDS = [
    { key: ['查看聯絡簿', '聯絡簿', 'homework', '功課'], type: 'diary' },
    { key: ['查看課表', '課表', 'schedule'], type: 'schedule' },
    { key: ['查看分數', '分數', 'score', 'grades'], type: 'score' },
    { key: ['查看今日簽到時間', '今日簽到時間', '簽到時間', 'attendance'], type: 'attendance' },
    { key: ['查看被記', '被記', '記錄', 'late', '登記'], type: 'discipline' },
];

function normalizeText(value) {
    return (value || '').toString().trim();
}

function normalizeClassId(value) {
    const text = normalizeText(value);
    if (!text) return '';
    return text;
}

function normalizeDateKey(value) {
    if (value === null || value === undefined) return '';
    if (value instanceof Date && !Number.isNaN(value.getTime())) {
        return getTodayKey(value);
    }

    const raw = normalizeText(value).replace(/\s+/, ' ');
    if (!raw) return '';

    const datePart = raw.split('T')[0].replace(/\//g, '-');

    const match = datePart.match(/^(\d{4})-(\d{1,2})-(\d{1,2})$/) ||
        datePart.match(/^(\d{1,2})-(\d{1,2})-(\d{4})$/);

    if (!match) return '';

    let year, month, day;
    if (match[1].length === 4) {
        year = Number(match[1]);
        month = Number(match[2]);
        day = Number(match[3]);
    } else {
        month = Number(match[1]);
        day = Number(match[2]);
        year = Number(match[3]);
    }

    if (!year || !month || !day) return '';

    const date = new Date(year, month - 1, day);
    if (Number.isNaN(date.getTime())) return '';

    return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
}

function getTodayKey(date = new Date()) {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
}

function getWeekdayIndex(date = new Date()) {
    return (date.getDay() + 6) % 7;
}

function asArray(value) {
    return Array.isArray(value) ? value : [];
}

function normalizeDiaryEntry(entry) {
    if (!entry || typeof entry !== 'object') {
        return null;
    }

    const date = toPlainLine(entry.date || entry.day || entry.createdAt || '');
    const tag = toPlainLine(entry.tag || entry.category || '一般');
    const content = toPlainLine(entry.content || entry.note || entry.message || '');

    if (!date && !content && !tag) {
        return null;
    }

    return {
        date,
        tag: tag || '一般',
        content,
    };
}

function getDiaryEntries(data) {
    const diaryEntries = asArray(data?.diaryEntries)
        .map(normalizeDiaryEntry)
        .filter(Boolean)
        .sort((a, b) => (b.date || '').localeCompare(a.date || ''));

    if (diaryEntries.length) {
        return diaryEntries;
    }

    return asArray(data?.diary)
        .map(normalizeDiaryEntry)
        .filter(Boolean)
        .sort((a, b) => (b.date || '').localeCompare(a.date || ''));
}

function resolveClassId(messageText, fallbackClassId = DEFAULT_CLASS_ID) {
    const text = normalizeText(messageText);
    const explicitMatch = text.match(/(?:班級|class(?:id)?|class)\s*[:：\s]*([A-Za-z0-9_-]+)/i);
    if (explicitMatch && explicitMatch[1]) {
        return normalizeClassId(explicitMatch[1]);
    }

    const fallback = normalizeClassId(fallbackClassId || '');
    return fallback || '729';
}

function toPlainLine(value) {
    if (value == null) return '';
    return String(value).replace(/\s+/g, ' ').trim();
}

function buildReplyTextForData(type, data, classId, studentNumber = '') {
    if (type === 'schedule') {
        const entries = asArray(data?.scheduleEntries)
            .filter((entry) => entry && typeof entry === 'object')
            .map((entry) => ({
                weekday: Number(entry.weekday ?? 0),
                lesson: Number(entry.lesson ?? 0),
                subject: toPlainLine(entry.subject),
                teacher: toPlainLine(entry.teacher),
                startTime: toPlainLine(entry.startTime),
                endTime: toPlainLine(entry.endTime),
            }))
            .sort((a, b) => a.weekday - b.weekday || a.lesson - b.lesson);

        if (!entries.length) {
            return '目前沒有課表資料，請先在 729 軟體中同步課表。';
        }

        const today = new Date();
        const weekdayIndex = getWeekdayIndex(today);
        const todayLessons = entries.filter((entry) => entry.weekday === weekdayIndex);

        if (!todayLessons.length) {
            return `今天沒有排課；目前可用課表：\n${entries.slice(0, 3).map((entry) => `星期${DAY_NAMES[entry.weekday] || entry.weekday + 1} 第${entry.lesson + 1}節 ${entry.subject || '未命名'}`).join('\n')}`;
        }

        return `今天的課表：\n${todayLessons.map((entry) => `第${entry.lesson + 1}節 ${entry.subject || '未命名'}${entry.teacher ? ` (${entry.teacher})` : ''}${entry.startTime && entry.endTime ? ` ${entry.startTime}-${entry.endTime}` : ''}`).join('\n')}`;
    }

    if (type === 'diary') {
        const todayKey = getTodayKey();
        const entries = getDiaryEntries(data);
        const todayEntries = entries.filter((entry) => normalizeDateKey(entry.date) === todayKey);

        if (!todayEntries.length) {
            return '今天沒有聯絡簿內容。';
        }

        return `今天的聯絡簿：\n${todayEntries.map((entry, index) => `${index + 1}. ${entry.content || '無內容'}（${entry.tag || '一般'}）`).join('\n')}`;
    }

    if (type === 'score') {
        const allSeats = asArray(data?.seats)
            .filter((entry) => entry && typeof entry === 'object')
            .map((entry) => ({
                number: toPlainLine(entry.number).replace(/^0+(?=\d)/, ''),
                name: toPlainLine(entry.name),
                score: Number(entry.score ?? 0),
            }))
            .filter((entry) => entry.number || entry.name || entry.score !== 0);
        const seats = studentNumber
            ? allSeats.filter((entry) => entry.number === studentNumber.replace(/^0+(?=\d)/, '')).slice(0, 1)
            : allSeats.slice(0, 5);

        if (seats.length) {
            if (studentNumber) {
                return `你現在有${seats[0].score}分。`;
            }
            return seats.map((entry) => `${entry.number || entry.name || '座位'}：${entry.score}`).join('\n');
        }

        return '目前沒有可查詢的分數資料。';
    }

    if (type === 'attendance') {
        const todayKey = getTodayKey();
        const records = asArray(data?.attendanceRecords)
            .filter((entry) => entry && typeof entry === 'object')
            .map((entry) => ({
                studentName: toPlainLine(entry.studentName),
                studentNumber: toPlainLine(entry.studentNumber),
                date: toPlainLine(entry.date),
                time: toPlainLine(entry.time),
                late: !!entry.late,
            }))
            .filter((entry) => entry.date === todayKey)
            .slice(0, 5);

        if (!records.length) {
            return '今天還沒有簽到紀錄。';
        }

        return `今日簽到：\n${records.map((entry) => `${entry.studentName || entry.studentNumber || '學生'} ${entry.time}${entry.late ? '（遲到）' : ''}`).join('\n')}`;
    }

    if (type === 'discipline') {
        const allRecords = asArray(data?.studentRecords)
            .filter((entry) => entry && typeof entry === 'object')
            .map((entry) => ({
                studentNumber: toPlainLine(entry.studentNumber),
                studentName: toPlainLine(entry.studentName),
                date: toPlainLine(entry.date),
                type: toPlainLine(entry.type),
                note: toPlainLine(entry.note),
            }));
        const records = (studentNumber
            ? allRecords.filter((entry) => entry.studentNumber === studentNumber)
            : allRecords).slice(0, 3);

        if (!records.length) {
            return '目前沒有被記紀錄。';
        }

        return `被記紀錄：\n${records.map((entry) => `${entry.studentName || '學生'} ${entry.date}：${entry.type || '紀錄'}${entry.note ? ` / ${entry.note}` : ''}`).join('\n')}`;
    }

    return '沒有對應資料。';
}

function initFirebase() {
    if (!admin.apps.length) {
        const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH || process.env.GOOGLE_APPLICATION_CREDENTIALS;
        const projectId = process.env.FIREBASE_PROJECT_ID || process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT;

        if (serviceAccountPath) {
            const serviceAccount = require(serviceAccountPath);
            admin.initializeApp({
                credential: admin.credential.cert(serviceAccount),
                projectId: projectId || serviceAccount.project_id,
            });
        } else if (projectId) {
            admin.initializeApp({ projectId });
        } else {
            throw new Error('Firebase 未設定：請設定 FIREBASE_SERVICE_ACCOUNT_PATH 或 GOOGLE_APPLICATION_CREDENTIALS，才可讀取 Firestore。');
        }
    }

    return admin.firestore();
}

async function getLineUserProfile(userId) {
    if (!userId) return null;

    const db = initFirebase();
    const snapshot = await db.collection(LINE_USER_COLLECTION).doc(userId).get();
    return snapshot.exists ? snapshot.data() || {} : null;
}

async function saveLineUserProfile(userId, data) {
    if (!userId) {
        throw new Error('LINE 使用者識別失敗，無法儲存座號。');
    }

    const db = initFirebase();
    await db.collection(LINE_USER_COLLECTION).doc(userId).set({
        ...data,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
}

function isValidStudentNumber(value) {
    return /^\d{1,3}$/.test(normalizeText(value));
}

async function fetchClassData(classId) {
    const seedId = normalizeText(classId || DEFAULT_CLASS_ID || '729');
    const candidateIds = Array.from(new Set([
        seedId,
        normalizeClassId(seedId),
        seedId.replace(/^0+/, ''),
        `0${seedId.replace(/^0+/, '')}`,
    ].filter(Boolean)));

    if (!candidateIds.length) {
        return null;
    }

    try {
        const db = initFirebase();
        let merged = {};

        for (const id of candidateIds) {
            const classRef = db.collection('classes').doc(id);
            const [publicDoc, privateDoc] = await Promise.all([
                classRef.get(),
                classRef.collection('private').doc('state').get(),
            ]);

            if (publicDoc.exists || privateDoc.exists) {
                const publicData = publicDoc.exists ? publicDoc.data() || {} : {};
                const privateData = privateDoc.exists ? privateDoc.data() || {} : {};
                merged = { ...publicData, ...privateData };
                if (Object.keys(merged).length > 0) {
                    return merged;
                }
            }
        }

        return null;
    } catch (error) {
        console.error('[firebase] fetch class data failed', error);
        return {
            __firebaseError: true,
            __errorMessage: error.message || String(error),
        };
    }
}

async function buildReply(message, fallbackClassId = DEFAULT_CLASS_ID, userId = null) {
    const text = normalizeText(message);
    if (!text) {
        return null;
    }

    const profile = userId ? await getLineUserProfile(userId) : null;
    if (profile?.awaitingStudentNumber) {
        if (!isValidStudentNumber(text)) {
            return '錯誤，請輸入你的座號，例如30號填寫30。';
        }

        await saveLineUserProfile(userId, {
            studentNumber: text,
            awaitingStudentNumber: false,
        });
        return `已記住你的座號 ${text}。`;
    }

    const normalized = text.toLowerCase();
    for (const item of KEYWORDS) {
        const matched = item.key.some((keyword) => normalized.includes(keyword.toLowerCase()));
        if (matched) {
            if (item.reply) {
                return item.reply;
            }

            let studentNumber = '';
            if (item.type === 'score' || item.type === 'discipline') {
                studentNumber = toPlainLine(profile?.studentNumber);

                if (!studentNumber) {
                    await saveLineUserProfile(userId, { awaitingStudentNumber: true });
                    return '請問你是幾號？例如30號填寫30';
                }
            }

            const classId = resolveClassId(text, fallbackClassId);
            const data = await fetchClassData(classId);
            if (!data || data.__firebaseError) {
                const reason = data && data.__errorMessage ? data.__errorMessage : 'Firebase 讀取失敗';
                return reason;
            }
            return buildReplyTextForData(item.type, data, classId, studentNumber);
        }
    }

    return null;
}

function sendLineReply(userId, replyText) {
    if (!LINE_ACCESS_TOKEN || !userId) {
        console.log('[LINE] fake reply ->', { userId, replyText });
        return Promise.resolve();
    }

    const payload = JSON.stringify({
        to: userId,
        messages: [{ type: 'text', text: replyText }],
    });

    const options = {
        hostname: 'api.line.me',
        path: '/v2/bot/message/push',
        method: 'POST',
        headers: {
            Authorization: `Bearer ${LINE_ACCESS_TOKEN}`,
            'Content-Type': 'application/json; charset=utf-8',
            'Content-Length': Buffer.byteLength(payload, 'utf8'),
        },
    };

    return new Promise((resolve, reject) => {
        const req = https.request(options, (res) => {
            let responseText = '';
            res.on('data', (chunk) => {
                responseText += chunk;
            });
            res.on('end', () => {
                if (res.statusCode >= 200 && res.statusCode < 300) {
                    console.log('[LINE] reply ok', responseText);
                    resolve();
                    return;
                }
                console.error('[LINE] reply error', res.statusCode, responseText);
                resolve();
            });
        });

        req.on('error', (error) => {
            console.error('[LINE] reply failed', error);
            reject(error);
        });

        req.write(Buffer.from(payload, 'utf8'));
        req.end();
    });
}

app.use(express.json({
    verify: (req, _res, buf) => {
        req.rawBody = buf;
    }
}));

app.get('/', (_req, res) => {
    res.json({ ok: true, message: '729 LINE webhook is running.', mode: 'ngrok-free', defaultClassId: DEFAULT_CLASS_ID });
});

app.post('/webhook', async (req, res) => {
    try {
        const body = req.body || {};
        const events = Array.isArray(body.events) ? body.events : [];

        if (LINE_SECRET) {
            const signature = req.headers['x-line-signature'];
            if (!signature) {
                return res.status(401).json({ ok: false, message: 'missing x-line-signature' });
            }
        }

        for (const event of events) {
            if (event.type !== 'message' || event.message?.type !== 'text') {
                continue;
            }

            const text = event.message.text || '';
            const userId = event.source?.userId || null;
            const replyText = await buildReply(text, DEFAULT_CLASS_ID, userId);

            console.log('[webhook] message:', text, 'userId:', userId);
            if (replyText) {
                await sendLineReply(userId, replyText);
            }
        }

        res.status(200).json({ ok: true });
    } catch (error) {
        console.error('[webhook] failed', error);
        res.status(500).json({ ok: false, message: 'internal error' });
    }
});

if (require.main === module) {
    app.listen(PORT, () => {
        console.log(`Webhook server running on http://localhost:${PORT}`);
        console.log(`Default classId: ${DEFAULT_CLASS_ID}`);
        console.log('Use ngrok: ngrok http 3000');
    });
}

module.exports = {
    app,
    buildReply,
    buildReplyTextForData,
    fetchClassData,
    resolveClassId,
};
