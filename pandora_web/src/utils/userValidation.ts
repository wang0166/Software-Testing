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
  // 允许文字和组合音标，连接符只出现在两段文字之间。
  if (/[\p{Cc}\p{Cf}\p{Zl}\p{Zp}]/u.test(value) || !/^\p{L}[\p{L}\p{M}]*(?:[ ·・-]\p{L}[\p{L}\p{M}]*)*$/u.test(name)) {
    return '姓名只能包含文字，空格、中点和连字符只能用在姓名中间';
  }
  return '';
}

export function passwordError(value: string): string {
  if (!value.trim()) return '请填写或生成密码';
  const length = [...value].length;
  if (length < 12 || length > 128) return '密码须为 12–128 个字符';
  if (/\s|[\p{Cc}\p{Cf}\p{Zl}\p{Zp}]/u.test(value)) return '密码不能包含空白或控制字符';
  if (!/[A-Z]/.test(value) || !/[a-z]/.test(value) || !/[0-9]/.test(value)
      || !/[\x21-\x2F\x3A-\x40\x5B-\x60\x7B-\x7E]/.test(value)) {
    return '密码须包含大小写字母、数字和英文特殊符号';
  }
  const normalized = value.toLowerCase();
  const compact = normalized.replace(/[^a-z0-9]/g, '');
  const simplified = compact.replace(/0/g, 'o').replace(/1/g, 'i')
    .replace(/3/g, 'e').replace(/4/g, 'a').replace(/5/g, 's');
  const common = new Set(['123456', '12345678', '123456789', '1234567890', '111111', '000000',
    'password', 'password1', 'password123', 'qwerty', 'qwerty123', 'abc123', 'admin', 'admin123',
    'letmein', 'welcome', 'welcome123', 'iloveyou', 'p@ssword', 'p@ssw0rd', 'passw0rd', 'changeme']);
  if (common.has(normalized) || common.has(compact) || common.has(simplified)) return '不能使用常见弱密码';
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
