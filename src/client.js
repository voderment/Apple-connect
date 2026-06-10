import { TokenProvider } from "./auth.js";

export class AppStoreConnectApiError extends Error {
  constructor(message, response, payload) {
    super(message);
    this.name = "AppStoreConnectApiError";
    this.status = response.status;
    this.statusText = response.statusText;
    this.payload = payload;
  }
}

export class AppStoreConnectClient {
  constructor(authOptions, options = {}) {
    this.baseUrl = options.baseUrl || "https://api.appstoreconnect.apple.com";
    this.tokenProvider = new TokenProvider(authOptions);
  }

  async request(pathOrUrl, options = {}) {
    const url = buildUrl(this.baseUrl, pathOrUrl, options.query);
    const token = await this.tokenProvider.getToken();
    const headers = {
      Authorization: `Bearer ${token}`,
      Accept: "application/json",
      ...options.headers,
    };

    let body;
    if (options.body !== undefined) {
      headers["Content-Type"] = "application/json";
      body = JSON.stringify(options.body);
    }

    const response = await fetch(url, {
      method: options.method || "GET",
      headers,
      body,
    });

    if (response.status === 204) {
      return null;
    }

    const text = await response.text();
    const payload = text ? parseJson(text) : null;

    if (!response.ok) {
      throw new AppStoreConnectApiError(formatApiError(response, payload), response, payload);
    }

    return payload;
  }

  async paginate(path, query = {}) {
    const resources = [];
    let next = path;
    let nextQuery = query;

    while (next) {
      const page = await this.request(next, { query: nextQuery });
      resources.push(...(page.data || []));
      next = page.links?.next || null;
      nextQuery = {};
    }

    return resources;
  }

  listApps(options = {}) {
    return this.paginate("/v1/apps", {
      "filter[bundleId]": options.bundleId,
      "filter[name]": options.name,
      "fields[apps]": "name,bundleId,sku,primaryLocale",
      limit: options.limit || 200,
      sort: "name",
    });
  }

  listAppInfos(appId) {
    return this.paginate(`/v1/apps/${encodeURIComponent(appId)}/appInfos`, {
      "fields[appInfos]": "state,appStoreState",
      limit: 200,
    });
  }

  listAppInfoLocalizations(appInfoId, options = {}) {
    return this.paginate(`/v1/appInfos/${encodeURIComponent(appInfoId)}/appInfoLocalizations`, {
      "filter[locale]": options.locales,
      "fields[appInfoLocalizations]":
        "locale,name,subtitle,privacyPolicyUrl,privacyChoicesUrl,privacyPolicyText",
      limit: 200,
    });
  }

  createAppInfoLocalization(appInfoId, attributes) {
    return this.request("/v1/appInfoLocalizations", {
      method: "POST",
      body: {
        data: {
          type: "appInfoLocalizations",
          attributes,
          relationships: {
            appInfo: {
              data: {
                type: "appInfos",
                id: appInfoId,
              },
            },
          },
        },
      },
    });
  }

  updateAppInfoLocalization(localizationId, attributes) {
    return this.request(`/v1/appInfoLocalizations/${encodeURIComponent(localizationId)}`, {
      method: "PATCH",
      body: {
        data: {
          type: "appInfoLocalizations",
          id: localizationId,
          attributes,
        },
      },
    });
  }

  listAppStoreVersions(appId, options = {}) {
    return this.paginate(`/v1/apps/${encodeURIComponent(appId)}/appStoreVersions`, {
      "filter[platform]": options.platform,
      "filter[versionString]": options.versionString,
      "filter[appVersionState]": options.state,
      "fields[appStoreVersions]": "platform,versionString,appVersionState,appStoreState,createdDate",
      limit: options.limit || 200,
    });
  }

  listAppStoreVersionLocalizations(appStoreVersionId, options = {}) {
    return this.paginate(
      `/v1/appStoreVersions/${encodeURIComponent(appStoreVersionId)}/appStoreVersionLocalizations`,
      {
        "filter[locale]": options.locales,
        "fields[appStoreVersionLocalizations]":
          "locale,description,keywords,marketingUrl,promotionalText,supportUrl,whatsNew",
        limit: 200,
      },
    );
  }

  createAppStoreVersionLocalization(appStoreVersionId, attributes) {
    return this.request("/v1/appStoreVersionLocalizations", {
      method: "POST",
      body: {
        data: {
          type: "appStoreVersionLocalizations",
          attributes,
          relationships: {
            appStoreVersion: {
              data: {
                type: "appStoreVersions",
                id: appStoreVersionId,
              },
            },
          },
        },
      },
    });
  }

  updateAppStoreVersionLocalization(localizationId, attributes) {
    return this.request(`/v1/appStoreVersionLocalizations/${encodeURIComponent(localizationId)}`, {
      method: "PATCH",
      body: {
        data: {
          type: "appStoreVersionLocalizations",
          id: localizationId,
          attributes,
        },
      },
    });
  }
}

function buildUrl(baseUrl, pathOrUrl, query = {}) {
  const url = pathOrUrl.startsWith("http")
    ? new URL(pathOrUrl)
    : new URL(pathOrUrl, ensureTrailingSlash(baseUrl));

  for (const [key, value] of Object.entries(query)) {
    if (value === undefined || value === null || value === "") {
      continue;
    }

    url.searchParams.set(key, Array.isArray(value) ? value.join(",") : String(value));
  }

  return url;
}

function ensureTrailingSlash(value) {
  return value.endsWith("/") ? value : `${value}/`;
}

function parseJson(text) {
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

function formatApiError(response, payload) {
  const firstError = Array.isArray(payload?.errors) ? payload.errors[0] : null;
  if (firstError) {
    const parts = [
      `App Store Connect API ${response.status} ${response.statusText}`,
      firstError.code,
      firstError.title,
      firstError.detail,
    ].filter(Boolean);

    return parts.join(": ");
  }

  return `App Store Connect API ${response.status} ${response.statusText}`;
}
