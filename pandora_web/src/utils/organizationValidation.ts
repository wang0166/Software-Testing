export const duplicateOrganizationNameMessage = '该组织下已有同名记录';

export function organizationNameKey(name: string): string {
  return name.normalize('NFKC').trim().replace(/\s+/gu, ' ').toLowerCase();
}

export function organizationNameExists(units: { name: string; parentId?: string }[], parentId: string, name: string): boolean {
  const key = organizationNameKey(name);
  return units.some(unit => unit.parentId === parentId && organizationNameKey(unit.name) === key);
}

export function organizationTextErrors(name: string, description: string) {
  const trimmedName = name.trim();
  const trimmedDescription = description.trim();
  return {
    name: !trimmedName ? '请输入名称'
      : trimmedName.length > 100 ? '名称最多 100 个字符'
      : /[\p{Cc}\p{Cf}]/u.test(name) ? '名称不能包含控制字符'
      : !/\p{L}/u.test(trimmedName) ? '名称须包含文字，可搭配数字和符号' : '',
    description: trimmedDescription.length > 500 ? '介绍最多 500 个字符'
      : /[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/.test(description) ? '介绍含有无效控制字符'
      : trimmedDescription && !/\p{L}/u.test(trimmedDescription) ? '介绍须包含文字，也可以留空' : '',
  };
}
