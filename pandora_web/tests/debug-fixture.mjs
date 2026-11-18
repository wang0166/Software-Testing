// 内存后端夹具供自动联调的失败、清理与浏览器验证使用，不访问真实服务。
export function createDebugBackend(options = {}) {
  const state = {
    users: new Map([[1, { id: 1, username: 'business_admin', realName: '现有管理员', role: 'ADMIN', status: 'ACTIVE', departmentId: null, teamId: null, permissions: ['user:manage', 'org:manage', 'audit:read', 'content:read', 'company-matter:manage'] }],
      [2, { id: 2, username: 'business_employee', realName: '现有员工', role: 'EMPLOYEE', status: 'ACTIVE', departmentId: 10, teamId: 20 }]]),
    departments: new Map([[10, { id: 10, name: '现有部门', companyId: 1, description: '原介绍' }]]),
    teams: new Map([[20, { id: 20, name: '现有团队', departmentId: 10, description: '原介绍' }]]),
    matters: new Map([[30, { id: 30, title: '现有事件', content: '原内容', sortOrder: 1, startDate: '2026-11-18T09:00:00+08:00', deadline: '2026-11-19T18:00:00+08:00' }]]),
    audits: options.noAudits ? [] : [{ id: 40, actor: '测试作者', action: '提交日志', objectType: 'LOG', objectId: '100', target: '工作日志 #100', result: 'SUCCESS', source: 'USER', time: '2026-11-18T10:00:00+08:00', changes: [] },
      { id: 41, actor: '测试执行人', action: '更新进度', objectType: 'TASK', objectId: '101', target: '任务 #101', result: 'SUCCESS', source: 'USER', time: '2026-11-18T10:00:00+08:00', changes: [] }],
    passwords: new Map([[1, 'existing-password-never-used'], [2, 'existing-password-never-used']]), sessions: new Map(), calls: [], nextId: 1000,
  };
  const response = (data, status = 200, code = 0, message = 'fixture') => new Response(JSON.stringify({ code, data, message }), { status, headers: { 'Content-Type': 'application/json' } });
  const paged = (items, query) => { const page = Number(query.get('page') || 1), size = Number(query.get('size') || 10); return { items: items.slice((page - 1) * size, page * size), page, size, total: items.length }; };
  const fetch = async (address, init = {}) => {
    const url = new URL(address, 'http://fixture'), method = init.method || 'GET';
    const body = init.body ? JSON.parse(init.body) : undefined;
    const call = { method, path: url.pathname, query: Object.fromEntries(url.searchParams), body };
    state.calls.push(call);
    if (options.fail?.(call, state)) return response(null, 500, 50000, '预设失败');
    const path = url.pathname.replace(/^\/api/, ''), query = url.searchParams;
    if (path === '/auth/me') return response(state.users.get(1));
    if (path === '/auth/login') {
      const user = [...state.users.values()].find(row => row.username === body.username);
      if (!user || user.status !== 'ACTIVE' || state.passwords.get(user.id) !== body.password) return response(null, 401, 40101, '测试账号登录失败');
      const token = 'fixture-session-' + state.sessions.size + '-' + state.calls.length;
      state.sessions.set(token, user.id); return response({ accessToken: 'fixture-access-' + token, refreshToken: token, user });
    }
    if (path === '/auth/logout') { state.sessions.delete(body.refreshToken); return response(null); }
    if (path === '/companies') return response([{ id: 1, name: '测试公司' }]);
    if (path === '/users' && method === 'GET') {
      const rows = [...state.users.values()].filter(user => (!query.get('keyword') || (user.username + user.realName).includes(query.get('keyword'))) && (!query.get('teamId') || String(user.teamId) === query.get('teamId')) && (!query.get('departmentId') || String(user.departmentId) === query.get('departmentId')));
      return response(paged(rows, query));
    }
    if (path === '/users' && method === 'POST') {
      const id = state.nextId++;
      const { password, ...user } = body;
      state.users.set(id, { ...user, id, status: 'ACTIVE' }); state.passwords.set(id, password);
      return response({ id: options.wrongUserId ? 1 : id });
    }
    const userMatch = path.match(/^\/users\/(\d+)(?:\/(status|password))?$/);
    if (userMatch) {
      const id = Number(userMatch[1]), user = state.users.get(id);
      if (!user) return response(null, 404, 40401);
      if (method === 'GET') return response(user);
      if (userMatch[2] === 'status') user.status = body.status === 1 ? 'ACTIVE' : 'DISABLED';
      else if (userMatch[2] === 'password') state.passwords.set(id, body.password);
      else Object.assign(user, body);
      return response(null);
    }
    for (const kind of ['departments', 'teams']) {
      if (path === '/' + kind && method === 'GET') return response([...state[kind].values()]);
      if (path === '/' + kind && method === 'POST') { const id = state.nextId++; state[kind].set(id, { ...body, id }); return response({ id }); }
      const match = path.match(new RegExp('^/' + kind + '/(\\d+)$'));
      if (match && method === 'DELETE') {
        const id = Number(match[1]);
        if ([...state.users.values()].some(user => Number(kind === 'teams' ? user.teamId : user.departmentId) === id) || kind === 'departments' && [...state.teams.values()].some(team => team.departmentId === id)) return response(null, 409, 40904);
        state[kind].delete(id); return response(null);
      }
    }
    if (path === '/company-matters' && method === 'GET') return response(paged([...state.matters.values()].sort((a, b) => a.sortOrder - b.sortOrder || a.id - b.id), query));
    if (path === '/company-matters' && method === 'POST') { const id = state.nextId++; state.matters.set(id, { ...body, id }); return response({ id }); }
    const matterMatch = path.match(/^\/company-matters\/(\d+)$/);
    if (matterMatch && method === 'PUT') {
      const item = state.matters.get(Number(matterMatch[1]));
      if (!item) return response(null, 404, 40401);
      Object.assign(item, body); return response(null);
    }
    if (path === '/audits') return response(paged(state.audits.filter(row => row.objectType === query.get('objectType') && (!query.get('action') || row.action === query.get('action'))), query));
    const auditMatch = path.match(/^\/audits\/(\d+)$/);
    if (auditMatch) { const row = state.audits.find(row => row.id === Number(auditMatch[1])); return row ? response(row) : response(null, 404, 40401); }
    throw new Error('未预设的接口 ' + method + ' ' + path);
  };
  return { state, fetch };
}
