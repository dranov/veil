import { useValueDiff } from './useValueDiff';
import { FieldFilter, useFieldVisibility } from './fieldVisibility';
import { styles } from './verificationResultsStyles';
import { useWidgetShortcuts } from './useWidgetShortcuts';
import * as React from 'react';
import { InsertionSourceContext, useEditorInsertion } from './editorInsertion';
import HtmlDisplay from './htmlDisplay';
import {
  ChangeInfo,
  CopyButton,
  formatActionLabel,
  renderValue,
  mergeTheoryWithExtras,
  InstantiationRow,
} from './veilUtils';

// ========== Types ==========

import type { InductionMetadataData, StructuredJson, DischargerStatusFinished, VerificationCondition, VerificationResultsProps, InsertPosition } from './protocol';
import { getEffectiveStatus, buildAlternativeMap, proofStyle, firstCounterexample, selectWitness } from './verificationSelectors';

type StatusFilter = 'all' | 'proven' | 'disproven' | 'unknown' | 'error' | 'timeout' | 'pending';

// ========== Helpers ==========

const parseEnumTheoryKey = (key: string): [string, string] | null => {
  const match = key.match(/^(.+)_Enum\.(.+)$/);
  return match ? [match[1], match[2]] : null;
};

const compactEnumDecls = (fields: Record<string, unknown>): string[] => {
  const enumEntries = Object.keys(fields)
    .map(parseEnumTheoryKey)
    .filter((entry): entry is [string, string] => entry !== null);

  return [...new Set(enumEntries.map(([enumName]) => enumName))].map((enumName) => {
    const constructors = enumEntries
      .filter(([name]) => name === enumName)
      .map(([, ctor]) => ctor);
    return `enum ${enumName} = {${[...new Set(constructors)].join(', ')}}`;
  });
};

/** Key-value row component for state display */
const CexKVRow: React.FC<{
  k: string;
  v: unknown;
  changeInfo?: ChangeInfo;
}> = ({ k, v, changeInfo }) => {
  const hasChange = changeInfo?.type === 'full' || changeInfo?.type === 'array';
  const mergedView = changeInfo?.type === 'array' ? changeInfo.mergedView : undefined;

  return (
    <div className={`cex-kv-row ${hasChange ? 'changed' : ''}`}>
      <div className="cex-kv-key"><code>{k}</code></div>
      <div className="cex-kv-sep">↦</div>
      <div className="cex-kv-val">
        {renderValue(v, mergedView)}
      </div>
    </div>
  );
};

/** State panel component showing fields in a card */
const StatePanel: React.FC<{
  title: string;
  fields: Record<string, unknown>;
  changes?: Map<string, ChangeInfo>;
  statusIndicator?: React.ReactNode;
}> = ({ title, fields, changes, statusIndicator }) => {
  const entries = Object.entries(fields);

  return (
    <div className="cex-state-panel">
      <div className="cex-state-header">
        <span>{title}</span>
        {statusIndicator && (
          <span className="cex-state-status">{statusIndicator}</span>
        )}
      </div>
      <div className="cex-state-body">
        {entries.length === 0 ? (
          <div className="cex-empty-state">No fields</div>
        ) : (
          <div className="cex-kv-table">
            {entries.map(([k, v]) => (
              <CexKVRow key={k} k={k} v={v} changeInfo={changes?.get(k)} />
            ))}
          </div>
        )}
      </div>
    </div>
  );
};

/** Collapsible panel component for displaying fields */
const CollapsibleFieldsPanel: React.FC<{
  title: string;
  fields: Record<string, unknown>;
  defaultExpanded?: boolean;
  compactEnums?: boolean;
}> = ({ title, fields, defaultExpanded = false, compactEnums = false }) => {
  const [expanded, setExpanded] = React.useState(defaultExpanded);
  const enumDecls = compactEnums ? compactEnumDecls(fields) : [];
  const entries = Object.entries(fields)
    .filter(([key]) => !compactEnums || parseEnumTheoryKey(key) === null);
  const count = enumDecls.length + entries.length;

  return (
    <div className="cex-theory-panel">
      <div
        className="cex-theory-header"
        onClick={() => setExpanded(!expanded)}
      >
        <span className="cex-theory-toggle">{expanded ? '▼' : '▶'}</span>
        <span className="cex-theory-label">{title}</span>
        <span className="cex-theory-count">({count} {count === 1 ? 'field' : 'fields'})</span>
      </div>
      {expanded && (
        <div className="cex-theory-body">
          {count === 0 ? (
            <div className="cex-empty-state">No fields</div>
          ) : (
            <div className="cex-kv-table">
              {enumDecls.map(decl => (
                <div key={decl} className="cex-kv-row cex-enum-row"><code>{decl}</code></div>
              ))}
              {entries.map(([k, v]) => (
                <CexKVRow key={k} k={k} v={v} />
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
};

/** Structured counterexample view with side-by-side pre/post states */
const StructuredCexView: React.FC<{
  data: StructuredJson;
  property: string;
  isInitializer?: boolean;
  headerRightContent?: React.ReactNode;
}> = ({ data, property, isInitializer = false, headerRightContent }) => {
  const { theory, preState, postState, label, instantiation, extraVals } = data;

  // State for toolbar features
  const [showRemovals, setShowRemovals] = React.useState(false);
  const [isWideEnough, setIsWideEnough] = React.useState(true);
  const containerRef = React.useRef<HTMLDivElement>(null);

  // Detect when container is too narrow for side-by-side layout
  React.useEffect(() => {
    const container = containerRef.current;
    if (!container) return;

    const observer = new ResizeObserver((entries) => {
      for (const entry of entries) {
        // Stack panels vertically when width < 600px
        setIsWideEnough(entry.contentRect.width >= 600);
      }
    });

    observer.observe(container);
    return () => observer.disconnect();
  }, []);

  // Compute all unique field names from pre and post state
  const allFieldNames = React.useMemo(() => {
    const names = new Set<string>();
    for (const key of Object.keys(preState)) names.add(key);
    if (postState) {
      for (const key of Object.keys(postState)) names.add(key);
    }
    return Array.from(names).sort();
  }, [preState, postState]);
  const visibility = useFieldVisibility(allFieldNames);
  const {hiddenFields, showFilterPanel, setShowFilterPanel} = visibility;


  // Filter fields based on hiddenFields
  const filteredPreState = React.useMemo(() => {
    const filtered: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(preState)) {
      if (!hiddenFields.has(k)) filtered[k] = v;
    }
    return filtered;
  }, [preState, hiddenFields]);

  const filteredPostState = React.useMemo(() => {
    if (!postState) return null;
    const filtered: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(postState)) {
      if (!hiddenFields.has(k)) filtered[k] = v;
    }
    return filtered;
  }, [postState, hiddenFields]);

  const changes = useValueDiff(filteredPreState, filteredPostState ?? {}, filteredPostState !== null);

  // Filter changes to only include visible fields, and optionally hide removals
  const filteredChanges = React.useMemo(() => {
    const filtered = new Map<string, ChangeInfo>();
    for (const [k, info] of changes) {
      if (hiddenFields.has(k)) continue;
      if (!showRemovals && info.type === 'array') {
        // Filter out removed elements when showRemovals is false
        const filteredMergedView = info.mergedView.filter(m => m.status !== 'removed');
        filtered.set(k, { type: 'array', mergedView: filteredMergedView });
      } else {
        filtered.set(k, info);
      }
    }
    return filtered;
  }, [changes, hiddenFields, showRemovals]);

  // Merge theory with extraVals that have '.' in their names
  const { combinedTheory, remainingExtraVals } = React.useMemo(
    () => mergeTheoryWithExtras(theory, extraVals),
    [theory, extraVals]
  );

  const shortcuts = useWidgetShortcuts({
    escape: () => setShowFilterPanel(false),
    r: () => setShowRemovals(prev => !prev),
    f: () => setShowFilterPanel(prev => !prev),
  });

  return (
    <div className="cex-structured-view" ref={containerRef} {...shortcuts}>
      {/* Combined header with toolbar and controls */}
      <div className="cex-header-row">
        <div className="cex-header-left">
          <span className="cex-header-label">Counterexample</span>
          <button
            className={`cex-toolbar-btn ${hiddenFields.size > 0 ? 'cex-filter-active' : ''}`}
            onClick={(e) => { e.stopPropagation(); setShowFilterPanel(!showFilterPanel); }}
            title="Filter visible fields (F)"
          >
            Filter fields {hiddenFields.size > 0 ? `(${hiddenFields.size} hidden)` : ''} (F)
          </button>
          <button
            className="cex-toolbar-btn"
            onClick={(e) => { e.stopPropagation(); setShowRemovals(!showRemovals); }}
            title="Show/hide removed elements (R)"
          >
            {showRemovals ? "Hide removals (R)" : "Show removals (R)"}
          </button>
        </div>
        {headerRightContent && (
          <div className="cex-header-right">
            {headerRightContent}
          </div>
        )}
      </div>

      {/* Instantiation */}
      {instantiation && Object.keys(instantiation).length > 0 && (
        <InstantiationRow instantiation={instantiation} prefix="cex" />
      )}

      {/* Theory (collapsible, expanded by default) */}
      {Object.keys(combinedTheory).length > 0 && (
        <CollapsibleFieldsPanel title="Theory" fields={combinedTheory} defaultExpanded={true} compactEnums={true} />
      )}

      {/* Centered action chip above panels (when side-by-side) */}
      {isWideEnough && (
        <div className="cex-action-row">
          <span className="cex-action-chip">{formatActionLabel(label)}</span>
        </div>
      )}

      {/* Side-by-side or stacked state panels */}
      <div className={`cex-states-container ${!isWideEnough ? 'cex-states-stacked' : ''}`}>
        <StatePanel
          title="Pre-State"
          fields={filteredPreState}
          statusIndicator={
            isInitializer
              ? undefined
              : <span className="cex-status-valid">✓ Satisfies all invariants </span>
          }
        />
        {/* Narrow view: centered action chip between stacked panels */}
        {!isWideEnough && filteredPostState && (
          <div className="cex-narrow-action">
            <span className="cex-action-chip">{formatActionLabel(label)}</span>
          </div>
        )}
        {filteredPostState && (
          <StatePanel
            title="Post-State"
            fields={filteredPostState}
            changes={filteredChanges}
            statusIndicator={<span className="cex-status-invalid">✗ Violates <span className="cex-property-name">{property}</span></span>}
          />
        )}
      </div>

      {/* Extra Values (collapsible, collapsed by default, shown below states) */}
      {Object.keys(remainingExtraVals).length > 0 && (
        <CollapsibleFieldsPanel title="Extra Values" fields={remainingExtraVals} />
      )}

      {/* Filter panel modal */}
      <FieldFilter prefix="cex" fieldNames={allFieldNames} visibility={visibility} />
    </div>
  );
};

const TRUST_RECONSTRUCTION_OPTION = 'set_option veil.smt.trust false';

/** Banner shown when there are VCs that need manual proof (unknown/error status) */
const ManualProofBanner: React.FC<{
  vcs: VerificationCondition[];
  alternativeMap: Map<number, VerificationCondition[]>;
  theoremInsertPos: InsertPosition;
}> = ({ vcs, alternativeMap, theoremInsertPos }) => {
  const {insert: insertTheorem, error: insertionError} = useEditorInsertion(theoremInsertPos);
  const [inserting, setInserting] = React.useState(false);
  const [dismissed, setDismissed] = React.useState(false);

  // Get VCs that need manual proof (unknown/error/timeout, not disproven - those have counterexamples)
  const needsManualProofVCs = vcs.filter(vc =>
    vc.theoremText &&
    isManualProofStatus(getVisibleStatus(vc, alternativeMap))
  );

  const count = needsManualProofVCs.length;
  if (count === 0 || dismissed) return null;

  const handleInsertAll = async () => {
    setInserting(true);
    const allTheorems = needsManualProofVCs
      .map(vc => vc.theoremText)
      .filter((t): t is string => t != null)
      .join('\n\n');
    await insertTheorem(allTheorems);
    setInserting(false);
  };

  return (
    <div className="vr-failure-banner">
      {insertionError}
      <span className="vr-failure-banner-icon">⚠️</span>
      <span className="vr-failure-banner-text">
        {count} verification condition{count !== 1 ? 's' : ''} could not be discharged automatically
      </span>
      <button
        className="vr-failure-banner-action"
        onClick={handleInsertAll}
        disabled={inserting}
      >
        {inserting ? 'Inserting...' : 'Insert to prove interactively'}
      </button>
      <button
        className="vr-failure-banner-dismiss"
        onClick={() => setDismissed(true)}
        title="Dismiss"
      >
        ×
      </button>
    </div>
  );
};

/** Banner shown when one or more VCs were proven by trusting the SMT solver. */
const TrustedSmtBanner: React.FC<{
  vcs: VerificationCondition[];
  optionInsertPos?: InsertPosition | null;
}> = ({ vcs, optionInsertPos }) => {
  const {insert: insertOption, error: insertionError} = useEditorInsertion(optionInsertPos);
  const insertTrustOption = () => insertOption(TRUST_RECONSTRUCTION_OPTION);
  const [inserting, setInserting] = React.useState(false);
  const alternatives = buildAlternativeMap(vcs);
  const count = filterToVisibleVCs(vcs).filter(vc => {
    const witness = selectWitness(vc, alternatives.get(vc.id));
    return witness.status === 'proven' && witness.proofHasSorry === true;
  }).length;

  if (count === 0) return null;

  const handleInsertTrustOption = async () => {
    setInserting(true);
    await insertTrustOption();
    setInserting(false);
  };

  return (
    <div
      className="vr-trusted-smt-banner"
      title="These goals were discharged with a trusted SMT result; no Lean proof was reconstructed. `set_option veil.smt.trust false` to enable proof reconstruction."
    >
      {insertionError}
      <span className="vr-trusted-smt-banner-icon">⚠️</span>
      <span className="vr-trusted-smt-banner-text">
        Trusting SMT solver for {count} goal{count === 1 ? '' : 's'}.{' '}
        <button
          className="vr-trusted-smt-option"
          onClick={handleInsertTrustOption}
          disabled={inserting || !optionInsertPos}
          title="Insert this option above #gen_spec"
        >
          <code>{TRUST_RECONSTRUCTION_OPTION}</code>
        </button>{' '}
        to enable proof reconstruction.
      </span>
    </div>
  );
};

function getStatusIcon(status: VerificationCondition['status']): React.ReactNode {
  switch (status) {
    case 'proven': return '✅';
    case 'disproven': return '❌';
    case 'unknown': return '❓';
    case 'error': return '💥';
    case 'timeout': return '⏱️';
    case null: return <span className="spinner">⏳</span>;
    default: return '⭕';
  }
}

function getStatusClass(status: VerificationCondition['status']): string {
  return status || 'pending';
}

interface ExceptionGroup {
  message: string;
  dischargerNames: string[];
}

// Extract exceptions from dischargers, preserving which dischargers produced them.
function getExceptionGroupsFromVC(vc: VerificationCondition): ExceptionGroup[] {
  const exceptionMap = new Map<string, Set<string>>();
  for (const discharger of vc.timing.dischargers) {
    const addException = (message: string) => {
      const dischargerNames = exceptionMap.get(message) ?? new Set<string>();
      dischargerNames.add(discharger.name);
      exceptionMap.set(message, dischargerNames);
    };

    // Check if status is an object with finished.res.exceptions
    if (typeof discharger.status === 'object' && discharger.status !== null) {
      const finished = (discharger.status as DischargerStatusFinished).finished;
      if (finished?.res?.exceptions) {
        for (const ex of finished.res.exceptions) {
          addException(ex);
        }
      }
    }
    // Also check the result field for exceptions
    if (discharger.result?.exceptions) {
      for (const ex of discharger.result.exceptions) {
        addException(ex);
      }
    }
  }
  return Array.from(exceptionMap.entries()).map(([message, dischargerNames]) => ({
    message,
    dischargerNames: Array.from(dischargerNames).sort(),
  }));
}

function getUnknownReasonGroupsFromVC(vc: VerificationCondition): ExceptionGroup[] {
  const reasonMap = new Map<string, Set<string>>();

  for (const discharger of vc.timing.dischargers) {
    const reasons = discharger.result?.data?.reasons;
    if (!reasons) continue;

    for (const reason of reasons) {
      const dischargerNames = reasonMap.get(reason) ?? new Set<string>();
      dischargerNames.add(discharger.name);
      reasonMap.set(reason, dischargerNames);
    }
  }

  return Array.from(reasonMap.entries()).map(([message, dischargerNames]) => ({
    message,
    dischargerNames: Array.from(dischargerNames).sort(),
  }));
}

// Helper to check if a VC is an induction VC
function isInductionVC(vc: VerificationCondition): boolean {
  return vc.metadata.type === 'induction';
}

// Helper to get induction metadata data (returns null for trace VCs)
function getInductionData(vc: VerificationCondition): InductionMetadataData | null {
  if (vc.metadata.type === 'induction') {
    return vc.metadata.data;
  }
  return null;
}

// Group VCs by action (only for induction VCs)
function groupByAction(vcs: VerificationCondition[]): Map<string, VerificationCondition[]> {
  const groups = new Map<string, VerificationCondition[]>();
  for (const vc of vcs) {
    const inductionData = getInductionData(vc);
    if (!inductionData) continue; // Skip non-induction VCs
    const action = inductionData.action;
    if (!groups.has(action)) {
      groups.set(action, []);
    }
    groups.get(action)!.push(vc);
  }
  return groups;
}

function getVisibleStatus(
  vc: VerificationCondition,
  alternativeMap: Map<number, VerificationCondition[]>
): VerificationCondition['status'] {
  return getEffectiveStatus(vc, alternativeMap.get(vc.id));
}

function isManualProofStatus(status: VerificationCondition['status']): boolean {
  return status === 'unknown' || status === 'error' || status === 'timeout';
}

function hasRunningDischarger(targetVC?: VerificationCondition): boolean {
  return targetVC?.timing.dischargers.some(d => d.status === 'running') === true;
}

// Filter to only show primary induction VCs (exclude all alternatives, trace VCs, and dormant VCs)
function filterToVisibleVCs(vcs: VerificationCondition[]): VerificationCondition[] {
  return vcs.filter(vc => vc.alternativeFor == null && isInductionVC(vc) && !vc.isDormant);
}

// ========== Components ==========

function getFilterButtonContent(filter: StatusFilter): React.ReactNode {
  const label = filter === 'all' ? 'All' : filter.charAt(0).toUpperCase() + filter.slice(1);

  switch (filter) {
    case 'all':
      return label;
    case 'pending':
      return <><span className="spinner-small">⏳</span> {label}</>;
    case 'proven':
      return <>✅ {label}</>;
    case 'disproven':
      return <>❌ {label}</>;
    case 'unknown':
      return <>❓ {label}</>;
    case 'error':
      return <>💥 {label}</>;
    case 'timeout':
      return <>⏱️ {label}</>;
    default:
      return label;
  }
}

interface PropertyRowProps {
  vc: VerificationCondition;
  alternatives?: VerificationCondition[];
  theoremInsertPos: InsertPosition;
  serverTime: number;
}

const PropertyRow: React.FC<PropertyRowProps> = ({ vc, alternatives = [], theoremInsertPos, serverTime }) => {
  const [expanded, setExpanded] = React.useState(false);
  const [selectedCounterexampleId, setSelectedCounterexampleId] = React.useState<number>();
  const [showRawHtml, setShowRawHtml] = React.useState(false);
  const effectiveStatus = getEffectiveStatus(vc, alternatives);
  const activeVCs = [vc, ...alternatives.filter(v => !v.isDormant)];
  const witness = selectWitness(vc, alternatives);
  const counterexamples = activeVCs.flatMap(v => {
    const counterexample = firstCounterexample(v);
    return counterexample ? [{ vc: v, counterexample }] : [];
  });
  const selected = counterexamples.find(c => c.vc.id === selectedCounterexampleId)
    ?? counterexamples.find(c => getInductionData(c.vc)?.style === 'tr') ?? counterexamples[0];
  const activeCounterexample = selected?.counterexample;
  const {insert: insertTheorem, error: insertionError} = useEditorInsertion(theoremInsertPos);
  const needsManualProof = isManualProofStatus(effectiveStatus);
  const hasTheoremText = !!vc.theoremText;
  const alternativeTheorems = alternatives.filter(v => v.theoremText);
  const hasInteractiveAttempt = activeVCs.some(v => v.timing.dischargers.some(d => d.isInteractive));
  const isInteractiveProven = witness.status === 'proven' && witness.timing.dischargers.some(
    d => d.id === witness.timing.successfulDischargerId && d.isInteractive);
  const mergeDiagnostics = (extract: (v: VerificationCondition) => ExceptionGroup[]) => {
    const groups = new Map<string, Set<string>>();
    for (const related of activeVCs) for (const group of extract(related)) {
      const names = groups.get(group.message) ?? new Set<string>();
      for (const name of group.dischargerNames) names.add(name);
      groups.set(group.message, names);
    }
    return Array.from(groups, ([message, names]) => ({message, dischargerNames: [...names].sort()}));
  };
  const allExceptions = mergeDiagnostics(getExceptionGroupsFromVC);
  const allUnknownReasons = mergeDiagnostics(getUnknownReasonGroupsFromVC);
  const hasExceptions = allExceptions.length > 0;
  const hasUnknownReasons = allUnknownReasons.length > 0;
  const isExpandable = counterexamples.length > 0 || hasExceptions || hasUnknownReasons || alternativeTheorems.length > 0;
  const isQueued = effectiveStatus === null && !activeVCs.some(hasRunningDischarger);
  const timeDisplay = activeVCs.map(v => {
    const running = v.timing.dischargers.find(d => d.status === 'running' && d.startTime != null);
    const time = running?.startTime != null ? Math.max(0, serverTime - running.startTime) : v.timing.totalTime;
    if (time == null) return null;
    return `${proofStyle(v)} ${time < 1000 ? `${time}ms` : `${(time / 1000).toFixed(2)}s`}`;
  }).filter(Boolean).join(' + ');
  const counterexampleToggle = counterexamples.length > 1 && (
    <div className="counterexample-toggle">
      {counterexamples.map(c => <button key={c.vc.id}
        className={`cex-toggle-btn ${selected?.vc.id === c.vc.id ? 'active' : ''}`}
        onClick={e => { e.stopPropagation(); setSelectedCounterexampleId(c.vc.id); }}
        title={c.vc.name}>{proofStyle(c.vc)} ({c.vc.id})</button>)}
    </div>
  );

  // Handle click on property row
  const handleRowClick = async (e: React.MouseEvent) => {
    const isCmdOrCtrl = e.metaKey || e.ctrlKey;

    // Modified shift-click inserts the first alternative; all are listed when expanded.
    if (isCmdOrCtrl && e.shiftKey && alternativeTheorems.length > 0) {
      e.preventDefault();
      e.stopPropagation();
      await insertTheorem(alternativeTheorems[0].theoremText!);
      return;
    }

    // Cmd-click (Mac) or Ctrl-click (Windows/Linux) to insert theorem
    if (isCmdOrCtrl && hasTheoremText) {
      e.preventDefault();
      e.stopPropagation();
      await insertTheorem(vc.theoremText!);
      return;
    }

    // Normal click: toggle expanded
    if (isExpandable) {
      setExpanded(!expanded);
    }
  };

  // Build tooltip text based on available actions
  const getTooltip = (): string | undefined => {
    const parts: string[] = [];
    if (hasTheoremText) parts.push(`Cmd/Ctrl-click to insert ${proofStyle(vc)} theorem`);
    if (alternativeTheorems.length > 0) parts.push(`Cmd/Ctrl+Shift-click for ${proofStyle(alternativeTheorems[0])} version`);
    return parts.length > 0 ? parts.join(', ') : undefined;
  };

  return (
    <>
      {insertionError}
      <div
        className={`property-row status-${getStatusClass(effectiveStatus)} ${isExpandable ? 'expandable' : ''} ${needsManualProof && hasTheoremText ? 'insertable' : ''}`}
        onClick={handleRowClick}
        style={{ cursor: isExpandable || hasTheoremText ? 'pointer' : 'default' }}
        title={getTooltip()}
      >
        {isExpandable && (
          <span className="property-toggle">{expanded ? '▼' : '▶'}</span>
        )}
        <span className="property-icon">{isQueued ? '⏳' : getStatusIcon(effectiveStatus)}</span>
        <span className="property-name">{getInductionData(vc)?.property}</span>
        {activeVCs.map(v => <span key={v.id} className={`vc-style-badge ${v.status === null ? 'tr-running' : ''}`}>
          {proofStyle(v)}{v.status === null && '...'}
        </span>)}
        {(isInteractiveProven || hasInteractiveAttempt) && (
          <span className="vc-style-badge interactive-badge">
            Interactive
          </span>
        )}
        {timeDisplay && (
          <span className="property-time">{timeDisplay}</span>
        )}
      </div>
      {expanded && alternativeTheorems.length > 0 && <div className="counterexample-toggle">
        {[vc, ...alternativeTheorems].filter(v => v.theoremText).map(v =>
          <button key={v.id} className="cex-toggle-btn" onClick={() => insertTheorem(v.theoremText!)}>
            Insert {proofStyle(v)} theorem ({v.id})
          </button>)}
      </div>}
      {expanded && hasExceptions && (
        <div className="exceptions-container">
          <div className="exceptions-label">Exceptions</div>
          <div className="exceptions-content">
            {allExceptions.map((exception, idx) => (
              <div key={idx} className="exception-entry">
                <div className="exception-source">{exception.dischargerNames.join(', ')}</div>
                <pre className="exception-item">{exception.message}</pre>
              </div>
            ))}
          </div>
        </div>
      )}
      {expanded && hasUnknownReasons && (
        <div className="exceptions-container">
          <div className="exceptions-label">Reasons for Unknown</div>
          <div className="exceptions-content">
            {allUnknownReasons.map((reason, idx) => (
              <div key={idx} className="exception-entry">
                <div className="exception-source">{reason.dischargerNames.join(', ')}</div>
                <pre className="exception-item">{reason.message}</pre>
              </div>
            ))}
          </div>
        </div>
      )}
      {expanded && activeCounterexample && (
        <div className="counterexample-container">
          {activeCounterexample.structuredJson && !showRawHtml ? (
            <StructuredCexView
              data={activeCounterexample.structuredJson}
              property={getInductionData(vc)?.property ?? ''}
              isInitializer={getInductionData(vc)?.action === 'initializer'}
              headerRightContent={
                <>
                  <button
                    className="cex-view-toggle"
                    onClick={(e) => { e.stopPropagation(); setShowRawHtml(!showRawHtml); }}
                  >
                    Show raw model
                  </button>
                  {counterexampleToggle}
                </>
              }
            />
          ) : (
            <>
              <div className="counterexample-header">
                <div className="counterexample-label">Counterexample</div>
                <div className="counterexample-toggles">
                  {activeCounterexample.structuredJson && (
                    <button
                      className="cex-view-toggle"
                      onClick={(e) => { e.stopPropagation(); setShowRawHtml(!showRawHtml); }}
                    >
                      Show structured
                    </button>
                  )}
                  {counterexampleToggle}
                </div>
              </div>
              <div className="counterexample-content">
                {typeof activeCounterexample.html === 'string'
                  ? <span dangerouslySetInnerHTML={{ __html: activeCounterexample.html }} />
                  : <HtmlDisplay html={activeCounterexample.html} />
                }
              </div>
            </>
          )}
        </div>
      )}
    </>
  );
};

interface ActionSectionProps {
  action: string;
  vcs: VerificationCondition[];
  alternativeMap: Map<number, VerificationCondition[]>;
  theoremInsertPos: InsertPosition;
  serverTime: number;
}

const ActionSection: React.FC<ActionSectionProps> = ({ action, vcs, alternativeMap, theoremInsertPos, serverTime }) => {
  const [expanded, setExpanded] = React.useState(true);
  const {insert: insertTheorem, error: insertionError} = useEditorInsertion(theoremInsertPos);
  const [inserting, setInserting] = React.useState(false);

  // Get VCs that need manual proof (unknown/error/timeout, not disproven - those have counterexamples)
  const needsManualProofVCs = vcs.filter(vc =>
    vc.theoremText &&
    isManualProofStatus(getVisibleStatus(vc, alternativeMap))
  );
  const needsManualProofCount = needsManualProofVCs.length;

  const handleInsertNeedsProof = async (e: React.MouseEvent) => {
    e.stopPropagation();
    if (needsManualProofCount === 0) return;
    setInserting(true);
    const allTheorems = needsManualProofVCs
      .map(vc => vc.theoremText)
      .filter((t): t is string => t != null)
      .join('\n\n');
    await insertTheorem(allTheorems);
    setInserting(false);
  };

  return (
    <div className="action-section">
      {insertionError}
      <div className="action-header" onClick={() => setExpanded(!expanded)}>
        <span className="action-toggle">{expanded ? '▼' : '▶'}</span>
        <span className="action-name">{action}</span>
        {needsManualProofCount > 0 && (
          <>
            <span className="action-failed-count">({needsManualProofCount} need{needsManualProofCount === 1 ? 's' : ''} manual proof)</span>
            <button
              className="action-insert-failed"
              onClick={handleInsertNeedsProof}
              disabled={inserting}
            >
              {inserting ? 'Inserting...' : 'Insert'}
            </button>
          </>
        )}
      </div>
      {expanded && (
        <div className="action-properties">
          {vcs.map((vc) => (
            <PropertyRow
              key={vc.id}
              vc={vc}
              theoremInsertPos={theoremInsertPos}
              alternatives={alternativeMap.get(vc.id)}
              serverTime={serverTime}
            />
          ))}
        </div>
      )}
    </div>
  );
};

const VerificationResultsView: React.FC<VerificationResultsProps> = ({ results, theoremInsertPos, optionInsertPos }) => {
  const [statusFilter, setStatusFilter] = React.useState<StatusFilter>('all');
  const [showRawJson, setShowRawJson] = React.useState(false);

  // Build map from primary VC ID to its alternative VC (from ALL VCs including dormant)
  const alternativeMap = React.useMemo(
    () => buildAlternativeMap(results.vcs),
    [results.vcs]
  );

  // Filter to only show primary VCs (alternatives are shown inline with their primary)
  const visibleVCs = React.useMemo(
    () => filterToVisibleVCs(results.vcs),
    [results.vcs]
  );

  // Compute counts for each status (only from visible/non-dormant VCs)
  const statusCounts = React.useMemo(() => {
    const counts = {
      all: visibleVCs.length,
      pending: 0,
      proven: 0,
      disproven: 0,
      unknown: 0,
      error: 0,
      timeout: 0,
    };

    visibleVCs.forEach((vc) => {
      const effectiveStatus = getVisibleStatus(vc, alternativeMap);
      if (effectiveStatus === null) {
        counts.pending++;
      } else if (effectiveStatus === 'proven') {
        counts.proven++;
      } else if (effectiveStatus === 'disproven') {
        counts.disproven++;
      } else if (effectiveStatus === 'unknown') {
        counts.unknown++;
      } else if (effectiveStatus === 'error') {
        counts.error++;
      } else if (effectiveStatus === 'timeout') {
        counts.timeout++;
      }
    });

    return counts;
  }, [visibleVCs, alternativeMap]);

  // Filter VCs based on status (from already-visible VCs)
  const filteredVCs = React.useMemo(() => {
    if (statusFilter === 'all') return visibleVCs;
    if (statusFilter === 'pending') {
      return visibleVCs.filter((vc) => getVisibleStatus(vc, alternativeMap) === null);
    }
    return visibleVCs.filter((vc) => getVisibleStatus(vc, alternativeMap) === statusFilter);
  }, [visibleVCs, statusFilter, alternativeMap]);

  // Group VCs by action
  const actionGroups = React.useMemo(() => groupByAction(filteredVCs), [filteredVCs]);

  // Separate initialization from other actions
  const initializationVCs = actionGroups.get('initializer') || [];
  const otherActions = Array.from(actionGroups.entries()).filter(
    ([action]) => action !== 'initializer'
  );



  const prettyJson = React.useMemo(() => showRawJson ? JSON.stringify(results, null, 2) : '', [showRawJson, results]);

  return (
    <>
      <style>{styles}</style>
      <div className="vr-root">
        {/* Toolbar with JSON toggle */}
        <div className="vr-toolbar">
          <button className="vr-toggle-link" onClick={() => setShowRawJson(!showRawJson)}>
            {showRawJson ? "Show formatted" : "Show JSON"}
          </button>
        </div>

        {showRawJson ? (
          <div className="vr-json-view">
            <CopyButton text={prettyJson} className="vr-copy-button" />
            <div className="vr-json-content">
              {prettyJson}
            </div>
          </div>
        ) : (
          <>
            {/* Filters */}
            <div className="vr-filters">
              <span className="vr-filter-label">Filter by status ({visibleVCs.length} VCs):</span>
              {(['all', 'pending', 'proven', 'disproven', 'unknown', 'error', 'timeout'] as StatusFilter[]).map((filter) => {
                // Only show filter buttons for groups with elements
                if (statusCounts[filter] === 0) return null;
                return (
                  <button
                    key={filter}
                    className={`vr-filter-button ${statusFilter === filter ? 'active' : ''}`}
                    onClick={() => setStatusFilter(filter)}
                  >
                    {getFilterButtonContent(filter)} ({statusCounts[filter]})
                  </button>
                );
              })}
            </div>

            <TrustedSmtBanner
              vcs={results.vcs}
              optionInsertPos={optionInsertPos}
            />

            {/* Banner for VCs needing manual proof */}
            <ManualProofBanner
              vcs={visibleVCs}
              alternativeMap={alternativeMap}
              theoremInsertPos={theoremInsertPos}
            />

            {filteredVCs.length === 0 ? (
              <div className="vr-empty">No verification conditions match the selected filter.</div>
            ) : (
              <>
                {/* Initialization Section */}
                {initializationVCs.length > 0 && (
                  <div className="vr-section">
                    <div className="vr-section-title">
                      Initialization must establish the invariant:
                    </div>
                    <div className="vr-section-content">
                      <div className="action-properties">
                        {initializationVCs.map((vc) => (
                          <PropertyRow
                            key={vc.id}
                            vc={vc}
                            alternatives={alternativeMap.get(vc.id)}
                            theoremInsertPos={theoremInsertPos}
                            serverTime={results.serverTime}
                          />
                        ))}
                      </div>
                    </div>
                  </div>
                )}

                {/* Actions Section */}
                {otherActions.length > 0 && (
                  <div className="vr-section">
                    <div className="vr-section-title">
                      The following set of actions must preserve the invariant:
                    </div>
                    <div className="vr-section-content">
                      {otherActions.map(([action, vcs]) => (
                        <ActionSection
                          key={action}
                          action={action}
                          vcs={vcs}
                          alternativeMap={alternativeMap}
                          theoremInsertPos={theoremInsertPos}
                          serverTime={results.serverTime}
                        />
                      ))}
                    </div>
                  </div>
                )}
              </>
            )}
          </>
        )}
      </div>
    </>
  );
};

export default function VerificationResultsWidget(props: VerificationResultsProps) {
  return <InsertionSourceContext.Provider value={props.insertionSourceHash}><VerificationResultsView {...props} /></InsertionSourceContext.Provider>;
}
