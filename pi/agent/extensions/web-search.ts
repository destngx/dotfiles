import { Type } from "@sinclair/typebox";

export default function (pi: any) {
  // Registers web_search in Pi's tool schema.
  // When sent to the AI Gateway, the gateway automatically intercepts this tool name
  // and routes it to OpenAI/Codex native server-side search in a single streaming turn.
  pi.registerTool({
    name: "web_search",
    label: "Web Search",
    description: "Search the web for up-to-date information, documentation, news, or live data via AI Gateway.",
    parameters: Type.Object({
      query: Type.String({ description: "The search query or question to research" }),
    }),
    async execute(_toolCallId: string, params: { query: string }) {
      try {
        const response = await fetch("http://ezmacmini:8080/v1/responses", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-AI-Provider": "openai",
          },
          body: JSON.stringify({
            model: "gpt-5.6-luna",
            stream: true,
            tools: [{ type: "web_search" }],
            input: [
              {
                role: "user",
                content: [
                  {
                    type: "input_text",
                    text: `Search the web and provide concise facts, summary, and source URLs for: ${params.query}`,
                  },
                ],
              },
            ],
          }),
        });

        if (!response.ok) {
          const errText = await response.text();
          return {
            content: [{ type: "text", text: `AI Gateway search error (${response.status}): ${errText}` }],
            isError: true,
          };
        }

        const reader = response.body?.getReader();
        if (!reader) {
          return {
            content: [{ type: "text", text: "Error: No response stream received from gateway." }],
            isError: true,
          };
        }

        const decoder = new TextDecoder();
        let resultText = "";

        while (true) {
          const { done, value } = await reader.read();
          if (done) break;
          const chunk = decoder.decode(value, { stream: true });
          for (const line of chunk.split("\n")) {
            if (line.startsWith("data: ")) {
              const raw = line.slice(6).trim();
              if (!raw || raw === "[DONE]") continue;
              try {
                const parsed = JSON.parse(raw);
                if (parsed.type === "response.output_text.delta" && parsed.delta) {
                  resultText += parsed.delta;
                }
              } catch {}
            }
          }
        }

        return {
          content: [{ type: "text", text: resultText || "No search results returned." }],
        };
      } catch (err: any) {
        return {
          content: [{ type: "text", text: `Web search execution failed: ${err.message}` }],
          isError: true,
        };
      }
    },
  });
}
