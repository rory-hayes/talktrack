import admin from "firebase-admin";
import { buildScenarioLibrary } from "./scenario-library.mjs";

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function run() {
  const scenarios = buildScenarioLibrary();
  const batchSize = 400;

  for (let i = 0; i < scenarios.length; i += batchSize) {
    const batch = db.batch();
    const slice = scenarios.slice(i, i + batchSize);

    for (const scenario of slice) {
      const ref = db.collection("scenarios").doc(scenario.id);
      batch.set(ref, scenario, { merge: true });
    }

    await batch.commit();
    console.log(`Seeded ${Math.min(i + batchSize, scenarios.length)} / ${scenarios.length}`);
  }

  console.log(`Done. Seeded ${scenarios.length} scenarios.`);
}

run().catch((error) => {
  console.error(error);
  process.exit(1);
});
