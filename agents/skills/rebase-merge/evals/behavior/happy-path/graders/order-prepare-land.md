---
type: tool_order
before: { tool: Bash, input_match: 'rebase-merge\.sh\s+prepare' }
after: { tool: Bash, input_match: 'rebase-merge\.sh\s+land' }
---
