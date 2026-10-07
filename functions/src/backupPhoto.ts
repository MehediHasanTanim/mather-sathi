/** `backups/{uid}/{historyId}.jpg` → the pieces, or null for any other object. */
export function parseBackupPath(name: string): { uid: string; id: string } | null {
  const m = /^backups\/([^/]+)\/([^/]+)\.jpg$/.exec(name);
  return m ? { uid: m[1], id: m[2] } : null;
}

export interface HistoryDocs {
  /** Clears `photoUrl`. Must not create the doc when it is gone (e.g. after deleteMyData). */
  clearPhotoUrl(uid: string, id: string): Promise<void>;
}

/** When a backup is deleted (30-day lifecycle rule), the history doc must stop pointing at it. Returns whether it acted. */
export async function handleBackupDeleted(name: string, docs: HistoryDocs): Promise<boolean> {
  const p = parseBackupPath(name);
  if (!p) return false;
  await docs.clearPhotoUrl(p.uid, p.id);
  return true;
}
