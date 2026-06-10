import test from "node:test";
import assert from "node:assert/strict";
import {
  createTemplate,
  normalizeMetadataDocument,
  planMetadata,
  validateMetadata,
} from "../src/metadata.js";

test("normalizes locale-keyed metadata objects", () => {
  const document = normalizeMetadataDocument({
    "en-US": {
      name: "Example App",
      description: "Useful app.",
      keywords: "utility,notes",
      supportUrl: "https://example.com/support",
    },
  });

  assert.deepEqual(document.localizations, [
    {
      locale: "en-US",
      appInfo: { name: "Example App" },
      version: {
        description: "Useful app.",
        keywords: "utility,notes",
        supportUrl: "https://example.com/support",
      },
    },
  ]);
});

test("validates App Store metadata limits", () => {
  const result = validateMetadata({
    localizations: [
      {
        locale: "en-US",
        appInfo: {
          name: "A",
          subtitle: "x".repeat(31),
        },
        version: {
          description: "x".repeat(4001),
          keywords: "k".repeat(101),
          promotionalText: "x".repeat(171),
          supportUrl: "example.com",
        },
      },
    ],
  });

  assert.equal(result.errors.length, 6);
});

test("creates a useful default template", () => {
  const template = createTemplate(["en-US", "zh-Hans"]);
  assert.equal(template.localizations.length, 2);
  assert.equal(template.localizations[0].version.description, "");
});

test("plans app info creation before version localization creation", async () => {
  const client = {
    async listAppInfos() {
      return [{ id: "app-info-1", attributes: { state: "PREPARE_FOR_SUBMISSION" } }];
    },
    async listAppInfoLocalizations() {
      return [];
    },
    async listAppStoreVersionLocalizations() {
      return [];
    },
  };

  const plan = await planMetadata(client, {
    appId: "app-1",
    versionId: "version-1",
    document: {
      localizations: [
        {
          locale: "en-US",
          appInfo: { name: "Example App" },
          version: {
            description: "Useful app.",
            keywords: "utility,notes",
            supportUrl: "https://example.com/support",
          },
        },
      ],
    },
  });

  assert.equal(plan.errors.length, 0);
  assert.deepEqual(
    plan.actions.map((action) => `${action.resource}:${action.action}`),
    ["appInfoLocalization:create", "appStoreVersionLocalization:create"],
  );
});
