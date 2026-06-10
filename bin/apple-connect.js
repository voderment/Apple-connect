#!/usr/bin/env node

import { runCli } from "../src/cli.js";

runCli(process.argv).catch((error) => {
  if (error?.name === "CliError") {
    console.error(error.message);
    process.exitCode = 1;
    return;
  }

  console.error(error?.stack || error?.message || String(error));
  process.exitCode = 1;
});
