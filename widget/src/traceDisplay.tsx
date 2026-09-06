import { styles } from './traceDisplayStyles';
import { useWidgetShortcuts } from './useWidgetShortcuts';
import * as React from 'react';
import {
  ChangeInfo,
  diffChanges,
  CopyButton,
  formatActionLabel,
  renderValue,
  dequalify,
  mergeTheoryWithExtras,
  InstantiationRow,
} from './veilUtils';
import HtmlDisplay from './htmlDisplay';


// ========== Types ==========
import type { ParsedState, TraceData, ModelCheckingResult, ModelCheckerViewProps } from './protocol';
import { resultSummary } from './resultSelectors';

/* ===================== Render ===================== */

function isCollapsibleValue(v: unknown): boolean {
  if (Array.isArray(v)) return true;
  if (typeof v === "object" && v !== null) return true;
  if (typeof v === "string" && (v.includes("\n") || v.length > 60)) return true;
  return false;
}

function previewValue(v: unknown): string {
  if (Array.isArray(v)) {
    if (v.length > 0 && Array.isArray(v[0])) {
      return `Array(${v.length}) of tuples`;
    }
    return `Array(${v.length})`;
  }
  if (typeof v === "object" && v !== null) {
    try {
      return JSON.stringify(v).slice(0, 80) + "…";
    } catch {
      return "[object]";
    }
  }
  if (typeof v === "string") {
    const dq = dequalify(v);
    const s = dq.replace(/\s+/g, " ");
    return s.length > 80 ? s.slice(0, 80) + "…" : s;
  }
  return String(v);
}

const KVRow: React.FC<{
  k: string;
  v: unknown;
  changeInfo?: ChangeInfo;
  showRemovals?: boolean;
  onHideField?: (fieldName: string) => void;
}> = ({
  k,
  v,
  changeInfo,
  showRemovals = false,
  onHideField,
}) => {
  const collapsible = isCollapsibleValue(v);

  // Highlight the row if there's any change (array or full)
  const hasChange = changeInfo?.type === 'full' || changeInfo?.type === 'array';

  // Start expanded by default
  const [expanded, setExpanded] = React.useState(true);

  // For array changes, compute the merged view to pass to renderValue
  // If showRemovals is false, filter out removed elements from the merged view
  const mergedView = React.useMemo(() => {
    if (!expanded || changeInfo?.type !== 'array') return undefined;
    const view = changeInfo.mergedView;
    if (!showRemovals) {
      // Filter out removed elements when showRemovals is false
      return view.filter(m => m.status !== 'removed');
    }
    return view;
  }, [expanded, changeInfo, showRemovals]);

  return (
    <div
      className={`kv-row ${collapsible ? "has-toggle" : ""} ${
        hasChange ? "changed" : ""
      }`}
    >
      <div
        className={`kv-key ${onHideField ? 'kv-key-clickable' : ''}`}
        onClick={(e) => {
          if (onHideField && (e.altKey || e.metaKey)) {
            e.preventDefault();
            onHideField(k);
          }
        }}
        title={onHideField ? "Alt/Cmd-click to hide this field" : undefined}
      >
        <code>{k}</code>
      </div>
      <div className="kv-sep">↦</div>

      <div className={`kv-val ${expanded ? "expanded" : "collapsed"}`}>
        {collapsible && (
          <button
            className="kv-toggle"
            type="button"
            onClick={() => setExpanded((e) => !e)}
            aria-label={expanded ? "Collapse value" : "Expand value"}
            title={expanded ? "Collapse" : "Expand"}
          >
            {expanded ? "▼" : "▶"}
          </button>
        )}

        <div className="kv-content">
          {expanded ? renderValue(v, mergedView) : <code>{previewValue(v)}</code>}
        </div>
      </div>
    </div>
  );
};

const StateCard: React.FC<{
  st: ParsedState;
  highlighted?: boolean;
  previousFields?: Record<string, unknown>;
  showRemovals?: boolean;
  forceOpen?: boolean | null;  // null means use local state, true/false forces open/closed
  hiddenFields?: Set<string>;
  onHideField?: (fieldName: string) => void;
  onResetForceOpen?: () => void;  // Called when user clicks header while forceOpen is active
}> = ({ st, highlighted = false, previousFields, showRemovals = false, forceOpen = null, hiddenFields, onHideField, onResetForceOpen }) => {
  const isFailing = st.failing === true;
  const [localOpen, setLocalOpen] = React.useState(true);

  // Sync local state when forceOpen changes - this ensures that when we
  // reset to individual control, each state keeps the forced value
  React.useEffect(() => {
    if (forceOpen !== null) {
      setLocalOpen(forceOpen);
    }
  }, [forceOpen]);

  // Use forceOpen if set, otherwise use local state
  const open = forceOpen !== null ? forceOpen : localOpen;
  const changes = React.useMemo(() => {
    if (!open) return new Map<string, ChangeInfo>();
    const visible = Object.fromEntries(Object.entries(st.fields).filter(([key]) => !hiddenFields?.has(key)));
    const previous = previousFields && Object.fromEntries(Object.entries(previousFields).filter(([key]) => !hiddenFields?.has(key)));
    return diffChanges(previous, visible);
  }, [open, st.fields, previousFields, hiddenFields]);

  const handleHeaderClick = () => {
    if (forceOpen !== null && onResetForceOpen) {
      // User clicked while in force mode - switch to individual control
      // Set local state to opposite of current forced state, then reset force
      setLocalOpen(!forceOpen);
      onResetForceOpen();
    } else {
      setLocalOpen(o => !o);
    }
  };
  // Filter out hidden fields
  const entries = Object.entries(st.fields).filter(([k]) => !hiddenFields?.has(k));

  return (
    <div className={`state-card ${highlighted ? "is-highlighted" : ""} ${isFailing ? "is-failing" : ""}`}>
      <div className="state-header" onClick={handleHeaderClick}>
        <span className="action-chip" title={st.tag ?? ''}>
          {st.tag || '(no action)'}
        </span>
        {isFailing && <span className="failing-badge">FAILED</span>}
        <span className="state-id">(index: {st.index})</span>
        <div className="state-toggle">{open ? "▼" : "▶"}</div>
      </div>

      {open && (
        <div className="state-body">
          <div className="kv-table">
            {entries.map(([k, v]) => (
              <KVRow key={k} k={k} v={v} changeInfo={changes?.get(k)} showRemovals={showRemovals} onHideField={onHideField} />
            ))}
          </div>
        </div>
      )}
    </div>
  );
};

/** Collapsible section for displaying fields with a title */
const CollapsibleFieldsSection: React.FC<{
  title: string;
  fields: Record<string, unknown>;
  defaultExpanded?: boolean;
}> = ({ title, fields, defaultExpanded = false }) => {
  const [expanded, setExpanded] = React.useState(defaultExpanded);
  const entries = Object.entries(fields);

  return (
    <div className="theory-section">
      <div className="theory-header" onClick={() => setExpanded((e) => !e)}>
        <span className="theory-toggle">{expanded ? "▼" : "▶"}</span>
        <span className="theory-label">{title}</span>
      </div>
      {expanded && (
        <div className="theory-content">
          <div className="kv-table">
            {entries.map(([k, v]) => (
              <KVRow key={k} k={k} v={v} />
            ))}
          </div>
        </div>
      )}
    </div>
  );
};

/** Collapsible section for displaying theory info */
const TheorySection: React.FC<{ theory: Record<string, unknown> }> = ({ theory }) => {
  return <CollapsibleFieldsSection title="Theory" fields={theory} />;
};

/** One result interpretation shared by every header. */
const ResultHeader: React.FC<{result: ModelCheckingResult}> = ({result}) => {
  const summary = resultSummary(result);
  if (!summary) return null;
  return <div className={`result-header result-${summary.severity}`}>
    <span className="result-icon">{summary.icon}</span>
    <span className="result-label">{summary.label}</span>
    {summary.details && <div className="result-details">{summary.details}</div>}
  </div>;
};

/** Helper to convert TraceData states to ParsedState format */
function traceDataToStates(traceData: TraceData): ParsedState[] {
  return traceData.states.map((st) => ({
    index: st.index,
    tag: formatActionLabel(st.transition),
    fields: st.fields,
    failing: st.failing,
  }));
}

const ModelCheckerView: React.FC<ModelCheckerViewProps> = ({
  result,
  layout = "vertical",
  rawHtml,
}) => {
  const isVertical = layout === "vertical";
  const [showRawJson, setShowRawJson] = React.useState(false);
  const [showRawModel, setShowRawModel] = React.useState(false);
  const [showRemovals, setShowRemovals] = React.useState(false);
  const [allStatesOpen, setAllStatesOpen] = React.useState<boolean | null>(null);  // null = individual control
  const [hiddenFields, setHiddenFields] = React.useState<Set<string>>(new Set());
  const [showFilterPanel, setShowFilterPanel] = React.useState(false);

  // Compute all unique field names from the trace
  const traceData = 'trace' in result ? result.trace : undefined;
  const allFieldNames = React.useMemo(() => {
    if (!traceData?.states) return [];
    const names = new Set<string>();
    for (const state of traceData.states) {
      for (const key of Object.keys(state.fields)) {
        names.add(key);
      }
    }
    return Array.from(names).sort();
  }, [traceData]);

  const toggleFieldVisibility = (fieldName: string) => {
    setHiddenFields(prev => {
      const next = new Set(prev);
      if (next.has(fieldName)) {
        next.delete(fieldName);
      } else {
        next.add(fieldName);
      }
      return next;
    });
  };

  const showAllFields = () => setHiddenFields(new Set());
  const hideAllFields = () => setHiddenFields(new Set(allFieldNames));

  const shortcuts = useWidgetShortcuts({
    escape: () => setShowFilterPanel(false),
    c: showRawJson ? undefined : () => setAllStatesOpen(prev => prev === false ? true : false),
    r: showRawJson ? undefined : () => setShowRemovals(prev => !prev),
    f: showRawJson ? undefined : () => setShowFilterPanel(prev => !prev),
  });



  const prettyJson = React.useMemo(() => showRawJson ? JSON.stringify(result, null, 2) : '', [showRawJson, result]);

  // Extract trace and theory from results (works for all result types)
  const trace = React.useMemo(() => traceData ? traceDataToStates(traceData) : [], [traceData]);
  const [visibleStateCount, setVisibleStateCount] = React.useState(100);

  // Merge theory with extraVals that have '.' in their names
  const { combinedTheory, remainingExtraVals } = React.useMemo(() => {
    if (!traceData?.theory) {
      return { combinedTheory: {}, remainingExtraVals: {} };
    }
    return mergeTheoryWithExtras(traceData.theory, traceData.extraVals);
  }, [traceData]);

  const instantiation = traceData?.instantiation;
  const initialization = 'initialization' in result ? result.initialization : undefined;

  return (
    <>
      <style>{styles}</style>
      <div className="mc-root" {...shortcuts}>
        <div className="mc-toolbar">
          {!showRawJson && !showRawModel && (
            <>
              <button
                className={`mc-toggle-link ${hiddenFields.size > 0 ? 'mc-filter-active' : ''}`}
                onClick={() => setShowFilterPanel(!showFilterPanel)}
                title="Filter visible fields (F)"
              >
                Filter fields {hiddenFields.size > 0 ? `(${hiddenFields.size} hidden)` : ''} (F)
              </button>
              <button className="mc-toggle-link" onClick={() => setAllStatesOpen(allStatesOpen === false ? true : false)} title="Keyboard shortcut: C">
                {allStatesOpen === false ? "Expand all (C)" : "Collapse all (C)"}
              </button>
              <button className="mc-toggle-link" onClick={() => setShowRemovals(!showRemovals)} title="Keyboard shortcut: R">
                {showRemovals ? "Hide removals (R)" : "Show removals (R)"}
              </button>
            </>
          )}
          {rawHtml && (
            <button className="mc-toggle-link" onClick={() => setShowRawModel(!showRawModel)}>
              {showRawModel ? "Show structured" : "Show raw model"}
            </button>
          )}
          <button className="mc-toggle-link" onClick={() => setShowRawJson(!showRawJson)}>
            {showRawJson ? "Show formatted" : "Show JSON"}
          </button>
        </div>

        {showRawJson ? (
          <div className="mc-json-view">
            <CopyButton text={prettyJson} className="mc-copy-button" />
            <div className="mc-json-content">
              {prettyJson}
            </div>
          </div>
        ) : showRawModel && rawHtml ? (
          <div className="mc-raw-model">
            <HtmlDisplay html={rawHtml} />
          </div>
        ) : (
          <>
            <ResultHeader result={result} />
            {initialization && <>
              <TheorySection theory={initialization.theory} />
              <CollapsibleFieldsSection title="State at initializer failure" fields={initialization.state} />
            </>}

            {instantiation && Object.keys(instantiation).length > 0 && (
              <InstantiationRow instantiation={instantiation} prefix="mc" />
            )}

            {Object.keys(combinedTheory).length > 0 && <TheorySection theory={combinedTheory} />}

            {trace.length > 0 ? (
              <>
                <div className={`mc-trace ${isVertical ? "vertical" : "horizontal"}`}>
                  {trace.slice(0, visibleStateCount).map((s: ParsedState, idx: number) => {
                    const prev = idx > 0 ? trace[idx - 1].fields : undefined;
                    return <StateCard key={s.index} st={s} previousFields={prev} showRemovals={showRemovals} forceOpen={allStatesOpen} hiddenFields={hiddenFields} onHideField={toggleFieldVisibility} onResetForceOpen={() => setAllStatesOpen(null)} />;
                  })}
                </div>

                {Object.keys(remainingExtraVals).length > 0 && (
                  <CollapsibleFieldsSection title="Extra Values" fields={remainingExtraVals} />
                )}

                <div className="mc-summary">
                  {visibleStateCount < trace.length && <button onClick={() => setVisibleStateCount(count => count + 100)}>Show next {Math.min(100, trace.length - visibleStateCount)} states</button>}
                  <strong>Summary:</strong> {trace.length} states in trace
                </div>
              </>
            ) : (
              'result' in result && result.result === "found_violation" && (
                <div className="mc-summary">
                  <strong>No trace available</strong>
                </div>
              )
            )}
          </>
        )}

        {/* Filter panel modal - rendered at root level for fixed positioning */}
        {showFilterPanel && (
          <>
            <div className="mc-filter-backdrop" onClick={() => setShowFilterPanel(false)} />
            <div className="mc-filter-panel">
              <div className="mc-filter-header">
                <span>Visible Fields</span>
                <div className="mc-filter-actions">
                  <button className="mc-filter-action" onClick={showAllFields}>Show all</button>
                  <button className="mc-filter-action" onClick={hideAllFields}>Hide all</button>
                  <button className="mc-filter-close" onClick={() => setShowFilterPanel(false)} title="Close (Esc)">×</button>
                </div>
              </div>
              <div className="mc-filter-list">
                {allFieldNames.map(name => (
                  <label key={name} className="mc-filter-item">
                    <input
                      type="checkbox"
                      checked={!hiddenFields.has(name)}
                      onChange={() => toggleFieldVisibility(name)}
                    />
                    <code>{name}</code>
                  </label>
                ))}
              </div>
            </div>
          </>
        )}
      </div>
    </>
  );
};

export default ModelCheckerView;
