const RESET = "\x1b[0m";

// ── Claude Code Playful Spinner Verbs ──
const SPINNER_VERBS = [
  "Cooking…",
  "Pondering…",
  "Combobulating…",
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

// ── Scanning / Shimmer Highlight Beam Generator with Spinner ──
function generateShimmerFrames(text: string): string[] {
  const frames: string[] = [];
  const len = text.length;
  const positions: number[] = [];

  // Forward sweep
  for (let p = 0; p < len; p++) positions.push(p);
  // Backward sweep
  for (let p = len - 2; p > 0; p--) positions.push(p);

  for (let k = 0; k < positions.length; k++) {
    const pos = positions[k];
    const dot = SPINNER_DOTS[k % SPINNER_DOTS.length];
    const coloredDot = `\x1b[1;38;2;130;205;255m${dot}${RESET}`;

    let textFrame = "";
    for (let i = 0; i < len; i++) {
      const char = text[i];
      const dist = Math.abs(i - pos);

      if (dist === 0) {
        // Bright highlight peak (bold white)
        textFrame += `\x1b[1;38;2;255;255;255m${char}${RESET}`;
      } else if (dist === 1) {
        // Soft glowing cyan
        textFrame += `\x1b[38;2;170;225;255m${char}${RESET}`;
      } else if (dist === 2) {
        // Trailing accent
        textFrame += `\x1b[38;2;90;155;215m${char}${RESET}`;
      } else {
        // Dim base text
        textFrame += `\x1b[38;2;100;105;115m${char}${RESET}`;
      }
    }
    frames.push(`${coloredDot} ${textFrame}`);
  }
  return frames;
}

export default function (pi: any) {
  let phraseIndex = 0;
  let phraseTimer: NodeJS.Timeout | null = null;
  let activeUi: any = null;

  function setPhrase(ui: any, phrase: string) {
    if (!ui) return;
    const frames = generateShimmerFrames(phrase);

    // Overwrite the default "⠙ Working..." indicator with our shimmering text
    if (typeof ui.setWorkingIndicator === "function") {
      ui.setWorkingIndicator({
        frames: frames,
        intervalMs: 50,
      });
    }

    // Clear the default text message so only the animated text is shown
    if (typeof ui.setWorkingMessage === "function") {
      ui.setWorkingMessage("");
    }

    // Update the collapsed thinking block label
    if (typeof ui.setHiddenThinkingLabel === "function") {
      ui.setHiddenThinkingLabel(`💭 ${phrase}`);
    }
  }

  function startPhraseRotation(ui: any) {
    stopPhraseRotation();
    activeUi = ui;

    // Pick a random starting verb
    phraseIndex = Math.floor(Math.random() * SPINNER_VERBS.length);
    const initialPhrase = SPINNER_VERBS[phraseIndex % SPINNER_VERBS.length];
    setPhrase(ui, initialPhrase);
    phraseIndex++;

    // Rotate phrase every 3.0 seconds
    phraseTimer = setInterval(() => {
      if (activeUi) {
        const nextPhrase = SPINNER_VERBS[phraseIndex % SPINNER_VERBS.length];
        setPhrase(activeUi, nextPhrase);
        phraseIndex++;
      }
    }, 8000);
  }

  function stopPhraseRotation() {
    if (phraseTimer) {
      clearInterval(phraseTimer);
      phraseTimer = null;
    }
    activeUi = null;
  }

  pi.on("session_start", async (_event: any, ctx: any) => {
    if (ctx?.ui) {
      startPhraseRotation(ctx.ui);
      stopPhraseRotation();
    }
  });

  pi.on("turn_start", async (_event: any, ctx: any) => {
    if (ctx?.ui) {
      startPhraseRotation(ctx.ui);
    }
  });

  pi.on("tool_call", async (event: any, ctx: any) => {
    if (ctx?.ui) {
      const toolName = event?.toolName || event?.name || "tool";
      setPhrase(ctx.ui, `Running ${toolName}...`);
    }
  });

  pi.on("turn_end", async () => {
    stopPhraseRotation();
  });

  pi.on("agent_end", async () => {
    stopPhraseRotation();
  });
}
