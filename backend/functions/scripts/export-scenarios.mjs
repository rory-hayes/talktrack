import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { buildScenarioLibrary } from "./scenario-library.mjs";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const scenarios = buildScenarioLibrary();
const outputPath = path.resolve(__dirname, "../../../ios/Clearify/Resources/scenarios.json");

fs.mkdirSync(path.dirname(outputPath), { recursive: true });
fs.writeFileSync(outputPath, JSON.stringify(scenarios, null, 2));

console.log(`Wrote ${scenarios.length} scenarios to ${outputPath}`);
