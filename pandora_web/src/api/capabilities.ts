import { isMock } from './http';

// 管理接口已实现并通过真实 PostgreSQL 契约测试；连接旧版服务时失败会明确显示，不回退演示。
export const BACKEND_CAPABILITIES = {
  users: true,
  organization: true,
  audits: true,
  matterWrite: true,
} as const;

export type Capability = keyof typeof BACKEND_CAPABILITIES;
export function supports(capability: Capability) {
  return isMock() || BACKEND_CAPABILITIES[capability];
}
export function requireCapability(capability: Capability) {
  if (!supports(capability)) throw new Error('当前后端尚未提供此管理接口，请等待后端实现后联调');
}
