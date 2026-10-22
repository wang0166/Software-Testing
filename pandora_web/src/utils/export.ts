export function toCSV(rows: string[][]) {
  return rows.map((r) => r.map((c) => `"${String(c).replace(/"/g, '""')}"`).join(',')).join('\r\n');
}

export function downloadCSV(filename: string, rows: string[][]) {
  const blob = new Blob(['\uFEFF' + toCSV(rows)], { type: 'text/csv;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

export interface OpLog { time: string; action: string; detail: string }

export function readOpLog(): OpLog[] {
  try {
    return JSON.parse(localStorage.getItem('pandora-ops') ?? '[]') as OpLog[];
  } catch {
    return [];
  }
}

export function writeOpLog(action: string, detail: string) {
  const log: OpLog = { time: new Date().toLocaleString('zh-CN'), action, detail };
  try {
    localStorage.setItem('pandora-ops', JSON.stringify([...readOpLog(), log].slice(-100)));
  } catch {
    // 忽略
  }
}

export function clearOpLog() {
  localStorage.removeItem('pandora-ops');
}
