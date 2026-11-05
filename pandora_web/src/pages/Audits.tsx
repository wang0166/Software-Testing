import { useEffect, useState } from 'react';
import { api, type AuditFilter } from '../api/client';
import { useAsync } from '../hooks/hooks';
import { Empty, Modal, Skeleton } from '../components/ui';
import { Icon } from '../components/Icon';

const TYPES: Record<string, string> = { LOG: '工作日志', TASK: '派发任务' };
const FIELDS: Record<string, string> = { status: '状态', executionStatus: '执行状态', reviewStatus: '检查状态', name: '任务名称', content: '日志正文', details: '任务描述', startDate: '开始时间', deadline: '截止时间', urgency: '紧急程度', assigneeCount: '接收人数', assignmentId: '接收记录编号', commentId: '点评编号' };
const VALUES: Record<string, string> = { DRAFT: '草稿', SUBMITTED: '已提交', NOT_STARTED: '未开始', IN_PROGRESS: '进行中', COMPLETED: '已完成', NONE: '未邀约', PENDING: '待检查', APPROVED: '已通过', RETURNED: '已退回', URGENT: '紧急', NOT_URGENT: '普通' };
const EMPTY = { actor: '', action: '', from: '', to: '', objectType: 'LOG', result: '' };
const QUICK_TYPES = [['LOG', '工作日志'], ['TASK', '派发任务']] as const;
const SOURCES: Record<string, string> = { SYSTEM: '系统自动处理', USER: '用户操作', LOCAL: '本地维护', LEGACY: '历史记录' };
const formatTime = (value: string) => { const date = new Date(value); return Number.isNaN(date.getTime()) ? value : date.toLocaleString('zh-CN', { timeZone: 'Asia/Shanghai', hour12: false }); };
const resultLabel = (value: string) => value === 'SUCCESS' || value === '成功' ? '成功' : value === 'FAILED' || value === '失败' ? '失败' : value;

export function Audits() {
  const [draft, setDraft] = useState(EMPTY);
  const [filter, setFilter] = useState<AuditFilter>(EMPTY);
  const [page, setPage] = useState(1);
  const [error, setError] = useState('');
  const [selected, setSelected] = useState<string | null>(null);
  const list = useAsync(() => api.listAudits({ ...filter, page, size: 10 }), [filter, page]);
  const pages = Math.max(1, Math.ceil((list.data?.total ?? 0) / 10));
  useEffect(() => { if (!list.loading && !list.error && page > pages) setPage(pages); }, [list.loading, list.error, page, pages]);
  const field = (key: keyof typeof EMPTY) => ({ value: draft[key], onChange: (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => setDraft({ ...draft, [key]: e.target.value }) });
  const search = (next = draft) => {
    if (next.from && next.to && next.to < next.from) { setError('结束日期不得早于开始日期'); return; }
    setError(''); setDraft(next); setPage(1);
    setFilter({ ...next, actor: next.actor.trim(), action: next.action.trim() });
  };
  return <div>
    <div className="pd-hero"><div><span className="pd-eyebrow">日志与任务</span><h2>日志与任务操作记录</h2><p>查看日志和任务的操作人、时间、处理结果及变更详情。</p></div><span className="pd-readonly"><Icon name="audit" />只读记录</span></div>
    <section className="pd-card">
      <div className="pd-card-head"><div><h3 className="pd-sub">查询日志与任务记录</h3><p className="pd-hint">记录手机端各角色对日志和任务的操作；日志不可删除。</p></div></div>
      <div className="pd-audit-quick-types" role="group" aria-label="按业务类型快速筛选">{QUICK_TYPES.map(([value, label]) => <button key={value} className={'pd-btn' + (filter.objectType === value ? ' primary' : '')} type="button" aria-pressed={filter.objectType === value} onClick={() => search({ ...draft, objectType: value })}>{label}</button>)}</div>
      <form className="pd-audit-filters" onSubmit={event => { event.preventDefault(); search(); }}>
        <label>操作者<input className="pd-input" aria-label="操作者" placeholder="姓名或账号" {...field('actor')} /></label>
        <label>记录类型<select className="pd-select" aria-label="记录类型" {...field('objectType')}>{Object.entries(TYPES).map(([key, value]) => <option key={key} value={key}>{value}</option>)}</select></label>
        <label>动作<input className="pd-input" aria-label="动作" placeholder="如：修改、提交、删除" {...field('action')} /></label>
        <label>操作结果<select className="pd-select" aria-label="操作结果" {...field('result')}><option value="">全部结果</option><option value="SUCCESS">成功</option><option value="FAILED">失败</option></select></label>
        <label>开始日期<input className="pd-input" aria-label="开始日期" type="date" {...field('from')} /></label>
        <label>结束日期<input className="pd-input" aria-label="结束日期" type="date" {...field('to')} /></label>
        <div className="pd-actions"><button className="pd-btn primary" type="submit"><Icon name="search" />查询记录</button><button className="pd-btn" type="button" onClick={() => { setDraft(EMPTY); setFilter({ ...EMPTY }); setPage(1); setError(''); }}>重置筛选</button></div>
      </form>
      {error && <p className="pd-inline-error" role="alert">{error}</p>}
    </section>
    <section className="pd-card pd-audit-list"><div className="pd-card-head"><h3 className="pd-sub">记录列表 <span className="pd-count">共 {list.data?.total ?? 0} 条</span></h3><button className="pd-btn" disabled={list.loading} onClick={list.reload}>刷新</button></div>
      {list.loading ? <Skeleton rows={5} /> : list.error ? <div role="alert" className="pd-inline-error">{list.error}<button className="pd-btn" onClick={list.reload}>重试</button></div> : <>
        <div className="pd-scroll-x"><table className="pd-table"><thead><tr><th>操作者 / 时间</th><th>动作</th><th>业务对象</th><th>结果</th><th>操作</th></tr></thead><tbody>{list.data?.items.map(row => <tr key={row.id}>
          <td><div className="pd-member-copy"><b>{row.actor}</b><small>{formatTime(row.time)}</small></div></td><td>{row.action}</td>
          <td><div className="pd-member-copy"><b>{TYPES[row.objectType ?? ''] ?? row.target}{row.objectId ? ' #' + row.objectId : ''}</b><small>{row.summary || '未提供操作摘要'}</small></div></td>
          <td><span className={'pd-result ' + (resultLabel(row.result) === '成功' ? 'ok' : 'failed')}>{resultLabel(row.result)}</span></td><td><button className="pd-btn text" onClick={() => setSelected(String(row.id))}>查看详情</button></td>
        </tr>)}</tbody></table></div>
        {!list.data?.total && <Empty title="暂无匹配的操作记录" hint="可调整筛选条件；新发生的操作会在这里显示。" />}
        <div className="pd-pagination"><span>第 {page} / {pages} 页 · 共 {list.data?.total ?? 0} 条</span><div className="pd-actions"><button className="pd-btn" disabled={page <= 1} onClick={() => setPage(p => p - 1)}>上一页</button><button className="pd-btn" disabled={page >= pages} onClick={() => setPage(p => p + 1)}>下一页</button></div></div>
      </>}
    </section>
    {selected && <Modal title="操作记录详情" onClose={() => setSelected(null)}><AuditDetails id={selected} /></Modal>}
  </div>;
}

function AuditDetails({ id }: { id: string }) {
  const detail = useAsync(() => api.getAudit(id), [id]);
  if (detail.loading) return <Skeleton rows={4} />;
  if (detail.error) return <div className="pd-inline-error" role="alert">{detail.error}<button className="pd-btn" onClick={detail.reload}>重试</button></div>;
  const row = detail.data!;
  return <><dl className="pd-record-details">{[['记录编号', row.id], ['操作者', row.actor], ['业务类型', TYPES[row.objectType ?? ''] ?? row.objectType], ['业务编号', row.objectId], ['动作', row.action], ['操作对象', row.target], ['发生时间', formatTime(row.time)], ['结果', resultLabel(row.result)], ['来源', SOURCES[row.source ?? ''] ?? row.source], ['操作摘要', row.summary]].map(([label, value]) => <div key={label}><dt>{label}</dt><dd>{value || '未记录'}</dd></div>)}</dl>
    <h3 className="pd-sub pd-detail-heading">字段变化</h3>{row.changes.length ? <div className="pd-scroll-x"><table className="pd-table"><thead><tr><th>字段</th><th>变更前</th><th>变更后</th></tr></thead><tbody>{row.changes.map((change, index) => <tr key={index}><td>{FIELDS[change.field] ?? change.field}</td><td>{change.before == null ? '—' : VALUES[change.before] ?? change.before}</td><td>{change.after == null ? '—' : VALUES[change.after] ?? change.after}</td></tr>)}</tbody></table></div> : <p className="pd-hint">此记录没有字段变化详情。</p>}
    <p className="pd-field-hint">正文仅记录是否发生修改，本页记录不用于还原数据。</p>
  </>;
}
