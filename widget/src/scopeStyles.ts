/** Scope our flat class-selector rules, including rules inside media blocks.
 * At-rules and keyframe steps remain unchanged. This helper is for these local
 * stylesheets, not a parser for arbitrary user CSS.
 */
export function scopeStyles(root: string, css: string): string {
  return css.replace(/\/\*[\s\S]*?\*\//g, '').replace(/(^|(?<=[{}]))(\s*)([^{}]+)\{/g, (rule, boundary, whitespace, selectors: string) => {
    if (!selectors.trimStart().startsWith('.')) return rule;
    const scoped = selectors.split(',').map(selector => {
      const trimmed = selector.trim();
      return trimmed.startsWith(root) ? trimmed : `${root} ${trimmed}`;
    }).join(', ');
    return `${boundary}${whitespace}${scoped} {`;
  });
}
