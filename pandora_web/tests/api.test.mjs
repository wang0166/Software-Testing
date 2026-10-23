import { test, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import { build } from 'esbuild';
import { resolve } from 'node:path';

// 将浏览器模块打包为独立测试入口，不依赖新增测试框架。
const outfile = resolve('dist/tests/api-bundle.mjs');
await build({ stdin: { contents: "export * from './src/api/client'; export * from './src/api/http'; export * from './src/api/capabilities';", resolveDir: process.cwd() },
  bundle: true, platform: 'node', format: 'esm', outfile, define: { 'import.meta.env': '{"VITE_API_BASE":"/api","VITE_USE_MOCK":"false"}' } });
const { api, request, requestPage, setTokens, getToken, setMockMode, supports } = await import(new URL('../dist/tests/api-bundle.mjs', import.meta.url));
const memory = new Map();
globalThis.localStorage = { getItem: key => memory.get(key) ?? null, setItem: (key, value) => memory.set(key, String(value)), removeItem: key => memory.delete(key) };
globalThis.window = new EventTarget();
const response = (data, status = 200, code = 0) => new Response(JSON.stringify({ code, message: code ? '测试错误' : 'ok', data }), { status });
beforeEach(() => { memory.clear(); globalThis.fetch = async () => { throw new Error('测试不允许真实联网'); }; });

test('真实模式为默认模式，未实现的管理接口不会发请求', async () => {
  let calls = 0;
  globalThis.fetch = async () => { calls++; return response({}); };
  assert.equal(supports('users'), false);
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
  const created = await api.createMatter({ title: '测试事项', content: '原备注', sortOrder: 50 });
  await api.updateMatter(String(created.id), { title: '测试事项', content: '新备注', sortOrder: 50 });
  assert.equal((await api.listMatters(1, 100)).items.find(x => x.id === String(created.id)).content, '新备注');
  const unit = await api.createDepartment('测试部门', 1, '介绍');
  assert.ok((await api.listDepartments()).some(x => x.id === String(unit.id)));
  await api.deleteUnit('departments', String(unit.id));
  assert.ok(!(await api.listDepartments()).some(x => x.id === String(unit.id)));
});
