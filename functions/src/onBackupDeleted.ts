import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { onObjectDeleted } from "firebase-functions/v2/storage";
import { handleBackupDeleted } from "./backupPhoto";

export const onBackupDeleted = onObjectDeleted({ region: "asia-south1" }, async (event) => {
  const db = getFirestore();
  await handleBackupDeleted(event.data.name, {
    clearPhotoUrl: async (uid, id) => {
      try {
        await db.doc(`users/${uid}/history/${id}`).update({ photoUrl: FieldValue.delete() });
      } catch (e) {
        if ((e as { code?: number }).code !== 5) throw e; // 5 = NOT_FOUND: the history doc is already gone
      }
    },
  });
});
