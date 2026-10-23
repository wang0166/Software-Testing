import { isMock } from './http';

// 依据当前后端控制器核对，新增后端接口后在此显式开放对应模块。
export const BACKEND_CAPABILITIES = {
  users: false,
  organization: false,
  roles: false,
  config: false,
  audits: false,
  matterWrite: false,
} as const;

export type Capability = keyof typeof BACKEND_CAPABILITIES;
export function supports(capability: Capability) {
  return isMock() || BACKEND_CAPABILITIES[capability];
}
export function requireCapability(capability: Capability) {
  if (!supports(capability)) throw new Error('当前后端尚未提供此管理接口，请等待后端实现后联调');
}
