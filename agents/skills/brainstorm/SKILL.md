---
name: brainstorm
skill_id: brainstorm
description: MANDATORY HIGH-FREQUENCY AUTO-TRIGGER First step for (1) any complex/ambiguous request, and (2) ANY runtime error, validation failure, or command crash (e.g. MissingStatePathError, ConflictError). Do NOT touch files or write code until this chain completes. Stop, apply 5 Whys to diagnose the true root cause, and use First Principles thinking to propose clean, structural upstream fixes (like system prompts) instead of fragile code workarounds.
---

# SKILL: First Principles & 5 Whys Brainstorming

This is the mandatory cognitive entry point for analyzing complex requests, debugging tracebacks, and solving system/validation errors. 

## When to Trigger (Mandatory)

You MUST automatically invoke this skill in the following scenarios:
1. **Runtime & Execution Errors**: Any terminal command crash, test failure, API `400`/`500` bad request, JSON parsing error, or traceback (e.g., `MissingStatePathError`).
2. **Ambiguous or Structural Requests**: Whenever the user asks to "re-architect", "integrate", "redesign", or requests features that span multiple system layers.
3. **Prompt & Logic Mismatches**: Any alignment issues between GraphWeave workflows, catalog node validation rules, or preprocessor steps.

## Step-by-Step Problem Solving Process

### Step 1 — Decompose the Surface Problem (5 Whys)
- Do not accept surface explanations (e.g. "it crashed because the parameter was missing").
- Ask **"Why?" five times** in a logical progression.
- Pivot from **symptoms** (e.g. "State path not found") to **systemic/foundational causes** (e.g. "LLM system prompt forbids standard environment variables, causing them to convert to dynamic placeholders").

### Step 2 — Isolate the Core Issue (First Principles)
- Separate the **running environment** from the **orchestration logic**.
- Strip away assumptions about how the code currently behaves and identify the **simplest, most elegant truth** (e.g. "OS variables belong to the terminal shell execution runtime, not the GraphWeave JSON compiler").

### Step 3 — Formulate the Upstream Solution
- Always prioritize **upstream changes** (like clarifying LLM system prompts or intent schemas) over **low-level structural code additions**.
- Keep the actual code simple, clean, and decoupled from the dynamic AI planning outputs.

## Output Format

Whenever you execute a brainstorming cycle, present your findings to the user using this exact structure:

```markdown
# 🏛️ First-Principles & 5-Whys Analysis

## 1. Problem Statement
- **Observed Behavior**: [Detailed description of error, traceback, or requirement]
- **Environment**: [Monorepo / Obsidian / CLI Node / GraphWeave]

## 2. The 5-Whys Chain
1. **Why?** → [Answer 1]
2. **Why?** → [Answer 2]
3. **Why?** → [Answer 3]
4. **Why?** → [Answer 4]
5. **Why?** → [Root Systemic Cause]

## 3. First-Principles Breakdown
- **Surface Symptom**: [What went wrong on the surface]
- **The Core Truth**: [Why the current architecture/prompt has a conceptual clash]
- **Decoupled Strategy**: [How to resolve the clash by separating responsibilities]

## 4. Proved Solution & Changes
- [ ] **Upstream Prompt Update**: [Changes in system prompts]
- [ ] **Workflow/Script Simplification**: [Reverting workarounds or cleaning up code]

## 5. Verification Plan
- [ ] [Restart / Regen / Ingestion Check]
```

## What NOT To Do
- ❌ Never write quick, ad-hoc bug patches or hardcode fallback parameters without conducting a 5-Whys check first.
- ❌ Never blame a specific variable or command before examining the system prompt that generated it.
- ❌ Never mix OS environmental variables with compile-time dynamic state variables.
