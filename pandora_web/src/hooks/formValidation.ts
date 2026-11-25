import { useState } from 'react';

export function useFormValidation<Field extends string>(formId: string, errors: Partial<Record<Field, string>>) {
  const [touched, setTouched] = useState<Partial<Record<Field, boolean>>>({});
  const [submitted, setSubmitted] = useState(false);
  const error = (name: Field) => (submitted || touched[name]) ? errors[name] : undefined;
  const errorId = (name: Field) => `${formId}-${name}-error`;
  return {
    error, errorId,
    field: (name: Field) => ({
      name,
      onBlur: () => setTouched(current => ({ ...current, [name]: true })),
      'aria-invalid': !!error(name),
      'aria-describedby': error(name) ? errorId(name) : undefined,
    }),
    showAll: () => setSubmitted(true),
    reset: () => { setTouched({}); setSubmitted(false); },
    focus: (name: Field) => {
      const form = document.getElementById(formId) as HTMLFormElement | null;
      const field = form?.elements.namedItem(name);
      if (field instanceof HTMLElement) field.focus();
    },
  };
}
