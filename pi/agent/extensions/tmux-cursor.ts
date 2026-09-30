import { readFileSync, watch, writeFileSync, unlinkSync, type FSWatcher } from "fs";
import { execFile } from "child_process";
import { tmpdir } from "os";
import { join } from "path";
import { CustomEditor, type ExtensionAPI } from "@earendil-works/pi-coding-agent";

const REVERSE_VIDEO = /\x1b\[7m([\s\S]*?)\x1b\[0m/g;

function tmux(args: string[]): Promise<void> {
  return new Promise((resolve, reject) => {
    execFile("tmux", args, (error) => (error ? reject(error) : resolve()));
  });
}

export default function (pi: ExtensionAPI) {
  const pane = process.env.TMUX_PANE;
  if (!process.env.TMUX || !pane) return;

  const paneKey = pane.replace(/[^a-zA-Z0-9_-]/g, "_");
  const stateFile = join(tmpdir(), `pi-focus-cursor-${paneKey}-${process.pid}`);
  let focused = true;
  let watcher: FSWatcher | undefined;
  let activeTui: any;
  let previousFactory: ((tui: any, theme: any, kb: any) => any) | undefined;

  function readFocus() {
    try {
      const next = readFileSync(stateFile, "utf8").trim() !== "unfocused";
      if (next !== focused) {
        focused = next;
        activeTui?.requestRender?.();
      }
    } catch {
      // Keep the current cursor state if the focus file is briefly unavailable.
    }
  }

  pi.on("session_start", async (_event, ctx) => {
    if (!ctx.hasUI) return;

    previousFactory = ctx.ui.getEditorComponent?.() ?? undefined;
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

    writeFileSync(stateFile, "focused", "utf8");
    watcher = watch(stateFile, readFocus);

    const focusOutCommand = `run-shell -b 'if [ -e ${stateFile} ]; then printf unfocused > ${stateFile}; fi'`;
    const focusInCommand = `run-shell -b 'if [ -e ${stateFile} ]; then printf focused > ${stateFile}; fi'`;
    try {
      await tmux(["set-hook", "-a", "-p", "-t", pane, "pane-focus-out", focusOutCommand]);
      await tmux(["set-hook", "-a", "-p", "-t", pane, "pane-focus-in", focusInCommand]);
    } catch (error) {
      ctx.ui.notify(`tmux cursor focus hooks could not be installed: ${String(error)}`, "warning");
    }
  });

  pi.on("session_shutdown", async () => {
    watcher?.close();
    watcher = undefined;
    activeTui = undefined;
    try {
      unlinkSync(stateFile);
    } catch {
      // File may already be gone.
    }
  });
}
