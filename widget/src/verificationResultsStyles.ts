import {sharedDiffCSS, sharedListCSS, generateFilterPanelCSS, generateJsonViewCSS, generateToggleLinkCSS, generateInstantiationCSS} from './sharedStyles';
import {scopeStyles} from './scopeStyles';

export const styles = scopeStyles('.vr-root', `
    .vr-root {
      --vr-proven: #52c41a; --vr-proven-background: rgba(82, 196, 26, 0.1);
      --vr-disproven: #ff4d4f; --vr-disproven-background: rgba(255, 77, 79, 0.1);
      --vr-error: #fa8c16; --vr-error-background: rgba(250, 140, 22, 0.1);
      --vr-unknown: #1890ff; --vr-unknown-background: rgba(24, 144, 255, 0.1);
      --vr-timeout: #faad14; --vr-timeout-background: rgba(250, 173, 20, 0.1);
      --vr-pending: #d9d9d9; --vr-pending-background: rgba(217, 217, 217, 0.05);

      font-family: system-ui, -apple-system, sans-serif;
      max-width: 100%;
      padding: 16px;
      background: var(--vscode-editor-background);
      border-radius: 8px;
    }

    .vr-filters {
      display: flex;
      gap: 8px;
      margin-bottom: 16px;
      padding: 12px;
      background: var(--vscode-editorWidget-background);
      border: 1px solid var(--vscode-panel-border);
      border-radius: 6px;
      flex-wrap: wrap;
      align-items: center;
    }

    .vr-filter-label {
      font-weight: 600;
      font-size: 14px;
      color: var(--vscode-foreground);
    }

    .vr-filter-button {
      padding: 6px 12px;
      border: 1px solid var(--vscode-panel-border);
      background: var(--vscode-editorWidget-background);
      color: var(--vscode-foreground);
      border-radius: 4px;
      cursor: pointer;
      font-size: 13px;
      transition: all 0.2s;
    }

    .vr-filter-button:hover {
      background: var(--vscode-list-hoverBackground);
      border-color: var(--vscode-panel-border);
    }

    .vr-filter-button.active {
      background: var(--vscode-button-background);
      color: var(--vscode-button-foreground);
      border-color: var(--vscode-button-background);
    }

    .vr-section {
      margin-bottom: 24px;
      background: var(--vscode-editorWidget-background);
      border: 1px solid var(--vscode-panel-border);
      border-radius: 6px;
      overflow: hidden;
    }

    .vr-section-title {
      font-weight: 600;
      font-size: 16px;
      padding: 12px 16px;
      background: var(--vscode-editorGroupHeader-tabsBackground);
      border-bottom: 1px solid var(--vscode-panel-border);
      color: var(--vscode-foreground);
    }

    .vr-section-content {
      padding: 12px;
    }

    .action-section {
      margin-bottom: 12px;
      border: 1px solid var(--vscode-panel-border);
      border-radius: 4px;
      overflow: hidden;
    }

    .action-header {
      display: flex;
      align-items: center;
      gap: 8px;
      padding: 10px 12px;
      background: var(--vscode-editorWidget-background);
      cursor: pointer;
      user-select: none;
      transition: background 0.2s;
    }

    .action-header:hover {
      background: var(--vscode-list-hoverBackground);
    }

    .action-toggle {
      font-size: 12px;
      color: var(--vscode-descriptionForeground);
    }

    .action-name {
      font-weight: 600;
      font-size: 14px;
      color: var(--vscode-foreground);
    }

    .action-properties {
      padding: 8px 12px 8px 32px;
      background: var(--vscode-editorWidget-background);
    }

    .property-row {
      display: flex;
      align-items: center;
      gap: 8px;
      padding: 6px 8px;
      margin: 2px 0;
      border-radius: 4px;
      transition: background 0.15s;
    }

    .property-row:hover {
      background: var(--vscode-list-hoverBackground);
    }

    .property-icon {
      font-size: 16px;
      flex-shrink: 0;
    }

    .property-name {
      font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
      font-size: 13px;
      color: var(--vscode-editor-foreground);
      flex-grow: 1;
    }

    .property-time {
      font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
      font-size: 12px;
      margin-left: auto;
      padding: 2px 6px;
      background: var(--vscode-editorWidget-background);
      color: var(--vscode-descriptionForeground);
      border: 1px solid var(--vscode-panel-border);
      border-radius: 6px;
      white-space: nowrap;
    }

    .time-in-progress {
      opacity: 0.6;
    }

    /* Failure banner */
    .vr-failure-banner {
      display: flex;
      align-items: center;
      gap: 10px;
      padding: 10px 14px;
      margin-bottom: 16px;
      background: rgba(255, 77, 79, 0.08);
      border: 1px solid rgba(255, 77, 79, 0.3);
      border-radius: 6px;
    }

    .vr-failure-banner-icon {
      font-size: 16px;
      flex-shrink: 0;
    }

    .vr-failure-banner-text {
      font-size: 13px;
      color: var(--vscode-foreground);
      flex-grow: 1;
    }

    .vr-failure-banner-action {
      padding: 5px 12px;
      background: var(--vscode-button-secondaryBackground);
      color: var(--vscode-button-secondaryForeground);
      border: 1px solid var(--vscode-panel-border);
      border-radius: 4px;
      cursor: pointer;
      font-size: 12px;
      white-space: nowrap;
      transition: all 0.15s;
    }

    .vr-failure-banner-action:hover {
      background: var(--vscode-button-secondaryHoverBackground);
    }

    .vr-failure-banner-action:disabled {
      opacity: 0.5;
      cursor: not-allowed;
    }

    .vr-failure-banner-dismiss {
      padding: 2px 8px;
      background: transparent;
      border: none;
      color: var(--vscode-descriptionForeground);
      cursor: pointer;
      font-size: 16px;
      line-height: 1;
      border-radius: 3px;
      transition: all 0.15s;
    }

    .vr-failure-banner-dismiss:hover {
      background: var(--vscode-toolbar-hoverBackground);
      color: var(--vscode-foreground);
    }

    .vr-trusted-smt-banner {
      display: flex;
      align-items: center;
      gap: 10px;
      padding: 10px 14px;
      margin-bottom: 16px;
      background: rgba(250, 173, 20, 0.1);
      border: 1px solid rgba(250, 173, 20, 0.35);
      border-radius: 6px;
    }

    .vr-trusted-smt-banner-icon {
      font-size: 16px;
      flex-shrink: 0;
    }

    .vr-trusted-smt-banner-text {
      font-size: 13px;
      color: var(--vscode-foreground);
      flex-grow: 1;
    }

    .vr-trusted-smt-option {
      border: 0;
      padding: 0;
      margin: 0;
      background: none;
      color: var(--vscode-textLink-foreground);
      cursor: pointer;
      font: inherit;
    }

    .vr-trusted-smt-option code {
      color: inherit;
      text-decoration: underline;
      text-underline-offset: 2px;
    }

    .vr-trusted-smt-option:hover code {
      color: var(--vscode-textLink-activeForeground);
    }

    .vr-trusted-smt-option:disabled {
      cursor: not-allowed;
      opacity: 0.7;
    }

    /* Section-level failed count and insert action */
    .action-failed-count {
      font-size: 12px;
      color: #ff4d4f;
      margin-left: 8px;
    }

    .action-insert-failed {
      margin-left: auto;
      padding: 3px 10px;
      background: transparent;
      color: var(--vscode-textLink-foreground);
      border: none;
      cursor: pointer;
      font-size: 12px;
      border-radius: 3px;
      transition: all 0.15s;
    }

    .action-insert-failed:hover {
      background: var(--vscode-toolbar-hoverBackground);
      text-decoration: underline;
    }

    .action-insert-failed:disabled {
      opacity: 0.5;
      cursor: not-allowed;
    }

    /* Visual hint for cmd-clickable property names */
    .property-row.insertable .property-name {
      text-decoration: underline dotted;
      text-underline-offset: 2px;
    }

    .property-row.status-proven {
      background: var(--vr-proven-background);
      border-left: 3px solid var(--vr-proven);
    }

    .property-row.status-disproven {
      background: var(--vr-disproven-background);
      border-left: 3px solid var(--vr-disproven);
    }

    .property-row.status-error {
      background: var(--vr-error-background);
      border-left: 3px solid var(--vr-error);
    }

    .property-row.status-unknown {
      background: var(--vr-unknown-background);
      border-left: 3px solid var(--vr-unknown);
    }

    .property-row.status-timeout {
      background: var(--vr-timeout-background);
      border-left: 3px solid var(--vr-timeout);
    }

    .property-row.status-pending {
      background: var(--vr-pending-background);
      border-left: 3px solid var(--vr-pending);
    }

    .spinner {
      display: inline-block;
      animation: veil-vr-spin 2s linear infinite;
    }

    .spinner-small {
      display: inline-block;
      font-size: 14px;
    }

    @keyframes veil-vr-spin {
      0% { transform: rotate(0deg); }
      100% { transform: rotate(360deg); }
    }

    .vr-empty {
      padding: 24px;
      text-align: center;
      color: var(--vscode-disabledForeground);
      font-style: italic;
    }

    .property-row.expandable:hover {
      background: var(--vscode-list-activeSelectionBackground);
      opacity: 0.9;
    }

    .property-toggle {
      font-size: 12px;
      color: var(--vscode-descriptionForeground);
      margin-right: 4px;
      flex-shrink: 0;
    }

    .counterexample-container {
      margin-left: 32px;
      margin-top: 8px;
      margin-bottom: 8px;
      padding: 12px;
      background: var(--vscode-editorWidget-background);
      border-left: 3px solid #ff4d4f;
      border-radius: 4px;
      overflow-x: auto;
    }

    .counterexample-label {
      font-weight: 600;
      font-size: 12px;
      color: var(--vscode-descriptionForeground);
      margin-bottom: 8px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }

    .counterexample-content {
      font-size: 13px;
      color: var(--vscode-editor-foreground);
    }

    .exceptions-container {
      margin-left: 32px;
      margin-top: 8px;
      margin-bottom: 8px;
      padding: 12px;
      background: var(--vscode-editorWidget-background);
      border-left: 3px solid #fa8c16;
      border-radius: 4px;
      overflow-x: auto;
    }

    .exceptions-label {
      font-weight: 600;
      font-size: 12px;
      color: var(--vscode-descriptionForeground);
      margin-bottom: 8px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }

    .exceptions-content {
      display: flex;
      flex-direction: column;
      gap: 8px;
    }

    .exception-entry {
      display: flex;
      flex-direction: column;
      gap: 4px;
    }

    .exception-source {
      font-size: 11px;
      font-weight: 600;
      color: var(--vscode-descriptionForeground);
      letter-spacing: 0.2px;
      text-transform: uppercase;
    }

    .exception-item {
      margin: 0;
      padding: 8px 12px;
      background: var(--vscode-inputValidation-errorBackground, rgba(250, 140, 22, 0.1));
      border: 1px solid var(--vscode-inputValidation-errorBorder, #fa8c16);
      border-radius: 4px;
      font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, "Liberation Mono", monospace;
      font-size: 12px;
      color: var(--vscode-editor-foreground);
      white-space: pre-wrap;
      word-break: break-word;
      overflow-wrap: break-word;
    }

    .counterexample-column-header {
      text-align: left;
    }

    .counterexample-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 8px;
    }

    .counterexample-toggle {
      display: flex;
      gap: 4px;
    }

    .cex-toggle-btn {
      padding: 2px 8px;
      font-size: 11px;
      font-weight: 500;
      border: 1px solid var(--vscode-panel-border);
      background: var(--vscode-editorWidget-background);
      color: var(--vscode-foreground);
      border-radius: 3px;
      cursor: pointer;
      transition: all 0.15s;
    }

    .cex-toggle-btn:hover {
      background: var(--vscode-list-hoverBackground);
    }

    .cex-toggle-btn.active {
      background: var(--vscode-button-background);
      color: var(--vscode-button-foreground);
      border-color: var(--vscode-button-background);
    }

    .vc-style-badge {
      font-size: 10px;
      font-weight: 600;
      padding: 2px 6px;
      border-radius: 3px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      flex-shrink: 0;
    }

    .tr-badge {
      background: rgba(24, 144, 255, 0.15);
      color: #1890ff;
      border: 1px solid rgba(24, 144, 255, 0.3);
    }

    .tr-badge.tr-running {
      animation: veil-vr-pulse 1.5s ease-in-out infinite;
    }

    .interactive-badge {
      background: rgba(82, 196, 26, 0.15);
      color: #52c41a;
      border: 1px solid rgba(82, 196, 26, 0.3);
    }

    @keyframes veil-vr-pulse {
      0%, 100% {
        opacity: 1;
        background: rgba(24, 144, 255, 0.15);
      }
      50% {
        opacity: 0.7;
        background: rgba(24, 144, 255, 0.3);
      }
    }

    .vr-toolbar {
      display: flex;
      justify-content: flex-end;
      padding: 4px 0;
      margin-bottom: 8px;
    }

    ${generateToggleLinkCSS('vr')}
    ${generateJsonViewCSS('vr')}

    /* Structured counterexample styles */
    .counterexample-toggles {
      display: flex;
      gap: 12px;
      align-items: center;
    }

    .cex-view-toggle {
      font-size: 11px;
      color: var(--vscode-textLink-foreground);
      cursor: pointer;
      text-decoration: none;
      background: none;
      border: none;
      padding: 2px 6px;
      border-radius: 3px;
    }

    .cex-view-toggle:hover {
      text-decoration: underline;
      background: var(--vscode-toolbar-hoverBackground);
    }

    .cex-structured-view {
      font-family: system-ui, -apple-system, sans-serif;
    }

    .cex-header-row {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 12px;
    }

    .cex-header-left {
      display: flex;
      align-items: center;
      gap: 12px;
    }

    .cex-header-right {
      display: flex;
      align-items: center;
      gap: 12px;
    }

    .cex-header-label {
      font-weight: 600;
      font-size: 12px;
      color: var(--vscode-descriptionForeground);
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }

    ${generateInstantiationCSS('cex')}

    .cex-action-chip {
      display: inline-block;
      font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
      font-size: 12px;
      font-weight: 600;
      background: var(--vscode-activityBarBadge-background, #007acc);
      color: var(--vscode-activityBarBadge-foreground, #fff);
      border-radius: 999px;
      padding: 4px 12px;
      line-height: 1.4;
    }

    .cex-states-container {
      display: flex;
      gap: 16px;
      flex-wrap: wrap;
    }

    .cex-states-container.cex-states-stacked {
      flex-direction: column;
    }

    .cex-narrow-action {
      display: flex;
      justify-content: center;
      align-items: center;
      padding: 8px 0;
      width: 100%;
    }

    .cex-action-row {
      display: flex;
      justify-content: center;
      align-items: center;
      padding: 12px 0;
      margin-bottom: 12px;
    }

    .cex-state-panel {
      flex: 1;
      min-width: 280px;
      max-width: 100%;
      background: var(--vscode-editor-background);
      border: 1px solid var(--vscode-panel-border);
      border-radius: 6px;
      overflow: hidden;
    }

    .cex-state-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      font-weight: 600;
      font-size: 12px;
      padding: 8px 12px;
      background: var(--vscode-editorGroupHeader-tabsBackground);
      border-bottom: 1px solid var(--vscode-panel-border);
      color: var(--vscode-foreground);
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }

    .cex-state-status {
      font-size: 10px;
      font-weight: 500;
      text-transform: none;
      letter-spacing: normal;
    }

    .cex-status-valid {
      color: var(--vscode-testing-iconPassed, #4caf50);
    }

    .cex-status-invalid {
      color: var(--vscode-testing-iconFailed, #f44336);
    }

    .cex-property-name {
      font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
      font-weight: 600;
    }

    .cex-state-body {
      padding: 8px;
    }

    .cex-empty-state {
      padding: 12px;
      text-align: center;
      color: var(--vscode-disabledForeground);
      font-style: italic;
      font-size: 12px;
    }

    .cex-kv-table {
      border: 1px solid var(--vscode-panel-border);
      border-radius: 4px;
      overflow: hidden;
    }

    .cex-kv-row {
      display: grid;
      grid-template-columns: minmax(80px, auto) auto 1fr;
      gap: 8px;
      padding: 6px 10px;
      align-items: baseline;
      border-bottom: 1px solid var(--vscode-panel-border);
      background: var(--vscode-editorWidget-background);
      transition: background-color 0.15s ease, border-left-color 0.15s ease;
      border-left: 3px solid transparent;
    }

    .cex-kv-row:last-child {
      border-bottom: none;
    }

    .cex-kv-row.changed {
      background: var(--vscode-editor-findMatchHighlightBackground, rgba(255, 213, 0, 0.15));
      border-left: 3px solid var(--vscode-editor-findMatchHighlightBorder, #ffd500);
    }

    .cex-enum-row {
      grid-template-columns: 1fr;
    }

    .cex-enum-row code {
      background: transparent;
      padding: 0;
      color: var(--vscode-foreground);
      font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
      font-size: 11px;
      word-break: break-all;
    }

    .cex-kv-key {
      font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
      font-size: 11px;
      word-break: break-all;
    }

    .cex-kv-key code {
      background: transparent;
      padding: 0;
      color: var(--vscode-foreground);
    }

    .cex-kv-sep {
      color: var(--vscode-descriptionForeground);
      font-size: 11px;
    }

    .cex-kv-val {
      font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
      font-size: 11px;
      word-break: break-all;
    }

    .cex-kv-val code {
      background: transparent;
      padding: 0;
      color: var(--vscode-foreground);
    }

    ${sharedDiffCSS}
    ${sharedListCSS}

    .cex-toolbar {
      display: flex;
      gap: 12px;
    }

    .cex-toolbar-btn {
      font-size: 11px;
      color: var(--vscode-textLink-foreground);
      cursor: pointer;
      text-decoration: none;
      background: none;
      border: none;
      padding: 2px 6px;
      border-radius: 3px;
    }

    .cex-toolbar-btn:hover {
      text-decoration: underline;
      background: var(--vscode-toolbar-hoverBackground);
    }

    ${generateFilterPanelCSS('cex')}

    /* Theory panel styles (collapsible) */
    .cex-theory-panel {
      margin-bottom: 12px;
      background: var(--vscode-editor-background);
      border: 1px solid var(--vscode-panel-border);
      border-radius: 6px;
      overflow: hidden;
    }

    /* Add gap when theory panel follows states container (for Extra Values) */
    .cex-states-container + .cex-theory-panel {
      margin-top: 12px;
    }

    .cex-theory-header {
      display: flex;
      align-items: center;
      gap: 8px;
      padding: 8px 12px;
      background: var(--vscode-editorGroupHeader-tabsBackground);
      cursor: pointer;
      user-select: none;
      transition: background 0.2s;
    }

    .cex-theory-header:hover {
      background: var(--vscode-list-hoverBackground);
    }

    .cex-theory-toggle {
      font-size: 10px;
      color: var(--vscode-descriptionForeground);
    }

    .cex-theory-label {
      font-weight: 600;
      font-size: 12px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      color: var(--vscode-foreground);
    }

    .cex-theory-count {
      font-size: 11px;
      color: var(--vscode-descriptionForeground);
    }

    .cex-theory-body {
      padding: 8px;
      border-top: 1px solid var(--vscode-panel-border);
    }

`);
