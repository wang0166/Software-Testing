import { api, type CompanyMatter, type CurrentUser, type UserRow } from './client';
import { DEBUG_ENDPOINTS, redactDebugData } from './debug';
import { ApiError, getToken, isMock, request } from './http';
import { labelToCode } from '../constants/roles';

export type AutoStatus = 'pending' | 'running' | 'passed' | 'failed' | 'skipped';
export interface AutoCheck { id: string; status: AutoStatus; message: string; elapsed: number; checks: number; data?: unknown }
export interface AutoReport { checks: AutoCheck[]; notes: string[]; retained: { kind: string; id: string; state: string }[]; phase: 'testing' | 'cleanup' | 'complete' }
interface Options { onUpdate?: (report: AutoReport) => void; shouldStop?: () => boolean }

export function initialAutoReport(): AutoReport {
  return { checks: DEBUG_ENDPOINTS.map(endpoint => ({ id: endpoint.id, status: 'pending', message: '等待自动测试', elapsed: 0, checks: 0 })), notes: [], retained: [], phase: 'testing' };
}
function assert(value: unknown, message: string): asserts value { if (!value) throw new Error(message); }
function identifier(value: unknown): string {
  const id = String(value ?? '');
  assert(/^[1-9]\d*$/.test(id) && Number.isSafeInteger(Number(id)), '接口未返回有效的记录编号');
  return id;
}
function sameUser(user: UserRow, username: string, administrator: CurrentUser) {
  assert(user.username === username && String(user.id) !== String(administrator.id), '测试账号归属未确认，已阻止修改现有账号');
}

/** 自动串联当前管理员接口；仅修改本次创建且已核实归属的测试记录。 */
export async function runAutomaticDebug(options: Options = {}): Promise<AutoReport> {
  if (isMock()) throw new Error('请使用真实管理员账号登录后执行自动联调');
  const administratorToken = getToken();
  assert(administratorToken, '请先登录管理员账号');
  const suffix = crypto.randomUUID().replace(/-/g, '').slice(0, 12);
  const marker = `接口联调测试_${suffix}`;
  const username = `it_${suffix}`;
  const password = `It!${crypto.randomUUID()}`;
  const newPassword = `It!${crypto.randomUUID()}`;
  const secrets = [password, newPassword];
  const report = initialAutoReport();
  let administrator: CurrentUser | undefined;
  let departmentId = '', teamId = '', userId = '', matterId = '';
  let ownedUser = false, ownedMatter = false, ownedDepartment = false, ownedTeam = false, userAttempted = false, matterAttempted = false;
  let userDisabled = false, departmentDeleted = false, teamDeleted = false;
  let session: { accessToken: string; refreshToken: string } | undefined;
  const emit = () => options.onUpdate?.({ ...report, checks: report.checks.map(item => ({ ...item })), notes: [...report.notes], retained: [...report.retained] });
  const note = (message: string) => { if (!report.notes.includes(message)) report.notes.push(message); emit(); };
  const skip = (id: string, message: string) => {
    const item = report.checks.find(row => row.id === id)!;
    if (item.status === 'pending') { item.status = 'skipped'; item.message = message; emit(); }
  };
  const probe = async <T,>(id: string, work: () => Promise<T>): Promise<T | undefined> => {
    if (getToken() !== administratorToken) { skip(id, '管理员会话已变化，未继续请求'); return undefined; }
    if (report.phase !== 'cleanup' && options.shouldStop?.()) { skip(id, '已停止后续测试'); return undefined; }
    const item = report.checks.find(row => row.id === id)!;
    const priorError = item.status === 'failed' ? item.message : '';
    item.status = 'running'; item.message = report.phase === 'cleanup' ? '正在执行测试数据收尾' : '正在自动请求并核验'; emit();
    const started = Date.now();
    try {
      const value = await work();
      item.status = priorError ? 'failed' : 'passed'; item.message = priorError || '请求与业务核验通过';
      item.data = redactDebugData(value, secrets); return value;
    } catch (cause) {
      item.status = 'failed';
      item.message = String(redactDebugData(cause instanceof ApiError ? `HTTP ${cause.httpStatus || '未连接'} · ${cause.code} · ${cause.message}` : cause instanceof Error ? cause.message : '请求异常', secrets));
      return undefined;
    } finally { item.elapsed += Date.now() - started; item.checks++; emit(); }
  };
  const logoutTestSession = async () => {
    assert(session, '没有取得测试账号会话');
    const refreshToken = session.refreshToken;
    await request('/auth/logout', { method: 'POST', body: JSON.stringify({ refreshToken }) });
    session = undefined;
    return null;
  };
  const findOwnedMatter = async (id: string): Promise<CompanyMatter> => {
    const first = await api.listMatters(1, 100);
    const lastPage = Math.max(1, Math.ceil(first.total / first.size));
    const last = lastPage === 1 ? first : await api.listMatters(lastPage, 100);
    const found = [...first.items, ...last.items].find(item => String(item.id) === id);
    assert(found && found.title.startsWith(marker) && found.content.includes(marker), '未找到归属明确的测试事件，已阻止修改现有事件');
    return found;
  };
  emit();
  try {
    administrator = await probe('auth-me', async () => { const me = await api.me(); identifier(me.id); assert(Array.isArray(me.permissions), '身份响应缺少权限列表'); return me; });
    if (!administrator) return report;
    const companies = await probe('companies-list', () => api.listCompanies());
    const departments = await probe('departments-list', () => api.listDepartments());
    const teams = await probe('teams-list', () => api.listTeams());
    const users = await probe('users-list', () => api.listUsers({ page: 1, size: 10 }));
    await probe('matters-list', () => api.listMatters(1, 10));

    let auditId = '';
    for (const objectType of ['LOG', 'TASK']) {
      const audits = await probe('audits-list', () => api.listAudits({ objectType, page: 1, size: 10 }));
      if (audits?.items.length) {
        auditId ||= identifier(audits.items[0].id);
        const action = audits.items[0].action;
        await probe('audits-list', async () => {
          const filtered = await api.listAudits({ objectType, action, page: 1, size: 10 });
          assert(filtered.items.every(item => item.action === action), '动作筛选结果不匹配'); return filtered;
        });
      }
    }
    if (auditId) await probe('audits-get', () => api.getAudit(auditId));
    else skip('audits-get', '当前没有日志或任务记录，无法取得真实详情编号');

    if (companies?.length && departments) {
      departmentId = await probe('departments-create', async () => {
        const created = await api.createDepartment(marker, Number(companies[0].id), marker);
        const id = identifier(created.id);
        assert(!departments.some(item => String(item.id) === id), '新建部门返回了已有编号，未继续操作');
        // 先记住已创建编号，即使读回失败，finally 也会核对名称后尝试清理。
        departmentId = id;
        const row = (await api.listDepartments()).find(item => item.id === id);
        assert(row?.name === marker && row.parentId === String(companies[0].id), '新建部门的名称或公司归属不符');
        ownedDepartment = true;
        return id;
      }) ?? departmentId;
    } else skip('departments-create', '公司或部门列表不可用，无法自动创建测试部门');
    if (ownedDepartment && teams) {
      teamId = await probe('teams-create', async () => {
        const created = await api.createTeam(marker, Number(departmentId), marker);
        const id = identifier(created.id);
        assert(!teams.some(item => String(item.id) === id), '新建团队返回了已有编号，未继续操作');
        teamId = id;
        const row = (await api.listTeams()).find(item => item.id === id);
        assert(row?.name === marker && row.parentId === departmentId, '新建团队的名称或部门归属不符'); ownedTeam = true; return id;
      }) ?? teamId;
    } else skip('teams-create', '未取得测试部门或团队基线，无法创建测试团队');

    userId = await probe('users-create', async () => {
      const before = await api.listUsers({ keyword: username, page: 1, size: 10 });
      assert(!before.items.some(item => item.username === username), '测试账号名称已存在，已阻止复用');
      userAttempted = true;
      const created = await api.createUser({ username, password, realName: marker, role: 'ADMIN', departmentId: null, teamId: null,
        phone: '19900000000', idNumber: '99000020000101008X' });
      const id = identifier(created.id);
      const user = await api.getUser(id); sameUser(user, username, administrator!);
      ownedUser = true; userId = id; return id;
    }) ?? userId;
    const readableUser = ownedUser ? userId : users?.items[0]?.id;
    if (readableUser) await probe('users-get', () => api.getUser(String(readableUser)));
    else skip('users-get', '没有可读取的用户编号');
    if (ownedUser) {
      session = await probe('auth-login', async () => {
        // 使用独立测试账号登录，不调用会清理当前管理员会话的 api.login。
        const data = await request<{ accessToken: string; refreshToken: string; user: { id: number | string; role: string } }>('/auth/login', { method: 'POST', body: JSON.stringify({ username, password }) });
        assert(data?.accessToken && data.refreshToken && data.user?.role === 'ADMIN' && String(data.user.id) === userId, '测试账号登录响应不符合约定');
        secrets.push(data.accessToken, data.refreshToken); return data;
      });
      if (session) await probe('auth-logout', logoutTestSession);
      else skip('auth-logout', '测试账号登录失败，未注销当前管理员');

      await probe('users-update', async () => {
        await api.updateUser(userId, { realName: marker + '_已编辑', role: ownedTeam ? 'EMPLOYEE' : 'ADMIN', departmentId: ownedTeam ? Number(departmentId) : null, teamId: ownedTeam ? Number(teamId) : null });
        const row = await api.getUser(userId); sameUser(row, username, administrator!);
        assert(row.name === marker + '_已编辑' && (labelToCode(row.role) ?? row.role) === (ownedTeam ? 'EMPLOYEE' : 'ADMIN'), '用户修改未正确回显'); return row;
      });
      await probe('users-list', async () => {
        const list = await api.listUsers({ keyword: username, page: 1, size: 10 });
        assert(list.items.length > 0 && list.items.every(item => item.username === username), '用户关键词筛选未正确返回测试账号'); return list;
      });
      await probe('users-status', async () => {
        await api.setUserStatus(userId, false);
        const disabled = await api.getUser(userId); assert(disabled.status === '停用', '停用状态未回显'); userDisabled = true;
        await api.setUserStatus(userId, true);
        const enabled = await api.getUser(userId); assert(enabled.status === '启用', '启用状态未回显'); userDisabled = false; return enabled;
      });
      await probe('users-password', async () => {
        await api.resetPassword(userId, newPassword);
        const login = await request<{ accessToken: string; refreshToken: string; user: { id: number | string } }>('/auth/login', { method: 'POST', body: JSON.stringify({ username, password: newPassword }) });
        assert(login?.accessToken && login.refreshToken && String(login.user?.id) === userId, '重置密码后无法使用新密码登录测试账号');
        secrets.push(login.accessToken, login.refreshToken); session = login;
        await logoutTestSession(); return { id: userId, verified: '新密码登录与测试会话注销通过' };
      });
    } else for (const id of ['auth-login', 'auth-logout', 'users-update', 'users-status', 'users-password']) skip(id, '未创建并确认独立测试账号，未操作现有账号');

    const readableTeam = teamId || teams?.[0]?.id;
    if (readableTeam) await probe('team-members', () => api.listTeamMembers(String(readableTeam), { page: 1, size: 10 }));
    else skip('team-members', '没有可查询的团队编号');

    const matter = { title: marker, content: marker + '：自动联调专用虚构数据，当前接口不支持删除，保留供核对。', sortOrder: 2147483647, startDate: '2000-01-01T00:00:00+08:00', deadline: '2000-01-01T01:00:00+08:00' };
    matterId = await probe('matters-create', async () => {
      matterAttempted = true;
      const created = await api.createMatter(matter); const id = identifier(created.id);
      matterId = id; await findOwnedMatter(id); ownedMatter = true; return id;
    }) ?? matterId;
    if (ownedMatter) await probe('matters-update', async () => {
      await api.updateMatter(matterId, { ...matter, title: marker + '_已结束' });
      const row = await findOwnedMatter(matterId); assert(row.title === marker + '_已结束', '事件修改未正确回显'); return row;
    });
    else skip('matters-update', '未确认新建测试事件的归属，未修改现有事件');
  } catch (cause) {
    note(String(redactDebugData(cause instanceof Error ? cause.message : '自动测试中断', secrets)));
  } finally {
    report.phase = 'cleanup'; emit();
    if (getToken() === administratorToken && administrator) {
      // 创建响应中断时，用本次随机账号精确查回；绝不借用已有业务账号。
      if (userAttempted && !ownedUser) {
        try {
          const list = await api.listUsers({ keyword: username, page: 1, size: 100 });
          const row = list.items.find(item => item.username === username);
          if (row) { sameUser(row, username, administrator); userId = identifier(row.id); ownedUser = true; }
        } catch { note('测试账号创建状态未能确认，请核对本次测试记录'); }
      }
      if (session) await probe('auth-logout', logoutTestSession);
      if (ownedUser) {
        await probe('users-status', async () => {
          sameUser(await api.getUser(userId), username, administrator!);
          await api.setUserStatus(userId, false);
          const row = await api.getUser(userId); assert(row.status === '停用', '测试账号未成功停用'); userDisabled = true; return { id: userId, state: '测试账号已停用' };
        });
        await probe('users-update', async () => {
          sameUser(await api.getUser(userId), username, administrator!);
          await api.updateUser(userId, { realName: marker + '_已停用', role: 'ADMIN', departmentId: null, teamId: null });
          const row = await api.getUser(userId); assert(!row.departmentId && !row.teamId, '测试账号组织归属尚未清空'); return { id: userId, state: '测试账号已解除测试组织归属' };
        });
      }
      if (teamId) await probe('teams-delete', async () => {
        const row = (await api.listTeams()).find(item => item.id === teamId);
        assert(row?.name === marker && row.parentId === departmentId, '测试团队归属未确认，未执行删除');
        await api.deleteUnit('teams', teamId);
        assert(!(await api.listTeams()).some(item => item.id === teamId), '测试团队删除后仍可查询'); teamDeleted = true; return { id: teamId, state: '测试团队已删除' };
      });
      if (departmentId) await probe('departments-delete', async () => {
        const row = (await api.listDepartments()).find(item => item.id === departmentId);
        assert(row?.name === marker, '测试部门归属未确认，未执行删除');
        await api.deleteUnit('departments', departmentId);
        assert(!(await api.listDepartments()).some(item => item.id === departmentId), '测试部门删除后仍可查询'); departmentDeleted = true; return { id: departmentId, state: '测试部门已删除' };
      });
    } else note('管理员会话已变化，无法继续自动收尾；请核对下方尚未清理的测试记录');
    if (ownedUser) report.retained.push({ kind: '联调账号', id: userId, state: userDisabled ? '已停用，接口不支持删除' : '停用未确认，需要处理' });
    else if (userAttempted) note('开户请求已发出，但创建结果未确认，可能需要核对本次联调账号');
    if (matterId) report.retained.push({ kind: '联调事件', id: matterId, state: ownedMatter ? '已保留测试标记，接口不支持删除' : '创建结果待核对，未操作该编号' });
    else if (matterAttempted) note('事件创建请求已发出，未确认是否写入，请核对测试事件');
    if (teamId && !teamDeleted) report.retained.push({ kind: '测试团队', id: teamId, state: '未成功清理，需要处理' });
    if (departmentId && !departmentDeleted) report.retained.push({ kind: '测试部门', id: departmentId, state: '未成功清理，需要处理' });
    for (const item of report.checks) if (item.status === 'pending') { item.status = 'skipped'; item.message = options.shouldStop?.() ? '已停止后续测试' : '前置条件未满足，未发送请求'; }
    report.phase = 'complete'; emit();
  }
  return report;
}
