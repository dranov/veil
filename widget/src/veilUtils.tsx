
import * as React from 'react';

import type { MergedElement } from './valueDiff';
export { deepEqual, computeMergedView, diffChanges } from './valueDiff';
export type { ChangeInfo, MergedElement } from './valueDiff';

// ========== React Helpers ==========

/** Concatenate React nodes with separator */
export function joinNodes(nodes: React.ReactNode[], sep: React.ReactNode = ', '): React.ReactNode {
  const out: React.ReactNode[] = [];
  nodes.forEach((n, i) => {
    out.push(<span key={`n-${i}`}>{n}</span>);
    if (i < nodes.length - 1) out.push(<span key={`s-${i}`}>{sep}</span>);
  });
  return <>{out}</>;
}

/** Copy button component */
export const CopyButton: React.FC<{ text: string; className?: string }> = ({ text, className }) => {
  const [copied, setCopied] = React.useState(false);

  const handleCopy = async () => {
    try {
      await navigator.clipboard.writeText(text);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch (err) {
      console.error('Failed to copy:', err);
    }
  };

  return (
    <button className={className} onClick={handleCopy} title="Copy to clipboard">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
        {copied ? (
          <path d="M20 6L9 17l-5-5" strokeLinecap="round" strokeLinejoin="round" />
        ) : (
          <>
            <rect x="9" y="9" width="13" height="13" rx="2" ry="2" />
            <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" />
          </>
        )}
      </svg>
      {copied ? 'Copied!' : 'Copy JSON'}
    </button>
  );
};

// ========== String Helpers ==========

/** Remove namespace prefixes like A.B.C, keeping only the last segment */
export function dequalify(s: string): string {
  const parts = s.trim().split(/\s+/);

  const cleaned = parts
    .map((tok) => {
      let t = tok.replace(/^[()\[\]{}:,]+|[()\[\]{}:,]+$/g, "");
      if (/^-?\d+(?:\.\d+)?$/.test(t)) return t;
      if (t.includes(".")) {
        const segs = t.split(".");
        t = segs[segs.length - 1] || t;
      }
      return t;
    })
    .filter((t) => t.length > 0);

  return cleaned.join(" ");
}

/** Format an action/label object like {"recv": {"sender": 2}} into "recv(sender = 2)" */
export function formatActionLabel(label: unknown): string {
  if (typeof label === "string") {
    return label;
  }

  if (typeof label === "object" && label !== null) {
    const obj = label as Record<string, unknown>;
    const keys = Object.keys(obj);

    if (keys.length === 1) {
      let actionName = keys[0];
      if (actionName.startsWith("_")) {
        actionName = actionName.slice(1);
      }

      const args = obj[keys[0]];
      if (typeof args === "object" && args !== null && !Array.isArray(args)) {
        const argObj = args as Record<string, unknown>;
        const argKeys = Object.keys(argObj);
        if (argKeys.length > 0) {
          const formatValue = (v: unknown): string => {
            if (typeof v === "string") return v;
            if (typeof v === "number" || typeof v === "boolean") return String(v);
            return JSON.stringify(v);
          };
          const argStr = argKeys
            .map((k) => `${k} = ${formatValue(argObj[k])}`)
            .join(", ");
          return `${actionName}(${argStr})`;
        }
      }

      return actionName;
    }
  }

  return JSON.stringify(label);
}

// ========== Value Rendering ==========

/** Render any value inline (arrays as [a, b, ...]) */
export function renderValueInline(x: unknown): React.ReactNode {
  if (Array.isArray(x)) {
    const elements = x.map((el, i) => <span key={i}>{renderValueInline(el)}</span>);
    return <code>[{joinNodes(elements)}]</code>;
  }
  if (typeof x === 'object' && x !== null) {
    return <code>{JSON.stringify(x)}</code>;
  }
  if (typeof x === 'string') {
    return <code>{dequalify(x)}</code>;
  }
  return <code>{String(x)}</code>;
}

/** Render inline array using merged view for proper ordering */
export function renderInlineArrayMerged(mergedView: MergedElement[]): React.ReactNode {
  const parts: React.ReactNode[] = [];

  mergedView.forEach((item, i) => {
    const element = renderValueInline(item.element);
    const className = item.status === 'added' ? 'changed-element' : item.status === 'removed' ? 'removed-element' : undefined;
    parts.push(className ? <span key={i} className={className}>{element}</span> : <span key={i}>{element}</span>);
    if (i < mergedView.length - 1) parts.push(<span key={`comma-${i}`}>, </span>);
  });
  return <code>[{parts}]</code>;
}

/** Render inline array (when no diff info available) */
export function renderInlineArray(arr: unknown[]): React.ReactNode {
  const parts: React.ReactNode[] = [];
  arr.forEach((e, i) => {
    parts.push(<span key={i}>{renderValueInline(e)}</span>);
    if (i < arr.length - 1) parts.push(<span key={`comma-${i}`}>, </span>);
  });
  return <code>[{parts}]</code>;
}

/**
 * Render a row from an inner array:
 * - If it's a flat tuple (all elements are primitives), render as (a, b, c)
 * - Otherwise, render the inner array inline as [a, b, ...]
 */
export function renderRowFromInnerArray(e: unknown, status?: 'unchanged' | 'added' | 'removed'): React.ReactNode {
  const className = status === 'added' ? 'changed-element' : status === 'removed' ? 'removed-element' : undefined;

  if (Array.isArray(e)) {
    const isFlatTuple = e.every(el => !Array.isArray(el));
    if (isFlatTuple) {
      const parts: React.ReactNode[] = [];
      e.forEach((el, i) => {
        parts.push(renderValueInline(el));
        if (i < e.length - 1) parts.push(', ');
      });
      const code = <code>({parts})</code>;
      return className ? <span className={className}>{code}</span> : code;
    } else {
      const content = renderValueInline(e);
      return className ? <span className={className}>{content}</span> : content;
    }
  }
  return renderValue(e);
}

/** Render a value with optional diff highlighting via mergedView */
export function renderValue(v: unknown, mergedView?: MergedElement[]): React.ReactNode {
  if (Array.isArray(v)) {
    if (v.length === 0 && (!mergedView || mergedView.length === 0)) {
      return <code>[]</code>;
    }

    if (mergedView && mergedView.length > 0) {
      const hasInnerArray = mergedView.some(m => Array.isArray(m.element));

      if (hasInnerArray) {
        return (
          <ul className="list">
            {mergedView.map((item, i) => (
              <li key={i}>{renderRowFromInnerArray(item.element, item.status)}</li>
            ))}
          </ul>
        );
      }

      return renderInlineArrayMerged(mergedView);
    }

    const hasInnerArray = v.some(Array.isArray);
    if (hasInnerArray) {
      return (
        <ul className="list">
          {v.map((e, i) => (
            <li key={i}>{renderRowFromInnerArray(e)}</li>
          ))}
        </ul>
      );
    }

    return renderInlineArray(v);
  }

  if (typeof v === 'object' && v !== null) {
    return <code>{JSON.stringify(v)}</code>;
  }

  if (typeof v === 'string') {
    return <code>{dequalify(v)}</code>;
  }

  return <code>{String(v)}</code>;
}

// ========== Extra Values Processing ==========

export interface SplitExtraValsResult {
  theoryExtras: Record<string, unknown>;
  remainingExtras: Record<string, unknown>;
}

/**
 * Split extraVals: items with '.' in name go to theory, others stay as extra values.
 * This is used to merge theory-related extraVals (like "tot.le") into the theory section.
 */
export function splitExtraVals(extraVals: Record<string, unknown> | undefined): SplitExtraValsResult {
  const theoryExtras: Record<string, unknown> = {};
  const remainingExtras: Record<string, unknown> = {};

  if (extraVals) {
    for (const [k, v] of Object.entries(extraVals)) {
      if (k.includes('.')) {
        theoryExtras[k] = v;
      } else {
        remainingExtras[k] = v;
      }
    }
  }

  return { theoryExtras, remainingExtras };
}

/**
 * Merge theory with extraVals that have '.' in their names.
 * Returns the combined theory and remaining extraVals.
 */
export function mergeTheoryWithExtras(
  theory: Record<string, unknown>,
  extraVals: Record<string, unknown> | undefined
): { combinedTheory: Record<string, unknown>; remainingExtraVals: Record<string, unknown> } {
  const { theoryExtras, remainingExtras } = splitExtraVals(extraVals);
  return {
    combinedTheory: { ...theory, ...theoryExtras },
    remainingExtraVals: remainingExtras,
  };
}

// ========== Instantiation Component ==========

export interface InstantiationRowProps {
  instantiation: Record<string, unknown>;
  prefix: string;
}

/** Reusable instantiation row component */
export const InstantiationRow: React.FC<InstantiationRowProps> = ({ instantiation, prefix }) => {
  if (!instantiation || Object.keys(instantiation).length === 0) {
    return null;
  }

  return (
    <div className={`${prefix}-instantiation-row`}>
      <span className={`${prefix}-instantiation-label`}>Instantiation</span>
      <div className={`${prefix}-instantiation-values`}>
        {Object.entries(instantiation).map(([k, v]) => (
          <span key={k} className={`${prefix}-instantiation-item`}>
            <span className={`${prefix}-instantiation-key`}>{k}</span>
            <span className={`${prefix}-instantiation-eq`}>=</span>
            <span className={`${prefix}-instantiation-val`}>{String(v)}</span>
          </span>
        ))}
      </div>
    </div>
  );
};
