// 角色与权限唯一真相：对照 PDF 第5章，管理员 Web 只读
export const ROLES = ['创始人', '老总', '组长', '组员', '管理员'] as const;
export type Role = (typeof ROLES)[number];

// 管理员在 Web 可见、可点、可做三件事全部锁死，页面只读这里的结论
export const PERMISSIONS: Record<Role, { visible: string; can: string; webCanEdit: boolean }> = {
  创始人: { visible: '全公司', can: '看全部', webCanEdit: false },
  老总: { visible: '本部门', can: '看本部门', webCanEdit: false },
  组长: { visible: '本队', can: '看本队', webCanEdit: false },
  组员: { visible: '自己', can: '写日志', webCanEdit: false },
  管理员: { visible: '全公司只读', can: '不可提交/点评', webCanEdit: false },
};

// 用户状态：停用不可登录，写死两种
export const USER_STATUS = ['启用', '停用'] as const;
