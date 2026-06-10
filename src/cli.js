import { mkdir } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { Command } from "commander";
import { AppStoreConnectClient } from "./client.js";
import { loadEnvFile, resolveAuthOptions, resolveBaseUrl } from "./config.js";
import {
  CliError,
  applyMetadataPlan,
  createTemplate,
  planMetadata,
  pullMetadata,
  readMetadataFile,
  validateMetadata,
  writeMetadataFile,
} from "./metadata.js";

export async function runCli(argv) {
  const program = new Command();

  program
    .name("apple-connect")
    .description("CLI workflows for App Store Connect app metadata.")
    .option("--env-file <path>", "load credentials from an env file", ".env")
    .option("--key-id <id>", "App Store Connect API key ID")
    .option("--issuer-id <id>", "App Store Connect API issuer ID")
    .option("--private-key-path <path>", "path to the AuthKey_<KEY_ID>.p8 file")
    .option("--private-key <pem>", "private key PEM content")
    .option("--base-url <url>", "App Store Connect API base URL");

  program
    .command("auth")
    .description("Authentication utilities.")
    .command("check")
    .description("Verify the API credentials by listing one app.")
    .action(async () => {
      const client = createClient(program);
      const apps = await client.listApps({ limit: 1 });
      console.log(`OK: credentials work. Visible apps: ${apps.length > 0 ? "at least 1" : "0"}.`);
    });

  program
    .command("apps:list")
    .description("List apps visible to the API key.")
    .option("--bundle-id <bundleId>", "filter by bundle ID")
    .option("--name <name>", "filter by app name")
    .option("--json", "print JSON")
    .action(async (options) => {
      const client = createClient(program);
      const apps = await client.listApps(options);
      printResources(apps, options.json, ["id", "name", "bundleId", "sku", "primaryLocale"]);
    });

  program
    .command("versions:list")
    .description("List App Store versions for an app.")
    .requiredOption("--app-id <id>", "App Store Connect app ID")
    .option("--platform <platform>", "IOS, MAC_OS, TV_OS, or VISION_OS")
    .option("--version-string <version>", "filter by public version string")
    .option("--state <state>", "filter by appVersionState, for example PREPARE_FOR_SUBMISSION")
    .option("--json", "print JSON")
    .action(async (options) => {
      const client = createClient(program);
      const versions = await client.listAppStoreVersions(options.appId, options);
      printResources(versions, options.json, [
        "id",
        "platform",
        "versionString",
        "appVersionState",
        "appStoreState",
        "createdDate",
      ]);
    });

  const metadata = program.command("metadata").description("Manage localized App Store metadata.");

  metadata
    .command("template")
    .description("Create a JSON/YAML template for multi-locale copy.")
    .option("--locales <locales>", "comma-separated locales", "en-US,zh-Hans,ja")
    .option("--out <path>", "output path", "metadata/app-store-copy.json")
    .action(async (options) => {
      const locales = splitCsv(options.locales);
      const outPath = resolve(options.out);
      await mkdir(dirname(outPath), { recursive: true });
      await writeMetadataFile(outPath, createTemplate(locales));
      console.log(`Created ${outPath}`);
    });

  metadata
    .command("validate")
    .description("Validate a metadata copy file locally.")
    .requiredOption("--file <path>", "metadata JSON/YAML file")
    .action(async (options) => {
      const document = await readMetadataFile(options.file);
      const result = validateMetadata(document);
      printValidation(result);
      if (result.errors.length > 0) {
        throw new CliError("Metadata validation failed.");
      }
    });

  metadata
    .command("pull")
    .description("Pull current App Info and App Store version localizations into a file.")
    .requiredOption("--app-id <id>", "App Store Connect app ID")
    .requiredOption("--version-id <id>", "App Store version ID")
    .option("--app-info-id <id>", "App Info resource ID, if you already know it")
    .option("--out <path>", "output path", "metadata/app-store-copy.json")
    .action(async (options) => {
      const client = createClient(program);
      const outPath = resolve(options.out);
      const document = await pullMetadata(client, options);
      await mkdir(dirname(outPath), { recursive: true });
      await writeMetadataFile(outPath, document);
      console.log(`Pulled ${document.localizations.length} localizations into ${outPath}`);
    });

  metadata
    .command("plan")
    .description("Preview creates/updates for a metadata copy file.")
    .requiredOption("--app-id <id>", "App Store Connect app ID")
    .requiredOption("--version-id <id>", "App Store version ID")
    .requiredOption("--file <path>", "metadata JSON/YAML file")
    .option("--app-info-id <id>", "App Info resource ID, if you already know it")
    .option("--no-ensure-app-info", "do not require/create matching App Info locales")
    .option("--json", "print JSON")
    .action(async (options) => {
      const client = createClient(program);
      const document = await readMetadataFile(options.file);
      const plan = await planMetadata(client, {
        ...options,
        document,
        ensureAppInfo: options.ensureAppInfo,
      });
      printPlan(plan, options.json);
      if (plan.errors.length > 0) {
        throw new CliError("Plan has errors.");
      }
    });

  metadata
    .command("apply")
    .description("Apply metadata creates/updates. Dry-run unless --yes is provided.")
    .requiredOption("--app-id <id>", "App Store Connect app ID")
    .requiredOption("--version-id <id>", "App Store version ID")
    .requiredOption("--file <path>", "metadata JSON/YAML file")
    .option("--app-info-id <id>", "App Info resource ID, if you already know it")
    .option("--no-ensure-app-info", "do not require/create matching App Info locales")
    .option("--yes", "actually write changes to App Store Connect")
    .option("--json", "print JSON plan/results")
    .action(async (options) => {
      const client = createClient(program);
      const document = await readMetadataFile(options.file);
      const plan = await planMetadata(client, {
        ...options,
        document,
        ensureAppInfo: options.ensureAppInfo,
      });

      printPlan(plan, options.json);
      if (plan.errors.length > 0) {
        throw new CliError("Plan has errors. Fix them before applying.");
      }

      if (!options.yes) {
        console.log("Dry run only. Re-run with --yes to write these changes.");
        return;
      }

      const results = await applyMetadataPlan(client, plan);
      if (options.json) {
        console.log(JSON.stringify({ results }, null, 2));
      } else {
        console.log(`Applied ${results.length} changes.`);
      }
    });

  await program.parseAsync(argv);
}

function createClient(program) {
  const options = program.opts();
  loadEnvFile(options.envFile);
  return new AppStoreConnectClient(resolveAuthOptions(options), {
    baseUrl: resolveBaseUrl(options),
  });
}

function printResources(resources, asJson, fields) {
  if (asJson) {
    console.log(JSON.stringify(resources, null, 2));
    return;
  }

  const rows = resources.map((resource) => {
    const row = { id: resource.id };
    for (const field of fields.filter((item) => item !== "id")) {
      row[field] = resource.attributes?.[field] ?? "";
    }
    return row;
  });
  console.table(rows);
}

function printValidation(result) {
  if (result.errors.length === 0 && result.warnings.length === 0) {
    console.log(`OK: ${result.localizations.length} localizations validated.`);
    return;
  }

  if (result.errors.length > 0) {
    console.log("Errors:");
    for (const error of result.errors) {
      console.log(`- ${error}`);
    }
  }

  if (result.warnings.length > 0) {
    console.log("Warnings:");
    for (const warning of result.warnings) {
      console.log(`- ${warning}`);
    }
  }
}

function printPlan(plan, asJson) {
  if (asJson) {
    console.log(JSON.stringify(plan, null, 2));
    return;
  }

  if (plan.errors.length > 0) {
    console.log("Errors:");
    for (const error of plan.errors) {
      console.log(`- ${error}`);
    }
  }

  if (plan.warnings.length > 0) {
    console.log("Warnings:");
    for (const warning of plan.warnings) {
      console.log(`- ${warning}`);
    }
  }

  const rows = plan.actions.map((action) => ({
    locale: action.locale,
    resource: action.resource,
    action: action.action,
    id: action.id || "",
    fields: (action.fields || []).join(", "),
  }));

  console.table(rows);
}

function splitCsv(value) {
  return String(value)
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
}
