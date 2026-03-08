import { describe, expect, it } from "vitest";

import { resolveFirebaseAdminOptions, resolveStorageBucket } from "../src/firebaseBootstrap";

describe("firebase bootstrap", () => {
  it("prefers explicit storage bucket env overrides", () => {
    expect(resolveStorageBucket({
      FIREBASE_STORAGE_BUCKET: "gs://custom-bucket",
      FIREBASE_STORAGE_EMULATOR_HOST: "127.0.0.1:9199",
      GCLOUD_PROJECT: "clearify-5414d",
    })).toBe("custom-bucket");
  });

  it("uses FIREBASE_CONFIG storageBucket when present", () => {
    expect(resolveFirebaseAdminOptions({
      FIREBASE_CONFIG: JSON.stringify({
        projectId: "clearify-5414d",
        storageBucket: "clearify-5414d.appspot.com",
      }),
    })).toEqual({
      projectId: "clearify-5414d",
      storageBucket: "clearify-5414d.appspot.com",
    });
  });

  it("derives an emulator bucket from the project id when none is configured", () => {
    expect(resolveFirebaseAdminOptions({
      FIREBASE_STORAGE_EMULATOR_HOST: "127.0.0.1:9199",
      GCLOUD_PROJECT: "clearify-5414d",
    })).toEqual({
      projectId: "clearify-5414d",
      storageBucket: "clearify-5414d.appspot.com",
    });
  });

  it("does not invent a bucket outside emulator mode", () => {
    expect(resolveFirebaseAdminOptions({
      GCLOUD_PROJECT: "clearify-5414d",
    })).toEqual({
      projectId: "clearify-5414d",
    });
  });
});
