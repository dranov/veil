import * as React from 'react';
import { shortcutKey } from './shortcuts';

export function useWidgetShortcuts(actions: Record<string, (() => void) | undefined>) {
  return {
    tabIndex: 0,
    'data-veil-shortcuts': true,
    onKeyDown: (event: React.KeyboardEvent<HTMLElement>) => {
      const key = shortcutKey({...event, target: event.target as HTMLElement, isComposing: event.nativeEvent.isComposing});
      const action = key === null ? undefined : actions[key];
      if (action) { event.preventDefault(); event.stopPropagation(); action(); }
    },
  };
}
