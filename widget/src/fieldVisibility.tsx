import * as React from 'react';

export function useFieldVisibility(fieldNames: string[]) {
  const [hiddenFields, setHiddenFields] = React.useState<Set<string>>(new Set());
  const [showFilterPanel, setShowFilterPanel] = React.useState(false);
  const toggleFieldVisibility = (name: string) => setHiddenFields(previous => {
    const next = new Set(previous);
    if (next.has(name)) next.delete(name); else next.add(name);
    return next;
  });
  return {hiddenFields, showFilterPanel, setShowFilterPanel, toggleFieldVisibility,
    showAllFields: () => setHiddenFields(new Set()),
    hideAllFields: () => setHiddenFields(new Set(fieldNames))};
}

type Visibility = ReturnType<typeof useFieldVisibility>;

export function FieldFilter({prefix, fieldNames, visibility}: {
  prefix: 'mc' | 'cex'; fieldNames: string[]; visibility: Visibility;
}) {
  const {hiddenFields, showFilterPanel, setShowFilterPanel, toggleFieldVisibility, showAllFields, hideAllFields} = visibility;
  if (!showFilterPanel) return null;
  return <>
    <div className={`${prefix}-filter-backdrop`} onClick={() => setShowFilterPanel(false)} />
    <div className={`${prefix}-filter-panel`} role="dialog" aria-label="Visible Fields">
      <div className={`${prefix}-filter-header`}>
        <span>Visible Fields</span>
        <div className={`${prefix}-filter-actions`}>
          <button className={`${prefix}-filter-action`} onClick={showAllFields}>Show all</button>
          <button className={`${prefix}-filter-action`} onClick={hideAllFields}>Hide all</button>
          <button className={`${prefix}-filter-close`} onClick={() => setShowFilterPanel(false)} title="Close (Esc)">×</button>
        </div>
      </div>
      <div className={`${prefix}-filter-list`}>
        {fieldNames.map(name => <label key={name} className={`${prefix}-filter-item`}>
          <input type="checkbox" checked={!hiddenFields.has(name)} onChange={() => toggleFieldVisibility(name)} />
          <span>{name}</span>
        </label>)}
      </div>
    </div>
  </>;
}
