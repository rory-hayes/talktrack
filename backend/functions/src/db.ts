import { initializeApp, getApps } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";

import { resolveFirebaseAdminOptions } from "./firebaseBootstrap";

if (!getApps().length) {
  initializeApp(resolveFirebaseAdminOptions());
}

export const db = getFirestore();
export const storage = getStorage();
