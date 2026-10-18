// 数据访问层：每个方法先按 design.md `/api` 约定写好真请求，USE_MOCK 时回退本地 mock
// 字段口径按组内《产品需求与设计文档.pdf》第6页：users.username 登录、role 中文、status 1启用/0停用
// work_logs.status：DRAFT 草稿 / SUBMITTED 已提交 / NOT_SUBMITTED 未提交（派生，不落库）
import { USE_MOCK, getToken, request, setToken, sleep, type PageData } from './http';

export interface UserRow { id: string; username: string; name: string; dept: string; team: string; role: string; status: string }
export interface LogRow { id: string; author: string; date: string; summary: string; status: string; visible: string }
export interface StatsData { submitRate: number; unsubmitted: string[]; total: number; submitted: number }

export const mockUsers: UserRow[] = [
  { id: 'u-01', username: 'founder', name: '创始人', dept: '总部', team: '-', role: '创始人', status: '启用' },
  { id: 'u-02', username: 'laozong_a', name: '老总A', dept: '产品部', team: '-', role: '老总', status: '启用' },
  { id: 'u-03', username: 'laozong_b', name: '老总B', dept: '技术部', team: '-', role: '老总', status: '启用' },
  { id: 'u-04', username: 'zuzhang_a', name: '组长A', dept: '产品部', team: '如来佛组', role: '组长', status: '启用' },
  { id: 'u-05', username: 'zuzhang_b', name: '组长B', dept: '产品部', team: '观音组', role: '组长', status: '启用' },
  { id: 'u-06', username: 'zuzhang_c', name: '组长C', dept: '技术部', team: '平台组', role: '组长', status: '启用' },
  { id: 'u-07', username: 'zuyuan_a', name: '组员A', dept: '产品部', team: '如来佛组', role: '组员', status: '启用' },
  { id: 'u-08', username: 'zuyuan_b', name: '组员B', dept: '产品部', team: '如来佛组', role: '组员', status: '启用' },
  { id: 'u-09', username: 'zuyuan_c', name: '组员C', dept: '技术部', team: '平台组', role: '组员', status: '停用' },
  { id: 'u-10', username: 'zuyuan_d', name: '组员D', dept: '产品部', team: '观音组', role: '组员', status: '启用' },
  { id: 'u-11', username: 'zuyuan_e', name: '组员E', dept: '产品部', team: '观音组', role: '组员', status: '启用' },
  { id: 'u-12', username: 'zuyuan_f', name: '组员F', dept: '技术部', team: '平台组', role: '组员', status: '启用' },
  { id: 'u-13', username: 'zuyuan_g', name: '组员G', dept: '技术部', team: '平台组', role: '组员', status: '启用' },
  { id: 'u-14', username: 'zuyuan_h', name: '组员H', dept: '技术部', team: '架构组', role: '组员', status: '启用' },
  { id: 'u-15', username: 'zuyuan_i', name: '组员I', dept: '产品部', team: '如来佛组', role: '组员', status: '启用' },
  { id: 'u-16', username: 'zuyuan_j', name: '组员J', dept: '产品部', team: '观音组', role: '组员', status: '启用' },
  { id: 'u-17', username: 'zuyuan_k', name: '组员K', dept: '技术部', team: '架构组', role: '组员', status: '停用' },
  { id: 'u-18', username: 'zuyuan_l', name: '组员L', dept: '技术部', team: '架构组', role: '组员', status: '启用' },
  { id: 'u-19', username: 'admin', name: '管理员', dept: '总部', team: '-', role: '管理员', status: '启用' },
  { id: 'u-20', username: 'zuyuan_m', name: '组员M', dept: '产品部', team: '如来佛组', role: '组员', status: '启用' },
];

export const mockLogs: LogRow[] = [
  { id: 'l-01', author: '组员A', date: '当天', summary: '完成首页动效设计，走查 12 处动效清单', status: '已提交', visible: '直接上级可见' },
  { id: 'l-02', author: '组员A', date: '当天', summary: '同步研发验收清单，确认本周交付项', status: '草稿', visible: '直接上级可见' },
  { id: 'l-03', author: '组员B', date: '当天', summary: '用户访谈第 5 场记录，聚焦反馈链路', status: '已提交', visible: '直接上级可见' },
  { id: 'l-04', author: '组员C', date: '当天', summary: '（未提交）', status: '未提交', visible: '-' },
  { id: 'l-05', author: '组员D', date: '当天', summary: '输出周报初稿，汇总完成率与下周三件事', status: '已提交', visible: '直接上级可见' },
  { id: 'l-06', author: '组员E', date: '当天', summary: '回访 3 家重点客户，记录导图反馈', status: '已提交', visible: '直接上级可见' },
  { id: 'l-07', author: '组员F', date: '当天', summary: '直播选品会纪要，确认排期负责人', status: '已提交', visible: '直接上级可见' },
  { id: 'l-08', author: '组员G', date: '当天', summary: '竞品走查笔记，对比三款视图页密度', status: '草稿', visible: '直接上级可见' },
  { id: 'l-09', author: '组员H', date: '当天', summary: '补充空态文案，统一引导语与按钮', status: '已提交', visible: '直接上级可见' },
  { id: 'l-10', author: '组员I', date: '当天', summary: '复盘会记录，整理结论与待办归属', status: '已提交', visible: '直接上级可见' },
  { id: 'l-11', author: '组员J', date: '当天', summary: '客服高频问题 Top10 初筛', status: '草稿', visible: '直接上级可见' },
  { id: 'l-12', author: '组员L', date: '当天', summary: '帮助文档更新，补充日志新建截图', status: '已提交', visible: '直接上级可见' },
  { id: 'l-13', author: '组员M', date: '当天', summary: '用户反馈分类，24 条归为 5 类', status: '已提交', visible: '直接上级可见' },
  { id: 'l-14', author: '组长A', date: '当天', summary: '团队日报汇总，3 人已交 2 人未交', status: '已提交', visible: '直接上级可见' },
  { id: 'l-15', author: '组长B', date: '当天', summary: '观音组排期对齐，确认本周交付', status: '已提交', visible: '直接上级可见' },
  { id: 'l-16', author: '组长C', date: '当天', summary: '平台组联调记录，3 个接口已通', status: '草稿', visible: '直接上级可见' },
  { id: 'l-17', author: '老总A', date: '当天', summary: '部门周会纪要，点评两个团队进展', status: '已提交', visible: '直接上级可见' },
  { id: 'l-18', author: '老总B', date: '当天', summary: '技术评审结论，确认架构方案', status: '已提交', visible: '直接上级可见' },
  { id: 'l-19', author: '创始人', date: '当天', summary: '全公司周报 Ren，确认下周三件大事', status: '已提交', visible: '直接上级可见' },
  { id: 'l-20', author: '组员K', date: '当天', summary: '（未提交）', status: '未提交', visible: '-' },
];

export const mockStats: StatsData = { submitRate: 80, unsubmitted: ['组员C', '组员K'], total: 20, submitted: 16 };

const USER_KEY = 'pandora-user';
const ROLE_KEY = 'pandora-role';

export interface LoginResult { token: string; name: string; role: string }

export const api = {
  // POST /api/auth/login —— design.md：登录成功返回 token，服务端校验停用
  async login(username: string, password = ''): Promise<LoginResult> {
    const clean = username.trim();
    if (!clean) throw new Error('请输入登录账号（username）');
    if (!password.trim()) throw new Error('请输入密码');
    if (!USE_MOCK) {
      const d = await request<LoginResult>('/auth/login', { method: 'POST', body: JSON.stringify({ username: clean, password }) });
      setToken(d.token);
      localStorage.setItem(USER_KEY, clean);
      localStorage.setItem(ROLE_KEY, d.role);
      return d;
    }
    await sleep();
    const banned = mockUsers.find((u) => u.username === clean && u.status === '停用');
    if (banned) throw new Error(`账号「${clean}」已停用，请联系管理员`);
    setToken('mock-token');
    localStorage.setItem(USER_KEY, clean);
    localStorage.setItem(ROLE_KEY, '管理员');
    return { token: 'mock-token', name: clean, role: '管理员' };
  },
  logout() {
    setToken('');
    localStorage.removeItem(USER_KEY);
    localStorage.removeItem(ROLE_KEY);
  },
  currentUser() {
    return getToken() ? localStorage.getItem(USER_KEY) ?? '' : '';
  },
  // GET /api/users?page=&size=&keyword=&role=&status=
  async listUsers(): Promise<UserRow[]> {
    if (!USE_MOCK) {
      const d = await request<PageData<UserRow>>('/users?page=1&size=200');
      return d.list;
    }
    await sleep();
    return [...mockUsers];
  },
  // GET /api/logs?scope=all&page=&size=&status=&keyword= —— 只读
  async listLogs(): Promise<LogRow[]> {
    if (!USE_MOCK) {
      const d = await request<PageData<LogRow>>('/logs?scope=all&page=1&size=200');
      return d.list;
    }
    await sleep(280);
    return [...mockLogs];
  },
  // GET /api/stats/overview —— 只读，NOT_SUBMITTED 由后端派生
  async stats(): Promise<StatsData> {
    if (!USE_MOCK) return request<StatsData>('/stats/overview');
    await sleep();
    return { ...mockStats, unsubmitted: [...mockStats.unsubmitted] };
  },
};
