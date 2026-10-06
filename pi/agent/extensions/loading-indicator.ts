// ── ANSI Palette ──
const RESET = "\x1b[0m";

// Realistic Multi-Tone Ocean Wave Palette: dark blue -> mid blue -> light blue -> pure white high tops
const W_DARK = "\x1b[38;2;25;75;170m"; // Deep dark ocean blue (troughs)
const W_MID = "\x1b[38;2;50;130;220m"; // Mid ocean blue (swell body)
const W_LIGHT = "\x1b[38;2;85;185;245m"; // Light azure blue (wave slopes / and \)
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

// ── Playful Spinner Verbs (Randomized every 5s) ──
const SPINNER_VERBS = [
  "Cooking…",
  "Pondering…",
  "Combobulating…",
  "Catching the wind…",
  "Hoisting anchor…",
  "Navigating waters…",
  "Dodging kraken…",
  "Charting course…",
  "Scrubbing deck…",
  "Consulting compass…",
  "Hunting treasure…",
  "Captain shipping…",
  "Battening hatches…",
  "Full steam ahead…",
  "Flibbertigibbeting…",
  "Whatchamacalliting…",
  "Boondoggling…",
  "Fiddle-faddling…",
  "Lollygagging…",
  "Razzmatazzing…",
  "Sock-hopping…",
  "Tomfoolering…",
  "Moonwalking…",
  "Spelunking…",
  "Percolating…",
  "Bamboozling…",
  "Shenaniganing…",
  "Skedaddling…",
  "Kerfuffling…",
  "Cogitating…",
  "Synthesizing…",
  "Hocus-pocusing…",
  "Gobbledygooking…",
  "Discombobulating…",
  "Cat-napping…",
  "Noodling…",
  "Brainstorming…",
  "Abracadabraing…",
  "Brouhahaing…",
  "Rigmaroling…",
  "Higgledy-piggledying…",
  "Ballyhooing…",
  "Hullaballooing…",
];

// ── Braille Spinner Frames ──
const SPINNER_DOTS = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];

// ── Dynamic Flags for Sailing Right & Left ──
const FLAGS_RIGHT = ["|>", "|}", "|]", "|)"];
const FLAGS_LEFT = ["<|", "{|", "[|", "(|"];

const TEXT_COL_WIDTH = 21;
// Base frame interval: fast braille spinner & light effect (80ms)
const BASE_INTERVAL_MS = 80;
// Wave step advances every 3 ticks: 3 * 80ms = 240ms
const WAVE_SLOWDOWN = 3;
// Boat advances every 9 ticks: 9 * 80ms = 720ms (3x slower than wave)
const BOAT_SLOWDOWN = 9;
// Text randomizes every 5 seconds
const PHRASE_INTERVAL_MS = 5000;

let currentPhrase = SPINNER_VERBS[Math.floor(Math.random() * SPINNER_VERBS.length)];

// ── Closed-form Shimmer Position Calculator ──
function getShimmerPos(k: number, len: number): number {
  if (len <= 1) return 0;
  const cycle = (len - 1) * 2;
  const p = k % cycle;
  return p < len ? p : cycle - p;
}

// ── Render Scanning Highlight Beam Across Current Verb ──
function renderShimmerText(verb: string, k: number): string {
  const chars = Array.from(verb);
  const len = chars.length;
  const shimmerPos = getShimmerPos(k, len);
  let text = "";
  for (let i = 0; i < len; i++) {
    const char = chars[i];
    const dist = Math.abs(i - shimmerPos);

    if (dist === 0) {
      text += `\x1b[1;38;2;255;255;255m${char}${RESET}`;
    } else if (dist === 1) {
      text += `\x1b[38;2;170;225;255m${char}${RESET}`;
    } else if (dist === 2) {
      text += `\x1b[38;2;90;155;215m${char}${RESET}`;
    } else {
      text += `\x1b[38;2;140;150;165m${char}${RESET}`;
    }
  }
  const textWidth = len + 1;
  const pad = " ".repeat(Math.max(0, TEXT_COL_WIDTH - textWidth));
  return `${text}${pad}`;
}

// ── Build multi-tone dynamically evolving ocean wave with ~70% '-' and '~' calm water & ripples ──
function buildColoredWave(
  len: number,
  side: "left" | "right",
  dir: number,
  waveStep: number
): string {
  let res = "";

  // Dynamic ocean conditions cycle across steps:
  // 0: Rolling swell with gentle crests
  // 1: Choppy energetic sea with whitecaps
  // 2: High swell with breaking foam spray
  // 3: Frothy crests and popping bubbles
  const swellMode = Math.floor(waveStep / 4) % 4;

  // Funny ocean encounters: cycles through leaping fish, cruising shark, rubber ducky
  const encounterType = Math.floor(waveStep / 8) % 3;
  const hasEncounter = len >= 20;
  const encounterPos = Math.floor(len / 2);

  const isBow = (dir === 1 && side === "right") || (dir === -1 && side === "left");

  let i = 0;
  while (i < len) {
    const dist = side === "left" ? len - 1 - i : i;

    // ── Dynamic Bow Wave & Stern Wake directly hugging the boat ──
    if (dist === 0) {
      // Cutting wave directly at the hull
      const c = isBow ? (waveStep % 2 === 0 ? "^" : "/") : "-";
      res += `${c === "-" ? W_DARK : W_WHITE}${c}${RESET}`;
      i++;
    } else if (dist === 1) {
      // Churning foam / flat wake
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
      // ── Living Ocean Surprises (strictly 3 characters) ──
      if (encounterType === 0) {
        // Leaping fish
        const fishChar =
          waveStep % 4 < 2 ? (side === "left" ? "><>" : "<><") : "^><^".slice(0, 3);
        res += `${FISH}${fishChar}${RESET}`;
      } else if (encounterType === 1) {
        // Mysterious shark fin cruising along
        res += `${W_DARK}-${SHARK}/|${RESET}`;
      } else {
        // Playful rubber duck bobbing on the waves
        res += `${W_MID}-${DUCK}o<${RESET}`;
      }
      i += 3;
    } else {
      // ── Dynamic Rolling Ocean Swell (~70% '-' and '~') ──
      const wavePhase = (i + (side === "left" ? -waveStep : waveStep) + waveStep * 2 + 120) % 16;

      if (wavePhase === 0) {
        // High top crest peak: pure brilliant white
        res += `${W_WHITE}^${RESET}`;
      } else if (wavePhase === 5) {
        // Wave slope rising: light azure blue
        res += `${W_LIGHT}/${RESET}`;
      } else if (wavePhase === 6) {
        // Wave slope falling: light azure blue
        res += `${W_LIGHT}\\${RESET}`;
      } else if (wavePhase === 11 && swellMode === 3) {
        // Breaker spray (occasional white foam)
        res += `${W_WHITE}\`${RESET}`;
      } else if (
        wavePhase === 1 ||
        wavePhase === 2 ||
        wavePhase === 7 ||
        wavePhase === 8 ||
        wavePhase === 12
      ) {
        // Calm flat water troughs: dark ocean blue '-'
        res += `${W_DARK}-${RESET}`;
      } else if (wavePhase === 3 || wavePhase === 4) {
        // Mid swell surface ripples: mid ocean blue '~'
        res += `${W_MID}~${RESET}`;
      } else {
        // Deep water troughs: dark ocean blue '~'
        res += `${W_DARK}~${RESET}`;
      }
      i++;
    }
  }
  return res;
}

// ── Dynamic Frame Object: Decouples Continuous Boat/Wave Animation from Randomizing Text ──
class DynamicFrame {
  k: number;
  line1: string;
  seaPart: string;

  constructor(k: number, line1: string, seaPart: string) {
    this.k = k;
    this.line1 = line1;
    this.seaPart = seaPart;
  }

  render(): string {
    const dot = SPINNER_DOTS[this.k % SPINNER_DOTS.length];
    const coloredDot = `\x1b[1;38;2;130;205;255m${dot}${RESET}`;
    const textPart = renderShimmerText(currentPhrase, this.k);
    const line2 = `${coloredDot} ${textPart}  ${this.seaPart}`;
    return `${this.line1}\n${line2}`;
  }

  get length(): number {
    return this.render().length;
  }

  toString(): string {
    return this.render();
  }

  [Symbol.toPrimitive](): string {
    return this.render();
  }
}

function gcd(a: number, b: number): number {
  return b === 0 ? a : gcd(b, a % b);
}

function lcm(a: number, b: number): number {
  return (a * b) / gcd(a, b);
}

// ── Precompute Continuous Sea & Boat Trajectory (Runs continuously from start to end) ──
function generateContinuousFrames(): DynamicFrame[] {
  const termWidth = process.stdout.columns || 80;
  const targetContentWidth = Math.max(50, termWidth - 4); // 4 columns margin for TUI padding
  const prefixWidth = TEXT_COL_WIDTH + 4; // dot (1) + space (1) + text (TEXT_COL_WIDTH) + gap (2)

  const seaWidth = Math.max(20, targetContentWidth - prefixWidth);
  const waveTotal = seaWidth - 6; // 6 cols for boat: space (1) + hull (4) + space (1)
  const xMin = 2;
  const xMax = Math.max(xMin + 2, waveTotal - 2);

  // Boat trajectory across the full wave width
  // Sails with a main direction (right, then left) with a 20% back rate on intermediate steps
  const positions: { x: number; dir: number }[] = [];
  let curX = xMin;
  positions.push({ x: curX, dir: 1 });

  // Outward leg: main direction is right (dir: 1), 20% back rate
  while (curX < xMax) {
    const isBack = Math.random() < 0.20 && curX > xMin;
    if (isBack) {
      curX--;
      positions.push({ x: curX, dir: -1 });
    } else {
      curX++;
      positions.push({ x: curX, dir: 1 });
    }
  }

  // Return leg: main direction is left (dir: -1), 20% back rate
  while (curX > xMin + 1) {
    const isBack = Math.random() < 0.20 && curX < xMax;
    if (isBack) {
      curX++;
      positions.push({ x: curX, dir: 1 });
    } else {
      curX--;
      positions.push({ x: curX, dir: -1 });
    }
  }

  // Full cycle ensures continuous uninterrupted sailing
  const boatCycle = positions.length * BOAT_SLOWDOWN;
  // Multiple of 10 ensures braille spinner also loops seamlessly
  const totalFrames = lcm(10, boatCycle);

  const frames: DynamicFrame[] = [];
  const hullColored = `${B_HULL}\\__/${RESET}`;

  for (let k = 0; k < totalFrames; k++) {
    // Wave advances every 3 ticks: 3 * 80ms = 240ms
    const waveStep = Math.floor(k / WAVE_SLOWDOWN);

    // Boat advances every 9 ticks: 9 * 80ms = 720ms
    const boatIdx = Math.floor(k / BOAT_SLOWDOWN) % positions.length;
    const { x, dir } = positions[boatIdx];

    const flags = dir === 1 ? FLAGS_RIGHT : FLAGS_LEFT;
    const flagStr = flags[Math.floor(k / WAVE_SLOWDOWN) % flags.length];

    const flagColored =
      dir === 1
        ? `${B_MAST}|${RESET}${B_FLAG}${flagStr.slice(1)}${RESET}`
        : `${B_FLAG}${flagStr.slice(0, 1)}${RESET}${B_MAST}|${RESET}`;

    // Line 1: flag positioned directly over hull center
    const flagSpaces = prefixWidth + x + 2;
    const line1 = " ".repeat(flagSpaces) + flagColored;

    // Fast-rolling dynamic waves on left and right sides
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

  function applyIndicator(ui: any) {
    if (!ui) return;
    activeUi = ui;

    // Set working indicator ONCE with continuous dynamic frames
    if (typeof ui.setWorkingIndicator === "function") {
      ui.setWorkingIndicator({
        frames: generateContinuousFrames(),
        intervalMs: BASE_INTERVAL_MS,
      });
    }

    if (typeof ui.setWorkingMessage === "function") {
      ui.setWorkingMessage("");
    }

    if (typeof ui.setHiddenThinkingLabel === "function") {
      ui.setHiddenThinkingLabel(`💭 ${currentPhrase}  ~~~~~~~~~~~^~^ \\__/ ~^~^~~~~~~~~~~`);
    }
  }

  function startRandomizeTimer() {
    stopRandomizeTimer();

    // Randomize text every 5 seconds WITHOUT resetting the boat/wave loading animation
    phraseTimer = setInterval(() => {
      const nextIndex = Math.floor(Math.random() * SPINNER_VERBS.length);
      currentPhrase = SPINNER_VERBS[nextIndex];

      if (activeUi && typeof activeUi.setHiddenThinkingLabel === "function") {
        activeUi.setHiddenThinkingLabel(`💭 ${currentPhrase}  ~~~~~~~~~~~^~^ \\__/ ~^~^~~~~~~~~~~`);
      }
    }, PHRASE_INTERVAL_MS);
    if (phraseTimer && typeof phraseTimer.unref === "function") {
      phraseTimer.unref();
    }
  }

  function stopRandomizeTimer() {
    if (phraseTimer) {
      clearInterval(phraseTimer);
      phraseTimer = null;
    }
  }

  function startSession(ui: any) {
    if (!ui) return;
    activeUi = ui;
    // Only initialize if not already running; do NOT reset on intermediate block/tool finish
    if (!isRunning) {
      isRunning = true;
      const nextIndex = Math.floor(Math.random() * SPINNER_VERBS.length);
      currentPhrase = SPINNER_VERBS[nextIndex];
      applyIndicator(ui);
      startRandomizeTimer();
    }
  }

  function stopSession() {
    stopRandomizeTimer();
    isRunning = false;
    activeUi = null;
  }

  // Handle terminal window resizing dynamically
  if (process.stdout && typeof process.stdout.on === "function") {
    process.stdout.on("resize", () => {
      if (activeUi && isRunning) {
        applyIndicator(activeUi);
      }
    });
  }

  // Configure indicator frames when the session starts
  pi.on("session_start", async (_event: any, ctx: any) => {
    if (ctx?.ui) {
      applyIndicator(ctx.ui);
    }
  });

  // Start continuous loading animation when the agent starts
  pi.on("agent_start", async (_event: any, ctx: any) => {
    if (ctx?.ui) {
      startSession(ctx.ui);
    }
  });

  // Fallback to start session on turn_start if not already running
  pi.on("turn_start", async (_event: any, ctx: any) => {
    if (ctx?.ui) {
      startSession(ctx.ui);
    }
  });

  // Stop session ONLY when the entire result is complete (same as notification.ts agent_settled)
  // Note: Do NOT listen to turn_end, as it fires after every single tool execution/block!
  pi.on("agent_end", async () => {
    stopSession();
  });

  pi.on("agent_settled", async () => {
    stopSession();
  });

  pi.on("session_shutdown", async () => {
    stopSession();
  });
}
