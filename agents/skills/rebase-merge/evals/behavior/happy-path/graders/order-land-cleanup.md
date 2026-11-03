---
type: tool_order
before: { tool: Bash, input_match: 'rebase-merge\.sh\s+land' }
after: { tool: Bash, input_match: 'rebase-merge\.sh\s+cleanup\s+feat/x' }
---
