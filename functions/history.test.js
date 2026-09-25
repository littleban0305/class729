const test = require('node:test');
const assert = require('node:assert/strict');
const { buildReply, buildHistoryMarkdown } = require('./server');

test('歷史關鍵字應回傳含有五個區段的歷史紀錄', async () => {
    const data = {
        diaryEntries: [
            { date: '2026-09-10', tag: '一般', content: '請準時交作業' },
        ],
        scheduleEntries: [
            { weekday: 0, lesson: 0, subject: '國文', teacher: '王老師', startTime: '08:00', endTime: '08:40' },
            { weekday: 1, lesson: 1, subject: '數學', teacher: '李老師', startTime: '09:00', endTime: '09:40' },
        ],
        seats: [
            { number: '30', name: '小明', score: 24 },
            { number: '31', name: '小華', score: 18 },
        ],
        attendanceRecords: [
            { studentNumber: '30', studentName: '小明', date: '2026-09-10', time: '07:42:15', late: false },
        ],
        studentRecords: [
            { studentNumber: '30', studentName: '小明', date: '2026-09-10', time: '07:50:00', type: '加分', note: '整理桌面' },
            { studentNumber: '30', studentName: '小明', date: '2026-09-11', time: '08:00:00', type: '扣分', note: '講話' },
        ],
    };

    const markdown = buildHistoryMarkdown(data, '729', '30');
    assert.match(markdown, /【聯絡簿】/);
    assert.match(markdown, /【課表】/);
    assert.match(markdown, /【分數】/);
    assert.match(markdown, /【簽到】/);
    assert.match(markdown, /【登記】/);
    assert.match(markdown, /目前分數/);

    const reply = await buildReply('歷史', '729', 'user-1');
    assert.ok(reply && reply.includes('【聯絡簿】'));
});
