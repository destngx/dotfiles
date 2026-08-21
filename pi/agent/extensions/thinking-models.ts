import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

type ThinkingLevel =
  | "off"
  | "minimal"
  | "low"
  | "medium"
  | "high"
  | "xhigh";

const thinkingByModel: Record<string, ThinkingLevel> = {
  // Use provider/model IDs shown by /model.
  "anthropic/claude-fable-5": "xhigh",
  "anthropic/claude-opus-5": "high",
  "anthropic/claude-sonnet-5": "low",
  "anthropic/claude-haiku-4-5": "off",
  "openai/gpt-5.6-sol": "high",
  "openai/gpt-5.6-terra": "low",
  "openai/gpt-5.6-luna": "off",
};

export default function (pi: ExtensionAPI) {
  pi.on("model_select", async (event, ctx) => {
    const modelId = `${event.model.provider}/${event.model.id}`;

    // Optional fallback for models not listed above.
    const thinking = thinkingByModel[modelId] ?? "medium";

    pi.setThinkingLevel(thinking);

    ctx.ui.notify(
      `${event.model.name ?? modelId} · thinking: ${pi.getThinkingLevel()}`,
      "info",
    );
  });
}
