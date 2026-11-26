import { useRef, useState } from 'react';
import { api, MATTER_LIMIT, MATTER_LIMIT_MESSAGE, type CompanyMatter } from '../api/client';
import { supports } from '../api/capabilities';
import { isMock } from '../api/http';
import { useAsync } from '../hooks/hooks';
import { useFormValidation } from '../hooks/formValidation';
import { Empty, Modal, Skeleton, useToast } from '../components/ui';
import { formatMatterTime, isMatterHour, isMatterSortOrder, joinMatterTime, MATTER_SORT_ORDER_ERROR, splitMatterTime } from '../utils/matterTime';

const HOURS = Array.from({ length: 24 }, (_, hour) => String(hour).padStart(2, '0'));
const PAGE_SIZE = MATTER_LIMIT;
const emptyDraft = { title: '', content: '', sortOrder: '1', startDate: '', startHour: '', deadline: '', deadlineHour: '' };
type MatterField = keyof typeof emptyDraft;
const fieldOrder: MatterField[] = ['title', 'content', 'startDate', 'startHour', 'deadline', 'deadlineHour', 'sortOrder'];

export function Matters() {
  const [page, setPage] = useState(1);
  const list = useAsync(() => api.listMatters(page, PAGE_SIZE), [page]);
  const total = list.data?.total ?? 0;
  const atLimit = total >= MATTER_LIMIT;
  const pageCount = Math.max(1, Math.ceil(total / (list.data?.size ?? PAGE_SIZE)));
  // 序号使用接口分页信息，独立于事项保存的排序值；翻页后继续编号。
  const startIndex = ((list.data?.page ?? page) - 1) * (list.data?.size ?? PAGE_SIZE);
  const [dialog, setDialog] = useState(false);
  const [editing, setEditing] = useState<CompanyMatter | null>(null);
  const [draft, setDraft] = useState(emptyDraft);
  const [busy, setBusy] = useState(false);
  const pending = useRef(false);
  const [error, setError] = useState('');
  const toast = useToast();
  const canWrite = supports('matterWrite');
  const start = joinMatterTime(draft.startDate, draft.startHour);
  const deadline = joinMatterTime(draft.deadline, draft.deadlineHour);
  const sortOrder = Number(draft.sortOrder);
  const errors: Partial<Record<MatterField, string>> = {
    title: !draft.title.trim() ? '请填写事件名称' : draft.title.trim().length > 200 ? '事件名称最多 200 个字符'
      : /\p{Cc}/u.test(draft.title) ? '事件名称不能包含控制字符' : '',
    content: !draft.content.trim() ? '请填写事件备注' : draft.content.trim().length > 100000 ? '事件备注最多 100000 个字符'
      : /[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/.test(draft.content) ? '事件备注含有无效控制字符' : '',
    startDate: isMatterHour(joinMatterTime(draft.startDate, '00')) ? '' : '请选择有效开始日期',
    startHour: HOURS.includes(draft.startHour) ? '' : '请选择开始小时',
    deadline: isMatterHour(joinMatterTime(draft.deadline, '00')) ? '' : '请选择有效截止日期',
    deadlineHour: !HOURS.includes(draft.deadlineHour) ? '请选择截止小时'
      : isMatterHour(start) && isMatterHour(deadline) && deadline < start ? '截止时间不得早于开始时间' : '',
    sortOrder: /^\d+$/.test(draft.sortOrder.trim()) && isMatterSortOrder(sortOrder) ? '' : MATTER_SORT_ORDER_ERROR,
  };
  const validation = useFormValidation('matter-form', errors);
  const feedback = (field: MatterField) => validation.error(field) && <small id={validation.errorId(field)} className="pd-field-error" role="alert">{validation.error(field)}</small>;
  const changeDraft = (field: MatterField, value: string) => { setDraft(current => ({ ...current, [field]: value })); setError(''); };
  const open = (matter: CompanyMatter | null) => {
    if (!matter && atLimit) return;
    setEditing(matter);
    setError(''); validation.reset();
    const start = splitMatterTime(matter?.startDate), end = splitMatterTime(matter?.deadline);
    setDraft({ title: matter?.title ?? '', content: matter?.content ?? '', sortOrder: String(matter?.sortOrder ?? 1), startDate: start.date, startHour: start.hour, deadline: end.date, deadlineHour: end.hour });
    setDialog(true);
  };
  const save = async () => {
    if (pending.current || !canWrite) return;
    validation.showAll();
    const first = fieldOrder.find(field => !!errors[field]);
    if (first) { validation.focus(first); return; }
    if (!editing && atLimit) { setError(MATTER_LIMIT_MESSAGE); return; }
    pending.current = true;
    setBusy(true); setError('');
    try {
      const value = { title: draft.title, content: draft.content, sortOrder, startDate: start, deadline };
      if (editing) await api.updateMatter(editing.id, value);
      else {
        const created = await api.createMatter(value);
        if (created?.id == null) throw new Error('创建响应缺少事件编号，请刷新核对结果');
      }
      setDialog(false); list.reload(); toast.push('ok', isMock() ? '已保存演示事件' : '事件已保存');
    } catch (e) {
      if (e instanceof Error && e.message === MATTER_LIMIT_MESSAGE) list.reload();
      setError(e instanceof Error ? e.message : '保存失败');
    } finally { pending.current = false; setBusy(false); }
  };
  return <div>
    <div className="pd-hero"><div><h2>事件纪</h2><p>记录公司重要事件，明确开始时间与截止时间</p></div></div>
    {list.loading ? <Skeleton rows={3} /> : list.error ? <div className="pd-card" role="alert"><p className="pd-err">{list.error}</p><button className="pd-btn" onClick={list.reload}>重试</button></div> : <div className="pd-card pd-matters-list">
      <div className="pd-card-head"><h3 className="pd-sub">事件清单 <span className="pd-count">{total} / {MATTER_LIMIT} 条</span></h3><div className="pd-actions"><button className="pd-btn" onClick={list.reload}>刷新</button><button className="pd-btn primary" disabled={!canWrite || atLimit} onClick={() => open(null)}>新建事件</button></div></div>
      {atLimit && <p role="status" className="pd-hint">{MATTER_LIMIT_MESSAGE}。可编辑已有事件。</p>}
      {!canWrite && <p role="status" className="pd-hint">当前后端仅支持查询，尚未提供事件维护及起止时间支持；本页只读，缺失时间显示“未设置”。</p>}
      {list.data?.items.map((m, index) => <article className="pd-tree-node" key={m.id}>
        <span className="pd-matter-order" title="序号">{startIndex + index + 1}</span><div className="pd-matter-body"><h3>{m.title}</h3><p className="pd-matter-content">{m.content}</p><p className="pd-matter-dates"><span>开始：{formatMatterTime(m.startDate)}</span><span aria-hidden="true">至</span><span>截止：{formatMatterTime(m.deadline)}</span></p></div><button className="pd-btn quiet" disabled={!canWrite} onClick={() => open(m)}>编辑</button>
      </article>)}
      {list.data?.total === 0 && <Empty title="暂无事件" />}
      {pageCount > 1 && <div className="pd-row"><span>第 {page} / {pageCount} 页 · 共 {total} 条</span><button className="pd-btn" disabled={page <= 1} onClick={() => setPage(p => p - 1)}>上一页</button><button className="pd-btn" disabled={page >= pageCount} onClick={() => setPage(p => p + 1)}>下一页</button></div>}
    </div>}
    {dialog && <Modal title={(editing ? '编辑' : '新建') + (isMock() ? '演示事件' : '事件')} onClose={() => !pending.current && setDialog(false)} footer={<><button className="pd-btn" disabled={busy} onClick={() => setDialog(false)}>取消</button><button className="pd-btn primary" type="submit" form="matter-form" disabled={busy || (!editing && atLimit)}>{busy ? '保存中…' : '保存'}</button></>}>
      <form id="matter-form" noValidate onSubmit={e => { e.preventDefault(); save(); }}>
        <fieldset className="pd-form-section pd-form" aria-label="事件资料" disabled={busy}>
        <label>事件名称 <input className="pd-input" {...validation.field('title')} aria-label="事件名称" required value={draft.title} onChange={e => changeDraft('title', e.target.value)} />{feedback('title')}</label>
        <label>事件备注 <textarea className="pd-input" {...validation.field('content')} aria-label="事件备注" required value={draft.content} onChange={e => changeDraft('content', e.target.value)} />{feedback('content')}</label>
        <fieldset className="pd-matter-time"><legend>开始时间</legend><div className="pd-row">
          <input className="pd-input" {...validation.field('startDate')} aria-label="开始日期" required type="date" value={draft.startDate} onChange={e => changeDraft('startDate', e.target.value)} />
          <select className="pd-select" {...validation.field('startHour')} aria-label="开始小时" required value={draft.startHour} onChange={e => changeDraft('startHour', e.target.value)}><option value="">选择小时</option>{HOURS.map(hour => <option key={hour} value={hour}>{hour} 时</option>)}</select>
        </div>{feedback('startDate')}{feedback('startHour')}</fieldset>
        <fieldset className="pd-matter-time"><legend>截止时间</legend><div className="pd-row">
          <input className="pd-input" {...validation.field('deadline')} aria-label="截止日期" required type="date" min={draft.startDate || undefined} value={draft.deadline} onChange={e => changeDraft('deadline', e.target.value)} />
          <select className="pd-select" {...validation.field('deadlineHour')} aria-label="截止小时" required value={draft.deadlineHour} onChange={e => changeDraft('deadlineHour', e.target.value)}><option value="">选择小时</option>{HOURS.map(hour => <option key={hour} value={hour}>{hour} 时</option>)}</select>
        </div>{feedback('deadline')}{feedback('deadlineHour')}</fieldset>
        <p className="pd-field-hint">北京时间，仅支持整点。旧记录只有日期时，保存前需补选小时。</p>
        <label>显示顺序（从 1 开始，越小越靠前）<input className="pd-input" {...validation.field('sortOrder')} aria-label="事件排序" required inputMode="numeric" value={draft.sortOrder} onChange={e => changeDraft('sortOrder', e.target.value)} />{feedback('sortOrder')}</label>
        {isMock() && <p className="pd-hint">演示改动仅在当前会话有效；刷新后恢复演示数据。</p>}
        {error && <p className="pd-inline-error" role="alert">{error}</p>}
        </fieldset>
      </form>
    </Modal>}
  </div>;
}
