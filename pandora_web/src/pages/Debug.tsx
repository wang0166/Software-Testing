import { useEffect, useRef, useState } from 'react';
import { API_BASE, isMock } from '../api/http';
import { DEBUG_ENDPOINTS } from '../api/debug';
import { initialAutoReport, runAutomaticDebug, type AutoReport, type AutoStatus } from '../api/debugAutomation';
import './Debug.css';

const STATUS: Record<AutoStatus, string> = { pending: '未开始', running: '进行中', passed: '通过', failed: '失败', skipped: '未验证' };
export function Debug() {
  const [report, setReport] = useState<AutoReport>(initialAutoReport);
  const [running, setRunning] = useState(false);
  const [stopping, setStopping] = useState(false);
  const [error, setError] = useState('');
  const lock = useRef(false);
  const stop = useRef(false);
  const mounted = useRef(true);
  useEffect(() => { mounted.current = true; return () => { mounted.current = false; stop.current = true; }; }, []);
  useEffect(() => {
    const leaving = (event: BeforeUnloadEvent) => { event.preventDefault(); event.returnValue = ''; };
    if (running) window.addEventListener('beforeunload', leaving);
    return () => window.removeEventListener('beforeunload', leaving);
  }, [running]);
  const start = async () => {
    if (lock.current || isMock()) return;
    lock.current = true; stop.current = false; setRunning(true); setStopping(false); setError(''); setReport(initialAutoReport());
    try {
      const result = await runAutomaticDebug({
        onUpdate: next => { if (mounted.current) setReport(next); },
        shouldStop: () => stop.current,
      });
      if (mounted.current) setReport(result);
    } catch (cause) {
      if (mounted.current) setError(cause instanceof Error ? cause.message : '自动测试失败');
    } finally {
      lock.current = false;
      if (mounted.current) { setRunning(false); setStopping(false); }
    }
  };
  const passed = report.checks.filter(item => item.status === 'passed').length;
  const failed = report.checks.filter(item => item.status === 'failed').length;
  const skipped = report.checks.filter(item => item.status === 'skipped').length;
  const settled = passed + failed + skipped;
  const routes = new Set(DEBUG_ENDPOINTS.map(item => item.method + ' ' + item.path)).size;
  return <div className="pd-debug">
    <div className="pd-hero"><div><span className="pd-eyebrow">开发工具</span><h2>接口联调</h2><p>一键执行管理员端全部接口的查询、写入、回查和测试数据收尾。</p></div><span className="pd-readonly">{routes} 个接口 · {DEBUG_ENDPOINTS.length} 个检查项</span></div>
    <section className="pd-card">
      <div className="pd-card-head"><div><h3 className="pd-sub">自动化测试</h3><p className="pd-hint">自动取编号和填写测试参数，当前请求前缀 <code>{API_BASE}</code>。</p></div>
        <div className="pd-actions"><button className="pd-btn primary" disabled={running || isMock()} onClick={start}>{running ? report.phase === 'cleanup' ? '正在停用账号并清理组织…' : '正在自动测试…' : '一键自动测试全部接口'}</button>
          {running && <button className="pd-btn" disabled={stopping || report.phase === 'cleanup'} onClick={() => { stop.current = true; setStopping(true); }}>{stopping ? '等待当前请求结束并清理…' : '停止并清理'}</button>}</div>
      </div>
      <div className="pd-debug-impact"><b>本次测试数据</b><p>将在当前后端创建一个专属联调账号和一条测试事件。账号在测试结束后停用，事件保留“接口联调测试”标记；现有接口不支持删除这两类记录。临时部门和团队会自动删除，现有员工资料及当前管理员会话不参与写入测试。</p></div>
      {isMock() && <p className="pd-inline-error">演示模式不能验证真实接口，请使用真实管理员账号重新登录。</p>}
      {error && <p className="pd-inline-error" role="alert">{error}</p>}
      <div className="pd-debug-counts" aria-live="polite"><span>已完成 <b>{settled} / {report.checks.length}</b></span><span className="success">通过 {passed}</span><span className="failure">失败 {failed}</span><span>未验证 {skipped}</span></div>
      <progress className="pd-debug-progress" aria-label="接口测试进度" value={settled} max={report.checks.length} />
      <p className="pd-field-hint">{running ? '顺序执行存在依赖的接口，测试中断也会尝试收尾。' : report.phase === 'complete' ? '本轮已结束。未验证项不计为通过；请同时查看下方保留记录和清理结果。' : '登录、改密、启停只使用本次创建的测试账号，注销不会退出当前管理员。没有真实日志／任务记录时，详情检查会说明原因。'}</p>
    </section>
    <section className="pd-card"><div className="pd-card-head"><h3 className="pd-sub">测试报告</h3><span className="pd-hint">{running ? report.phase === 'cleanup' ? '正在收尾' : '正在测试' : report.phase === 'complete' ? '已结束' : '等待开始'}</span></div>
      <div className="pd-scroll-x"><table className="pd-table pd-debug-table"><thead><tr><th>模块 / 检查项</th><th>接口</th><th>结果</th><th>耗时</th><th>检查详情</th></tr></thead><tbody>{DEBUG_ENDPOINTS.map(endpoint => {
        const result = report.checks.find(item => item.id === endpoint.id)!;
        return <tr key={endpoint.id} data-check={endpoint.id}><td><div className="pd-member-copy"><b>{endpoint.name}</b><small>{endpoint.group}</small></div></td>
          <td><span className={'pd-debug-method ' + endpoint.method.toLowerCase()}>{endpoint.method}</span> <code>{endpoint.path}</code></td>
          <td><span className={'pd-debug-status ' + result.status}>{STATUS[result.status]}</span><p className="pd-debug-message">{result.message}</p></td>
          <td>{result.checks ? result.elapsed + ' ms' : '—'}</td><td>{'data' in result ? <details><summary>查看脱敏结果</summary><pre className="pd-debug-json">{JSON.stringify(result.data, null, 2)}</pre></details> : '—'}</td></tr>;
      })}</tbody></table></div>
    </section>
    {(report.retained.length > 0 || report.notes.length > 0) && <section className="pd-card" aria-label="测试数据收尾">
      <h3 className="pd-sub">保留记录与清理结果</h3>
      {report.retained.length > 0 && <div className="pd-scroll-x"><table className="pd-table"><thead><tr><th>测试记录</th><th>编号</th><th>状态</th></tr></thead><tbody>{report.retained.map(item => <tr key={item.kind + item.id}><td>{item.kind}</td><td>{item.id}</td><td>{item.state}</td></tr>)}</tbody></table></div>}
      {report.notes.map(note => <p key={note} className="pd-inline-error">{note}</p>)}
    </section>}
  </div>;
}
