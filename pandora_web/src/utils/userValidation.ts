import { normalizeIdentity } from './identity';

export const duplicateUserMessages = {
  phone: '手机号已被使用',
  username: '账户名已存在',
  idNumber: '身份证号已被使用',
};

type IdentityFields = { username: string; phone?: string | null; idNumber?: string | null };

export function duplicateUserFields(candidate: Partial<IdentityFields>, existing: IdentityFields): (keyof IdentityFields)[] {
  const matches: (keyof IdentityFields)[] = [];
  if (candidate.username && candidate.username === existing.username.trim().toLowerCase()) matches.push('username');
  if (candidate.phone && candidate.phone === existing.phone?.trim()) matches.push('phone');
  if (candidate.idNumber && candidate.idNumber === normalizeIdentity(existing.idNumber ?? '')) matches.push('idNumber');
  return matches;
}

export function nameError(value: string): string {
  const name = value.trim();
  if (!name) return '请填写姓名';
  if (name.length > 64) return '姓名最多 64 个字符';
  if (!/\p{L}/u.test(name) || /[\p{Cc}\p{Cf}\p{Zl}\p{Zp}]/u.test(value)) return '姓名须包含文字，且不能含控制字符';
  return '';
}

export function passwordError(value: string): string {
  if (!value.trim()) return '请填写或生成密码';
  if (new TextEncoder().encode(value).length > 72) return '密码的 UTF-8 编码最多 72 字节';
  if ([...value].length < 12) return '密码至少 12 位';
  if (/[\p{Cc}\p{Cf}\p{Zl}\p{Zp}]/u.test(value)) return '密码不能包含控制字符';
  if (!/[A-Z]/.test(value) || !/[a-z]/.test(value) || !/[0-9]/.test(value) || !/[\p{P}\p{S}]/u.test(value)) {
    return '密码须包含大小写字母、数字和符号';
  }
  return '';
}

export function generateStrongPassword(): string {
  const pools = ['abcdefghijkmnpqrstuvwxyz', 'ABCDEFGHJKLMNPQRSTUVWXYZ', '23456789', '!@#$%^&*'];
  const alphabet = pools.join('');
  const random = new Uint32Array(1);
  const randomIndex = (length: number) => {
    const limit = 2 ** 32 - (2 ** 32 % length);
    do { crypto.getRandomValues(random); } while (random[0] >= limit);
    return random[0] % length;
  };
  const chars = pools.map(pool => pool[randomIndex(pool.length)]);
  while (chars.length < 16) chars.push(alphabet[randomIndex(alphabet.length)]);
  for (let i = chars.length - 1; i > 0; i--) {
    const j = randomIndex(i + 1);
    [chars[i], chars[j]] = [chars[j], chars[i]];
  }
  return chars.join('');
}
