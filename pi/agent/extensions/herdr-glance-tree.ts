import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// /glance-goto <entry id> moves the session to an entry of its tree, as
// picking it in /tree does: a prompt goes back into the editor, any other
// entry continues after itself. herdr-glance sends it from the phone.
//
// pi sends an unknown command to the model as a prompt, so herdr-glance
// sends this one only to a pane whose commands file names it. The file sits
// beside the status snapshot (statusline.ts) and names the session, so a
// new agent in the pane does not inherit it.
//
// Moving writes nothing to the session file, so the command adds a
// "herdr-glance-goto" entry where the session now is. herdr-glance follows
// the newest entry of the file, and this one marks the new position.
const COMMAND = "glance-goto";

function writeCommands(ctx: any): void {
  const pane = process.env.HERDR_PANE_ID;
  const session = ctx?.sessionManager?.getSessionFile?.();
  if (!pane || typeof session !== "string" || !path.isAbsolute(session)) return;
  try {
    const dir = process.env.HERDR_GLANCE_STATUS_DIR || path.join(os.homedir(), ".local/state/herdr-glance/status");
    const target = path.join(dir, `${pane.replace(/[^A-Za-z0-9._-]/g, "_")}.commands.json`);
    fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(`${target}.${process.pid}`, JSON.stringify({ version: 1, agent: "pi", session, commands: [COMMAND] }));
    fs.renameSync(`${target}.${process.pid}`, target);
  } catch {}
}

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => writeCommands(ctx));

  pi.registerCommand(COMMAND, {
    description: "Go to an entry of the session tree (used by herdr-glance)",
    handler: async (args, ctx) => {
      const id = args.trim();
      if (!id || !ctx.sessionManager.getEntry(id)) {
        ctx.ui.notify(`No entry ${id || "given"} in this session.`, "error");
        return;
      }
      if (!ctx.isIdle()) {
        ctx.ui.notify("Wait until pi is idle, then go back.", "error");
        return;
      }
      const result = await ctx.navigateTree(id, { summarize: false });
      if (result.cancelled) return;
      pi.appendEntry("herdr-glance-goto", { target: id });
    },
  });
}
