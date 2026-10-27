'use strict';

const http = require('http');

const PORT = process.env.PORT ? Number(process.env.PORT) : 4523;

const PROMPTS = {
  week: [
    { id: 'pw_1', text: '这一周哪件事最消耗你？', category: 'energy' },
    { id: 'pw_2', text: '哪次判断事后被证明是对的？', category: 'judgement' },
    { id: 'pw_3', text: '如果重来一次，你会先确认什么？', category: 'action' }
  ],
  month: [
    { id: 'pm_1', text: '这个月反复出现的模式是什么？', category: 'pattern' },
    { id: 'pm_2', text: '哪条价值锚点被引用得最多？', category: 'anchor' },
    { id: 'pm_3', text: '下个月准备停止做什么？', category: 'action' }
  ]
};

function sendJson(response, status, payload) {
  const body = JSON.stringify(payload);
  response.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store'
  });
  response.end(body);
}

const server = http.createServer((request, response) => {
  const url = new URL(request.url, `http://localhost:${PORT}`);

  if (url.pathname === '/health') {
    sendJson(response, 200, { status: 'ok' });
    return;
  }

  if (url.pathname === '/review-prompts') {
    const period = url.searchParams.get('period') === 'month' ? 'month' : 'week';
    sendJson(response, 200, { prompts: PROMPTS[period] });
    return;
  }

  sendJson(response, 404, { error: 'not found' });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`mock server listening on http://127.0.0.1:${PORT}`);
});
