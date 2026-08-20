import { execSync } from "child_process";
import * as path from "path";

// ── Colors ──
const CYAN = "\x1b[36m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const RED = "\x1b[31m";
const MAGENTA = "\x1b[35m";
const BLUE = "\x1b[34m";
const DIM = "\x1b[2m";
const BOLD = "\x1b[1m";
const RESET = "\x1b[0m";

// ── Truecolor helper ──
function rgb(r: number, g: number, b: number): string {
  return `\x1b[38;2;${Math.round(r)};${Math.round(g)};${Math.round(b)}m`;
}

// ── ANSI-Aware Truncator to Guarantee Terminal Width Compliance ──
function truncateToWidth(str: string, maxWidth: number): string {
  if (maxWidth <= 0) return "";
  let currentWidth = 0;
  let result = "";
  let inEscape = false;
  let escapeSeq = "";

  for (let i = 0; i < str.length; i++) {
    const char = str[i];
    if (char === "\x1b") {
      inEscape = true;
      escapeSeq = char;
      continue;
    }
    if (inEscape) {
      escapeSeq += char;
      if ((char >= "A" && char <= "Z") || (char >= "a" && char <= "z") || char === "\x07") {
        inEscape = false;
        result += escapeSeq;
      }
      continue;
    }

    const code = char.codePointAt(0) || 0;
    const charWidth =
      (code >= 0x1100 && (
        (code >= 0x1100 && code <= 0x115f) ||
        (code >= 0x2e80 && code <= 0xa4cf) ||
        (code >= 0xac00 && code <= 0xd7a3) ||
        (code >= 0xf900 && code <= 0xfaff) ||
        (code >= 0x1f000 && code <= 0x1ffff) ||
        (code >= 0x20000 && code <= 0x3ffff)
      )) ? 2 : 1;

    if (currentWidth + charWidth > maxWidth) {
      break;
    }
    result += char;
    currentWidth += charWidth;
  }

  return result + RESET;
}

// ── Token Formatter (11000 -> 11k, 200000 -> 200k, 1500000 -> 1.5M) ──
function formatTokens(count: number): string {
  if (!count || isNaN(count)) return "0";
  if (count >= 1_000_000) return (count / 1_000_000).toFixed(1).replace(/\.0$/, "") + "M";
  if (count >= 1_000) return (count / 1_000).toFixed(1).replace(/\.0$/, "") + "k";
  return String(count);
}

// ── Model Name Formatter ──
function formatModelName(model: any): string {
  if (!model) return "Unknown";
  if (typeof model === "string") return model;
  if (typeof model === "object") {
    return (
      model.displayName ||
      model.display_name ||
      model.name ||
      model.id ||
      model.model ||
      (model.provider && model.id ? `${model.provider}/${model.id}` : "Unknown")
    );
  }
  return String(model);
}

// ── Context RGB Gradient Bar (for wide terminals) ──
function renderBar(usedPct: number | null, width: number = 12): string {
  if (usedPct === null || isNaN(usedPct)) {
    return `\x1b[38;2;60;60;60m${"░".repeat(Math.max(1, width))}${RESET}`;
  }

  const clamped = Math.max(0, Math.min(100, usedPct));
  const filled = Math.round((clamped * width) / 100);

  let bar = "";
  for (let i = 0; i < width; i++) {
    const pos = width > 1 ? (i * 100) / (width - 1) : 0;
    let r: number, g: number, b: number;
    if (pos <= 50) {
      r = 0 + (220 * pos) / 50;
      g = 200;
      b = 80 - (80 * pos) / 50;
    } else {
      const adj = pos - 50;
      r = 220;
      g = 200 - (160 * adj) / 50;
      b = 0 + (20 * adj) / 50;
    }

    if (i < filled) {
      bar += `${rgb(r, g, b)}█`;
    } else {
      bar += `\x1b[38;2;60;60;60m░`;
    }
  }
  bar += RESET;
  return bar;
}

// ── Git repo, branch, dirty flag helper ──
function getGitInfo(cwd?: string): { repo: string; branch: string; isDirty: boolean } {
  try {
    const targetDir = cwd || process.cwd();
    const branch = execSync("git --no-optional-locks symbolic-ref --short HEAD 2>/dev/null", {
      cwd: targetDir,
      encoding: "utf8",
      timeout: 500,
    }).trim();
    const topLevel = execSync("git --no-optional-locks rev-parse --show-toplevel 2>/dev/null", {
      cwd: targetDir,
      encoding: "utf8",
      timeout: 500,
    }).trim();
    const repo = topLevel ? path.basename(topLevel) : "";

    let isDirty = false;
    try {
      const status = execSync("git --no-optional-locks status --porcelain -unormal 2>/dev/null", {
        cwd: targetDir,
        encoding: "utf8",
        timeout: 500,
      }).trim();
      isDirty = status.length > 0;
    } catch {}

    return { repo, branch, isDirty };
  } catch {
    return { repo: "", branch: "", isDirty: false };
  }
}

// ── Status State Structure ──
interface StatusState {
  model?: any;
  thinking?: string;
  usedPct?: number | null;
  contextWindow?: number;
  inputTokens?: number;
  outputTokens?: number;
  reasoningTokens?: number;
  cacheHitRate?: number;
  cost?: number;
  linesAdd?: number;
  linesDel?: number;
  cwd?: string;
}

// ── Responsive Statusline Builder ──
function buildStatusLine(state: StatusState, targetWidth: number): string {
  const maxWidth = Math.max(20, targetWidth - 1);
  const isSmall = maxWidth < 120;
  const isUltraSmall = maxWidth < 75;

  const { repo, branch, isDirty } = getGitInfo(state.cwd);
  const parts: string[] = [];

  // 1. Git Repository & Branch (Nerd Font: \uF07B folder, \uE725 branch)
  if (repo) {
    let repoPart = `${BOLD}${YELLOW}\uF07B ${repo}${RESET}`;
    if (branch) {
      const dirty = isDirty ? `${RED}*${RESET}` : "";
      const velocity = !isUltraSmall
        ? ` ${GREEN}+${state.linesAdd || 0}${RESET} ${RED}-${state.linesDel || 0}${RESET}`
        : "";
      repoPart += ` ${BOLD}${CYAN}\uE725 (${branch}${dirty}${velocity})${RESET}`;
    }
    parts.push(repoPart);
  }

  // 2. Context Window (No icon, colored percent text)
  const used = state.usedPct ?? null;
  let pctColor = GREEN;
  let pctText = "--%";

  if (used !== null && !isNaN(used)) {
    const usedVal = used < 10 ? used.toFixed(1) : String(Math.round(used));
    pctText = `${usedVal}%`;
    if (!isUltraSmall && state.contextWindow) {
      pctText += `/${formatTokens(state.contextWindow)}`;
    }
    if (used >= 90) {
      pctColor = RED;
    } else if (used >= 70) {
      pctColor = YELLOW;
    } else {
      pctColor = GREEN;
    }
  }

  if (isSmall) {
    // Small size: strip bar progress, keep clean colored status text & number
    parts.push(`${pctColor}${pctText}${RESET}`);
  } else {
    // Wide size: show full RGB gradient bar + colored percentage
    const bar = renderBar(used, 12);
    parts.push(`${bar} ${pctColor}${pctText}${RESET}`);
  }

  // 3. Tokens Breakdown (\uF062 in, \uF063 out, \uF0EB reason) - Shown on wide screens
  if (!isSmall) {
    const tokenParts: string[] = [];
    if (state.inputTokens) tokenParts.push(`${CYAN}\uF062 ${formatTokens(state.inputTokens)}${RESET}`);
    if (state.outputTokens) tokenParts.push(`${GREEN}\uF063 ${formatTokens(state.outputTokens)}${RESET}`);
    if (state.reasoningTokens) tokenParts.push(`${MAGENTA}\uF0EB ${formatTokens(state.reasoningTokens)}${RESET}`);
    if (tokenParts.length > 0) {
      parts.push(tokenParts.join(" "));
    }
  }

  // 4. Total Cost ($0.012)
  const costPart = `${YELLOW}$${Number(state.cost || 0).toFixed(3)}${RESET}`;
  parts.push(costPart);

  // 5. Model & Thinking Level (Clean text, no icon)
  const modelName = formatModelName(state.model);
  let modelPart = `${MAGENTA}${modelName}${RESET}`;

  if (!isUltraSmall && state.thinking) {
    modelPart += ` ${DIM}• ${state.thinking}${RESET}`;
  }
  parts.push(modelPart);

  const fullLine = parts.join(` ${DIM}|${RESET} `);
  return truncateToWidth(fullLine, maxWidth);
}

export default function (pi: any) {
  let state: StatusState = {
    model: "Unknown",
    thinking: "minimal",
    usedPct: null,
    contextWindow: 200000,
    cost: 0,
    linesAdd: 0,
    linesDel: 0,
  };

  function extractMetrics(ctx: any) {
    if (!ctx) return;
    if (ctx.model) state.model = ctx.model;
    if (ctx.thinkingLevel) state.thinking = ctx.thinkingLevel;
    if (ctx.cwd) state.cwd = ctx.cwd;

    // A. Official Pi context usage API
    if (typeof ctx.getContextUsage === "function") {
      try {
        const u = ctx.getContextUsage();
        if (u) {
          if (u.percent !== null && u.percent !== undefined) {
            state.usedPct = u.percent;
          }
          if (u.contextWindow) {
            state.contextWindow = u.contextWindow;
          }
        }
      } catch {}
    }

    // B. Calculate cumulative session tokens, cache, and cost using Pi's exact field names
    try {
      let totalIn = 0;
      let totalOut = 0;
      let totalReasoning = 0;
      let totalCacheRead = 0;
      let totalCost = 0;

      const entries = ctx.sessionManager?.getEntries?.() || ctx.session?.messages || [];
      for (const entry of entries) {
        const u = entry.usage || entry.message?.usage;
        if (u) {
          totalIn += u.input ?? u.inputTokens ?? u.input_tokens ?? u.promptTokens ?? 0;
          totalOut += u.output ?? u.outputTokens ?? u.output_tokens ?? u.completionTokens ?? 0;
          totalReasoning += u.reasoning ?? u.reasoningTokens ?? u.reasoning_tokens ?? u.thoughtTokens ?? 0;
          totalCacheRead += u.cacheRead ?? u.cacheReadTokens ?? u.cache_read_input_tokens ?? u.cachedTokens ?? 0;

          if (typeof u.cost === "object" && u.cost) {
            totalCost += u.cost.total || 0;
          } else if (typeof u.cost === "number") {
            totalCost += u.cost;
          } else if (typeof u.totalCost === "number") {
            totalCost += u.totalCost;
          }
        }
      }

      if (totalIn > 0) state.inputTokens = totalIn;
      if (totalOut > 0) state.outputTokens = totalOut;
      if (totalReasoning > 0) state.reasoningTokens = totalReasoning;
      if (totalCost > 0) state.cost = totalCost;

      if (totalCacheRead > 0 && totalIn > 0) {
        state.cacheHitRate = (totalCacheRead / (totalIn + totalCacheRead)) * 100;
      }
    } catch {}
  }

  pi.on("session_start", async (_event: any, ctx: any) => {
    extractMetrics(ctx);

    if (ctx.ui?.setFooter) {
      ctx.ui.setFooter((_tui: any, _theme: any, footerData: any) => {
        if (footerData?.onBranchChange) {
          footerData.onBranchChange(() => {});
        }
        return {
          render(width: number) {
            extractMetrics(ctx);
            return [buildStatusLine(state, width)];
          },
        };
      });
    }
  });

  pi.on("turn_start", async (_event: any, ctx: any) => {
    extractMetrics(ctx);
  });

  pi.on("turn_end", async (_event: any, ctx: any) => {
    extractMetrics(ctx);
  });

  pi.on("model_select", async (event: any, ctx: any) => {
    if (event?.model) state.model = event.model;
    extractMetrics(ctx);
  });

  pi.on("thinking_level_select", async (event: any, ctx: any) => {
    if (event?.level) state.thinking = event.level;
    extractMetrics(ctx);
  });
}
