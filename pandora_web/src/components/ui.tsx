import { createContext, useCallback, useContext, useEffect, useId, useLayoutEffect, useMemo, useRef, useState } from 'react';
import { createPortal } from 'react-dom';

// ---------- Toast：统一操作反馈 ----------
type ToastKind = 'ok' | 'err' | 'info';
interface ToastItem { id: number; kind: ToastKind; text: string }
interface ToastCtx { push: (kind: ToastKind, text: string) => void }
const ToastContext = createContext<ToastCtx>({ push: () => {} });
export const useToast = () => useContext(ToastContext);

export function ToastProvider({ children }: { children: React.ReactNode }) {
  const [items, setItems] = useState<ToastItem[]>([]);
  const seq = useRef(0);
  const push = useCallback((kind: ToastKind, text: string) => {
    const id = ++seq.current;
    setItems((l) => [...l, { id, kind, text }]);
    setTimeout(() => setItems((l) => l.filter((t) => t.id !== id)), 2600);
  }, []);
  const ctx = useMemo(() => ({ push }), [push]);
  const icon = { ok: '✓', err: '✕', info: 'ℹ' };
  return (
    <ToastContext.Provider value={ctx}>
      {children}
      {createPortal(<div className="pd-toasts" aria-live="polite" aria-atomic="false">
        {items.map((t) => (
          <div key={t.id} className={`pd-toast ${t.kind}`}><span className="ico">{icon[t.kind]}</span>{t.text}</div>
        ))}
      </div>, document.body)}
    </ToastContext.Provider>
  );
}

// ---------- Modal + Confirm ----------
const modalStack: HTMLElement[] = [];
let originalOverflow = '';
let originalInert = false;
export function Modal({ title, onClose, children, footer }: { title: string; onClose: () => void; children: React.ReactNode; footer?: React.ReactNode }) {
  const titleId = useId();
  const dialog = useRef<HTMLDivElement>(null);
  const close = useRef(onClose);
  close.current = onClose;
  useLayoutEffect(() => {
    const node = dialog.current!;
    const previousFocus = document.activeElement as HTMLElement | null;
    const root = document.getElementById('root');
    if (!modalStack.length) {
      originalOverflow = document.body.style.overflow;
      originalInert = root?.inert ?? false;
      document.body.style.overflow = 'hidden';
      if (root) root.inert = true;
    }
    modalStack.push(node);
    const controls = () => [...node.querySelectorAll<HTMLElement>('button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), a[href], [tabindex="0"]')].filter(element => element.getClientRects().length > 0);
    const initial = node.querySelector<HTMLElement>('input:not([disabled]), select:not([disabled]), textarea:not([disabled])') ?? controls()[0] ?? node;
    initial.focus();
    const onKey = (event: KeyboardEvent) => {
      if (modalStack[modalStack.length - 1] !== node) return;
      if (event.key === 'Escape') { event.preventDefault(); event.stopPropagation(); close.current(); }
      if (event.key === 'Tab') {
        const items = controls(), first = items[0] ?? node, last = items[items.length - 1] ?? node;
        if (event.shiftKey && (document.activeElement === first || !node.contains(document.activeElement))) { event.preventDefault(); last.focus(); }
        else if (!event.shiftKey && (document.activeElement === last || !node.contains(document.activeElement))) { event.preventDefault(); first.focus(); }
      }
    };
    const onFocus = (event: FocusEvent) => { if (modalStack[modalStack.length - 1] === node && !node.contains(event.target as Node)) (controls()[0] ?? node).focus(); };
    document.addEventListener('keydown', onKey);
    document.addEventListener('focusin', onFocus);
    return () => {
      document.removeEventListener('keydown', onKey);
      document.removeEventListener('focusin', onFocus);
      modalStack.splice(modalStack.indexOf(node), 1);
      if (!modalStack.length) { document.body.style.overflow = originalOverflow; if (root) root.inert = originalInert; }
      if (previousFocus?.isConnected) previousFocus.focus();
    };
  }, []);
  // 渲染到 body，避免页面动画或滚动容器限制 fixed 遮罩的范围。
  return createPortal(
    <div className="pd-mask" onClick={onClose}>
      <div className="pd-modal" role="dialog" aria-modal="true" aria-labelledby={titleId} tabIndex={-1} ref={dialog} onClick={(e) => e.stopPropagation()}>
        <div className="pd-modal-head">
          <span id={titleId}>{title}</span>
          <button className="pd-btn ghost" type="button" onClick={onClose} aria-label="关闭">×</button>
        </div>
        <div className="pd-modal-body">{children}</div>
        {footer && <div className="pd-modal-foot">{footer}</div>}
      </div>
    </div>, document.body
  );
}

interface ConfirmCtx { confirm: (opts: { title: string; desc?: string; okText?: string; danger?: boolean }) => Promise<boolean> }
const ConfirmContext = createContext<ConfirmCtx>({ confirm: async () => false });
export const useConfirm = () => useContext(ConfirmContext);

export function ConfirmProvider({ children }: { children: React.ReactNode }) {
  const [state, setState] = useState<{ open: boolean; opts: { title: string; desc?: string; okText?: string; danger?: boolean }; resolve?: (v: boolean) => void }>({ open: false, opts: { title: '' } });
  const confirm = useCallback((opts: { title: string; desc?: string; okText?: string; danger?: boolean }) => new Promise<boolean>((resolve) => setState({ open: true, opts, resolve })), []);
  const close = (v: boolean) => { state.resolve?.(v); setState((s) => ({ ...s, open: false })); };
  const ctx = useMemo(() => ({ confirm }), [confirm]);
  return (
    <ConfirmContext.Provider value={ctx}>
      {children}
      {state.open && (
        <Modal
          title={state.opts.title}
          onClose={() => close(false)}
          footer={
            <>
              <button className="pd-btn" onClick={() => close(false)}>取消</button>
              <button className={`pd-btn ${state.opts.danger ? 'danger' : 'primary'}`} onClick={() => close(true)}>{state.opts.okText ?? '确定'}</button>
            </>
          }
        >
          <p style={{ margin: 0, color: 'var(--sub)' }}>{state.opts.desc ?? '确定继续吗？'}</p>
        </Modal>
      )}
    </ConfirmContext.Provider>
  );
}

// ---------- 数据徽章卡 ----------
export function StatCard({ icon, value, label, tone = 1, delay = 0, spark }: { icon: string; value: React.ReactNode; label: string; tone?: 1 | 2 | 3 | 4; delay?: number; spark?: string }) {
  return (
    <div className={`pd-stat c${tone} pd-fade-up`} style={{ animationDelay: `${delay}s` }}>
      <div className="ico">{icon}</div>
      <div className="num">{value}</div>
      <div className="label">{label}</div>
      {spark && <div className="spark">{spark}</div>}
    </div>
  );
}

// ---------- 环形进度 ----------
export function Ring({ percent, label }: { percent: number; label: string }) {
  const p = Math.min(100, Math.max(0, percent));
  return (
    <div className="pd-ring" style={{ ['--p' as string]: p }}>
      <div className="core"><b>{p}%</b><span>{label}</span></div>
    </div>
  );
}

// ---------- 空态 ----------
export function Empty({ emoji = '🗂️', title, hint }: { emoji?: string; title: string; hint?: string }) {
  return (
    <div className="pd-empty">
      <span className="empty-mark" aria-hidden="true">—</span>
      <div style={{ fontWeight: 500, color: 'var(--sub)' }}>{title}</div>
      {hint && <div className="pd-hint" style={{ margin: '6px 0 0' }}>{hint}</div>}
    </div>
  );
}

// ---------- 骨架 ----------
export function Skeleton({ rows = 3 }: { rows?: number }) {
  return (
    <div className="pd-card">
      {Array.from({ length: rows }).map((_, i) => (
        <div key={i} className="pd-skeleton" style={{ height: 18, marginBottom: i === rows - 1 ? 0 : 12 }} />
      ))}
    </div>
  );
}
