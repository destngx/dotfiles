import { Container, Text, Spacer } from "@earendil-works/pi-tui";
import { execSync } from "child_process";
import * as path from "path";
import * as fs from "fs";
import * as os from "os";

// ── ANSI Color Palette ──
const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const CYAN = "\x1b[36m";
const YELLOW = "\x1b[33m";
const GREEN = "\x1b[32m";
const MAGENTA = "\x1b[35m";
const ORANGE = "\x1b[38;2;235;125;80m";
const BLUE = "\x1b[38;2;95;155;255m";
const DIM = "\x1b[2m";
const RED = "\x1b[31m";

// ── Colored Grid & Matrix Lines ──
const GRID_DOT = "\x1b[38;2;48;58;76m· \x1b[0m";
const DIVIDER = "\x1b[38;2;70;90;125m│\x1b[0m";

// ── Exact Tetris Animation Palette (from demo.gif / pi.dev) ──
const PI_ESC = "\x1b[";
const cyan_cell = `${PI_ESC}36m██${RESET}`;
const red_cell = `${PI_ESC}31m██${RESET}`;
const green_cell = `${PI_ESC}32m██${RESET}`;
const orange_cell = `${PI_ESC}33m██${RESET}`;
const white_cell = `${PI_ESC}1;37m██${RESET}`;
const flash_cell = `${PI_ESC}1;33m██${RESET}`;
const clawd_cell = `${PI_ESC}38;2;217;119;87m██${RESET}`; // Claude terra-cotta

interface GitInfo {
  repo: string;
  branch: string;
  isDirty: boolean;
}

function getGitInfo(cwd: string): GitInfo {
  try {
    const toplevel = execSync("git rev-parse --show-toplevel 2>/dev/null", {
      cwd,
      encoding: "utf8",
    }).trim();
    const repo = toplevel ? path.basename(toplevel) : "";
    const branch = execSync("git symbolic-ref --short HEAD 2>/dev/null", {
      cwd,
      encoding: "utf8",
    }).trim();
    const status = execSync("git status --porcelain -unormal 2>/dev/null", {
      cwd,
      encoding: "utf8",
    }).trim();
    return { repo, branch, isDirty: status.length > 0 };
  } catch {
    return { repo: "", branch: "", isDirty: false };
  }
}

function getChainedContextFiles(cwd: string) {
  const agentDir = path.join(os.homedir(), ".pi/agent");
  const candidates = ["AGENTS.override.md", "AGENTS.md", "AGENTS.MD", "CLAUDE.md", "CLAUDE.MD"];

  function findInDir(dir: string) {
    for (const f of candidates) {
      const p = path.join(dir, f);
      if (fs.existsSync(p)) {
        try {
          if (fs.statSync(p).isFile()) return { path: p, name: f, dir };
        } catch {}
      }
    }
    return null;
  }

  const list: { type: string; path: string; name: string; dir: string }[] = [];
  // 1. Global
  const globalContext = findInDir(agentDir);
  if (globalContext) list.push({ type: "global", ...globalContext });

  // 2. Ancestors to CWD (from highest root down to local CWD)
  const ancestors: { type: string; path: string; name: string; dir: string }[] = [];
  let curr = path.resolve(cwd);
  while (true) {
    const ctx = findInDir(curr);
    if (ctx && ctx.dir !== agentDir) {
      ancestors.unshift({
        type: curr === path.resolve(cwd) ? "local" : "ancestor",
        ...ctx,
      });
    }
    const parent = path.dirname(curr);
    if (parent === curr) break;
    curr = parent;
  }

  list.push(...ancestors);
  return list;
}

function formatRulesChain(chain: { type: string; dir: string }[]) {
  if (chain.length === 0) {
    return `${DIM}standard (no AGENTS.md)${RESET}`;
  }

  const parts = chain.map((c) => {
    if (c.type === "global") return `${CYAN}global${RESET}`;
    const base = path.basename(c.dir);
    return `${GREEN}${base}${RESET}`;
  });

  return `${GREEN}✓${RESET} ${parts.join(`${DIM} → ${RESET}`)} ${DIM}(${chain.length} chained)${RESET}`;
}

function getResourceCounts(cwd: string) {
  let skills = 0;
  let prompts = 0;
  let extensions = 0;

  // Extensions
  const globalExt = path.join(os.homedir(), ".pi/agent/extensions");
  if (fs.existsSync(globalExt)) {
    extensions += fs.readdirSync(globalExt).filter((f) => f.endsWith(".ts") || f.endsWith(".js")).length;
  }
  const localExt = path.join(cwd, ".pi/extensions");
  if (fs.existsSync(localExt)) {
    extensions += fs.readdirSync(localExt).filter((f) => f.endsWith(".ts") || f.endsWith(".js")).length;
  }

  // Skills
  const globalSkills = path.join(os.homedir(), ".pi/agent/skills");
  if (fs.existsSync(globalSkills)) {
    skills += fs.readdirSync(globalSkills).length;
  }
  const localSkills = path.join(cwd, ".pi/skills");
  if (fs.existsSync(localSkills)) {
    skills += fs.readdirSync(localSkills).length;
  }

  // Prompts
  const globalPrompts = path.join(os.homedir(), ".pi/agent/prompts");
  if (fs.existsSync(globalPrompts)) {
    prompts += fs.readdirSync(globalPrompts).length;
  }
  const localPrompts = path.join(cwd, ".pi/prompts");
  if (fs.existsSync(localPrompts)) {
    prompts += fs.readdirSync(localPrompts).length;
  }

  return { skills, prompts, extensions };
}

function in_cells(y: number, x: number, cellsStr: string): boolean {
  const cells = cellsStr.split(" ");
  return cells.includes(`${y},${x}`);
}

function in_piece(y: number, x: number, py: number, px: number, cellsStr: string): boolean {
  const cells = cellsStr.split(" ");
  for (const item of cells) {
    const [dy, dx] = item.split(",").map(Number);
    if (y === py + dy && x === px + dx) return true;
  }
  return false;
}

function get_cell(phase: number, active: string, ax: number, ay: number, flash: number, white: number, y: number, x: number): string {
  if (white === 1) {
    if (in_cells(y, x, "3,2 3,3 3,4 4,2 4,4 5,2 5,3 5,5 6,2 6,5")) return clawd_cell;
    return GRID_DOT;
  }
  if (white === 2) {
    if (in_cells(y, x, "3,2 3,3 3,4 4,2 4,4 5,2 5,3 5,5 6,2 6,5")) return white_cell;
    return GRID_DOT;
  }
  if (flash === 1 && y === 6 && x >= 1 && x <= 6) return flash_cell;

  if (active === "left" && in_piece(y, x, ay, ax, "0,0 1,0 1,1 2,0")) return red_cell;
  if (active === "top" && in_piece(y, x, ay, ax, "0,0 0,1 0,2 1,2")) return cyan_cell;
  if (active === "right" && in_piece(y, x, ay, ax, "0,0 1,0 2,0 2,1")) return green_cell;

  if (phase === 4) {
    if (in_cells(y, x, "2,2 2,3 2,4 3,4")) return cyan_cell;
    if (in_cells(y, x, "3,2 4,2 4,3 5,2")) return red_cell;
    if (in_cells(y, x, "4,5 5,5")) return green_cell;
    return GRID_DOT;
  }

  if (phase >= 5) {
    if (in_cells(y, x, "3,2 3,3 3,4 4,4")) return cyan_cell;
    if (in_cells(y, x, "4,2 5,2 5,3 6,2")) return red_cell;
    if (in_cells(y, x, "5,5 6,5")) return green_cell;
    return GRID_DOT;
  }

  if (phase <= 3 && in_cells(y, x, "6,1 6,2 6,3 6,4")) return orange_cell;
  if (phase >= 2 && in_cells(y, x, "2,2 2,3 2,4 3,4")) return cyan_cell;
  if (phase >= 1 && in_cells(y, x, "3,2 4,2 4,3 5,2")) return red_cell;
  if (phase >= 3 && in_cells(y, x, "4,5 5,5 6,5 6,6")) return green_cell;

  return GRID_DOT;
}

// ── Exact 20-frame animation timeline from demo.gif ──
const ANIMATION_STEPS = [
  // 1. Left red piece falls:
  { phase: 0, active: "left", ax: 2, ay: 0, flash: 0, white: 0, delay: 75 },
  { phase: 0, active: "left", ax: 2, ay: 1, flash: 0, white: 0, delay: 75 },
  { phase: 0, active: "left", ax: 2, ay: 2, flash: 0, white: 0, delay: 75 },
  { phase: 0, active: "left", ax: 2, ay: 3, flash: 0, white: 0, delay: 75 },

  // 2. Top cyan piece falls:
  { phase: 1, active: "top", ax: 2, ay: 0, flash: 0, white: 0, delay: 75 },
  { phase: 1, active: "top", ax: 2, ay: 1, flash: 0, white: 0, delay: 75 },
  { phase: 1, active: "top", ax: 2, ay: 2, flash: 0, white: 0, delay: 75 },

  // 3. Right green piece falls:
  { phase: 2, active: "right", ax: 5, ay: 0, flash: 0, white: 0, delay: 75 },
  { phase: 2, active: "right", ax: 5, ay: 1, flash: 0, white: 0, delay: 75 },
  { phase: 2, active: "right", ax: 5, ay: 2, flash: 0, white: 0, delay: 75 },
  { phase: 2, active: "right", ax: 5, ay: 3, flash: 0, white: 0, delay: 75 },
  { phase: 2, active: "right", ax: 5, ay: 4, flash: 0, white: 0, delay: 75 },

  // 4. Line clear flash on bottom row:
  { phase: 3, active: "none", ax: 0, ay: 0, flash: 0, white: 0, delay: 200 },
  { phase: 3, active: "none", ax: 0, ay: 0, flash: 1, white: 0, delay: 80 },
  { phase: 3, active: "none", ax: 0, ay: 0, flash: 0, white: 0, delay: 80 },
  { phase: 3, active: "none", ax: 0, ay: 0, flash: 1, white: 0, delay: 80 },

  // 5. Floor clears, pieces drop down 1 row:
  { phase: 4, active: "none", ax: 0, ay: 0, flash: 0, white: 0, delay: 100 },

  // 6. Pi logo fully forms:
  { phase: 5, active: "none", ax: 0, ay: 0, flash: 0, white: 0, delay: 400 },

  // 7. White flash on completed Pi logo:
  { phase: 5, active: "none", ax: 0, ay: 0, flash: 0, white: 2, delay: 120 },
  { phase: 5, active: "none", ax: 0, ay: 0, flash: 0, white: 0, delay: 120 },
  { phase: 5, active: "none", ax: 0, ay: 0, flash: 0, white: 1, delay: 1500 }, // Hold steady
];

class TetrisWelcomeHeader extends Container {
  tui: any;
  ctx: any;
  stepIndex: number = 0;
  timer: NodeJS.Timeout | null = null;

  constructor(tui: any, ctx: any) {
    super();
    this.tui = tui;
    this.ctx = ctx;
    this.buildHeader();
    this.scheduleNextFrame();
  }

  scheduleNextFrame() {
    this.stopAnimation();
    const currentStep = ANIMATION_STEPS[this.stepIndex];
    this.timer = setTimeout(() => {
      this.stepIndex = (this.stepIndex + 1) % ANIMATION_STEPS.length;
      this.buildHeader();
      if (this.tui?.requestRender) {
        this.tui.requestRender();
      }
      this.scheduleNextFrame();
    }, currentStep.delay);
  }

  stopAnimation() {
    if (this.timer) {
      clearTimeout(this.timer);
      this.timer = null;
    }
  }

  dispose() {
    this.stopAnimation();
  }

  renderLogoLines(): string[] {
    const step = ANIMATION_STEPS[this.stepIndex];
    const lines: string[] = [];
    for (let y = 1; y <= 6; y++) {
      let row = "";
      for (let x = 1; x <= 7; x++) {
        row += get_cell(step.phase, step.active, step.ax, step.ay, step.flash, step.white, y, x);
      }
      lines.push(row);
    }
    return lines;
  }

  buildHeader() {
    this.clear();

    const cwd = this.ctx?.cwd || process.cwd();
    const git = getGitInfo(cwd);
    const counts = getResourceCounts(cwd);
    const rulesChain = getChainedContextFiles(cwd);

    const model = this.ctx?.model?.name || this.ctx?.model?.id || "Claude Haiku 4.5";
    const thinking = this.ctx?.thinkingLevel || "minimal";

    const repoName = git.repo || path.basename(cwd);
    const branchStr = git.branch ? ` ${GREEN} (${git.branch}${git.isDirty ? `${RED}*${RESET}` : ""})${RESET}` : "";

    const logoLines = this.renderLogoLines();

    // ── 6-line Aligned Information Grid with Chained Rules ──
    const infoLines = [
      `${BOLD}${ORANGE}Pi${RESET} ${CYAN}v0.84.2${RESET} ${DIM}(Claude Code edition)${RESET}`,
      `${BLUE}Model:${RESET}     ${MAGENTA}${model}${RESET} ${DIM}•${RESET} ${CYAN}${thinking} thinking${RESET}`,
      `${BLUE}Workspace:${RESET} ${YELLOW} ${repoName}${RESET}${branchStr}`,
      `${BLUE}Resources:${RESET} ${GREEN}${counts.skills} skills${RESET} ${DIM}·${RESET} ${YELLOW}${counts.prompts} prompts${RESET} ${DIM}·${RESET} ${CYAN}${counts.extensions} extensions${RESET}`,
      `${BLUE}Custom Rules:${RESET}     ${formatRulesChain(rulesChain)}`,
      `${BLUE}Shortcuts:${RESET} ${DIM}Type ${CYAN}/help${DIM} for commands • ${CYAN}Ctrl+P${DIM} switch model${RESET}`,
    ];

    this.addChild(new Spacer(1));

    for (let i = 0; i < 6; i++) {
      this.addChild(new Text(`  ${logoLines[i]}  ${DIVIDER}  ${infoLines[i]}`, 0, 0));
    }

    this.addChild(new Spacer(1));
  }
}

export default function (pi: any) {
  pi.on("session_start", async (_event: any, ctx: any) => {
    if (ctx?.ui?.setHeader) {
      ctx.ui.setHeader((tui: any, _theme: any) => {
        return new TetrisWelcomeHeader(tui, ctx);
      });
    }
  });
}
