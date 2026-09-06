import type { InsertPosition } from './protocol';

/** Delimit both sides so insertion is valid before a command and at EOF. */
export function insertionText(text: string): string {
  return '\n\n' + text.replace(/\r\n/g, '\n').replace(/\n+$/, '') + '\n\n';
}

export function insertionEdit(uri: string, version: number, position: InsertPosition, text: string) {
  return {documentChanges: [{textDocument: {uri, version}, edits: [{range: {start: position, end: position}, newText: insertionText(text)}]}]};
}

export function insertionErrorMessage(error: unknown): string {
  if (typeof error === 'object' && error !== null && 'message' in error && typeof error.message === 'string') return error.message;
  return String(error);
}
