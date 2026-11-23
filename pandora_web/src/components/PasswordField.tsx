import { useState } from 'react';
import { generateStrongPassword, passwordError } from '../utils/userValidation';
import { useToast } from './ui';

export function PasswordField({ id, label, value, onChange, onBlur, error }: {
  id: string;
  label: string;
  value: string;
  onChange: (value: string) => void;
  onBlur: () => void;
  error?: string;
}) {
  const [visible, setVisible] = useState(false);
  const toast = useToast();
  const copy = async () => {
    try { await navigator.clipboard.writeText(value); toast.push('ok', '密码已复制，请通过安全渠道交付'); }
    catch { toast.push('err', '无法复制，可显示后手动复制'); }
  };
  return <div className="pd-form pd-password-control">
    <label htmlFor={id}>{label}<span className="pd-required">*</span></label>
    <div className="pd-password-field">
      <input id={id} className="pd-input" name="password" required aria-label={label} aria-invalid={!!error}
        aria-describedby={`${id}-hint${error ? ` ${id}-error` : ''}`} type={visible ? 'text' : 'password'}
        autoComplete="new-password" spellCheck={false} value={value} onChange={e => onChange(e.target.value)} onBlur={onBlur} />
      <button className="pd-btn" type="button" aria-pressed={visible} onClick={() => setVisible(current => !current)}>{visible ? '隐藏密码' : '显示密码'}</button>
    </div>
    {error && <small id={`${id}-error`} className="pd-field-error" role="alert">{error}</small>}
    <div className="pd-actions pd-password-actions">
      <button className="pd-btn" type="button" onClick={() => { onChange(generateStrongPassword()); setVisible(false); }}>{value ? '重新生成强密码' : '生成强密码'}</button>
      <button className="pd-btn text" type="button" disabled={!!passwordError(value)} onClick={copy}>复制密码</button>
    </div>
    <p id={`${id}-hint`} className="pd-field-hint">至少 12 位，包含大小写字母、数字和符号。请通过安全渠道交付。</p>
  </div>;
}
