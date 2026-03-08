import { AppOptions } from "firebase-admin/app";

type BootstrapEnv = Record<string, string | undefined>;

interface ParsedFirebaseConfig {
  projectId?: string;
  storageBucket?: string;
}

function parseFirebaseConfig(rawValue: string | undefined): ParsedFirebaseConfig {
  if (!rawValue) {
    return {};
  }

  const trimmed = rawValue.trim();
  if (!trimmed.startsWith("{")) {
    return {};
  }

  try {
    const parsed = JSON.parse(trimmed) as ParsedFirebaseConfig;
    return {
      projectId: parsed.projectId?.trim() || undefined,
      storageBucket: normalizeStorageBucket(parsed.storageBucket),
    };
  } catch {
    return {};
  }
}

function normalizeStorageBucket(bucket: string | undefined): string | undefined {
  if (!bucket) {
    return undefined;
  }

  const trimmed = bucket.trim();
  if (!trimmed) {
    return undefined;
  }

  const withoutScheme = trimmed.replace(/^gs:\/\//, "");
  return withoutScheme.replace(/\/+$/, "") || undefined;
}

function isEmulatorEnvironment(env: BootstrapEnv): boolean {
  return Boolean(
    env.FIREBASE_EMULATOR_HUB ||
      env.FIRESTORE_EMULATOR_HOST ||
      env.FIREBASE_AUTH_EMULATOR_HOST ||
      env.FIREBASE_STORAGE_EMULATOR_HOST ||
      env.STORAGE_EMULATOR_HOST ||
      env.FUNCTIONS_EMULATOR,
  );
}

function resolveProjectId(env: BootstrapEnv, firebaseConfig: ParsedFirebaseConfig): string | undefined {
  return (
    env.GOOGLE_CLOUD_PROJECT?.trim() ||
    env.GCLOUD_PROJECT?.trim() ||
    firebaseConfig.projectId
  );
}

export function resolveStorageBucket(env: BootstrapEnv): string | undefined {
  const firebaseConfig = parseFirebaseConfig(env.FIREBASE_CONFIG);
  const explicitBucket = normalizeStorageBucket(env.FIREBASE_STORAGE_BUCKET ?? env.STORAGE_BUCKET);
  if (explicitBucket) {
    return explicitBucket;
  }

  if (firebaseConfig.storageBucket) {
    return firebaseConfig.storageBucket;
  }

  if (!isEmulatorEnvironment(env)) {
    return undefined;
  }

  const projectId = resolveProjectId(env, firebaseConfig);
  if (!projectId) {
    return undefined;
  }

  return `${projectId}.appspot.com`;
}

export function resolveFirebaseAdminOptions(env: BootstrapEnv = process.env): AppOptions | undefined {
  const firebaseConfig = parseFirebaseConfig(env.FIREBASE_CONFIG);
  const projectId = resolveProjectId(env, firebaseConfig);
  const storageBucket = resolveStorageBucket(env);

  const options: AppOptions = {};
  if (projectId) {
    options.projectId = projectId;
  }
  if (storageBucket) {
    options.storageBucket = storageBucket;
  }

  return Object.keys(options).length > 0 ? options : undefined;
}
