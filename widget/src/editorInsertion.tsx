import * as React from 'react';
import { EditorContext, useRpcSession } from '@leanprover/infoview';
import type { InsertPosition } from './protocol';
import { insertionEdit, insertionErrorMessage } from './editorEdits';

export const InsertionSourceContext = React.createContext('');

/** Shared adapter: validate anchors, use a versioned edit, and surface errors in the widget. */
export function useEditorInsertion(position?: InsertPosition | null) {
  const editor = React.useContext(EditorContext);
  const sourceHash = React.useContext(InsertionSourceContext);
  const rpc = useRpcSession();
  const [error, setError] = React.useState<string>();
  const insert = async (text: string) => {
    try {
      if (!editor || !position) throw new Error('Editor insertion is unavailable.');
      const document = await rpc.call<string, {uri: string; version: number}>('Veil.Verifier.insertionDocument', sourceHash);
      await editor.api.applyEdit(insertionEdit(document.uri, document.version, position, text));
      setError(undefined);
      return true;
    } catch (error) {
      setError(insertionErrorMessage(error));
      return false;
    }
  };
  return {insert, error: error && <span role="alert" className="insertion-error">{error}</span>};
}
