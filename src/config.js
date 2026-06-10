import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";

const DEFAULT_BASE_URL = "https://api.appstoreconnect.apple.com";

export function loadEnvFile(filePath = ".env", env = process.env) {
  const resolved = resolve(filePath);
  if (!existsSync(resolved)) {
    return false;
  }

  const content = readFileSync(resolved, "utf8");
  for (const line of content.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) {
      continue;
    }

    const match = trimmed.match(/^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/);
    if (!match) {
      continue;
    }

    const [, key, rawValue] = match;
    if (Object.prototype.hasOwnProperty.call(env, key)) {
      continue;
    }

    env[key] = unquoteEnvValue(rawValue.trim());
  }

  return true;
}

export function resolveAuthOptions(options = {}, env = process.env) {
  return {
    keyId: options.keyId || env.ASC_KEY_ID,
    issuerId: options.issuerId || env.ASC_ISSUER_ID,
    privateKeyPath: options.privateKeyPath || env.ASC_PRIVATE_KEY_PATH,
    privateKey: options.privateKey || env.ASC_PRIVATE_KEY,
    tokenTtlSeconds: options.tokenTtlSeconds || env.ASC_TOKEN_TTL_SECONDS,
  };
}

export function resolveBaseUrl(options = {}, env = process.env) {
  return options.baseUrl || env.ASC_API_BASE_URL || DEFAULT_BASE_URL;
}

function unquoteEnvValue(value) {
  if (
    (value.startsWith("\"") && value.endsWith("\"")) ||
    (value.startsWith("'") && value.endsWith("'"))
  ) {
    return value.slice(1, -1);
  }

  return value;
}
