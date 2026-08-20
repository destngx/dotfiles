import * as fs from "fs";
import * as path from "path";
import * as os from "os";
import { exec } from "child_process";

// ── Desired Plugins List (Self-contained in TypeScript) ──
const REQUIRED_PLUGINS = [
  "npm:@piotr-oles/pi-reflag",
  "npm:@narumitw/pi-btw",
  "npm:pi-context-view",
  "npm:@juicesharp/rpiv-todo",
  "npm:@juicesharp/rpiv-ask-user-question",
  "npm:pi-subagents"
];

const NPM_NODE_MODULES = path.join(os.homedir(), ".pi/agent/npm/node_modules");

export default function (pi: any) {
  let hasCheckedThisProcess = false;

  pi.on("session_start", async (_event: any, ctx: any) => {
    if (hasCheckedThisProcess) return;
    hasCheckedThisProcess = true;

    try {
      const missing: string[] = [];

      for (const plugin of REQUIRED_PLUGINS) {
        const pkgName = plugin.replace(/^npm:/, "");
        const pkgDir = path.join(NPM_NODE_MODULES, pkgName);
        if (!fs.existsSync(pkgDir)) {
          missing.push(plugin);
        }
      }

      if (missing.length > 0) {
        if (typeof ctx?.ui?.notify === "function") {
          ctx.ui.notify(`Auto-installing ${missing.length} missing plugin(s)...`, "info");
        }

        for (const pkg of missing) {
          exec(`pi install "${pkg}"`, (err) => {
            if (!err && typeof ctx?.ui?.notify === "function") {
              ctx.ui.notify(`✓ Installed ${pkg}`, "info");
            }
          });
        }
      }
    } catch {
      // Non-blocking background check
    }
  });
}
