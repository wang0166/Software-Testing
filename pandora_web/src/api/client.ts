// 数据访问层依据 documents/后端接口文档.md 与实际控制器实现核对。
// 仅主动开启的演示模式使用 mock；真实模式不兜底，不调用尚未实现的管理接口。
import { request, requestPage, clearTokens, getToken, getRefreshToken, isMock, setTokens, sleep, type PageData } from './http';
import { requireCapability } from './capabilities';
import { labelToCode, codeToLabel, statusLabel, statusValue } from '../constants/roles';
import { isMatterHour, isMatterSortOrder, MATTER_SORT_ORDER_ERROR } from '../utils/matterTime';
import { identityError, normalizeIdentity } from '../utils/identity';
import { duplicateUserFields, duplicateUserMessages } from '../utils/userValidation';
import { duplicateOrganizationNameMessage, organizationNameExists, organizationTextErrors } from '../utils/organizationValidation';

export interface UserRow { id: string; username: string; name: string; dept: string; team: string; role: string; status: string; departmentId?: string | null; teamId?: string | null; idNumber?: string; gender?: string; phone?: string }
export interface CreateUserInput {
  username: string; password: string; realName: string; role: string; phone: string;
  departmentId?: number | null; teamId?: number | null; idNumber: string; gender?: string;
}
export interface OrgUnit { id: string; name: string; parentId?: string; description?: string; managerId?: string | null; leaderId?: string | null }
/** 公司事项独立于任务派发；时间按上海时区整点记录，兼容旧纯日期响应。 */
export const MATTER_LIMIT = 10;
export const MATTER_LIMIT_MESSAGE = '事件纪最多保留 10 条，已达到上限';
export interface CompanyMatter { id: string; title: string; content: string; sortOrder: number; startDate?: string; deadline?: string }
export interface CompanyMatterInput { title: string; content: string; sortOrder: number; startDate: string; deadline: string }
export interface AuditRow { id: string; actor: string; action: string; target: string; time: string; result: string; objectType?: string; objectId?: string; source?: string; summary?: string }
export interface AuditDetail extends AuditRow { changes: { field: string; before: string | null; after: string | null }[] }
export interface AuditFilter { actor?: string; action?: string; from?: string; to?: string; objectType?: string; page?: number; size?: number }
const AUDIT_TYPES = new Set(['LOG', 'TASK']);
export interface RolePerm { roleCode: string; label: string; permissions: string[] }

/** POST /auth/login 返回体（第2节） */
export interface LoginResponse {
  accessToken: string;
  refreshToken: string;
  tokenType: string;
  expiresIn: number;
  user: { id: string; username: string; realName: string; role: string; permissions?: string[]; departmentId: number | null; teamId: number | null };
}

const USER_KEY = 'pandora-user';
const ROLE_KEY = 'pandora-role';
const PERM_KEY = 'pandora-permissions';

// ---------------- mock 数据（无后端也能演示） ----------------
export const mockUsers: UserRow[] = [
  { id: 'u-01', username: 'founder', name: '创始人', dept: '总部', team: '-', role: '创始人', status: '启用', gender: '男', phone: '13800000001', idNumber: '110101199001011234' },
  { id: 'u-02', username: 'laozong_a', name: '老总A', dept: '产品部', team: '-', role: '老总', status: '启用', gender: '男', phone: '13800000002', idNumber: '110101199102022345' },
  { id: 'u-03', username: 'laozong_b', name: '老总B', dept: '技术部', team: '-', role: '老总', status: '启用', gender: '女', phone: '13800000003', idNumber: '110101199203033456' },
  { id: 'u-04', username: 'zuzhang_a', name: '组长A', dept: '产品部', team: '如来佛组', role: '组长', status: '启用', gender: '男', phone: '13800000004', idNumber: '110101199304044567' },
  { id: 'u-05', username: 'zuzhang_b', name: '组长B', dept: '产品部', team: '观音组', role: '组长', status: '启用', gender: '女', phone: '13800000005', idNumber: '110101199405055678' },
  { id: 'u-06', username: 'zuzhang_c', name: '组长C', dept: '技术部', team: '平台组', role: '组长', status: '启用', gender: '男', phone: '13800000006', idNumber: '110101199506066789' },
  { id: 'u-07', username: 'zuyuan_a', name: '组员A', dept: '产品部', team: '如来佛组', role: '组员', status: '启用', gender: '男', phone: '13900000001', idNumber: '110101199607077890' },
  { id: 'u-08', username: 'zuyuan_b', name: '组员B', dept: '产品部', team: '如来佛组', role: '组员', status: '启用', gender: '女', phone: '13900000002', idNumber: '110101199708088901' },
  { id: 'u-09', username: 'zuyuan_c', name: '组员C', dept: '技术部', team: '平台组', role: '组员', status: '停用', gender: '男', phone: '13900000003', idNumber: '110101199809099012' },
  { id: 'u-10', username: 'zuyuan_d', name: '组员D', dept: '产品部', team: '观音组', role: '组员', status: '启用', gender: '女', phone: '13900000004', idNumber: '110101199910101123' },
  { id: 'u-11', username: 'zuyuan_e', name: '组员E', dept: '产品部', team: '观音组', role: '组员', status: '启用', gender: '男', phone: '13900000005', idNumber: '110101200001011234' },
  { id: 'u-12', username: 'zuyuan_f', name: '组员F', dept: '技术部', team: '平台组', role: '组员', status: '启用', gender: '女', phone: '13900000006', idNumber: '110101200102022345' },
  { id: 'u-13', username: 'zuyuan_g', name: '组员G', dept: '技术部', team: '平台组', role: '组员', status: '启用', gender: '男', phone: '13900000007', idNumber: '110101200203033456' },
  { id: 'u-14', username: 'zuyuan_h', name: '组员H', dept: '技术部', team: '架构组', role: '组员', status: '启用', gender: '男', phone: '13900000008', idNumber: '110101200304044567' },
  { id: 'u-15', username: 'zuyuan_i', name: '组员I', dept: '产品部', team: '如来佛组', role: '组员', status: '启用', gender: '女', phone: '13900000009', idNumber: '110101200405055678' },
  { id: 'u-16', username: 'zuyuan_j', name: '组员J', dept: '产品部', team: '观音组', role: '组员', status: '启用', gender: '男', phone: '13900000010', idNumber: '110101200506066789' },
  { id: 'u-17', username: 'zuyuan_k', name: '组员K', dept: '技术部', team: '架构组', role: '组员', status: '停用', gender: '男', phone: '13900000011', idNumber: '110101200607077890' },
  { id: 'u-18', username: 'zuyuan_l', name: '组员L', dept: '技术部', team: '架构组', role: '组员', status: '启用', gender: '女', phone: '13900000012', idNumber: '110101200708088901' },
  { id: 'u-19', username: 'admin', name: '管理员', dept: '总部', team: '-', role: '管理员', status: '启用', gender: '男', phone: '13800000000', idNumber: '110101199001010000' },
  { id: 'u-20', username: 'zuyuan_m', name: '组员M', dept: '产品部', team: '如来佛组', role: '组员', status: '启用', gender: '男', phone: '13900000013', idNumber: '110101200809099012' },
];

export const mockDepartments: OrgUnit[] = [
  { id: '1', name: '总部', parentId: '1', description: '公司总部，统筹全局战略与经营管理' },
  { id: '2', name: '产品部', parentId: '1', description: '负责产品设计、需求分析与用户体验' },
  { id: '3', name: '技术部', parentId: '1', description: '负责系统研发、架构设计与运维保障' },
];
export const mockTeams: OrgUnit[] = [
  { id: '1', name: '如来佛组', parentId: '2', description: '主打核心业务功能的产品打磨' },
  { id: '2', name: '观音组', parentId: '2', description: '负责增长与用户运营侧产品' },
  { id: '3', name: '平台组', parentId: '3', description: '负责基础平台与服务端开发' },
  { id: '4', name: '架构组', parentId: '3', description: '负责技术架构选型与攻坚' },
];
export const mockMatters: CompanyMatter[] = [
  { id: 'm-1', title: 'Sprint2 后端骨架交付', content: '完成登录与组织接口联调', sortOrder: 1, startDate: '2026-10-26T09:00:00+08:00', deadline: '2026-11-15T18:00:00+08:00' },
  { id: 'm-2', title: 'M2 组织管理验收', content: '用户与组织管理 Web 侧可用', sortOrder: 2, startDate: '2026-11-01T09:00:00+08:00', deadline: '2026-11-30T18:00:00+08:00' },
  { id: 'm-3', title: '需求 V1.0 冻结', content: '五项待确认问题闭环后冻结', sortOrder: 3, deadline: '2026-12-10' },
];
export const mockAudits: AuditRow[] = [
  { id: 'a-1', actor: '演示员工', action: '提交日志', target: '工作日志 #1', objectType: 'LOG', objectId: '1', time: '2026-11-13T17:00:00+08:00', result: 'SUCCESS', summary: '演示员工提交了工作日志' },
  { id: 'a-2', actor: '演示接收人', action: '更新进度', target: '派发任务 #2', objectType: 'TASK', objectId: '2', time: '2026-11-13T16:30:00+08:00', result: 'SUCCESS', summary: '演示接收人将任务标记为已完成' },
];
export const mockRolePerms: RolePerm[] = [
  { roleCode: 'EMPLOYEE', label: '组员', permissions: ['task:execute', 'task:self', 'content:read'] },
  { roleCode: 'TEAM_LEADER', label: '组长', permissions: ['task:dispatch', 'task:execute', 'task:self', 'content:read'] },
  { roleCode: 'DEPT_MANAGER', label: '老总', permissions: ['task:dispatch', 'task:execute', 'task:self', 'content:read'] },
  { roleCode: 'FOUNDER', label: '创始人', permissions: ['task:dispatch', 'task:execute', 'task:self', 'content:read', 'company-task:manage'] },
  { roleCode: 'ADMIN', label: '管理员', permissions: ['user:manage', 'org:manage', 'role:manage', 'config:manage', 'audit:read', 'content:read', 'company-matter:manage'] },
];
// ---------------- 接口方法 ----------------
const useMock = isMock;
const mockPerms = () => mockRolePerms.find(r => r.roleCode === localStorage.getItem(ROLE_KEY))?.permissions ?? [];
function saveIdentity(u: CurrentUser) {
  localStorage.setItem(USER_KEY, u.realName || u.username);
  localStorage.setItem(ROLE_KEY, u.role);
  localStorage.setItem(PERM_KEY, JSON.stringify(u.permissions ?? []));
}
export interface CurrentUser {
  id?: number | string; username: string; realName?: string; role: string;
  departmentId?: number | null; teamId?: number | null; permissions?: string[];
}
function pageOf<T>(items: T[], page = 1, size = 20): PageData<T> {
  return { items: items.slice((page - 1) * size, page * size), page, size, total: items.length };
}
export const api = {
  async login(username: string, password: string) {
    clearTokens();
    const clean = username.trim();
    if (!clean || !password.trim()) throw new Error('请输入账号和密码');
    if (!useMock()) {
      const d = await request<LoginResponse>('/auth/login', { method: 'POST', body: JSON.stringify({ username: clean, password }) });
      if (!d?.accessToken || d.user?.role !== 'ADMIN') throw new Error('此管理端仅允许管理员登录，请使用移动端');
      setTokens(d.accessToken, d.refreshToken);
      saveIdentity(d.user);
      return d.user;
    }
    await sleep();
    const u = mockUsers.find(x => x.username === clean);
    if (!u || u.status !== '启用') throw new Error('演示账号不存在或已停用');
    if (labelToCode(u.role) !== 'ADMIN') throw new Error('此管理端仅允许管理员登录');
    setTokens('mock-access-token', 'mock-refresh-token');
    const user = { id: u.id, username: u.username, realName: u.name, role: 'ADMIN',
      permissions: mockRolePerms.find(r => r.roleCode === 'ADMIN')?.permissions ?? [] };
    saveIdentity(user);
    return user;
  },
  async logout() {
    try {
      if (!useMock() && getToken()) await request('/auth/logout', {
        method: 'POST', body: JSON.stringify({ refreshToken: getRefreshToken() }),
      });
    } finally { clearTokens(); }
  },
  async me(): Promise<CurrentUser> {
    if (useMock()) return { username: localStorage.getItem(USER_KEY) ?? '', role: localStorage.getItem(ROLE_KEY) ?? '', permissions: mockPerms() };
    const user = await request<CurrentUser>('/auth/me');
    if (!user || user.role !== 'ADMIN') {
      clearTokens();
      throw new Error('此管理端仅允许管理员登录');
    }
    saveIdentity(user);
    return user;
  },
  permissions(): string[] {
    try { const p: unknown = JSON.parse(localStorage.getItem(PERM_KEY) ?? '[]'); return Array.isArray(p) ? p.filter((x): x is string => typeof x === 'string') : []; }
    catch { return []; }
  },
  currentUser() { return getToken() ? localStorage.getItem(USER_KEY) ?? '' : ''; },
  currentRole() { return localStorage.getItem(ROLE_KEY) ?? ''; },
  async listUsers(params: { keyword?: string; role?: string; status?: string; departmentId?: string; teamId?: string; page?: number; size?: number } = {}): Promise<PageData<UserRow>> {
    requireCapability('users');
    const page = params.page ?? 1, size = params.size ?? 20;
    const q = new URLSearchParams({ page: String(page), size: String(size) });
    if (params.keyword) q.set('keyword', params.keyword);
    if (params.role) q.set('role', labelToCode(params.role) ?? params.role);
    if (params.status) q.set('status', String(statusValue(params.status)));
    if (params.departmentId) q.set('departmentId', params.departmentId);
    if (params.teamId) q.set('teamId', params.teamId);
    if (!useMock()) {
      const d = await requestPage<RawUser>('/users?' + q, { cache: 'no-store' });
      return { ...d, items: d.items.map(mapUser) };
    }
    await sleep();
    const key = (params.keyword ?? '').trim().toLowerCase();
    return pageOf(demoUserRows().filter(u => (!params.role || u.role === (codeToLabel(params.role))) &&
      (!params.status || u.status === params.status) &&
      (!params.departmentId || u.departmentId === params.departmentId) &&
      (!params.teamId || u.teamId === params.teamId) &&
      (!key || (u.username + u.name + u.dept + u.team).toLowerCase().includes(key))), page, size);
  },
  async findDuplicateUserFields(identity: Partial<Pick<CreateUserInput, 'username' | 'phone' | 'idNumber'>>, exceptUserId?: string) {
    const normalized = { username: identity.username?.trim().toLowerCase(), phone: identity.phone?.trim(), idNumber: normalizeIdentity(identity.idNumber ?? '') };
    const fieldsToCheck = Object.values(normalized).filter(Boolean).length;
    if (!fieldsToCheck) return [];
    const conflicts = new Set<keyof typeof duplicateUserMessages>();
    const check = (rows: UserRow[]) => {
      for (const user of rows) {
        if (user.id === exceptUserId) continue;
        for (const field of duplicateUserFields(normalized, user)) conflicts.add(field);
      }
    };
    if (useMock()) {
      check(demoUserRows());
      return [...conflicts];
    }
    // 当前接口没有手机号或证件号的精确查询，提交前分页核对，仅返回冲突字段。
    let page = 1;
    let total: number | undefined;
    let size: number | undefined;
    const checkedIds = new Set<string>();
    do {
      const result = await api.listUsers({ page, size: 100 });
      total ??= result.total;
      size ??= result.size;
      const expectedCount = Math.max(0, Math.min(size, total - (page - 1) * size));
      if (result.page !== page || result.size !== size || result.total !== total || result.items.length !== expectedCount) {
        throw new Error('用户列表分页已变化，请重试身份信息核对');
      }
      for (const user of result.items) {
        if (!/^\d+$/.test(user.id) || checkedIds.has(user.id) || typeof user.username !== 'string'
          || (user.phone != null && typeof user.phone !== 'string') || (user.idNumber != null && typeof user.idNumber !== 'string')) {
          throw new Error('用户列表响应无法用于身份信息核对，请刷新后重试');
        }
        checkedIds.add(user.id);
      }
      check(result.items);
      page += 1;
    } while ((page - 1) * size < total && conflicts.size < fieldsToCheck);
    return [...conflicts];
  },
  async listTeamMembers(teamId: string, params: { keyword?: string; page?: number; size?: number } = {}): Promise<PageData<UserRow>> {
    requireCapability('users');
    if (!useMock()) {
      const data = await api.listUsers({ ...params, teamId });
      // 不将服务器忽略筛选条件的结果当作本团队成员展示。
      if (data.items.some(user => user.teamId !== teamId)) throw new Error('成员响应的团队归属与所选团队不一致，请核对后端筛选');
      return data;
    }
    await sleep();
    if (!mockTeams.some(team => team.id === teamId)) throw new Error('团队不存在');
    const key = (params.keyword ?? '').trim().toLowerCase();
    const rows = demoUserRows().filter(user => user.teamId === teamId && (!key || (user.name + user.username).toLowerCase().includes(key)));
    return pageOf(rows, params.page ?? 1, params.size ?? 5);
  },
  async createUser(p: CreateUserInput) {
    requireCapability('users');
    if (!useMock()) return request<{ id: number | string }>('/users', {
      method: 'POST',
      // 密码原样提交，哈希由后端完成；明确字段以免误传表单内部状态。
      body: JSON.stringify({ username: p.username.trim(), password: p.password, realName: p.realName.trim(),
        role: labelToCode(p.role) ?? p.role, phone: p.phone.trim(),
        departmentId: p.departmentId ?? null, teamId: p.teamId ?? null,
        idNumber: normalizeIdentity(p.idNumber), gender: p.gender }),
    });
    await sleep();
    const candidate = { username: p.username.trim().toLowerCase(), phone: p.phone.trim(), idNumber: normalizeIdentity(p.idNumber) };
    const duplicate = demoUserRows().map(user => duplicateUserFields(candidate, user)[0]).find(Boolean);
    if (duplicate) throw new Error(duplicate === 'username' ? '该账号已存在' : duplicateUserMessages[duplicate]);
    const id = 'u-local-' + crypto.randomUUID();
    const departmentId = p.departmentId == null ? null : String(p.departmentId);
    const teamId = p.teamId == null ? null : String(p.teamId);
    const row: UserRow = { id, username: p.username.trim(), name: p.realName.trim(), role: codeToLabel(labelToCode(p.role) ?? p.role), status: '启用',
      departmentId, teamId, dept: mockDepartments.find(d => d.id === departmentId)?.name ?? '-', team: mockTeams.find(t => t.id === teamId)?.name ?? '-',
      phone: p.phone.trim(), gender: p.gender, idNumber: p.idNumber?.trim() };
    writeDemo('pandora-web-users-local', [...demoArray<UserRow>('pandora-web-users-local'), row]);
    return { id };
  },
  async getUser(id: string) {
    requireCapability('users');
    if (!useMock()) return mapUser(await request<RawUser>('/users/' + encodeURIComponent(id), { cache: 'no-store' }));
    const u = demoUserRows().find(x => x.id === id);
    if (!u) throw new Error('用户不存在');
    return withDemoOrgIds(u);
  },
  async updateUser(id: string, p: { realName?: string; role?: string; departmentId?: number | null; teamId?: number | null; idNumber?: string }) {
    requireCapability('users');
    const idNumber = p.idNumber === undefined ? undefined : normalizeIdentity(p.idNumber);
    if (idNumber !== undefined) {
      const error = identityError(idNumber);
      if (error) throw new Error(error);
    }
    if (!useMock()) {
      await request('/users/' + encodeURIComponent(id), {
        method: 'PUT',
        body: JSON.stringify({ realName: p.realName, role: p.role ? labelToCode(p.role) ?? p.role : undefined,
          departmentId: p.departmentId, teamId: p.teamId, idNumber }),
      });
      if (idNumber !== undefined) {
        // 旧版接口可能忽略新增字段，必须回读同一用户才能确认身份证号已写入。
        const saved = await api.getUser(id).catch(() => null);
        if (!saved || saved.id !== id || typeof saved.idNumber !== 'string' || normalizeIdentity(saved.idNumber) !== idNumber) {
          throw new Error('身份证号修改未能回读确认，请刷新详情核对后再操作');
        }
      }
      return;
    }
    await sleep();
    const rows = demoUserRows();
    const current = rows.find(user => user.id === id);
    if (!current) throw new Error('用户不存在');
    if (idNumber && rows.some(user => user.id !== id && duplicateUserFields({ idNumber }, user).includes('idNumber'))) {
      throw new Error(duplicateUserMessages.idNumber);
    }
    const departmentId = p.departmentId === undefined ? current.departmentId : p.departmentId == null ? null : String(p.departmentId);
    const teamId = p.teamId === undefined ? current.teamId : p.teamId == null ? null : String(p.teamId);
    const edits = demoRecord<Partial<UserRow>>('pandora-web-users-edits');
    writeDemo('pandora-web-users-edits', { ...edits, [id]: { ...edits[id], name: p.realName ?? current.name,
      role: p.role ? codeToLabel(labelToCode(p.role) ?? p.role) : current.role, departmentId, teamId, idNumber: idNumber ?? current.idNumber,
      dept: mockDepartments.find(d => d.id === departmentId)?.name ?? '-', team: mockTeams.find(t => t.id === teamId)?.name ?? '-' } });
  },
  async setUserStatus(id: string, enabled: boolean) {
    requireCapability('users');
    if (!useMock()) return request('/users/' + encodeURIComponent(id) + '/status', { method: 'PATCH', body: JSON.stringify({ status: enabled ? 1 : 0 }) });
    await sleep();
    if (!demoUserRows().some(user => user.id === id)) throw new Error('用户不存在');
    writeDemo('pandora-web-users-status', { ...demoRecord<string>('pandora-web-users-status'), [id]: enabled ? '启用' : '停用' });
  },
  async resetPassword(id: string, password: string) {
    requireCapability('users');
    if (!useMock()) return request('/users/' + encodeURIComponent(id) + '/password', { method: 'PUT', body: JSON.stringify({ password }) });
    await sleep();
    if (!demoUserRows().some(user => user.id === id)) throw new Error('用户不存在');
  },
  removeDemoUser(id: string) {
    if (!useMock()) throw new Error('真实模式不支持删除用户');
    writeDemo('pandora-web-users-removed', [...new Set([...demoArray<string>('pandora-web-users-removed'), id])]);
  },
  resetDemoUsers() {
    if (!useMock()) throw new Error('真实模式不能重置演示数据');
    for (const key of ['local', 'removed', 'edits', 'status']) localStorage.removeItem('pandora-web-users-' + key);
  },
  async listDepartments(): Promise<OrgUnit[]> {
    requireCapability('organization');
    if (!useMock()) return toUnits(await request('/departments', { cache: 'no-store' }), 'companyId');
    await sleep();
    const managers = demoUserRows().filter(user => labelToCode(user.role) === 'DEPT_MANAGER');
    return mockDepartments.map(unit => ({ ...unit, managerId: managers.find(manager => manager.departmentId === unit.id)?.id ?? null }));
  },
  async listCompanies(): Promise<{ id: string; name: string }[]> {
    requireCapability('organization');
    if (useMock()) return [{ id: '1', name: 'Pandora' }];
    return toItems<{ id: number | string; name: string }>(await request('/companies'))
      .map(company => ({ id: String(company.id), name: company.name }));
  },
  async listTeams(): Promise<OrgUnit[]> {
    requireCapability('organization');
    if (!useMock()) return toUnits(await request('/teams', { cache: 'no-store' }), 'departmentId');
    await sleep();
    const leaders = demoUserRows().filter(user => labelToCode(user.role) === 'TEAM_LEADER');
    return mockTeams.map(unit => ({ ...unit, leaderId: leaders.find(leader => leader.teamId === unit.id)?.id ?? null }));
  },
  async createDepartment(name: string, companyId: number, description?: string) {
    requireCapability('organization');
    const input = organizationInput(name, description);
    const demo = useMock();
    const departments = demo ? mockDepartments : await api.listDepartments();
    if (organizationNameExists(departments, String(companyId), input.name)) throw new Error(duplicateOrganizationNameMessage);
    if (!demo) return request<{ id: number }>('/departments', { method: 'POST', body: JSON.stringify({ ...input, companyId }) });
    const id = Date.now(); mockDepartments.push({ id: String(id), ...input, parentId: String(companyId) }); return { id };
  },
  async createTeam(name: string, departmentId: number, description?: string) {
    requireCapability('organization');
    const input = organizationInput(name, description);
    const demo = useMock();
    const teams = demo ? mockTeams : await api.listTeams();
    if (organizationNameExists(teams, String(departmentId), input.name)) throw new Error(duplicateOrganizationNameMessage);
    if (!demo) return request<{ id: number }>('/teams', { method: 'POST', body: JSON.stringify({ ...input, departmentId }) });
    const id = Date.now(); mockTeams.push({ id: String(id), ...input, parentId: String(departmentId) }); return { id };
  },
  async deleteUnit(kind: 'departments' | 'teams', id: string) {
    requireCapability('organization');
    if (!useMock()) return request('/' + kind + '/' + encodeURIComponent(id), { method: 'DELETE' });
    const units = kind === 'departments' ? mockDepartments : mockTeams;
    const unit = units.find(u => u.id === id);
    if (!unit) throw new Error('组织不存在');
    const hasMembers = demoUserRows().some(u => (kind === 'departments' ? u.departmentId : u.teamId) === id);
    if (hasMembers || (kind === 'departments' && mockTeams.some(t => t.parentId === id))) throw new Error('组织仍有下属组织或成员，不能删除');
    units.splice(units.indexOf(unit), 1);
  },
  async listMatters(page = 1, size = 20): Promise<PageData<CompanyMatter>> {
    if (!useMock()) {
      const d = await requestPage<CompanyMatter>('/company-matters?page=' + page + '&size=' + size, { cache: 'no-store' });
      return { ...d, items: d.items.map(x => ({ ...x, id: String(x.id) })) };
    }
    await sleep();
    return pageOf([...mockMatters].sort((a, b) => a.sortOrder - b.sortOrder), page, size);
  },
  async createMatter(m: CompanyMatterInput) {
    requireCapability('matterWrite');
    const value = matterInput(m);
    if (!useMock()) {
      const { total, page, size, items } = await api.listMatters(1, 1);
      if (total >= MATTER_LIMIT) throw new Error(MATTER_LIMIT_MESSAGE);
      if (page !== 1 || items.length !== Math.min(total, size)) throw new Error('暂时无法核对事件数量，请刷新后重试');
      return request<{ id: number }>('/company-matters', { method: 'POST', body: JSON.stringify(value) });
    }
    if (mockMatters.length >= MATTER_LIMIT) throw new Error(MATTER_LIMIT_MESSAGE);
    const id = Date.now(); mockMatters.push({ ...value, id: String(id) }); return { id };
  },
  async updateMatter(id: string, m: CompanyMatterInput) {
    requireCapability('matterWrite');
    const value = matterInput(m);
    if (!useMock()) return request('/company-matters/' + encodeURIComponent(id), { method: 'PUT', body: JSON.stringify(value) });
    const i = mockMatters.findIndex(x => x.id === id);
    if (i < 0) throw new Error('事件不存在');
    mockMatters[i] = { ...value, id };
  },
  async getAudit(id: string): Promise<AuditDetail> {
    requireCapability('audits');
    if (!useMock()) {
      const row = await request<AuditDetail>(`/audits/${encodeURIComponent(id)}`);
      if (!row || row.id == null) throw new Error('操作记录详情格式不正确');
      if (!row.objectType || !AUDIT_TYPES.has(row.objectType)) throw new Error('此页面仅支持日志和任务操作记录');
      // 旧记录可不含字段变化；错误结构应明确报错，避免详情页崩溃或伪造内容。
      if (row.changes != null && (!Array.isArray(row.changes) || row.changes.some(change => !change || typeof change.field !== 'string'
        || ![change.before, change.after].every(value => value == null || typeof value === 'string')))) throw new Error('操作记录字段变化格式不正确');
      return { ...row, changes: row.changes ?? [] };
    }
    const row = mockAudits.find(item => String(item.id) === String(id));
    if (!row) throw new Error('操作记录不存在');
    return { ...row, source: 'LEGACY', summary: '开发演示记录，不代表服务器操作', changes: [] };
  },
  async listAudits(params: AuditFilter = {}): Promise<PageData<AuditRow>> {
    requireCapability('audits');
    // 默认查询工作日志；每次请求都限定类型，防止其他管理记录混入。
    const objectType = params.objectType || 'LOG';
    if (!AUDIT_TYPES.has(objectType)) throw new Error('此页面仅支持日志和任务操作记录');
    const page = params.page ?? 1, size = params.size ?? 20;
    if (!useMock()) {
      const q = new URLSearchParams({ page: String(page), size: String(size), objectType });
      if (params.actor) q.set('actor', params.actor);
      if (params.action) q.set('action', params.action);
      if (params.from) q.set('from', params.from);
      if (params.to) q.set('to', params.to);
      const data = await requestPage<AuditRow>('/audits?' + q);
      if (data.items.some(row => row.objectType !== objectType)) throw new Error('操作记录响应与所选业务类型不一致，请核对后端筛选接口');
      return data;
    }
    const matching = mockAudits.filter(row => row.objectType === objectType
      && (!params.actor || row.actor.includes(params.actor))
      && (!params.action || row.action === params.action)
      && (!params.from || row.time.slice(0, 10) >= params.from)
      && (!params.to || row.time.slice(0, 10) <= params.to));
    return pageOf(matching, page, size);
  },
};
function toItems<T>(d: unknown): T[] {
  if (Array.isArray(d)) return d as T[];
  if (d && typeof d === 'object' && 'items' in d && Array.isArray(d.items)) return d.items as T[];
  throw new Error('列表响应格式不正确');
}
function toUnits(d: unknown, parent: 'companyId' | 'departmentId'): OrgUnit[] {
  return toItems<{ id: number; name: string; description?: string; companyId?: number; departmentId?: number; managerId?: number | string | null; leaderId?: number | string | null }>(d)
    .map(u => ({ id: String(u.id), name: u.name, description: u.description, parentId: u[parent] == null ? undefined : String(u[parent]),
      ...(parent === 'companyId' ? { managerId: u.managerId == null ? u.managerId : String(u.managerId) }
        : { leaderId: u.leaderId == null ? u.leaderId : String(u.leaderId) }) }));
}

function organizationInput(name: string, description?: string) {
  const errors = organizationTextErrors(name, description ?? '');
  const error = errors.name || errors.description;
  if (error) throw new Error(error);
  return { name: name.trim(), description: description?.trim() };
}

interface RawUser {
  id: number | string; username: string; realName: string; role: string; status: unknown;
  departmentId?: number | null; teamId?: number | null; departmentName?: string; teamName?: string;
  phone?: string; gender?: string; idNumber?: string;
}
function mapUser(u: RawUser): UserRow {
  return { id: String(u.id), username: u.username, name: u.realName, role: codeToLabel(u.role),
    dept: u.departmentName ?? (u.departmentId == null ? '-' : '部门' + u.departmentId),
    team: u.teamName ?? (u.teamId == null ? '-' : '团队' + u.teamId), status: statusLabel(u.status),
    departmentId: u.departmentId == null ? undefined : String(u.departmentId),
    teamId: u.teamId == null ? undefined : String(u.teamId),
    phone: u.phone, gender: u.gender, idNumber: u.idNumber };
}

function matterInput(m: CompanyMatterInput): CompanyMatterInput {
  const title = m.title.trim(), content = m.content.trim();
  if (!title || !content) throw new Error('事件名称和备注不能为空');
  if (title.length > 200 || content.length > 100000) throw new Error('事件名称最多 200 字，备注最多 100000 字');
  if (!isMatterSortOrder(m.sortOrder)) throw new Error(MATTER_SORT_ORDER_ERROR);
  if (!isMatterHour(m.startDate) || !isMatterHour(m.deadline)) throw new Error('请填写有效的开始时间和截止时间（精确到小时）');
  if (m.deadline < m.startDate) throw new Error('截止时间不得早于开始时间');
  return { title, content, sortOrder: m.sortOrder, startDate: m.startDate, deadline: m.deadline };
}

function withDemoOrgIds(user: UserRow): UserRow {
  // 旧演示记录仅有名称；只在能唯一定位时补 ID，真实接口不使用此推断。
  const departments = mockDepartments.filter(d => d.name === user.dept);
  const departmentId = user.departmentId !== undefined ? user.departmentId : (departments.length === 1 ? departments[0].id : undefined);
  const teams = mockTeams.filter(t => t.name === user.team && t.parentId === departmentId);
  return { ...user, departmentId, teamId: user.teamId !== undefined ? user.teamId : (teams.length === 1 ? teams[0].id : undefined) };
}

function readDemo(key: string): unknown {
  try { return JSON.parse(localStorage.getItem(key) ?? 'null'); } catch { return null; }
}
function demoArray<T>(key: string): T[] {
  const value = readDemo(key);
  return Array.isArray(value) ? value : [];
}
function demoRecord<T>(key: string): Record<string, T> {
  const value = readDemo(key);
  return value && typeof value === 'object' && !Array.isArray(value) ? value as Record<string, T> : {};
}
function writeDemo(key: string, value: unknown) {
  try { localStorage.setItem(key, JSON.stringify(value)); }
  catch { throw new Error('浏览器无法保存演示改动，请检查存储权限'); }
}
function demoUserRows(): UserRow[] {
  const local = demoArray<UserRow>('pandora-web-users-local').filter(user => user &&
    ['id', 'username', 'name', 'dept', 'team', 'role', 'status'].every(key => typeof user[key as keyof UserRow] === 'string'));
  const removed = demoArray<string>('pandora-web-users-removed');
  const edits = demoRecord<Partial<UserRow>>('pandora-web-users-edits');
  const statuses = demoRecord<string>('pandora-web-users-status');
  return [...mockUsers, ...local].filter(user => !removed.includes(user.id))
    .map(user => withDemoOrgIds({ ...user, ...edits[user.id], ...(typeof statuses[user.id] === 'string' ? { status: statuses[user.id] } : {}) }));
}
