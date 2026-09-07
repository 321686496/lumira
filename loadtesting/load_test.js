import http from 'k6/http';
import { check, group, sleep } from 'k6';
import { Trend } from 'k6/metrics';

const BASE_URL = __ENV.BASE_URL || 'https://lumira.iwtle.top';
const ADMIN_TOKEN = __ENV.ADMIN_TOKEN || '';
const SMOKE = __ENV.SMOKE === '1';

const clientAllTrend = new Trend('client_all_duration');
const adminAllTrend = new Trend('admin_all_duration');

const clientStages = SMOKE
  ? [{ duration: '25s', target: 2 }]
  : [
      { duration: '1m', target: 15 },
      { duration: '1m', target: 30 },
      { duration: '1m', target: 30 },
      { duration: '30s', target: 0 },
    ];

const adminStages = SMOKE
  ? [{ duration: '25s', target: 1 }]
  : [
      { duration: '1m', target: 8 },
      { duration: '1m', target: 20 },
      { duration: '1m', target: 20 },
      { duration: '30s', target: 0 },
    ];

export const options = {
  scenarios: {
    client: {
      exec: 'clientFlow',
      executor: 'ramping-vus',
      startVUs: SMOKE ? 1 : 3,
      stages: clientStages,
      gracefulRampDown: '30s',
    },
    admin: {
      exec: 'adminFlow',
      executor: 'ramping-vus',
      startVUs: SMOKE ? 1 : 2,
      stages: adminStages,
      gracefulRampDown: '30s',
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.05'],
    http_req_duration: ['p(95)<2000'],
  },
};

function registerDevice(deviceId) {
  const res = http.post(
    `${BASE_URL}/api/v1/device/register`,
    JSON.stringify({
      deviceId,
      alias: 'k6-load-test',
      platform: 'android',
      osVersion: '14',
      deviceModel: 'k6-virtual-device',
      appVersion: '1.0.0',
    }),
    {
      headers: { 'Content-Type': 'application/json' },
      tags: { name: 'device/register' },
      timeout: '10s',
    },
  );
  if (res.status === 200 || res.status === 201) {
    const body = res.json();
    return body.token || '';
  }
  return '';
}

export function setup() {
  const tokens = [];
  for (let i = 0; i < 80; i++) {
    const token = registerDevice(`k6load_${String(i).padStart(4, '0')}`);
    if (token) tokens.push(token);
  }

  let templateId = '';
  let categoryKey = '';
  if (tokens.length > 0) {
    const authHeaders = { Authorization: `Bearer ${tokens[0]}` };

    let listRes;
    try {
      listRes = http.get(`${BASE_URL}/api/v1/templates/list?since=0`, {
        headers: authHeaders,
        tags: { name: 'templates/list (setup)' },
        timeout: '10s',
      });
    } catch (e) {
      listRes = null;
    }
    if (listRes) {
      const body = listRes.json();
      const templates = Array.isArray(body) ? body : body.templates || body.items || [];
      if (templates.length > 0) {
        templateId = String(templates[0].id ?? templates[0].templateId ?? '');
      }
    }

    let catRes;
    try {
      catRes = http.get(`${BASE_URL}/api/v1/templates/categories`, {
        headers: authHeaders,
        tags: { name: 'templates/categories (setup)' },
        timeout: '10s',
      });
    } catch (e) {
      catRes = null;
    }
    if (catRes) {
      const body = catRes.json();
      const categories = Array.isArray(body) ? body : body.categories || body.items || body.list || [];
      if (categories.length > 0) {
        categoryKey = String(categories[0].key ?? categories[0].id ?? categories[0].name ?? '');
      }
    }
  }

  return { tokens, templateId, categoryKey };
}

function clientGet(url, token, name) {
  const res = http.get(url, {
    headers: { Authorization: `Bearer ${token}` },
    tags: { name },
  });
  check(res, {
    [`${name} 状态2xx`]: (r) => r.status >= 200 && r.status < 300,
  });
  return res;
}

function adminGet(url, name) {
  const res = http.get(url, {
    headers: { Authorization: `Bearer ${ADMIN_TOKEN}` },
    tags: { name },
  });
  check(res, {
    [`${name} 状态2xx`]: (r) => r.status >= 200 && r.status < 300,
  });
  return res;
}

export function clientFlow(data) {
  if (!data.tokens || data.tokens.length === 0) return;
  const agent = data.tokens.length > 1
    ? data.tokens[__VU % data.tokens.length]
    : data.tokens[0];

  const start = Date.now();

  group('公开端点', () => {
    const res = http.get(`${BASE_URL}/api/v1/health`, { tags: { name: 'health' } });
    check(res, { 'health 状态2xx': (r) => r.status >= 200 && r.status < 300 });

    if (data.categoryKey) {
      const thumbs = http.get(
        `${BASE_URL}/api/v1/thumbs/categories/${encodeURIComponent(data.categoryKey)}?w=300`,
        { tags: { name: 'thumbs/categories/:key' } },
      );
      check(thumbs, {
        'thumbs 状态2xx/304': (r) => r.status === 200 || r.status === 304,
      });
    }

    const weather = clientGet(
      `${BASE_URL}/api/v1/weather?lat=31.2304&lon=121.4737`,
      agent,
      'weather',
    );
  });

  group('模板链路', () => {
    clientGet(`${BASE_URL}/api/v1/templates/list?since=0`, agent, 'templates/list');
    clientGet(
      `${BASE_URL}/api/v1/templates/search?q=&sort=comprehensive&page=1&pageSize=20`,
      agent,
      'templates/search',
    );
    clientGet(`${BASE_URL}/api/v1/templates/owned`, agent, 'templates/owned');
    clientGet(`${BASE_URL}/api/v1/templates/prices`, agent, 'templates/prices');
    if (data.templateId) {
      clientGet(`${BASE_URL}/api/v1/templates/${data.templateId}`, agent, 'templates/:id');
    }
  });

  group('分类与场景', () => {
    clientGet(`${BASE_URL}/api/v1/templates/categories/tree`, agent, 'templates/categories/tree');
    clientGet(`${BASE_URL}/api/v1/templates/categories`, agent, 'templates/categories');
    clientGet(`${BASE_URL}/api/v1/scenes`, agent, 'scenes');
    clientGet(`${BASE_URL}/api/v1/usage/stats?itemType=template`, agent, 'usage/stats');
  });

  group('个人与积分', () => {
    clientGet(`${BASE_URL}/api/v1/profile`, agent, 'profile');
    clientGet(`${BASE_URL}/api/v1/points/balance`, agent, 'points/balance');
    clientGet(`${BASE_URL}/api/v1/points/transactions?limit=20`, agent, 'points/transactions');
    clientGet(`${BASE_URL}/api/v1/sign-in/status`, agent, 'sign-in/status');
    clientGet(`${BASE_URL}/api/v1/rewards`, agent, 'rewards');
  });

  group('通知与邀请', () => {
    clientGet(`${BASE_URL}/api/v1/notifications`, agent, 'notifications');
    clientGet(`${BASE_URL}/api/v1/invite/stats`, agent, 'invite/stats');
    clientGet(`${BASE_URL}/api/v1/account/status`, agent, 'account/status');
  });

  clientAllTrend.add(Date.now() - start);
  sleep(0.15 + Math.random() * 0.5);
}

export function adminFlow(data) {
  if (!ADMIN_TOKEN) return;
  const start = Date.now();

  group('Admin 总览', () => {
    adminGet(`${BASE_URL}/api/v1/admin/stats`, 'admin/stats');
    adminGet(`${BASE_URL}/api/v1/admin/devices?page=1&pageSize=20`, 'admin/devices');
    adminGet(`${BASE_URL}/api/v1/admin/invites?page=1&pageSize=20`, 'admin/invites');
    adminGet(`${BASE_URL}/api/v1/admin/rewards?page=1&pageSize=20`, 'admin/rewards');
  });

  group('Admin 内容管理', () => {
    adminGet(`${BASE_URL}/api/v1/admin/templates?page=1&pageSize=20`, 'admin/templates');
    adminGet(`${BASE_URL}/api/v1/admin/categories?level=1`, 'admin/categories');
    adminGet(`${BASE_URL}/api/v1/admin/scenes`, 'admin/scenes');
    if (data.templateId) {
      adminGet(`${BASE_URL}/api/v1/admin/templates/${data.templateId}`, 'admin/templates/:id');
    }
  });

  group('Admin 运营数据', () => {
    adminGet(`${BASE_URL}/api/v1/admin/usage/stats?itemType=template`, 'admin/usage/stats');
    adminGet(`${BASE_URL}/api/v1/admin/usage/builtin-templates`, 'admin/usage/builtin-templates');
    adminGet(`${BASE_URL}/api/v1/admin/usage/builtin-scenes`, 'admin/usage/builtin-scenes');
    adminGet(`${BASE_URL}/api/v1/admin/feedbacks?page=1&pageSize=20`, 'admin/feedbacks');
    adminGet(`${BASE_URL}/api/v1/admin/notifications`, 'admin/notifications');
    adminGet(`${BASE_URL}/api/v1/admin/redeem-batches`, 'admin/redeem-batches');
    adminGet(`${BASE_URL}/api/v1/admin/redeem-batches/templates`, 'admin/redeem-batches/templates');
    adminGet(`${BASE_URL}/api/v1/admin/questionnaire?page=1&pageSize=20`, 'admin/questionnaire');
    adminGet(`${BASE_URL}/api/v1/admin/questionnaire/stats`, 'admin/questionnaire/stats');
  });

  adminAllTrend.add(Date.now() - start);
  sleep(0.2 + Math.random() * 0.6);
}