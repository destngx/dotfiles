import { spawn } from "child_process";
import * as path from "path";
import * as os from "os";

const NOTIFY_SCRIPT = path.join(os.homedir(), ".pi/agent/notify.sh");
const NOTIFICATION_THRESHOLD_MS = 0; // Set to 0 to notify on all completions

function sendNotification(params: {
  title?: string;
  subtitle?: string;
  message?: string;
  sound?: string;
  sessionId?: string;
  weztermPane?: string;
  tmuxPane?: string;
  notificationType?: string;
}) {
  const title = params.title || "Pi";
  const subtitle = params.subtitle || "Completed";
  const message = (params.message || "Task completed").replace(/\s+/g, " ").slice(0, 350);
  const sound = params.sound || "Glass";
  const sessionId = params.sessionId || "pi";
  const weztermPane = params.weztermPane || process.env.WEZTERM_PANE || "";
  const tmuxPane = params.tmuxPane || process.env.TMUX_PANE || "";
  const notificationType = params.notificationType || "completed";

  try {
    const child = spawn(
      NOTIFY_SCRIPT,
      [title, subtitle, message, sound, sessionId, weztermPane, tmuxPane, notificationType],
      {
        detached: true,
        stdio: "ignore",
      }
    );
    child.unref();
  } catch (err) {
    // Non-blocking notification error handling
  }
}

function extractLastAssistantText(ctx: any): string {
  try {
    const entries = ctx?.sessionManager?.getEntries?.() || ctx?.session?.messages || [];
    for (let i = entries.length - 1; i >= 0; i--) {
      const entry = entries[i];
      const msg = entry.message || entry;
      if (msg && msg.role === "assistant") {
        if (typeof msg.content === "string" && msg.content.trim()) {
          return msg.content;
        }
        if (Array.isArray(msg.content)) {
          const textParts = msg.content
            .filter((p: any) => p.type === "text" && p.text)
            .map((p: any) => p.text)
            .join(" ");
          if (textParts.trim()) return textParts;
        }
      }
    }
  } catch {}
  return "Task completed";
}

export default function (pi: any) {
  let turnStartTime = Date.now();
  let currentSessionId = "pi-" + Date.now();
  let lastNotifiedTurnTime = 0;

  const triggerCompletionNotification = (ctx: any, source: string, type: string = "completed") => {
    const now = Date.now();
    if (now - lastNotifiedTurnTime < 1500) {
      return;
    }

    const elapsed = now - turnStartTime;
    if (NOTIFICATION_THRESHOLD_MS > 0 && elapsed < NOTIFICATION_THRESHOLD_MS) {
      return;
    }

    lastNotifiedTurnTime = now;
    const project = path.basename(ctx?.cwd || process.cwd());
    const lastMessage = extractLastAssistantText(ctx);

    sendNotification({
      title: "Pi",
      subtitle: `Completed · ${project}`,
      message: lastMessage,
      sound: "Glass",
      sessionId: currentSessionId,
      weztermPane: process.env.WEZTERM_PANE,
      tmuxPane: process.env.TMUX_PANE,
      notificationType: type,
    });
  };

  pi.on("session_start", async (_event: any, ctx: any) => {
    turnStartTime = Date.now();
    currentSessionId = ctx.session?.id || "pi-" + Date.now();
  });

  pi.on("turn_start", async (_event: any, _ctx: any) => {
    turnStartTime = Date.now();
  });

  pi.on("turn_end", async (_event: any, ctx: any) => {
    triggerCompletionNotification(ctx, "turn_end", "completed");
  });

  pi.on("agent_end", async (_event: any, ctx: any) => {
    triggerCompletionNotification(ctx, "agent_end", "completed");
  });
}
