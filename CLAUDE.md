# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A personal digital-twin project. The goal is to preserve Andrew Pennington's voice, memories, and values in a local AI model that family members can talk to. There are two independent systems here:

1. **Digital Twin** — Ollama-backed persona models + a Python chat GUI
2. **AI Team pipeline** — a PowerShell worker/supervisor loop using the `llm` CLI

---

## Commands

### Digital Twin GUI
```bash
python twin_chat.py
```
Requires Ollama running (`ollama serve` if not already up). The GUI handles model building internally via the ⚙ Build Model button.

### Build a model manually
```bash
ollama create andrew-legacy  -f Legacy.Modelfile
ollama create my-twin        -f StrongTwin.Modelfile
ollama create personal-interviewer -f Interviewer.Modelfile
```

### Chat with a model directly (no GUI)
```bash
ollama run andrew-legacy
ollama run my-twin
ollama run personal-interviewer
```

### List installed models
```bash
ollama list
```

### AI Team pipeline
```powershell
.\ai team\ai_team.ps1 -Task "Write a Python function that..."
```
Requires the `llm` CLI installed and configured with a Gemini API key. Output is written to `ai team\final_output.txt`.

---

## Architecture

### Modelfile hierarchy

| File | Ollama model name | Purpose |
|---|---|---|
| `Interviewer.Modelfile` | `personal-interviewer` | Asks one question at a time to collect biographical data |
| `Twin.Modelfile` | `my-twin` | First-gen digital twin with raw interview transcript baked in |
| `StrongTwin.Modelfile` | `my-twin` | Stricter version — better character constraints, same data |
| `Legacy.Modelfile` | `andrew-legacy` | Authoritative version: clean structured biography + 20+ MESSAGE training examples |

**`Legacy.Modelfile` is the canonical model.** The Twin/StrongTwin files are earlier iterations kept for reference. All future improvements should go into Legacy.Modelfile.

The Modelfile format is Ollama's native format:
- `FROM` — base model (currently `llama3.2:3b`)
- `PARAMETER` — inference settings (temperature, stop tokens, etc.)
- `SYSTEM` — the persona/identity system prompt
- `MESSAGE user/assistant` — few-shot training examples that lock in behavior

`MyIdentity.txt` is the raw source material (interview transcripts). It is not used at runtime — its content was synthesized into the `SYSTEM` block of `Legacy.Modelfile`.

### twin_chat.py

A single-file Python/tkinter app. Key design decisions:
- All Ollama communication is via the REST API (`http://localhost:11434`) using `requests`, never subprocess
- Responses are streamed token-by-token via `/api/chat` with `stream=True`
- Model building uses `subprocess.Popen` on `ollama create` and streams stdout into the chat window
- All network/subprocess calls run in daemon threads; UI updates are marshalled back via `self.after(0, ...)`
- Conversation history (`self.messages`) is a plain list of `{"role": ..., "content": ...}` dicts, reset on model switch or clear

The model name map lives in `MODELS` dict at the top of the file. To add a new persona, add an entry there and a corresponding entry in `MODELFILES`.

### AI Team pipeline (ai team/ai_team.ps1)

A multi-agent review loop driven entirely by the `llm` CLI:
1. **Worker** (Gemini Flash) — completes the task
2. **Supervisor** (Gemini Flash with critic system prompt) — reviews and either outputs `APPROVED` or lists issues
3. **Middle Manager** (33% random chance) — injects a satirical corporate-buzzword question the supervisor must address before reviewing
4. Loop repeats up to `$MaxIterations` (default 3) until `APPROVED` or max reached
5. Final output (approved or last attempt) is saved to `final_output.txt`

The `llm` CLI is Simon Willison's [`llm`](https://llm.datasette.io) Python package. It reads from stdin and writes to stdout, which is how the pipeline chains stages with `|`.
