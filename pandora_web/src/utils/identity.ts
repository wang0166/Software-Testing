/** 结构校验不等于实名核验；不使用号码推断或覆盖员工性别。 */
export function normalizeIdentity(value: string): string { return value.trim().toUpperCase(); }

export function identityError(raw: string): string {
  const value = normalizeIdentity(raw);
  if (!value) return '请填写身份证号';
  if (!/^\d{17}[\dX]$/.test(value)) return '身份证号应为18位，末位可为 X';
  const year = Number(value.slice(6, 10)), month = Number(value.slice(10, 12)), day = Number(value.slice(12, 14));
  const date = new Date(Date.UTC(year, month - 1, day));
  const today = new Date().toLocaleDateString('sv-SE', { timeZone: 'Asia/Shanghai' }).replace(/-/g, '');
  if (date.getUTCFullYear() !== year || date.getUTCMonth() !== month - 1 || date.getUTCDate() !== day || value.slice(6, 14) > today) return '请核对身份证号中的出生日期';
  const weights = [7, 9, 10, 5, 8, 4, 2, 1, 6, 3, 7, 9, 10, 5, 8, 4, 2];
  const sum = weights.reduce((total, weight, index) => total + Number(value[index]) * weight, 0);
  return value[17] === '10X98765432'[sum % 11] ? '' : '身份证号校验位不正确，请核对号码';
}
