// ========== Shared CSS ==========

/** Shared CSS for diff highlighting (changed/removed elements) */
export const sharedDiffCSS = `
  .changed-element {
    background: var(--vscode-diffEditor-insertedTextBackground, rgba(0, 255, 0, 0.2));
    border-radius: 3px;
    padding: 2px 4px;
    box-shadow: 0 0 0 2px var(--vscode-diffEditor-insertedLineBackground, rgba(0, 255, 0, 0.3));
    color: var(--vscode-editor-foreground);
  }
  .removed-element {
    background: var(--vscode-diffEditor-removedTextBackground, rgba(255, 0, 0, 0.2));
    border-radius: 3px;
    padding: 2px 4px;
    box-shadow: 0 0 0 2px var(--vscode-diffEditor-removedLineBackground, rgba(255, 0, 0, 0.3));
    color: var(--vscode-editor-foreground);
    text-decoration: line-through;
    opacity: 0.8;
  }
`;

/** Shared CSS for list rendering */
export const sharedListCSS = `
  ul.list {
    margin: 4px 0 0 0;
    padding: 0;
    list-style: none;
  }
  ul.list li {
    font-family: var(--mono, ui-monospace, SFMono-Regular, Menlo, Consolas, "Liberation Mono", monospace);
    font-size: 11px;
    line-height: 1.4;
    background: transparent;
    color: var(--vscode-foreground);
    margin: 2px 0;
  }
`;

/** Generate filter panel CSS with a given prefix (e.g., 'mc' or 'cex') */
export function generateFilterPanelCSS(prefix: string): string {
  return `
  .${prefix}-filter-active {
    color: var(--vscode-notificationsInfoIcon-foreground, #3794ff);
    font-weight: 600;
  }
  .${prefix}-filter-panel {
    position: fixed;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    z-index: 1000;
    min-width: 250px;
    max-width: 90vw;
    max-height: 400px;
    background: var(--vscode-editorWidget-background);
    border: 1px solid var(--vscode-panel-border);
    border-radius: 8px;
    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
    overflow: hidden;
  }
  .${prefix}-filter-backdrop {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.3);
    z-index: 999;
  }
  .${prefix}-filter-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 8px 12px;
    border-bottom: 1px solid var(--vscode-panel-border);
    font-weight: 600;
    font-size: 12px;
  }
  .${prefix}-filter-actions {
    display: flex;
    gap: 8px;
  }
  .${prefix}-filter-action {
    font-size: 10px;
    color: var(--vscode-textLink-foreground);
    background: none;
    border: none;
    cursor: pointer;
    padding: 2px 4px;
  }
  .${prefix}-filter-action:hover {
    text-decoration: underline;
  }
  .${prefix}-filter-close {
    font-size: 18px;
    line-height: 1;
    color: var(--vscode-foreground);
    background: none;
    border: none;
    cursor: pointer;
    padding: 0 4px;
    margin-left: 8px;
    opacity: 0.7;
  }
  .${prefix}-filter-close:hover {
    opacity: 1;
  }
  .${prefix}-filter-list {
    padding: 8px;
    max-height: 240px;
    overflow-y: auto;
  }
  .${prefix}-filter-item {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 4px;
    cursor: pointer;
    border-radius: 3px;
    font-size: 12px;
  }
  .${prefix}-filter-item:hover {
    background: var(--vscode-list-hoverBackground);
  }
  .${prefix}-filter-item input {
    margin: 0;
  }
  .${prefix}-filter-item code {
    font-size: 11px;
  }
`;
}

/** Generate JSON view CSS with a given prefix (e.g., 'mc' or 'vr') */
export function generateJsonViewCSS(prefix: string): string {
  return `
  .${prefix}-json-view {
    position: relative;
    background: var(--vscode-editor-background);
    border: 1px solid var(--vscode-panel-border);
    border-radius: 6px;
    max-height: 600px;
  }
  .${prefix}-json-content {
    padding: 12px;
    font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, "Liberation Mono", monospace;
    font-size: 12px;
    white-space: pre;
    overflow: auto;
    max-height: 600px;
  }
  .${prefix}-copy-button {
    position: absolute;
    top: 8px;
    right: 8px;
    display: inline-flex;
    align-items: center;
    gap: 4px;
    font-size: 11px;
    color: var(--vscode-button-foreground);
    background: var(--vscode-button-background);
    border: none;
    border-radius: 4px;
    padding: 4px 8px;
    cursor: pointer;
    transition: background 0.15s, opacity 0.15s;
    opacity: 0;
  }
  .${prefix}-json-view:hover .${prefix}-copy-button,
  .${prefix}-json-content:hover ~ .${prefix}-copy-button {
    opacity: 1;
  }
  .${prefix}-copy-button:hover {
    background: var(--vscode-button-hoverBackground);
  }
  .${prefix}-copy-button svg {
    width: 14px;
    height: 14px;
  }
`;
}

/** Generate toggle link CSS with a given prefix (e.g., 'mc' or 'vr') */
export function generateToggleLinkCSS(prefix: string): string {
  return `
  .${prefix}-toggle-link {
    font-size: 11px;
    color: var(--vscode-textLink-foreground);
    cursor: pointer;
    text-decoration: none;
    background: none;
    border: none;
    padding: 2px 6px;
    border-radius: 3px;
  }
  .${prefix}-toggle-link:hover {
    text-decoration: underline;
    background: var(--vscode-toolbar-hoverBackground);
  }
`;
}

/** Generate instantiation row CSS with a given prefix (e.g., 'mc' or 'cex') */
export function generateInstantiationCSS(prefix: string): string {
  return `
  .${prefix}-instantiation-row {
    display: flex;
    align-items: center;
    gap: 12px;
    margin-bottom: 12px;
    padding: 8px 12px;
    background: var(--vscode-editorWidget-background);
    border: 1px solid var(--vscode-panel-border);
    border-radius: 6px;
  }
  .${prefix}-instantiation-label {
    font-size: 10px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    color: var(--vscode-descriptionForeground);
    flex-shrink: 0;
  }
  .${prefix}-instantiation-values {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
  }
  .${prefix}-instantiation-item {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 3px 10px;
    background: var(--vscode-activityBarBadge-background);
    color: var(--vscode-activityBarBadge-foreground);
    border-radius: 12px;
    font-size: 12px;
  }
  .${prefix}-instantiation-key {
    color: var(--vscode-activityBarBadge-foreground);
    font-weight: 500;
  }
  .${prefix}-instantiation-eq {
    color: var(--vscode-activityBarBadge-foreground);
    opacity: 0.6;
  }
  .${prefix}-instantiation-val {
    color: var(--vscode-activityBarBadge-foreground);
    font-weight: 500;
  }
`;
}
