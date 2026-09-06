/** Ignore editor/platform shortcuts and events owned by editable or nested widgets. */
export function shortcutKey(event: {
  key: string; defaultPrevented: boolean; ctrlKey: boolean; metaKey: boolean;
  altKey: boolean; isComposing?: boolean;
  target: { closest?: (selector: string) => unknown } | null;
  currentTarget: unknown;
}): string | null {
  if (event.defaultPrevented || event.ctrlKey || event.metaKey || event.altKey || event.isComposing) return null;
  if (event.target?.closest?.('input, textarea, select, [contenteditable]:not([contenteditable="false"])')) return null;
  if (event.target?.closest?.('[data-veil-shortcuts]') !== event.currentTarget) return null;
  return event.key.toLowerCase();
}
