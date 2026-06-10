import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { SignJWT, importPKCS8 } from "jose";

const DEFAULT_TOKEN_TTL_SECONDS = 19 * 60;

export class AuthConfigError extends Error {
  constructor(message) {
    super(message);
    this.name = "AuthConfigError";
  }
}

export async function readPrivateKey(options) {
  if (options.privateKey) {
    return normalizePem(options.privateKey);
  }

  if (!options.privateKeyPath) {
    throw new AuthConfigError(
      "Missing App Store Connect private key. Set ASC_PRIVATE_KEY_PATH or ASC_PRIVATE_KEY.",
    );
  }

  const keyPath = resolve(options.privateKeyPath);
  return readFile(keyPath, "utf8");
}

export async function createJwt(options) {
  const keyId = options.keyId;
  const issuerId = options.issuerId;

  if (!keyId) {
    throw new AuthConfigError("Missing App Store Connect key ID. Set ASC_KEY_ID.");
  }

  if (!issuerId) {
    throw new AuthConfigError("Missing App Store Connect issuer ID. Set ASC_ISSUER_ID.");
  }

  const privateKey = await importPKCS8(await readPrivateKey(options), "ES256");
  const ttlSeconds = Number(options.tokenTtlSeconds || DEFAULT_TOKEN_TTL_SECONDS);

  return new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: keyId, typ: "JWT" })
    .setIssuer(issuerId)
    .setAudience("appstoreconnect-v1")
    .setIssuedAt()
    .setExpirationTime(`${ttlSeconds}s`)
    .sign(privateKey);
}

export class TokenProvider {
  constructor(options) {
    this.options = options;
    this.cachedToken = null;
    this.expiresAt = 0;
  }

  async getToken() {
    const now = Math.floor(Date.now() / 1000);
    if (this.cachedToken && now < this.expiresAt - 60) {
      return this.cachedToken;
    }

    this.cachedToken = await createJwt(this.options);
    this.expiresAt = now + Number(this.options.tokenTtlSeconds || DEFAULT_TOKEN_TTL_SECONDS);
    return this.cachedToken;
  }
}

function normalizePem(value) {
  return value.includes("\\n") ? value.replaceAll("\\n", "\n") : value;
}
