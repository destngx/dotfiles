import { CustomEditor, type ExtensionAPI } from "@earendil-works/pi-coding-agent";

const REVERSE_VIDEO = /\x1b\[7m([\s\S]*?)\x1b\[0m/g;
const FOCUS_IN = "\x1b[I";
const FOCUS_OUT = "\x1b[O";
const FOCUS_REPORTING = "\x1b[?1004h";
const DISABLE_FOCUS_REPORTING = "\x1b[?1004l";

export default function (pi: ExtensionAPI) {
  if (!process.env.TMUX_PANE && !process.env.HERDR_ENV && !process.env.TERM_PROGRAM?.toLowerCase().includes("herdr")) return;

  let focused = true;
  let activeTui: any;
  let unsubscribeInput: (() => void) | undefined;
  let previousFactory: ((tui: any, theme: any, kb: any) => any) | undefined;

  pi.on("session_start", async (_event, ctx) => {
    if (!ctx.hasUI || ctx.mode !== "tui") return;

    ctx.ui.setEditorComponent((tui: any, theme: any, keybindings: any) => {
      const editor = previousFactory
        ? previousFactory(tui, theme, keybindings)
        : new CustomEditor(tui, theme, keybindings);
      const render = editor.render.bind(editor);
      editor.render = (width: number) => {
        const lines = render(width);
        return focused ? lines : lines.map((line: string) => line.replace(REVERSE_VIDEO, "$1"));
      };
      activeTui = tui;
      return editor;
    });

    process.stdout.write(FOCUS_REPORTING);
    unsubscribeInput = ctx.ui.onTerminalInput((data) => {
      if (data.includes(FOCUS_IN)) {
        if (!focused) {
          focused = true;
          activeTui?.requestRender?.();
        }
        return { consume: true, data: data.replaceAll(FOCUS_IN, "") };
      }
      if (data.includes(FOCUS_OUT)) {
        if (focused) {
          focused = false;
          activeTui?.requestRender?.();
        }
        return { consume: true, data: data.replaceAll(FOCUS_OUT, "") };
      }
    });
  });

  pi.on("session_shutdown", async () => {
    unsubscribeInput?.();
    unsubscribeInput = undefined;
    activeTui = undefined;
    process.stdout.write(DISABLE_FOCUS_REPORTING);
  });
}
