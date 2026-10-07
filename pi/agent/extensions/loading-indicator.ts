// ── ANSI Palette ──
const RESET = "\x1b[0m";

// Realistic Multi-Tone Ocean Wave Palette: dark blue -> mid blue -> light blue -> pure white high tops
const W_DARK = "\x1b[38;2;25;75;170m"; // Deep dark ocean blue (troughs)
const W_MID = "\x1b[38;2;50;130;220m"; // Mid ocean blue (swell body)
const W_LIGHT = "\x1b[38;2;85;185;245m"; // Light azure blue (wave slopes / and \\\)
const W_CYAN = "\x1b[38;2;150;225;255m"; // Icy light blue (near-crest & wake foam)
const W_WHITE = "\x1b[1;38;2;255;255;255m"; // High top crest peaks, spray `, and bubbles °

// Funny Ocean Encounters Palette
const FISH = "\x1b[1;38;2;255;140;40m"; // Orange jumping fish
const SHARK = "\x1b[1;38;2;135;155;175m"; // Slate shark fin
const DUCK = "\x1b[1;38;2;255;220;50m"; // Yellow rubber ducky

// Boat & Captain Palette
const B_MAST = "\x1b[38;2;160;170;185m";
const B_FLAG = "\x1b[1;38;2;255;85;85m";
const B_HULL = "\x1b[38;2;225;145;75m";
const TRAIN = "\x1b[38;2;235;190;105m";
const SMOKE = "\x1b[38;2;175;190;205m";
const RAIL = "\x1b[38;2;130;145;160m";

// ── Playful Spinner Verbs (Randomized every 5s) ──
const SPINNER_VERBS = [
  "Cooking…", "Pondering…", "Combobulating…", "Catching the wind…", "Hoisting anchor…",
  "Navigating waters…", "Dodging kraken…", "Charting course…", "Scrubbing deck…",
  "Consulting compass…", "Hunting treasure…", "Captain shipping…", "Battening hatches…",
  "Full steam ahead…", "Flibbertigibbeting…", "Whatchamacalliting…", "Boondoggling…",
  "Fiddle-faddling…", "Lollygagging…", "Razzmatazzing…", "Moonwalking…", "Spelunking…",
  "Percolating…", "Bamboozling…", "Shenaniganing…", "Skedaddling…", "Kerfuffling…",
  "Cogitating…", "Synthesizing…", "Hocus-pocusing…", "Gobbledygooking…",
  "Discombobulating…", "Cat-napping…", "Noodling…", "Abracadabraing…", "Brouhahaing…",
  "Rigmaroling…", "Higgledy-piggledying…",
];

// ── Dynamic Flags for Sailing Right & Left ──
const FLAGS_RIGHT = ["|>", "|}", "|]", "|)"];
const FLAGS_LEFT = ["<|", "{|", "[|", "(|"];

const TEXT_COL_WIDTH = 21;
const BASE_INTERVAL_MS = 80;
const WAVE_SLOWDOWN = 3;
const BOAT_SLOWDOWN = 9;
const PHRASE_INTERVAL_MS = 5000;

let currentPhrase = SPINNER_VERBS[Math.floor(Math.random() * SPINNER_VERBS.length)];

function getShimmerPos(k: number, len: number): number {
  if (len <= 1) return 0;
  const cycle = (len - 1) * 2;
  const p = k % cycle;
  return p < len ? p : cycle - p;
}

function renderShimmerText(verb: string, k: number): string {
  const chars = Array.from(verb);
  const len = chars.length;
  const shimmerPos = getShimmerPos(k, len);
  let text = "";
  for (let i = 0; i < len; i++) {
    const char = chars[i];
    const dist = Math.abs(i - shimmerPos);
    if (dist === 0) text += `\x1b[1;38;2;255;255;255m${char}${RESET}`;
    else if (dist === 1) text += `\x1b[38;2;170;225;255m${char}${RESET}`;
    else if (dist === 2) text += `\x1b[38;2;90;155;215m${char}${RESET}`;
    else text += `\x1b[38;2;140;150;165m${char}${RESET}`;
  }
  return `${text}${" ".repeat(Math.max(0, TEXT_COL_WIDTH - len - 1))}`;
}

function buildColoredWave(len: number, side: "left" | "right", dir: number, waveStep: number): string {
  let res = "";
  const swellMode = Math.floor(waveStep / 4) % 4;
  const encounterType = Math.floor(waveStep / 8) % 3;
  const hasEncounter = len >= 20;
  const encounterPos = Math.floor(len / 2);
  const isBow = (dir === 1 && side === "right") || (dir === -1 && side === "left");
  let i = 0;
  while (i < len) {
    const dist = side === "left" ? len - 1 - i : i;
    if (dist === 0) {
      const c = isBow ? (waveStep % 2 === 0 ? "^" : "/") : "-";
      res += `${c === "-" ? W_DARK : W_WHITE}${c}${RESET}`;
      i++;
    } else if (dist === 1) {
      const c = isBow ? (waveStep % 2 === 0 ? "`" : "~") : "~";
      res += `${c === "`" ? W_WHITE : W_MID}${c}${RESET}`;
      i++;
    } else if (dist === 2) {
      const c = isBow ? "^" : "-";
      res += `${c === "^" ? W_WHITE : W_DARK}${c}${RESET}`;
      i++;
    } else if (dist === 3) {
      const c = (waveStep + dist) % 2 === 0 ? "-" : "~";
      res += `${W_MID}${c}${RESET}`;
      i++;
    } else if (hasEncounter && i === encounterPos && i + 3 <= len - 3) {
      if (encounterType === 0) res += `${FISH}${waveStep % 4 < 2 ? (side === "left" ? "><>" : "<><") : "^><"}${RESET}`;
      else if (encounterType === 1) res += `${W_DARK}-${SHARK}/|${RESET}`;
      else res += `${W_MID}-${DUCK}o<${RESET}`;
      i += 3;
    } else {
      const wavePhase = (i + (side === "left" ? -waveStep : waveStep) + waveStep * 2 + 120) % 24;
      if (wavePhase === 0) res += `${W_WHITE}^${RESET}`;
      else if (wavePhase === 7 || wavePhase === 8) res += `${W_LIGHT}~${RESET}`;
      else if (wavePhase === 11 && swellMode === 3) res += `${W_WHITE}\`${RESET}`;
      else if ([1, 2, 9, 10, 12].includes(wavePhase)) res += `${W_DARK}-${RESET}`;
      else if (wavePhase === 3 || wavePhase === 4) res += `${W_MID}~${RESET}`;
      else res += `${W_DARK}~${RESET}`;
      i++;
    }
  }
  return res;
}

class DynamicTrainFrame {
  step: number;
  smokePart: string;
  bodyLine: string;
  railLine: string;
  constructor(step: number, smokePart: string, bodyLine: string, railLine: string) {
    this.step = step;
    this.smokePart = smokePart;
    this.bodyLine = bodyLine;
    this.railLine = railLine;
  }
  render(): string {
    const textPart = renderShimmerText(currentPhrase, this.step);
    const chars = Array.from(currentPhrase);
    const textPad = " ".repeat(Math.max(1, 23 - Math.max(chars.length, TEXT_COL_WIDTH - 1)));
    const smokeLine = `  ${textPart}${textPad}${this.smokePart}`;
    return `${smokeLine}\n${this.bodyLine}\n${this.railLine}`;
  }
  get length(): number { return this.render().length; }
  toString(): string { return this.render(); }
  [Symbol.toPrimitive](): string { return this.render(); }
}

function generateTrainFrames(): DynamicTrainFrame[] {
  const frames: DynamicTrainFrame[] = [];
  const track = "--+--+--+--+--+--+--+--+--+--+--+--+--";
  const smokes = [".","0", "o", "O", "@", " "];
  const termWidth = process.stdout.columns || 80;
  const targetContentWidth = Math.max(50, termWidth - 4);
  const prefixWidth = 25;
  const railWidth = Math.max(20, targetContentWidth - prefixWidth);
  const trackPattern = track.repeat(Math.ceil((railWidth + 3) / track.length));
  const TRAIN_BODY   = " [_=_]-=nI";
  const TRAIN_WHEELS = "-=(0)==(o)=";
  const trainLen = TRAIN_WHEELS.length;
  const blankPrefix = "*".repeat(prefixWidth);
  const cycleLength = railWidth + trainLen + 6;
  let smoke = [" ", " ", " ", " "];

  for (let step = 0; step < cycleLength * 2; step++) {
    smoke = [smoke[1], smoke[2], smoke[3], smokes[Math.floor(Math.random() * smokes.length)]];
    const cycleStep = step % cycleLength;
    const trainOffset = cycleStep - trainLen;
    const trackOffset = Math.floor(step / 3) % 3;
    const railChars = trackPattern.slice(trackOffset, trackOffset + railWidth);

    // Line 1: Smoke trailing behind the chimney (+9)
    const smokeStr = smoke.join(" ");
    const smokeLen = smokeStr.length;
    const smokeStart = trainOffset + 3;
    let smokePart = "";
    if (smokeStart + smokeLen > 0 && smokeStart < railWidth) {
      const smokeScreenStart = Math.max(0, smokeStart);
      const smokeScreenEnd = Math.min(railWidth, smokeStart + smokeLen);
      const visibleSmoke = smokeStr.slice(smokeScreenStart - smokeStart, smokeScreenEnd - smokeStart);
      smokePart = `${" ".repeat(smokeScreenStart)}${SMOKE}${visibleSmoke}${RESET}`;
    }

    // Line 2: Train body sitting on top of the wheels
    let bodyContent = "";
    if (trainOffset + trainLen > 0 && trainOffset < railWidth) {
      const trainScreenStart = Math.max(0, trainOffset);
      const trainScreenEnd = Math.min(railWidth, trainOffset + trainLen);
      const visibleBody = TRAIN_BODY.padEnd(trainLen, " ").slice(trainScreenStart - trainOffset, trainScreenEnd - trainOffset);
      bodyContent = `${" ".repeat(trainScreenStart)}${TRAIN}${visibleBody}${RESET}`;
    }
    const bodyLine = `${blankPrefix}${bodyContent}`;

    // Line 3: Wheels embedded directly on the same line as the rails
    let railContent = "";
    if (trainOffset + trainLen <= 0 || trainOffset >= railWidth) {
      railContent = `${RAIL}${railChars}${RESET}`;
    } else {
      const trainScreenStart = Math.max(0, trainOffset);
      const trainScreenEnd = Math.min(railWidth, trainOffset + trainLen);
      const leftRail = railChars.slice(0, trainScreenStart);
      const visibleWheels = TRAIN_WHEELS.slice(trainScreenStart - trainOffset, trainScreenEnd - trainOffset);
      const rightRail = railChars.slice(trainScreenEnd, railWidth);

      const leftPart = leftRail ? `${RAIL}${leftRail}${RESET}` : "";
      const wheelsPart = `${TRAIN}${visibleWheels}${RESET}`;
      const rightPart = rightRail ? `${RAIL}${rightRail}${RESET}` : "";
      railContent = `${leftPart}${wheelsPart}${rightPart}`;
    }
    const railLine = `${blankPrefix}${railContent}`;

    frames.push(new DynamicTrainFrame(step, smokePart, bodyLine, railLine));
  }
  return frames;
}

class DynamicFrame {
  k: number;
  line1: string;
  seaPart: string;
  constructor(k: number, line1: string, seaPart: string) { this.k = k; this.line1 = line1; this.seaPart = seaPart; }
  render(): string { return `${this.line1}\n${renderShimmerText(currentPhrase, this.k)}  ${this.seaPart}`; }
  get length(): number { return this.render().length; }
  toString(): string { return this.render(); }
  [Symbol.toPrimitive](): string { return this.render(); }
}

function gcd(a: number, b: number): number { return b === 0 ? a : gcd(b, a % b); }
function lcm(a: number, b: number): number { return (a * b) / gcd(a, b); }

function generateContinuousFrames(): DynamicFrame[] {
  const waveOffset = Math.floor(Math.random() * 24);
  const termWidth = process.stdout.columns || 80;
  const targetContentWidth = Math.max(50, termWidth - 4);
  const prefixWidth = TEXT_COL_WIDTH + 2;
  const seaWidth = Math.max(20, targetContentWidth - prefixWidth);
  const waveTotal = seaWidth - 6;
  const xMin = 2;
  const xMax = Math.max(xMin + 2, waveTotal - 2);
  const positions: { x: number; dir: number }[] = [];
  let curX = xMin;
  positions.push({ x: curX, dir: 1 });
  while (curX < xMax) {
    const isBack = Math.random() < 0.20 && curX > xMin;
    curX += isBack ? -1 : 1;
    positions.push({ x: curX, dir: isBack ? -1 : 1 });
  }
  while (curX > xMin + 1) {
    const isBack = Math.random() < 0.20 && curX < xMax;
    curX += isBack ? 1 : -1;
    positions.push({ x: curX, dir: isBack ? 1 : -1 });
  }
  const boatCycle = positions.length * BOAT_SLOWDOWN;
  const totalFrames = lcm(10, boatCycle);
  const frames: DynamicFrame[] = [];
  const hullColored = `${B_HULL}\\__/${RESET}`;
  for (let k = 0; k < totalFrames; k++) {
    const waveStep = Math.floor(k / WAVE_SLOWDOWN) + waveOffset;
    const boatIdx = Math.floor(k / BOAT_SLOWDOWN) % positions.length;
    const { x, dir } = positions[boatIdx];
    const flags = dir === 1 ? FLAGS_RIGHT : FLAGS_LEFT;
    const flagStr = flags[Math.floor(k / WAVE_SLOWDOWN) % flags.length];
    const flagColored = dir === 1 ? `${B_MAST}|${RESET}${B_FLAG}${flagStr.slice(1)}${RESET}` : `${B_FLAG}${flagStr.slice(0, 1)}${RESET}${B_MAST}|${RESET}`;
    const flagOffset = dir === 1 ? 0 : -1;
    const flagSpaces = prefixWidth + x + 2 + flagOffset;
    const line1 = " ".repeat(flagSpaces) + flagColored;
    const leftColored = buildColoredWave(x, "left", dir, waveStep);
    const rightColored = buildColoredWave(waveTotal - x, "right", dir, waveStep);
    const seaPart = `${leftColored} ${hullColored} ${rightColored}`;
    frames.push(new DynamicFrame(k, line1, seaPart));
  }
  return frames;
}

export default function (pi: any) {
  let phraseTimer: NodeJS.Timeout | null = null;
  let activeUi: any = null;
  let isRunning = false;
  let activeAnimation: "boat" | "train" = "boat";

  function applyIndicator(ui: any) {
    if (!ui) return;
    activeUi = ui;
    if (typeof ui.setWorkingIndicator === "function") {
      ui.setWorkingIndicator({ frames: activeAnimation === "train" ? generateTrainFrames() : generateContinuousFrames(), intervalMs: activeAnimation === "train" ? 200 : BASE_INTERVAL_MS });
    }
    if (typeof ui.setWorkingMessage === "function") ui.setWorkingMessage("");
    if (typeof ui.setHiddenThinkingLabel === "function") ui.setHiddenThinkingLabel("");
  }

  function startRandomizeTimer() {
    stopRandomizeTimer();
    phraseTimer = setInterval(() => {
      currentPhrase = SPINNER_VERBS[Math.floor(Math.random() * SPINNER_VERBS.length)];
      if (activeUi && typeof activeUi.setHiddenThinkingLabel === "function") activeUi.setHiddenThinkingLabel("");
    }, PHRASE_INTERVAL_MS);
    if (phraseTimer && typeof phraseTimer.unref === "function") phraseTimer.unref();
  }

  function stopRandomizeTimer() { if (phraseTimer) { clearInterval(phraseTimer); phraseTimer = null; } }
  function startSession(ui: any) {
    if (!ui) return;
    activeUi = ui;
    if (!isRunning) {
      isRunning = true;
      currentPhrase = SPINNER_VERBS[Math.floor(Math.random() * SPINNER_VERBS.length)];
      activeAnimation = Math.random() < 0.5 ? "boat" : "train";
      applyIndicator(ui);
      startRandomizeTimer();
    }
  }
  function stopSession() { stopRandomizeTimer(); isRunning = false; activeUi = null; }

  if (process.stdout && typeof process.stdout.on === "function") {
    process.stdout.on("resize", () => { if (activeUi && isRunning) applyIndicator(activeUi); });
  }
  pi.on("session_start", async (_event: any, ctx: any) => { if (ctx?.ui) applyIndicator(ctx.ui); });
  pi.on("agent_start", async (_event: any, ctx: any) => { if (ctx?.ui) startSession(ctx.ui); });
  pi.on("turn_start", async (_event: any, ctx: any) => { if (ctx?.ui) startSession(ctx.ui); });
  pi.on("agent_end", async () => stopSession());
  pi.on("agent_settled", async () => stopSession());
  pi.on("session_shutdown", async () => stopSession());
}
