const express = require('express');
const fs = require('fs');
const path = require('path');
const https = require('https');
const admin = require('firebase-admin');

const app = express();
const PORT = process.env.PORT || 3000;
const HISTORY_EXPORT_DIR = path.join(__dirname, 'history_exports');

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
    '查看歷史',
    '歷史',
];

const KEYWORDS = [
    { key: ['查看聯絡簿', '聯絡簿', 'homework', '功課'], type: 'diary' },
    { key: ['查看課表', '課表', 'schedule'], type: 'schedule' },
    { key: ['查看分數', '分數', 'score', 'grades'], type: 'score' },
    { key: ['查看今日簽到時間', '今日簽到時間', '簽到時間', 'attendance'], type: 'attendance' },
    { key: ['查看被記', '被記', '記錄', 'late', '登記'], type: 'discipline' },
    { key: ['查看歷史', '歷史', 'history'], type: 'history' },
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

function escapeMarkdownCell(value) {
    return String(value ?? '').replace(/\|/g, '\\|').replace(/\r?\n/g, ' ');
}

function buildWeekScheduleTable(entries) {
    const weekdayNames = ['一', '二', '三', '四', '五', '六', '日'];
    const sortedEntries = asArray(entries)
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

    if (!sortedEntries.length) {
        return '目前沒有課表資料。';
    }

    const maxLesson = Math.max(...sortedEntries.map((entry) => entry.lesson + 1), 1);
    const rows = [];
    for (let lesson = 0; lesson < maxLesson; lesson += 1) {
        const row = ['第' + (lesson + 1) + '節'];
        for (let weekday = 0; weekday < 7; weekday += 1) {
            const cellEntries = sortedEntries.filter((entry) => entry.weekday === weekday && entry.lesson === lesson);
            const cellText = cellEntries.map((entry) => {
                const subject = entry.subject || '未排課';
                const teacher = entry.teacher ? `（${entry.teacher}）` : '';
                const time = entry.startTime && entry.endTime ? ` ${entry.startTime}-${entry.endTime}` : '';
                return `${subject}${teacher}${time}`;
            }).join('<br>');
            row.push(cellText || '—');
        }
        rows.push(row);
    }

    const headers = ['節次', '週一', '週二', '週三', '週四', '週五', '週六', '週日'];
    const columnWidths = headers.map((header, index) => {
        const maxCellLength = Math.max(header.length, ...rows.map((row) => escapeMarkdownCell(row[index]).length));
        return Math.max(6, maxCellLength + 2);
    });

    const formatRow = (values) => `| ${values.map((value, index) => escapeMarkdownCell(value).padEnd(columnWidths[index], ' ')).join(' | ')} |`;
    const separator = `| ${columnWidths.map((width) => '-'.repeat(Math.max(3, width))).join(' | ')} |`;

    return [formatRow(headers), separator, ...rows.map(formatRow)].join('\n');
}

function getPublicBaseUrl() {
    const configured = process.env.PUBLIC_BASE_URL || process.env.BASE_URL || process.env.LINE_PUBLIC_URL || `http://localhost:${PORT}`;
    return configured.replace(/\/$/, '');
}

function saveHistoryMarkdown(content, classId = DEFAULT_CLASS_ID) {
    fs.mkdirSync(HISTORY_EXPORT_DIR, { recursive: true });
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const safeClassId = normalizeText(classId || DEFAULT_CLASS_ID || '729').replace(/[^A-Za-z0-9_-]/g, '_') || '729';
    const fileName = `history_${safeClassId}_${timestamp}.md`;
    const fullPath = path.join(HISTORY_EXPORT_DIR, fileName);
    fs.writeFileSync(fullPath, content, 'utf8');
    return { fileName, fullPath, relativePath: path.relative(process.cwd(), fullPath) };
}

function buildHistoryReplyPayload(data, classId = DEFAULT_CLASS_ID, studentNumber = '') {
    const markdown = buildHistoryMarkdown(data, classId, studentNumber);
    const saved = saveHistoryMarkdown(markdown, classId);
    const publicBaseUrl = getPublicBaseUrl();
    const fileUrl = `${publicBaseUrl}/history/${encodeURIComponent(saved.fileName)}`;
    return {
        kind: 'history',
        text: '你可以點擊以下檔案來查看歷史',
        fileName: saved.fileName,
        fileUrl,
        filePath: saved.fullPath,
    };
}

function buildHistoryMarkdown(data, classId = DEFAULT_CLASS_ID, studentNumber = '') {
    const seatRecords = asArray(data?.seats)
        .filter((entry) => entry && typeof entry === 'object')
        .map((entry) => ({
            number: toPlainLine(entry.number).replace(/^0+(?=\d)/, ''),
            name: toPlainLine(entry.name),
            score: Number(entry.score ?? 0),
        }))
        .filter((entry) => entry.number || entry.name || entry.score !== 0);

    const targetStudentNumber = normalizeText(studentNumber).replace(/^0+(?=\d)/, '');
    const filteredSeats = targetStudentNumber
        ? seatRecords.filter((entry) => entry.number === targetStudentNumber)
        : seatRecords;
    const currentScoreSummary = filteredSeats.length
        ? filteredSeats.map((seat) => `${seat.name || seat.number || '學生'}：${seat.score} 分`).join('；')
        : '目前尚無分數資料';

    const diaryEntries = getDiaryEntries(data).map((entry) => `- ${normalizeDateKey(entry.date) || '日期未填'} | ${entry.tag || '一般'} | ${entry.content || '無內容'}`).join('\n');
    const scheduleEntries = asArray(data?.scheduleEntries)
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

    const attendanceEntries = asArray(data?.attendanceRecords ?? data?.attendanceToday)
        .filter((entry) => entry && typeof entry === 'object')
        .map((entry) => ({
            studentNumber: toPlainLine(entry.studentNumber).replace(/^0+(?=\d)/, ''),
            studentName: toPlainLine(entry.studentName),
            date: normalizeDateKey(entry.date) || toPlainLine(entry.date),
            time: toPlainLine(entry.time),
            late: !!entry.late,
        }))
        .filter((entry) => (!targetStudentNumber || entry.studentNumber === targetStudentNumber));
    const attendanceText = attendanceEntries.length
        ? attendanceEntries.map((entry) => `- ${entry.date || '日期未填'} | ${entry.studentName || entry.studentNumber || '學生'} | ${entry.time || '時間未填'}${entry.late ? '（遲到）' : '（準時）'}`).join('\n')
        : '- 無簽到紀錄';

    const registrationEntries = asArray(data?.studentRecords)
        .filter((entry) => entry && typeof entry === 'object')
        .map((entry) => ({
            studentNumber: toPlainLine(entry.studentNumber).replace(/^0+(?=\d)/, ''),
            studentName: toPlainLine(entry.studentName),
            date: normalizeDateKey(entry.date) || toPlainLine(entry.date),
            time: toPlainLine(entry.time),
            type: toPlainLine(entry.type),
            note: toPlainLine(entry.note),
        }))
        .filter((entry) => !targetStudentNumber || entry.studentNumber === targetStudentNumber)
        .sort((a, b) => (b.date || '').localeCompare(a.date || '') || (b.time || '').localeCompare(a.time || ''));
    const registrationText = registrationEntries.length
        ? registrationEntries.map((entry) => `- ${entry.date || '日期未填'} ${entry.time || ''} | ${entry.studentName || entry.studentNumber || '學生'} | ${entry.type || '紀錄'} | 原因：${entry.note || '無備註'}`).join('\n')
        : '- 無登記紀錄';

    const scoreEntries = registrationEntries.length
        ? registrationEntries.map((entry) => `- ${entry.date || '日期未填'} ${entry.time || ''} | ${entry.studentName || entry.studentNumber || '學生'} | ${entry.type || '紀錄'} | 原因：${entry.note || '無備註'}`).join('\n')
        : '- 無加減分紀錄';

    const historyMarkdown = [
        `# 【${normalizeText(classId) || DEFAULT_CLASS_ID}】歷史紀錄`,
        `> 產生時間：${new Date().toLocaleString('zh-TW')}`,
        '',
        '## 【聯絡簿】',
        diaryEntries || '- 無聯絡簿紀錄',
        '',
        '## 【課表】',
        buildWeekScheduleTable(scheduleEntries),
        '',
        '## 【分數】',
        `目前分數：${currentScoreSummary}`,
        scoreEntries,
        '',
        '## 【簽到】',
        attendanceText,
        '',
        '## 【登記】',
        registrationText,
        '',
    ].join('\n');

    return historyMarkdown;
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
            const preview = entries.slice(0, 3).map((entry) => {
                const time = entry.startTime && entry.endTime ? `${entry.startTime}-${entry.endTime}` : '時間未定';
                const teacher = entry.teacher ? ` (${entry.teacher})` : '';
                return `星期${DAY_NAMES[entry.weekday] || entry.weekday + 1}\n第${entry.lesson + 1}節 ${time}\n${entry.subject || '未命名'}${teacher}`;
            }).join('\n\n');
            return `今天沒有排課；目前可用課表：\n-------------------------\n${preview.replace(/\n\n/g, '\n-------------------------\n')}`;
        }

        const lessonText = todayLessons.map((entry) => {
            const time = entry.startTime && entry.endTime ? `${entry.startTime}-${entry.endTime}` : '時間未定';
            const teacher = entry.teacher ? ` (${entry.teacher})` : '';
            return `第${entry.lesson + 1}節 ${time}\n${entry.subject || '未命名'}${teacher}`;
        }).join('\n\n');
        return `今天的課表：\n-------------------------\n${lessonText.replace(/\n\n/g, '\n-------------------------\n')}`;
    }

    if (type === 'diary') {
        const todayKey = getTodayKey();
        const entries = getDiaryEntries(data);
        const todayEntries = entries.filter((entry) => normalizeDateKey(entry.date) === todayKey);

        if (!todayEntries.length) {
            return '今天沒有聯絡簿內容。';
        }

        return `今天的聯絡簿：\n-------------------------\n${todayEntries
            .map((entry, index) => `${index + 1}. ${entry.content || '無內容'}`)
            .join('\n')}`;
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
        const records = asArray(data?.attendanceRecords ?? data?.attendanceToday)
            .filter((entry) => entry && typeof entry === 'object')
            .map((entry) => ({
                studentName: toPlainLine(entry.studentName),
                studentNumber: toPlainLine(entry.studentNumber),
                date: toPlainLine(entry.date),
                time: toPlainLine(entry.time),
                late: !!entry.late,
            }))
            .filter((entry) => entry.date === todayKey)
            .filter((entry) => !studentNumber || entry.studentNumber === studentNumber)
            .slice(0, 5);

        if (!records.length) {
            return studentNumber ? '你今天還沒有簽到紀錄。' : '今天還沒有簽到紀錄。';
        }

        if (studentNumber) {
            return `你今天到教室的時間：${records[0].time}`;
        }
        return `今日簽到：\n${records.map((entry) => `${entry.studentName || entry.studentNumber || '學生'} ${entry.time}${entry.late ? '（遲到）' : ''}`).join('\n')}`;
    }

    if (type === 'discipline') {
        const todayKey = getTodayKey();
        const allRecords = asArray(data?.studentRecords)
            .filter((entry) => entry && typeof entry === 'object')
            .map((entry) => ({
                studentNumber: toPlainLine(entry.studentNumber),
                date: toPlainLine(entry.date),
                time: toPlainLine(entry.time),
                type: toPlainLine(entry.type),
                note: toPlainLine(entry.note),
            }));
        const records = (studentNumber
            ? allRecords.filter((entry) => entry.studentNumber === studentNumber && entry.date === todayKey)
            : allRecords.filter((entry) => entry.date === todayKey)).slice(0, 10);

        if (!records.length) {
            return '你今天沒有被登記！';
        }

        return `今天的被記紀錄：\n${records.map((entry, index) => `${index + 1}. ${entry.time || '時間未記錄'}：${entry.type || '紀錄'}${entry.note ? ` / ${entry.note}` : ''}`).join('\n')}`;
    }

    if (type === 'history') {
        return buildHistoryReplyPayload(data, classId, studentNumber).text;
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
            return null;
        }
    }

    return admin.firestore();
}

async function getLineUserProfile(userId) {
    if (!userId) return null;

    const db = initFirebase();
    if (!db) return null;

    const snapshot = await db.collection(LINE_USER_COLLECTION).doc(userId).get();
    return snapshot.exists ? snapshot.data() || {} : null;
}

async function saveLineUserProfile(userId, data) {
    if (!userId) {
        throw new Error('LINE 使用者識別失敗，無法儲存座號。');
    }

    const db = initFirebase();
    if (!db) return;

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

    const db = initFirebase();
    if (!db) {
        return null;
    }

    try {
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
                // Public fields contain the latest shared seat/score snapshot.
                // Keep private-only records, but let the shared snapshot win.
                merged = { ...privateData, ...publicData };
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

async function addDisciplineRecord(classId, studentNumber, type, note) {
    const db = initFirebase();
    if (!db) return null;

    const id = normalizeClassId(classId || DEFAULT_CLASS_ID || '729');
    const stateRef = db.collection('classes').doc(id).collection('private').doc('state');
    const snapshot = await stateRef.get();
    const state = snapshot.exists ? snapshot.data() || {} : {};
    const seats = asArray(state.seats).map((entry) => ({ ...entry }));
    const normalizedNumber = normalizeText(studentNumber).replace(/^0+(?=\d)/, '');
    const seat = seats.find((entry) => toPlainLine(entry.number).replace(/^0+(?=\d)/, '') === normalizedNumber);
    if (!seat) return null;

    const now = new Date();
    const studentRecords = asArray(state.studentRecords).map((entry) => ({ ...entry }));
    studentRecords.unshift({
        id: `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
        studentNumber: toPlainLine(seat.number),
        studentName: toPlainLine(seat.name),
        date: getTodayKey(now),
        time: now.toTimeString().slice(0, 8),
        type,
        note: toPlainLine(note) || `LINE ${type}`,
    });
    if (type === '秩序不佳' || type === '晚進教室') {
        seat.score = Number(seat.score ?? 0) - 1;
    }

    await stateRef.set({
        seats,
        studentRecords,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    await db.collection('classes').doc(id).set({
        seats,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    return { name: toPlainLine(seat.name), number: toPlainLine(seat.number), score: seat.score };
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

        const awaitingType = profile.awaitingStudentNumberType || '';
        await saveLineUserProfile(userId, {
            studentNumber: text,
            awaitingStudentNumber: false,
            awaitingStudentNumberType: null,
        });
        if (awaitingType) {
            const data = await fetchClassData(DEFAULT_CLASS_ID);
            if (!data || data.__firebaseError) return data?.__errorMessage || 'Firebase 讀取失敗';
            return buildReplyTextForData(awaitingType, data, DEFAULT_CLASS_ID, text);
        }
        return `已記住你的座號 ${text}。`;
    }

    const numberMatch = text.match(/(?:座號|學號)?\s*(\d{1,3})\s*(?:號)?/);
    const isQuery = /^(查看|查詢)/i.test(text);
    const recordType = text.includes('整潔')
        ? '整潔'
        : text.includes('晚進教室')
            ? '晚進教室'
            : (text.includes('秩序不佳') || text.includes('被記') ? '秩序不佳' : '');
    const cleanlinessRating = text.match(/優秀|待改進/)?.[0] || '';
    if (!isQuery && numberMatch && recordType) {
        const classId = resolveClassId(text, fallbackClassId);
        const note = cleanlinessRating || text
            .replace(numberMatch[0], '')
            .replace(/^(新增?被記|被記|記錄|秩序不佳|晚進教室|整潔)/i, '')
            .trim();
        const result = await addDisciplineRecord(classId, numberMatch[1], recordType, note);
        if (!result) return `找不到 ${numberMatch[1]} 號學生。`;
        return `已記 ${recordType}：${result.number} ${result.name || '同學'}，目前 ${result.score} 分。`;
    }

    const normalized = text.toLowerCase();
    for (const item of KEYWORDS) {
        const matched = item.key.some((keyword) => normalized.includes(keyword.toLowerCase()));
        if (matched) {
            if (item.reply) {
                return item.reply;
            }

            if (item.type === 'history') {
                const classId = resolveClassId(text, fallbackClassId);
                const data = await fetchClassData(classId);
                const fallbackData = {
                    diaryEntries: [],
                    scheduleEntries: [],
                    seats: [],
                    attendanceRecords: [],
                    studentRecords: [],
                };
                return buildHistoryReplyPayload(data || fallbackData, classId, profile?.studentNumber || '');
            }

            let studentNumber = '';
            if (item.type === 'score' || item.type === 'discipline' || item.type === 'attendance') {
                studentNumber = toPlainLine(profile?.studentNumber);

                if (!studentNumber) {
                    const numberMatch = text.match(/(?:座號|學號)?\s*(\d{1,3})\s*(?:號)?/);
                    if (numberMatch && isValidStudentNumber(numberMatch[1])) {
                        studentNumber = numberMatch[1];
                        if (userId) {
                            await saveLineUserProfile(userId, {
                                studentNumber,
                                awaitingStudentNumber: false,
                                awaitingStudentNumberType: null,
                            });
                        }
                    }
                }

                if ((item.type === 'attendance' || item.type === 'discipline') && !studentNumber) {
                    if (userId) {
                        await saveLineUserProfile(userId, {
                            awaitingStudentNumber: true,
                            awaitingStudentNumberType: item.type,
                        });
                    }
                    return '請問你是幾號？例如30號填寫30';
                }

            }

            const classId = resolveClassId(text, fallbackClassId);
            const data = await fetchClassData(classId);
            if (!data || data.__firebaseError) {
                if (item.type === 'history') {
                    return buildReplyTextForData('history', {
                        diaryEntries: [],
                        scheduleEntries: [],
                        seats: [],
                        attendanceRecords: [],
                        studentRecords: [],
                    }, classId, studentNumber);
                }
                const reason = data && data.__errorMessage ? data.__errorMessage : 'Firebase 讀取失敗';
                return reason;
            }
            return buildReplyTextForData(item.type, data, classId, studentNumber);
        }
    }

    return null;
}

function sendLineReply(userId, replyPayload) {
    if (!LINE_ACCESS_TOKEN || !userId) {
        console.log('[LINE] fake reply ->', { userId, replyPayload });
        return Promise.resolve();
    }

    let messages = [{ type: 'text', text: String(replyPayload || '') }];

    if (replyPayload && typeof replyPayload === 'object' && replyPayload.kind === 'history') {
        messages = [
            { type: 'text', text: replyPayload.text || '你可以點擊以下檔案來查看歷史' },
            {
                type: 'file',
                fileName: replyPayload.fileName || 'history.md',
                fileUrl: replyPayload.fileUrl || `http://localhost:${PORT}/history/${encodeURIComponent(replyPayload.fileName || 'history.md')}`,
            },
        ];
    }

    const payload = JSON.stringify({
        to: userId,
        messages,
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

app.get('/history/:fileName', (req, res) => {
    const fileName = path.basename(req.params.fileName || '');
    if (!fileName) {
        return res.status(400).send('缺少檔名');
    }

    const filePath = path.join(HISTORY_EXPORT_DIR, fileName);
    if (!fs.existsSync(filePath)) {
        return res.status(404).send('找不到歷史檔案');
    }

    return res.download(filePath, fileName);
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
            const replyPayload = await buildReply(text, DEFAULT_CLASS_ID, userId);

            console.log('[webhook] message:', text, 'userId:', userId);
            if (replyPayload) {
                await sendLineReply(userId, replyPayload);
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
    buildHistoryMarkdown,
    fetchClassData,
    addDisciplineRecord,
    resolveClassId,
};
