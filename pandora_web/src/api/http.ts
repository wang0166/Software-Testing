// 对齐 documents/后端接口文档.md：统一响应、Bearer、分页及错误处理。
// 成功 {"code":0,"message":"ok","data":{...}}
// 分页 data: {"items":[],"page":1,"size":20,"total":0}
// HTTP 状态码表达协议层结果，code 是稳定业务错误码（40001/40101/40103/40301/40901...）
// 服务端从令牌识别用户，前端任何筛选都不能扩大可见范围
export interface Envelope<T> { code: number; message: string; data: T }
export interface PageData<T> { items: T[]; page: number; size: number; total: number }

export const API_BASE = (import.meta.env.VITE_API_BASE as string | undefined) ?? '/api';

/**
 * 是否走 mock（假数据）。
 * 优先级：登录页明确选择 > 环境变量 > 默认真实模式。
 * 切换模式需要重新登录，真实接口失败不得自动转入演示。
 */
export function isMock(): boolean {
  const forced = localStorage.getItem('pandora-mock');
  if (forced === '1') return true;
  if (forced === '0') return false;
  return (import.meta.env.VITE_USE_MOCK as string | undefined) === 'true';
}

export function setMockMode(on: boolean) {
  if (on !== isMock()) clearTokens();
  localStorage.setItem('pandora-mock', on ? '1' : '0');
}

const TOKEN_KEY = 'pandora-access-token';
const REFRESH_KEY = 'pandora-refresh-token';

export function getToken() { return localStorage.getItem(TOKEN_KEY) ?? ''; }
export function setTokens(accessToken: string, refreshToken?: string) {
  if (accessToken) localStorage.setItem(TOKEN_KEY, accessToken);
  else localStorage.removeItem(TOKEN_KEY);
  if (refreshToken !== undefined) {
    if (refreshToken) localStorage.setItem(REFRESH_KEY, refreshToken);
    else localStorage.removeItem(REFRESH_KEY);
  }
}
export function getRefreshToken() { return localStorage.getItem(REFRESH_KEY) ?? ''; }
export function clearTokens() {
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(REFRESH_KEY);
  for (const key of ['pandora-user', 'pandora-role', 'pandora-permissions']) localStorage.removeItem(key);
}

// 文档第12节错误码表：给前端一句人话，别把 40301 甩给用户
const CODE_TEXT: Record<number, string> = {
  40001: '参数校验失败，请检查填写内容',
  40101: '用户名或密码错误',
  40102: '登录已过期，请重新登录',
  40103: '账号已锁定或停用，请联系管理员',
  40104: '账号已停用，请联系管理员',
  40301: '无权访问该资源',
  40302: '只有直属上级才能点评',
  40310: '当前角色无此操作权限',
  40311: '无权访问或操作该资源',
  40312: '仅本人可操作自己的记录',
  40313: '仅派发人可检查',
  40314: '无权维护该内容',
  40401: '资源不存在或不可见',
  40410: '记录不存在或不可见',
  40901: '当天已存在日志',
  40902: '已提交的日志不可修改',
  40903: '已过提交截止时间',
  40904: '组织仍有关联成员，不能删除',
  40905: '该公司/部门/团队的负责人已存在',
  42901: '登录尝试过于频繁，请稍后再试',
  50000: '服务内部错误，请稍后再试',
};

export class ApiError extends Error {
  constructor(public httpStatus: number, public code: number, message: string) {
    super(message);
    this.name = 'ApiError';
  }
  /** 令牌失效或账号停用需要重新登录；登录失败和禁止访问不是同一状态。 */
  get needLogin() { return this.code === 40102 || this.code === 40104; }
}

async function parse(res: Response): Promise<Envelope<unknown> | null> {
  try { return (await res.json()) as Envelope<unknown>; } catch { return null; }
}

/** 统一请求：带 Bearer、解包 data、HTTP+code 双重判错 */
export async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  const headers: Record<string, string> = { 'Content-Type': 'application/json', ...(init.headers as Record<string, string> | undefined) };
  const token = getToken();
  const publicAuth = ['/auth/login', '/auth/refresh'].includes(path);
  if (token && !publicAuth) headers.Authorization = `Bearer ${token}`;

  let res: Response;
  try {
    res = await fetch(`${API_BASE}${path}`, { ...init, headers });
  } catch {
    throw new ApiError(0, 0, '网络异常，请检查连接后重试');
  }

  const body = await parse(res);
  const expired = !publicAuth && (res.status === 401 || body?.code === 40102 || body?.code === 40104);
  if (expired) {
    clearTokens();
    window.dispatchEvent(new Event('pandora-session-expired'));
  }
  // HTTP 层失败：优先保留后端业务错误，不把失败替换为假数据。
  if (!res.ok) {
    const code = body?.code ?? res.status;
    const msg = body?.message || CODE_TEXT[code] || `请求失败（HTTP ${res.status}）`;
    throw new ApiError(res.status, code, msg);
  }
  if (!body || typeof body.code !== 'number' || !Object.prototype.hasOwnProperty.call(body, 'data')) {
    throw new ApiError(res.status, 0, '接口响应格式不正确，请检查服务地址和代理配置');
  }
  // HTTP 200 但 code 非 0，同样是业务错误
  if (body && body.code !== 0) {
    throw new ApiError(res.status, body.code, body.message || CODE_TEXT[body.code] || '操作失败');
  }
  return body.data as T;
}

/** 分页请求：文档规定 data 是 { items, page, size, total } */
export async function requestPage<T>(path: string, init: RequestInit = {}): Promise<PageData<T>> {
  const d = await request<PageData<T>>(path, init);
  if (!d || !Array.isArray(d.items) || !Number.isInteger(d.page) || d.page < 1 ||
      !Number.isInteger(d.size) || d.size < 1 || !Number.isInteger(d.total) || d.total < 0) {
    throw new ApiError(200, 0, '分页响应格式不正确');
  }
  return d;
}

export const sleep = (ms = 200) => new Promise((r) => setTimeout(r, ms));
