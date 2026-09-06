import {sharedDiffCSS, sharedListCSS, generateFilterPanelCSS, generateJsonViewCSS, generateToggleLinkCSS, generateInstantiationCSS} from './sharedStyles';
import {scopeStyles} from './scopeStyles';

export const styles = scopeStyles('.mc-root', `
    .mc-root {
      font-family: system-ui, -apple-system, sans-serif;
      max-width: 100%;
      overflow: auto;
    }
    .mc-trace.vertical {
      display: flex;
      flex-direction: column;
      gap: 8px;
      padding: 8px;
    }
    .mc-trace.horizontal {
      display: flex;
      flex-direction: row;
      gap: 8px;
      padding: 8px;
      overflow-x: auto;
    }
    .mc-summary {
      margin: 12px 8px;
      padding: 8px 12px;
      background: var(--vscode-editorWidget-background);
      border: 1px solid var(--vscode-panel-border);
      border-radius: 4px;
      max-width: 720px;
    }
    .state-card {
      --border: var(--vscode-panel-border);
      --header: var(--vscode-editorGroupHeader-tabsBackground);
      --mono: ui-monospace, SFMono-Regular, Menlo, Consolas, "Liberation Mono", monospace;
      background: var(--vscode-editorWidget-background);
      border: 1px solid var(--border);
      border-radius: 6px;
      min-width: 320px;
      max-width: 720px;
      box-shadow: 0 1px 2px rgba(0,0,0,.08);
      overflow: hidden;
    }
    .state-card.is-highlighted {
      outline: 2px solid var(--vscode-editor-selectionHighlightBorder);
      box-shadow: 0 0 0 3px var(--vscode-editor-selectionBackground);
    }
    .state-card.is-failing {
      outline: 2px solid var(--vscode-inputValidation-errorBorder);
      box-shadow: 0 0 0 3px var(--vscode-inputValidation-errorBackground);
    }
    .state-card.is-failing .state-header {
      background: var(--vscode-inputValidation-errorBackground);
    }
    .failing-badge {
      display: inline-block;
      font-family: var(--mono);
      font-size: 10px;
      font-weight: 600;
      background: var(--vscode-inputValidation-errorBorder);
      color: var(--vscode-editor-background);
      border-radius: 3px;
      padding: 2px 6px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .state-header {
      background: var(--header);
      border-bottom: 1px solid var(--border);
      padding: 6px 10px;
      display: flex;
      align-items: center;
      gap: 8px;
      font-weight: 600;
      cursor: pointer;
    }
    .state-id {
      font-size: 12px;
      color: var(--vscode-descriptionForeground);
      margin-left: auto;
    }
    .state-toggle { font-size: 12px; color: var(--vscode-descriptionForeground); user-select: none; }
    .action-chip {
      display: inline-block;
      font-family: var(--mono);
      font-size: 11px;
      font-weight: normal;
      background: var(--vscode-activityBarBadge-background);
      color: var(--vscode-activityBarBadge-foreground);
      border: 1px solid var(--vscode-activityBarBadge-foreground);
      border-radius: 999px;
      padding: 2px 8px;
      line-height: 1.4;
    }
    .state-body { padding: 10px; }
    .kv-table {
      border: 1px solid var(--border);
      border-radius: 4px;
      overflow: hidden;
    }
    .kv-row {
      display: grid;
      grid-template-columns: 1fr auto 2fr;
      gap: 8px;
      padding: 4px 10px;
      align-items: baseline;
      border-bottom: 1px solid var(--vscode-panel-border);
      background: var(--vscode-editor-background);
      transition: background-color .15s ease, border-left-color .15s ease;
      border-left: 3px solid transparent;
    }
    .kv-row:last-child { border-bottom: none; }
    .kv-row.changed {
      background: var(--vscode-editor-findMatchHighlightBackground);
      border-left: 3px solid var(--vscode-editor-findMatchHighlightBorder);
      color: var(--vscode-editor-foreground);
    }
    ${sharedDiffCSS}
    .kv-key {
      font-family: var(--mono);
      background: transparent;
      word-break: break-all;
      font-size: 11px;
    }
    .kv-sep { color: var(--vscode-descriptionForeground); background: transparent; }
    .kv-val {
      font-family: var(--mono);
      font-size: 11px;
      background: transparent;
      word-break: break-all;
      display: flex; align-items: flex-start; gap: 6px;
    }
    .kv-toggle {
      border: none; background: transparent; font-size: 12px; line-height: 1;
      cursor: pointer; color: var(--vscode-descriptionForeground); padding: 0 2px;
    }
    .kv-val.collapsed .kv-content code {
      white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 100%;
    }
    ${sharedListCSS}
    code {
      background: transparent;
      color: var(--vscode-foreground);
      padding: 2px 4px;
      border-radius: 3px;
      font-family: var(--mono);
    }
    .kv-val.collapsed .kv-content code {
      white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 100%;
    }
    .kv-content { display: block; }
    .action-chip { cursor: help; }
    .result-header {
      display: flex;
      align-items: center;
      gap: 8px;
      padding: 12px 16px;
      margin: 8px;
      border-radius: 6px;
      font-weight: 600;
      flex-wrap: wrap;
      max-width: 720px;
    }
    .result-violation {
      background: var(--vscode-inputValidation-errorBackground);
      border: 1px solid var(--vscode-inputValidation-errorBorder);
      color: var(--vscode-inputValidation-errorForeground, var(--vscode-foreground));
    }
    .result-success {
      background: var(--vscode-inputValidation-infoBackground);
      border: 1px solid var(--vscode-inputValidation-infoBorder);
      color: var(--vscode-inputValidation-infoForeground, var(--vscode-foreground));
    }
    .result-cancelled {
      background: var(--vscode-inputValidation-warningBackground);
      border: 1px solid var(--vscode-inputValidation-warningBorder);
      color: var(--vscode-inputValidation-warningForeground, var(--vscode-foreground));
    }
    .result-icon { font-size: 18px; }
    .result-label { font-size: 14px; }
    .result-details {
      width: 100%;
      font-size: 12px;
      font-weight: normal;
      color: var(--vscode-descriptionForeground);
      margin-top: 4px;
    }
    .theory-section {
      margin: 8px;
      border: 1px solid var(--vscode-panel-border);
      border-radius: 6px;
      background: var(--vscode-editorWidget-background);
      max-width: 720px;
    }
    .theory-header {
      display: flex;
      align-items: center;
      gap: 6px;
      padding: 8px 12px;
      cursor: pointer;
      font-weight: 600;
      font-size: 13px;
    }
    .theory-toggle {
      font-size: 12px;
      color: var(--vscode-descriptionForeground);
    }
    .theory-label {
      color: var(--vscode-foreground);
    }
    .theory-content {
      padding: 8px;
      border-top: 1px solid var(--vscode-panel-border);
    }
    .mc-toolbar {
      display: flex;
      justify-content: flex-end;
      gap: 12px;
      padding: 4px 8px;
      position: sticky;
      top: 0;
      z-index: 50;
      background: var(--vscode-editorWidget-background);
      border-bottom: 1px solid var(--vscode-panel-border);
    }
    ${generateToggleLinkCSS('mc')}
    ${generateFilterPanelCSS('mc')}
    ${generateInstantiationCSS('mc')}
    .mc-instantiation-row {
      max-width: 720px;
      margin-left: 8px;
      margin-right: 8px;
    }
    .kv-key-clickable {
      cursor: pointer;
    }
    .kv-key-clickable:hover {
      background: var(--vscode-list-hoverBackground);
      border-radius: 3px;
    }
    .mc-json-view {
      margin: 8px;
    }
    ${generateJsonViewCSS('mc')}
    .mc-raw-model {
      margin: 8px;
      padding: 12px;
      background: var(--vscode-editorWidget-background);
      border: 1px solid var(--vscode-panel-border);
      border-radius: 6px;
      overflow: auto;
      max-width: 720px;
    }
`);
