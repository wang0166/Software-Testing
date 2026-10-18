import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from 'react';

// ---------- Toast：替代 alert，右下角浮出更精致 ----------
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
      <div className="pd-toasts">
        {items.map((t) => (
          <div key={t.id} className={`pd-toast ${t.kind}`}><span className="ico">{icon[t.kind]}</span>{t.text}</div>
        ))}
      </div>
    </ToastContext.Provider>
  );
}

// ---------- Modal + Confirm ----------
export function Modal({ title, onClose, children, footer }: { title: string; onClose: () => void; children: React.ReactNode; footer?: React.ReactNode }) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose]);
  return (
    <div className="pd-mask" onClick={onClose}>
      <div className="pd-modal" onClick={(e) => e.stopPropagation()}>
        <div className="pd-modal-head">
          <span>{title}</span>
          <button className="pd-btn ghost" onClick={onClose} aria-label="关闭">✕</button>
        </div>
        <div className="pd-modal-body">{children}</div>
        {footer && <div className="pd-modal-foot">{footer}</div>}
      </div>
    </div>
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
          <p style={{ margin: 0, color: '#4a4770' }}>{state.opts.desc ?? '确定继续吗？'}</p>
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
      <span className="emoji">{emoji}</span>
      <div style={{ fontWeight: 800, color: '#4a4770' }}>{title}</div>
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
