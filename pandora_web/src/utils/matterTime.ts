// 事项按上海时区整点记录，避免浏览器所在时区改变用户选择的小时。
const HOUR_PATTERN = /^(\d{4}-\d{2}-\d{2})T([01]\d|2[0-3]):00:00\+08:00$/;

export function isMatterHour(value: string): boolean {
  const match = HOUR_PATTERN.exec(value);
  if (!match) return false;
  const date = new Date(match[1] + 'T00:00:00Z');
  return Number.isFinite(date.getTime()) && date.toISOString().slice(0, 10) === match[1];
}

export function splitMatterTime(value?: string): { date: string; hour: string } {
  if (!value) return { date: '', hour: '' };
  if (isMatterHour(value)) {
    const match = HOUR_PATTERN.exec(value)!;
    return { date: match[1], hour: match[2] };
  }
  // 旧的纯日期不自动解释为零点，编辑时须明确补选小时。
  return { date: /^\d{4}-\d{2}-\d{2}$/.test(value) ? value : '', hour: '' };
}

export function joinMatterTime(date: string, hour: string): string {
  return date && hour ? `${date}T${hour}:00:00+08:00` : '';
}

export function formatMatterTime(value?: string): string {
  if (!value) return '未设置';
  if (!isMatterHour(value)) return value;
  const { date, hour } = splitMatterTime(value);
  return `${date} ${hour}:00`;
}
