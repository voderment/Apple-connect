import { readFile, writeFile } from "node:fs/promises";
import { extname } from "node:path";
import YAML from "yaml";

export const APP_INFO_FIELDS = [
  "name",
  "subtitle",
  "privacyPolicyUrl",
  "privacyChoicesUrl",
  "privacyPolicyText",
];

export const VERSION_FIELDS = [
  "description",
  "keywords",
  "marketingUrl",
  "promotionalText",
  "supportUrl",
  "whatsNew",
];

export class CliError extends Error {
  constructor(message) {
    super(message);
    this.name = "CliError";
  }
}

export async function readMetadataFile(filePath) {
  const content = await readFile(filePath, "utf8");
  const parsed = parseDocument(content, filePath);
  return normalizeMetadataDocument(parsed);
}

export async function writeMetadataFile(filePath, document) {
  const content = isYamlPath(filePath)
    ? YAML.stringify(document, { lineWidth: 0 })
    : `${JSON.stringify(document, null, 2)}\n`;
  await writeFile(filePath, content, "utf8");
}

export function normalizeMetadataDocument(document) {
  if (!document || typeof document !== "object") {
    throw new CliError("Metadata file must contain an object or an array.");
  }

  const source = Array.isArray(document)
    ? document
    : document.localizations || document.locales || document;

  const entries = Array.isArray(source)
    ? source.map((entry) => normalizeLocalizationEntry(entry.locale, entry))
    : Object.entries(source).map(([locale, entry]) => normalizeLocalizationEntry(locale, entry));

  return {
    localizations: entries,
  };
}

export function validateMetadata(document, options = {}) {
  const normalized = normalizeMetadataDocument(document);
  const errors = [];
  const warnings = [];
  const seenLocales = new Set();

  for (const entry of normalized.localizations) {
    const location = entry.locale || "(missing locale)";

    if (!entry.locale || typeof entry.locale !== "string") {
      errors.push(`${location}: locale is required.`);
      continue;
    }

    if (seenLocales.has(entry.locale)) {
      errors.push(`${entry.locale}: duplicate locale.`);
    }
    seenLocales.add(entry.locale);

    validateFieldLengths(entry, errors, warnings);
    validateUrls(entry, errors);

    if (isEmptyObject(entry.appInfo) && isEmptyObject(entry.version)) {
      warnings.push(`${entry.locale}: no appInfo or version fields were provided.`);
    }

    if (options.warnForSubmission !== false) {
      warnForMissingSubmissionFields(entry, warnings);
    }
  }

  return { errors, warnings, localizations: normalized.localizations };
}

export function createTemplate(locales) {
  return {
    localizations: locales.map((locale) => ({
      locale,
      appInfo: {
        name: "",
        subtitle: "",
        privacyPolicyUrl: "",
      },
      version: {
        description: "",
        keywords: "",
        promotionalText: "",
        supportUrl: "",
        marketingUrl: "",
        whatsNew: "",
      },
    })),
  };
}

export async function pullMetadata(client, options) {
  const appInfoId = await resolveAppInfoId(client, options);
  const [appInfoLocalizations, versionLocalizations] = await Promise.all([
    client.listAppInfoLocalizations(appInfoId),
    client.listAppStoreVersionLocalizations(options.versionId),
  ]);

  const byLocale = new Map();
  for (const localization of appInfoLocalizations) {
    const locale = localization.attributes.locale;
    byLocale.set(locale, {
      locale,
      appInfo: pick(localization.attributes, APP_INFO_FIELDS),
      version: {},
    });
  }

  for (const localization of versionLocalizations) {
    const locale = localization.attributes.locale;
    const entry = byLocale.get(locale) || { locale, appInfo: {}, version: {} };
    entry.version = pick(localization.attributes, VERSION_FIELDS);
    byLocale.set(locale, entry);
  }

  return {
    localizations: [...byLocale.values()].sort((a, b) => a.locale.localeCompare(b.locale)),
  };
}

export async function planMetadata(client, options) {
  const validation = validateMetadata(options.document);
  const actions = [];
  const errors = [...validation.errors];
  const warnings = [...validation.warnings];
  const locales = validation.localizations.map((entry) => entry.locale);
  const appInfoId = await resolveAppInfoId(client, options);

  const [appInfoLocalizations, versionLocalizations] = await Promise.all([
    client.listAppInfoLocalizations(appInfoId, { locales }),
    client.listAppStoreVersionLocalizations(options.versionId, { locales }),
  ]);

  const existingAppInfo = indexByLocale(appInfoLocalizations);
  const existingVersion = indexByLocale(versionLocalizations);

  for (const entry of validation.localizations) {
    const appInfoAttributes = compactAttributes(entry.appInfo, APP_INFO_FIELDS);
    const versionAttributes = compactAttributes(entry.version, VERSION_FIELDS);
    const currentAppInfo = existingAppInfo.get(entry.locale);
    const currentVersion = existingVersion.get(entry.locale);

    if (!isEmptyObject(appInfoAttributes)) {
      const action = createResourceAction({
        resource: "appInfoLocalization",
        locale: entry.locale,
        existing: currentAppInfo,
        attributes: appInfoAttributes,
        requiredCreateFields: ["name"],
      });
      if (action.error) {
        errors.push(`${entry.locale}: ${action.error}`);
      }
      actions.push(action);
    }

    if (!isEmptyObject(versionAttributes)) {
      if (!currentAppInfo && options.ensureAppInfo !== false) {
        if (!appInfoAttributes.name) {
          errors.push(
            `${entry.locale}: App Info localization does not exist. Add appInfo.name so it can be created before version metadata.`,
          );
        } else if (isEmptyObject(appInfoAttributes)) {
          errors.push(
            `${entry.locale}: App Info localization does not exist and no appInfo fields were provided.`,
          );
        }
      }

      actions.push(
        createResourceAction({
          resource: "appStoreVersionLocalization",
          locale: entry.locale,
          existing: currentVersion,
          attributes: { locale: entry.locale, ...versionAttributes },
          requiredCreateFields: [],
        }),
      );
    }
  }

  return {
    appInfoId,
    versionId: options.versionId,
    errors,
    warnings,
    actions,
  };
}

export async function applyMetadataPlan(client, plan) {
  if (plan.errors.length > 0) {
    throw new CliError(`Plan has errors:\n${plan.errors.map((error) => `- ${error}`).join("\n")}`);
  }

  const results = [];
  const runnableActions = plan.actions.filter((action) => action.action !== "skip");
  const sortedActions = [
    ...runnableActions.filter((action) => action.resource === "appInfoLocalization"),
    ...runnableActions.filter((action) => action.resource === "appStoreVersionLocalization"),
  ];

  for (const action of sortedActions) {
    if (action.resource === "appInfoLocalization" && action.action === "create") {
      const response = await client.createAppInfoLocalization(plan.appInfoId, {
        locale: action.locale,
        ...action.attributes,
      });
      results.push({ action, id: response.data.id });
    }

    if (action.resource === "appInfoLocalization" && action.action === "update") {
      const response = await client.updateAppInfoLocalization(action.id, action.attributes);
      results.push({ action, id: response.data.id });
    }

    if (action.resource === "appStoreVersionLocalization" && action.action === "create") {
      const response = await client.createAppStoreVersionLocalization(
        plan.versionId,
        action.attributes,
      );
      results.push({ action, id: response.data.id });
    }

    if (action.resource === "appStoreVersionLocalization" && action.action === "update") {
      const attributes = omit(action.attributes, ["locale"]);
      const response = await client.updateAppStoreVersionLocalization(action.id, attributes);
      results.push({ action, id: response.data.id });
    }
  }

  return results;
}

export async function resolveAppInfoId(client, options) {
  if (options.appInfoId) {
    return options.appInfoId;
  }

  if (!options.appId) {
    throw new CliError("Missing --app-id or --app-info-id.");
  }

  const appInfos = await client.listAppInfos(options.appId);
  if (appInfos.length === 0) {
    throw new CliError(`No App Info resource found for app ${options.appId}.`);
  }

  if (appInfos.length > 1) {
    const prepared = appInfos.find((item) => item.attributes?.state === "PREPARE_FOR_SUBMISSION");
    return prepared?.id || appInfos[0].id;
  }

  return appInfos[0].id;
}

function parseDocument(content, filePath) {
  if (isYamlPath(filePath)) {
    return YAML.parse(content);
  }

  return JSON.parse(content);
}

function normalizeLocalizationEntry(localeFromKey, rawEntry = {}) {
  const locale = rawEntry.locale || localeFromKey;
  const appInfoSource = {
    ...(rawEntry.appInfo || rawEntry.appInfoLocalization || {}),
  };
  const versionSource = {
    ...(rawEntry.version || rawEntry.appStoreVersionLocalization || {}),
  };

  for (const field of APP_INFO_FIELDS) {
    if (Object.prototype.hasOwnProperty.call(rawEntry, field)) {
      appInfoSource[field] = rawEntry[field];
    }
  }

  for (const field of VERSION_FIELDS) {
    if (Object.prototype.hasOwnProperty.call(rawEntry, field)) {
      versionSource[field] = rawEntry[field];
    }
  }

  return {
    locale,
    appInfo: compactAttributes(appInfoSource, APP_INFO_FIELDS),
    version: compactAttributes(versionSource, VERSION_FIELDS),
  };
}

function validateFieldLengths(entry, errors, warnings) {
  const appInfo = entry.appInfo;
  const version = entry.version;
  const locale = entry.locale;

  if (hasValue(appInfo.name)) {
    const length = countCharacters(appInfo.name);
    if (length < 2 || length > 30) {
      errors.push(`${locale}: appInfo.name must be 2-30 characters.`);
    }
  }

  if (hasValue(appInfo.subtitle) && countCharacters(appInfo.subtitle) > 30) {
    errors.push(`${locale}: appInfo.subtitle must be 30 characters or fewer.`);
  }

  if (hasValue(version.promotionalText) && countCharacters(version.promotionalText) > 170) {
    errors.push(`${locale}: version.promotionalText must be 170 characters or fewer.`);
  }

  if (hasValue(version.description) && countCharacters(version.description) > 4000) {
    errors.push(`${locale}: version.description must be 4000 characters or fewer.`);
  }

  if (hasValue(version.whatsNew) && countCharacters(version.whatsNew) > 4000) {
    errors.push(`${locale}: version.whatsNew must be 4000 characters or fewer.`);
  }

  if (hasValue(version.keywords)) {
    const bytes = Buffer.byteLength(version.keywords, "utf8");
    if (bytes > 100) {
      errors.push(`${locale}: version.keywords must be 100 UTF-8 bytes or fewer.`);
    }

    for (const keyword of version.keywords.split(",").map((item) => item.trim()).filter(Boolean)) {
      if (countCharacters(keyword) <= 2) {
        warnings.push(`${locale}: keyword "${keyword}" is two characters or fewer.`);
      }
    }
  }
}

function validateUrls(entry, errors) {
  const urlFields = [
    ["appInfo.privacyPolicyUrl", entry.appInfo.privacyPolicyUrl],
    ["appInfo.privacyChoicesUrl", entry.appInfo.privacyChoicesUrl],
    ["version.marketingUrl", entry.version.marketingUrl],
    ["version.supportUrl", entry.version.supportUrl],
  ];

  for (const [field, value] of urlFields) {
    if (!hasValue(value)) {
      continue;
    }

    if (!isHttpUrl(value)) {
      errors.push(`${entry.locale}: ${field} must be a full http(s) URL.`);
    }
  }
}

function warnForMissingSubmissionFields(entry, warnings) {
  if (!isEmptyObject(entry.version)) {
    for (const field of ["description", "keywords", "supportUrl"]) {
      if (!hasValue(entry.version[field])) {
        warnings.push(`${entry.locale}: version.${field} is required before App Store submission.`);
      }
    }
  }
}

function createResourceAction(options) {
  const existing = options.existing;
  if (!existing) {
    const missingFields = options.requiredCreateFields.filter((field) => !hasValue(options.attributes[field]));
    if (missingFields.length > 0) {
      return {
        resource: options.resource,
        action: "invalid",
        locale: options.locale,
        fields: Object.keys(options.attributes),
        error: `Missing required create fields: ${missingFields.join(", ")}`,
      };
    }

    return {
      resource: options.resource,
      action: "create",
      locale: options.locale,
      attributes: options.attributes,
      fields: Object.keys(options.attributes),
    };
  }

  const changes = diffAttributes(existing.attributes || {}, options.attributes);
  if (Object.keys(changes).length === 0) {
    return {
      resource: options.resource,
      action: "skip",
      locale: options.locale,
      id: existing.id,
      attributes: {},
      fields: [],
    };
  }

  return {
    resource: options.resource,
    action: "update",
    locale: options.locale,
    id: existing.id,
    attributes: pick(options.attributes, Object.keys(changes)),
    fields: Object.keys(changes),
    changes,
  };
}

function indexByLocale(resources) {
  return new Map(resources.map((resource) => [resource.attributes.locale, resource]));
}

function diffAttributes(current, desired) {
  const changes = {};
  for (const [field, value] of Object.entries(desired)) {
    if (field === "locale") {
      continue;
    }

    if ((current[field] ?? null) !== (value ?? null)) {
      changes[field] = {
        from: current[field] ?? null,
        to: value ?? null,
      };
    }
  }

  return changes;
}

function compactAttributes(source = {}, allowedFields) {
  const output = {};
  for (const field of allowedFields) {
    if (Object.prototype.hasOwnProperty.call(source, field) && source[field] !== undefined) {
      output[field] = source[field];
    }
  }

  return output;
}

function pick(source = {}, fields) {
  const output = {};
  for (const field of fields) {
    if (Object.prototype.hasOwnProperty.call(source, field) && source[field] !== undefined) {
      output[field] = source[field];
    }
  }

  return output;
}

function omit(source = {}, fields) {
  return Object.fromEntries(Object.entries(source).filter(([field]) => !fields.includes(field)));
}

function isEmptyObject(value) {
  return Object.keys(value || {}).length === 0;
}

function hasValue(value) {
  return value !== undefined && value !== null && value !== "";
}

function countCharacters(value) {
  return [...String(value)].length;
}

function isHttpUrl(value) {
  try {
    const url = new URL(value);
    return url.protocol === "http:" || url.protocol === "https:";
  } catch {
    return false;
  }
}

function isYamlPath(filePath) {
  const extension = extname(filePath).toLowerCase();
  return extension === ".yaml" || extension === ".yml";
}
