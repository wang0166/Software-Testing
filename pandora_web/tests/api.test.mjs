import { test, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import { build } from 'esbuild';
import { resolve } from 'node:path';

// 将浏览器模块打包为独立测试入口，不依赖新增测试框架。
const outfile = resolve('dist/tests/api-bundle.mjs');
await build({ stdin: { contents: "export * from './src/api/client'; export * from './src/api/http'; export * from './src/api/capabilities'; export * from './src/utils/matterTime';", resolveDir: process.cwd() },
  bundle: true, platform: 'node', format: 'esm', outfile, define: { 'import.meta.env': '{"VITE_API_BASE":"/api","VITE_USE_MOCK":"false"}' } });
const { api, request, requestPage, setTokens, getToken, setMockMode, supports, BACKEND_CAPABILITIES, mockTeams, mockUsers, formatMatterTime, splitMatterTime } = await import(new URL('../dist/tests/api-bundle.mjs', import.meta.url));
const memory = new Map();
globalThis.localStorage = { getItem: key => memory.get(key) ?? null, setItem: (key, value) => memory.set(key, String(value)), removeItem: key => memory.delete(key) };
globalThis.window = new EventTarget();
const response = (data, status = 200, code = 0) => new Response(JSON.stringify({ code, message: code ? '测试错误' : 'ok', data }), { status });
beforeEach(() => { memory.clear(); Object.assign(BACKEND_CAPABILITIES, { users: true, organization: true, audits: true, matterWrite: true }); globalThis.fetch = async () => { throw new Error('测试不允许真实联网'); }; });

test('默认启用已交付接口，显式关闭能力后不会发请求或转入演示', async () => {
  let calls = 0;
  globalThis.fetch = async () => { calls++; return response({}); };
  assert.equal(supports('users'), true);
  BACKEND_CAPABILITIES.users = false; BACKEND_CAPABILITIES.matterWrite = false;
  await assert.rejects(api.listUsers(), /尚未提供/);
  await assert.rejects(api.createMatter({ title: '事项', content: '备注', sortOrder: 1 }), /尚未提供/);
  assert.equal(calls, 0);
});

test('认证使用真实角色和权限，公开登录请求不携带旧令牌', async () => {
  setTokens('old');
  globalThis.fetch = async (_url, init) => {
    assert.equal(init.headers.Authorization, undefined);
    return response({ accessToken: 'test-access', refreshToken: 'test-refresh', user: { username: 'admin', role: 'ADMIN', permissions: ['content:read'] } });
  };
  await api.login('admin', 'test-only');
  assert.equal(getToken(), 'test-access');
  assert.deepEqual(api.permissions(), ['content:read']);
});

test('空部门仍从公司接口获取真实公司 ID，不假定公司编号为 1', async () => {
  const urls = [];
  globalThis.fetch = async url => {
    urls.push(url);
    return response(url === '/api/companies' ? [{ id: 41, name: '测试公司' }] : []);
  };
  assert.deepEqual(await api.listCompanies(), [{ id: '41', name: '测试公司' }]);
  assert.deepEqual(await api.listDepartments(), []);
  assert.deepEqual(urls, ['/api/companies', '/api/departments']);
});

test('拒绝非管理员登录且不残留身份', async () => {
  globalThis.fetch = async () => response({ accessToken: 'test', user: { username: 'employee', role: 'EMPLOYEE' } });
  await assert.rejects(api.login('employee', 'test-only'), /仅允许管理员/);
  assert.equal(getToken(), '');
});

test('事项分页保留 total、page、size，数字 ID 转为稳定字符串', async () => {
  let path;
  globalThis.fetch = async url => { path = url; return response({ items: [{ id: 42, title: '事项', content: '内容', sortOrder: 2 }], total: 31, page: 2, size: 10 }); };
  const data = await api.listMatters(2, 10);
  assert.equal(path, '/api/company-matters?page=2&size=10');
  assert.equal(data.items[0].id, '42'); assert.equal(data.total, 31); assert.equal(data.page, 2);
  assert.equal(data.items[0].startDate, undefined); assert.equal(data.items[0].deadline, undefined);
});

test('空分页是成功结果，响应缺字段或 HTML 不冒充空数据', async () => {
  globalThis.fetch = async () => response({ items: [], page: 1, size: 10, total: 0 });
  assert.deepEqual((await requestPage('/test')).items, []);
  globalThis.fetch = async () => response({ items: [] });
  await assert.rejects(requestPage('/test'), /分页响应/);
  globalThis.fetch = async () => new Response('<html>wrong server</html>');
  await assert.rejects(request('/test'), /响应格式/);
});

test('403 不清登录，500、网络和业务失败不返回模拟成功', async () => {
  setTokens('test');
  globalThis.fetch = async () => response(null, 403, 40301);
  await assert.rejects(request('/test'), error => error.httpStatus === 403);
  assert.equal(getToken(), 'test');
  globalThis.fetch = async () => response(null, 500, 50000);
  await assert.rejects(request('/test'));
  globalThis.fetch = async () => response(null, 200, 40001);
  await assert.rejects(request('/test'));
  globalThis.fetch = async () => { throw new Error('network'); };
  await assert.rejects(request('/test'), /网络异常/);
});

test('过期响应清理令牌、用户与权限，并通知页面重新登录', async () => {
  setTokens('test', 'test-refresh'); memory.set('pandora-role', 'ADMIN'); memory.set('pandora-permissions', '["user:manage"]');
  let expired = false;
  window.addEventListener('pandora-session-expired', () => { expired = true; }, { once: true });
  globalThis.fetch = async () => response(null, 401, 40102);
  await assert.rejects(request('/auth/me'));
  assert.equal(expired, true); assert.equal(getToken(), ''); assert.deepEqual(api.permissions(), []); assert.equal(api.currentRole(), '');
});

test('切换模式清理身份；演示事项新增编辑和组织新增能够重新查询', async () => {
  setTokens('test'); setMockMode(true); assert.equal(getToken(), '');
  const dates = { startDate: '2026-10-29T09:00:00+08:00', deadline: '2026-11-05T18:00:00+08:00' };
  const created = await api.createMatter({ title: '测试事项', content: '原备注', sortOrder: 50, ...dates });
  await api.updateMatter(String(created.id), { title: '测试事项', content: '新备注', sortOrder: 50, ...dates });
  const matter = (await api.listMatters(1, 100)).items.find(x => x.id === String(created.id));
  assert.equal(matter.content, '新备注'); assert.equal(matter.startDate, dates.startDate); assert.equal(matter.deadline, dates.deadline);
  const unit = await api.createDepartment('测试部门', 1, '介绍');
  assert.ok((await api.listDepartments()).some(x => x.id === String(unit.id)));
  await api.deleteUnit('departments', String(unit.id));
  assert.ok(!(await api.listDepartments()).some(x => x.id === String(unit.id)));
});

test('创建请求同时携带手机号、手动账户名和原样初始密码，不额外发送表单状态', async () => {
  // 仅对内存中的测试模块临时开放，生产能力开关不变；测试不访问真实后端。
  BACKEND_CAPABILITIES.users = true;
  const initialPassword = 'Test-only!Pass42#';
  let called = false;
  globalThis.fetch = async (url, init) => {
    called = true;
    assert.equal(url, '/api/users'); assert.equal(init.method, 'POST');
    assert.deepEqual(JSON.parse(init.body), {
      username: 'custom_account', password: initialPassword, realName: '测试用户', role: 'EMPLOYEE',
      phone: '13000000000', departmentId: 2, teamId: 3, idNumber: '', gender: '女',
    });
    return response({ id: 123 });
  };
  try {
    assert.deepEqual(await api.createUser({ username: ' custom_account ', password: initialPassword,
      realName: ' 测试用户 ', role: '组员', phone: ' 13000000000 ', departmentId: 2, teamId: 3,
      idNumber: '', gender: '女', usernameEdited: true }), { id: 123 });
    assert.ok(called);
    assert.ok(!JSON.stringify([...memory]).includes(initialPassword));
  } finally { BACKEND_CAPABILITIES.users = false; }
});

test('用户详情与列表保留扩展资料，同时丢弃响应中的凭据字段', async () => {
  BACKEND_CAPABILITIES.users = true;
  const raw = { id: 123, username: 'custom_account', realName: '测试用户', role: 'EMPLOYEE', status: 'ACTIVE',
    departmentId: 2, teamId: 3, phone: '13000000000', gender: '女', idNumber: '', passwordHash: 'must-not-escape' };
  globalThis.fetch = async url => response(url.includes('?') ? { items: [raw], page: 1, size: 20, total: 1 } : raw);
  try {
    const detail = await api.getUser('123');
    const row = (await api.listUsers()).items[0];
    for (const item of [detail, row]) {
      assert.equal(item.id, '123'); assert.equal(item.phone, raw.phone); assert.equal(item.gender, raw.gender);
      assert.equal(item.idNumber, raw.idNumber); assert.equal(item.username, 'custom_account');
      assert.equal(item.status, '启用'); assert.equal('passwordHash' in item, false); assert.equal('password' in item, false);
      assert.equal(item.departmentId, '2'); assert.equal(item.teamId, '3');
    }
  } finally { BACKEND_CAPABILITIES.users = false; }
});

test('团队查询传稳定 ID、搜索与分页，真实模式不混入本地演示成员', async () => {
  BACKEND_CAPABILITIES.users = true;
  memory.set('pandora-web-users-local', JSON.stringify([{ id: 'local-only', name: '不应出现', teamId: '3' }]));
  globalThis.fetch = async url => {
    const query = new URL(url, 'http://test').searchParams;
    assert.equal(query.get('teamId'), '3'); assert.equal(query.get('keyword'), '测试');
    assert.equal(query.get('page'), '2'); assert.equal(query.get('size'), '5');
    return response({ items: [{ id: 123, username: 'test_member', realName: '测试成员', role: 'EMPLOYEE', status: 'ACTIVE', departmentId: 2, teamId: 3 }], page: 2, size: 5, total: 6 });
  };
  try {
    const data = await api.listTeamMembers('3', { keyword: '测试', page: 2, size: 5 });
    assert.equal(data.total, 6); assert.equal(data.page, 2); assert.equal(data.items.length, 1);
    assert.equal(data.items[0].id, '123'); assert.equal(data.items[0].teamId, '3');
    globalThis.fetch = async () => response({ items: [{ id: 1, username: 'other', realName: '其他团队', role: 'EMPLOYEE', status: 'ACTIVE', teamId: 4 }], page: 1, size: 5, total: 1 });
    await assert.rejects(api.listTeamMembers('3'), /团队归属/);
    globalThis.fetch = async () => response(null, 500, 50000);
    await assert.rejects(api.listTeamMembers('3'));
  } finally { BACKEND_CAPABILITIES.users = false; }
});

test('演示团队成员包含负责人，合并新增、转组、停用与移除记录，并按 ID 隔离同名团队', async () => {
  setMockMode(true);
  const teamCount = mockTeams.length, userCount = mockUsers.length;
  mockTeams.push({ id: 'same-name-team', name: '如来佛组', parentId: '3' });
  mockUsers.push({ id: 'other-team-member', username: 'other_member', name: '其他团队成员', dept: '技术部', team: '如来佛组', role: '组员', status: '启用', departmentId: '3', teamId: 'same-name-team' });
  memory.set('pandora-web-users-local', JSON.stringify([
    { id: 'local-new', username: 'new_member', name: '新增成员', dept: '产品部', team: '如来佛组', role: '组员', status: '启用', departmentId: '2', teamId: '1' },
    { id: 'local-no-team', username: 'changed_role', name: '改任负责人', dept: '产品部', team: '如来佛组', role: '组员', status: '启用', departmentId: '2', teamId: '1' },
  ]));
  memory.set('pandora-web-users-removed', '["u-07"]');
  memory.set('pandora-web-users-status', '{"u-10":"停用"}');
  memory.set('pandora-web-users-edits', JSON.stringify({
    'u-04': { dept: '产品部', team: '观音组', departmentId: '2', teamId: '2' },
    'local-no-team': { dept: '-', team: '-', role: '管理员', departmentId: null, teamId: null },
  }));
  try {
    const one = await api.listTeamMembers('1', { size: 100 });
    assert.ok(one.items.some(user => user.id === 'local-new'));
    for (const id of ['u-07', 'u-04', 'other-team-member', 'local-no-team']) assert.ok(!one.items.some(user => user.id === id));
    const two = await api.listTeamMembers('2', { size: 100 });
    assert.ok(two.items.some(user => user.id === 'u-04' && user.role === '组长'));
    assert.ok(two.items.some(user => user.id === 'u-10' && user.status === '停用'));
    const filtered = await api.listTeamMembers('1', { keyword: 'new_member' });
    assert.equal(filtered.total, 1); assert.equal(filtered.items[0].name, '新增成员');
    const first = await api.listTeamMembers('2', { page: 1, size: 2 });
    const next = await api.listTeamMembers('2', { page: 2, size: 2 });
    assert.equal(first.total, two.total); assert.equal(first.items.length, 2);
    assert.ok(next.items.every(user => !first.items.some(other => other.id === user.id)));
    assert.equal((await api.listTeamMembers('1', { keyword: '不存在的成员' })).total, 0);
  } finally { mockTeams.splice(teamCount); mockUsers.splice(userCount); }
});

test('事项只接受上海时区整点；拒绝缺失小时、非法日期、非零分钟和同日倒序', async () => {
  BACKEND_CAPABILITIES.matterWrite = true;
  let calls = 0;
  const input = { title: ' 时间测试 ', content: ' 备注 ', sortOrder: 1, startDate: '2026-10-29T09:00:00+08:00', deadline: '2026-10-29T09:00:00+08:00' };
  globalThis.fetch = async (url, init) => {
    calls++;
    assert.equal(url, '/api/company-matters'); assert.equal(init.method, 'POST');
    assert.deepEqual(JSON.parse(init.body), { ...input, title: '时间测试', content: '备注' });
    return response({ id: 50 });
  };
  try {
    for (const startDate of ['', '2026-10-29', '2026-02-30T09:00:00+08:00', '2026-10-29T24:00:00+08:00', '2026-10-29T09:30:00+08:00', '2026-10-29T09:00:01+08:00', '2026-10-29T09:00:00Z']) {
      await assert.rejects(api.createMatter({ ...input, startDate }), /有效的开始时间/);
    }
    await assert.rejects(api.updateMatter('50', { ...input, deadline: '2026-10-29T08:00:00+08:00' }), /不得早于/);
    await assert.rejects(api.updateMatter('50', { ...input, deadline: '2026-10-28T23:00:00+08:00' }), /不得早于/);
    assert.equal(calls, 0);
    assert.deepEqual(await api.createMatter({ ...input, internalState: true }), { id: 50 });
    assert.equal(calls, 1);
    globalThis.fetch = async (url, init) => {
      assert.equal(url, '/api/company-matters/50'); assert.equal(init.method, 'PUT');
      assert.equal(JSON.parse(init.body).deadline, '2026-10-30T00:00:00+08:00');
      return response({});
    };
    await api.updateMatter('50', { ...input, deadline: '2026-10-30T00:00:00+08:00' });
  } finally { BACKEND_CAPABILITIES.matterWrite = false; }
});

test('旧纯日期显示和编辑不补造小时，整点显示保留北京时间', () => {
  assert.equal(formatMatterTime(undefined), '未设置');
  assert.equal(formatMatterTime('2026-12-10'), '2026-12-10');
  assert.deepEqual(splitMatterTime('2026-12-10'), { date: '2026-12-10', hour: '' });
  const time = '2026-10-29T00:00:00+08:00';
  assert.equal(formatMatterTime(time), '2026-10-29 00:00');
  assert.deepEqual(splitMatterTime(time), { date: '2026-10-29', hour: '00' });
  // 非整点旧响应不能在显示时被悄悄截断成整点。
  assert.equal(formatMatterTime('2026-10-29T09:30:00+08:00'), '2026-10-29T09:30:00+08:00');
});

test('演示用户改动统一回显到分页和团队，带新增成员的组织不能删除，密码不落浏览器存储', async () => {
  setMockMode(true);
  const team = await api.createTeam('回归测试团队', 2);
  const teamId = String(team.id);
  const password = 'Regression-only!42';
  const created = await api.createUser({ username: 'regression_member', password, realName: '回归成员', role: 'EMPLOYEE', phone: '13000000000', departmentId: 2, teamId: Number(team.id) });
  const id = String(created.id);
  try {
    assert.equal((await api.listUsers({ keyword: 'regression_member', size: 1 })).total, 1);
    await assert.rejects(api.createUser({ username: 'regression_member', password, realName: '重名成员', role: 'EMPLOYEE', phone: '13000000000', departmentId: 2, teamId: Number(team.id) }), /账号已存在/);
    assert.equal((await api.listTeamMembers(teamId)).total, 1);
    await assert.rejects(api.deleteUnit('teams', teamId), /成员/);
    await api.setUserStatus(id, false);
    assert.equal((await api.getUser(id)).status, '停用');
    assert.equal((await api.listUsers({ status: '停用', keyword: 'regression_member' })).total, 1);
    await api.updateUser(id, { realName: '转组成员', departmentId: 2, teamId: 1 });
    assert.equal((await api.listTeamMembers(teamId)).total, 0);
    assert.ok((await api.listTeamMembers('1', { keyword: 'regression_member' })).items.some(user => user.name === '转组成员'));
    await api.resetPassword(id, password);
    assert.ok(!JSON.stringify([...memory]).includes(password));
    api.removeDemoUser(id);
    assert.equal((await api.listUsers({ keyword: 'regression_member' })).total, 0);
    await api.deleteUnit('teams', teamId);
  } finally {
    const index = mockTeams.findIndex(unit => unit.id === teamId);
    if (index >= 0) mockTeams.splice(index, 1);
  }
});

test('真实用户请求发送分页和筛选，不读取或写入演示缓存，也不开放本地删除与重置', async () => {
  BACKEND_CAPABILITIES.users = true;
  memory.set('pandora-web-users-local', '[{"id":"must-not-appear"}]');
  memory.set('pandora-web-users-status', '{"101":"停用"}');
  const before = JSON.stringify([...memory]);
  globalThis.fetch = async (url, init) => {
    if (init.method === 'POST') return response({ id: 102 });
    if (init.method) return response({});
    const query = new URL(url, 'http://test').searchParams;
    assert.equal(query.get('keyword'), 'server'); assert.equal(query.get('role'), 'EMPLOYEE'); assert.equal(query.get('status'), '1');
    assert.equal(query.get('page'), '3'); assert.equal(query.get('size'), '10');
    return response({ items: [{ id: 101, username: 'server', realName: '服务器用户', role: 'EMPLOYEE', status: 'ACTIVE' }], page: 3, size: 10, total: 51 });
  };
  try {
    const data = await api.listUsers({ keyword: 'server', role: '组员', status: '启用', page: 3, size: 10 });
    assert.equal(data.total, 51); assert.equal(data.items.length, 1); assert.equal(data.items[0].status, '启用');
    await api.createUser({ username: 'server_new', realName: '测试', phone: '13000000000', password: 'test-only', role: '组员' });
    await api.updateUser('101', { realName: '更新' }); await api.setUserStatus('101', false);
    assert.equal(JSON.stringify([...memory]), before);
    assert.throws(() => api.removeDemoUser('101'), /真实模式/);
    assert.throws(() => api.resetDemoUsers(), /真实模式/);
  } finally { BACKEND_CAPABILITIES.users = false; }
});

test('演示缓存容器损坏时可继续读取，并明确恢复基线', async () => {
  setMockMode(true);
  memory.set('pandora-web-users-local', '{}');
  memory.set('pandora-web-users-removed', 'null');
  memory.set('pandora-web-users-edits', '[]');
  memory.set('pandora-web-users-status', 'broken-json');
  assert.equal((await api.listUsers()).total, mockUsers.length);
  api.resetDemoUsers();
  assert.equal(memory.has('pandora-web-users-local'), false);
});

test('审计查询传递操作者、动作和分页，保留具体操作信息且失败不回退演示', async () => {
  BACKEND_CAPABILITIES.audits = true;
  const audit = { id: 'audit-42', actor: 'test_admin', action: '编辑用户', target: '用户 ID 123：调整团队归属', time: '2026-10-29T12:00:00+08:00', result: '成功' };
  globalThis.fetch = async url => {
    const query = new URL(url, 'http://test').searchParams;
    assert.equal(query.get('actor'), 'test_admin'); assert.equal(query.get('action'), '编辑用户');
    assert.equal(query.get('page'), '2'); assert.equal(query.get('size'), '10');
    return response({ items: [audit], total: 11, page: 2, size: 10 });
  };
  try {
    const data = await api.listAudits({ actor: 'test_admin', action: '编辑用户', page: 2, size: 10 });
    assert.deepEqual(data.items[0], audit); assert.equal(data.total, 11);
    globalThis.fetch = async () => response(null, 500, 50000);
    await assert.rejects(api.listAudits());
  } finally { BACKEND_CAPABILITIES.audits = false; }
});
