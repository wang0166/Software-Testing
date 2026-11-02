import { useState } from 'react';
import { api, type CompanyMatter } from '../api/client';
import { supports } from '../api/capabilities';
import { isMock } from '../api/http';
import { useAsync } from '../hooks/hooks';
import { Empty, Modal, Skeleton, useToast } from '../components/ui';
import { formatMatterTime, joinMatterTime, splitMatterTime } from '../utils/matterTime';

const HOURS = Array.from({ length: 24 }, (_, hour) => String(hour).padStart(2, '0'));

export function Matters() {
  const [page, setPage] = useState(1);
  const list = useAsync(() => api.listMatters(page, 10), [page]);
  const [dialog, setDialog] = useState(false);
  const [editing, setEditing] = useState<CompanyMatter | null>(null);
  const [draft, setDraft] = useState({ title: '', content: '', sortOrder: 1, startDate: '', startHour: '', deadline: '', deadlineHour: '' });
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const toast = useToast();
  const canWrite = supports('matterWrite');
  const open = (matter: CompanyMatter | null) => {
    setEditing(matter);
    setError('');
    const start = splitMatterTime(matter?.startDate), end = splitMatterTime(matter?.deadline);
    setDraft({ title: matter?.title ?? '', content: matter?.content ?? '', sortOrder: matter?.sortOrder ?? 1, startDate: start.date, startHour: start.hour, deadline: end.date, deadlineHour: end.hour });
    setDialog(true);
  };
  const save = async () => {
    if (busy || !canWrite) return;
    setBusy(true); setError('');
    try {
      const value = { title: draft.title, content: draft.content, sortOrder: draft.sortOrder,
        startDate: joinMatterTime(draft.startDate, draft.startHour), deadline: joinMatterTime(draft.deadline, draft.deadlineHour) };
      if (editing) await api.updateMatter(editing.id, value); else await api.createMatter(value);
      setDialog(false); list.reload(); toast.push('ok', isMock() ? '已保存演示事项' : '事项已保存');
    } catch (e) { setError(e instanceof Error ? e.message : '保存失败'); }
    finally { setBusy(false); }
  };
  return <div>
    <div className="pd-hero"><div><h2>公司十大事项</h2><p>记录重要事项，明确开始时间与截止时间</p></div></div>
    {list.loading ? <Skeleton rows={3} /> : list.error ? <div className="pd-card" role="alert"><p className="pd-err">{list.error}</p><button className="pd-btn" onClick={list.reload}>重试</button></div> : <div className="pd-card pd-matters-list">
      <div className="pd-card-head"><h3 className="pd-sub">事项清单 <span className="pd-count">{list.data?.total ?? 0}</span></h3><button className="pd-btn primary" disabled={!canWrite} onClick={() => open(null)}>新建事项</button></div>
      {!canWrite && <p role="status" className="pd-hint">当前后端仅支持查询，尚未提供事项维护及起止时间支持；本页只读，缺失时间显示“未设置”。</p>}
      {list.data?.items.map(m => <article className="pd-tree-node" key={m.id}>
        <span className="pd-matter-order" title="排序">{m.sortOrder}</span><div className="pd-matter-body"><h3>{m.title}</h3><p className="pd-matter-content">{m.content}</p><p className="pd-matter-dates"><span>开始：{formatMatterTime(m.startDate)}</span><span aria-hidden="true">至</span><span>截止：{formatMatterTime(m.deadline)}</span></p></div><button className="pd-btn quiet" disabled={!canWrite} onClick={() => open(m)}>编辑</button>
      </article>)}
      {list.data?.total === 0 && <Empty title="暂无事项" />}
      <div className="pd-row"><span>第 {page} 页 · 共 {list.data?.total ?? 0} 条</span><button className="pd-btn" disabled={page <= 1} onClick={() => setPage(p => p - 1)}>上一页</button><button className="pd-btn" disabled={page * 10 >= (list.data?.total ?? 0)} onClick={() => setPage(p => p + 1)}>下一页</button></div>
    </div>}
    {dialog && <Modal title={(editing ? '编辑' : '新建') + (isMock() ? '演示事项' : '事项')} onClose={() => !busy && setDialog(false)} footer={<><button className="pd-btn" disabled={busy} onClick={() => setDialog(false)}>取消</button><button className="pd-btn primary" disabled={busy} onClick={save}>{busy ? '保存中…' : '保存'}</button></>}>
      <div className="pd-form">
        <label>事项名称 <input className="pd-input" aria-label="事项名称" value={draft.title} onChange={e => setDraft({ ...draft, title: e.target.value })} /></label>
        <label>事项备注 <textarea className="pd-input" aria-label="事项备注" value={draft.content} onChange={e => setDraft({ ...draft, content: e.target.value })} /></label>
        <fieldset className="pd-matter-time"><legend>开始时间</legend><div className="pd-row">
          <input className="pd-input" aria-label="开始日期" type="date" value={draft.startDate} onChange={e => setDraft({ ...draft, startDate: e.target.value })} />
          <select className="pd-select" aria-label="开始小时" value={draft.startHour} onChange={e => setDraft({ ...draft, startHour: e.target.value })}><option value="">选择小时</option>{HOURS.map(hour => <option key={hour} value={hour}>{hour} 时</option>)}</select>
        </div></fieldset>
        <fieldset className="pd-matter-time"><legend>截止时间</legend><div className="pd-row">
          <input className="pd-input" aria-label="截止日期" type="date" min={draft.startDate || undefined} value={draft.deadline} onChange={e => setDraft({ ...draft, deadline: e.target.value })} />
          <select className="pd-select" aria-label="截止小时" value={draft.deadlineHour} onChange={e => setDraft({ ...draft, deadlineHour: e.target.value })}><option value="">选择小时</option>{HOURS.map(hour => <option key={hour} value={hour}>{hour} 时</option>)}</select>
        </div></fieldset>
        <p className="pd-field-hint">北京时间，仅支持整点。旧记录只有日期时，保存前需补选小时。</p>
        <label>排序 <input className="pd-input" aria-label="事项排序" type="number" step="1" value={draft.sortOrder} onChange={e => setDraft({ ...draft, sortOrder: Number(e.target.value) })} /></label>
        {isMock() && <p className="pd-hint">演示改动仅在当前会话有效；刷新后恢复演示数据。</p>}
        {error && <p className="pd-inline-error" role="alert">{error}</p>}
      </div>
    </Modal>}
  </div>;
}
