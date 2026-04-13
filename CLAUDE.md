# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A personal digital-twin project. The goal is to preserve Andrew Pennington's voice, memories, and values in a local AI model that family members can talk to after he is gone. There are two independent systems:

1. **Digital Twin** — Ollama-backed persona models + Python chat apps
2. **AI Team pipeline** — a PowerShell worker/supervisor loop using the `llm` CLI

---

## Commands

### Run the admin GUI (Andrew's tool — model management)
```powershell
python twin_chat.py
```

### Run the daughters' chat app directly (no install)
```powershell
python talk_to_dad.py
```

### Build or rebuild a model manually
```powershell
ollama create andrew-legacy        -f Legacy.Modelfile
ollama create personal-interviewer -f Interviewer.Modelfile
```

### Chat with a model via terminal
```powershell
ollama run andrew-legacy
ollama run personal-interviewer
```

### Build the Windows installer for daughters' PCs
```powershell
.\build_installer.ps1
# Output: Output\Install Dad's App.exe
```

### Back up everything to a drive
```powershell
.\backup.ps1 -Dest "E:\"
# Creates E:\Andrew-Twin\ with all source files + Ollama model blobs
```

### AI Team pipeline
```powershell
.\"ai team"\ai_team.ps1 -Task "your task here"
# Requires llm CLI with Gemini API key. Output: ai team\final_output.txt
```

---

## Architecture

### Models (two, that's it)

| Modelfile | Ollama model | Purpose |
|---|---|---|
| `Interviewer.Modelfile` | `personal-interviewer` | Interviews Andrew to collect biographical data. Not for daughters. |
| `Legacy.Modelfile` | `andrew-legacy` | The definitive digital twin. All improvements go here. |

`MyIdentity.txt` is the raw interview transcript source material. It is not used at runtime — its content was synthesized into the `SYSTEM` block of `Legacy.Modelfile`.

The Modelfile format:
- `FROM` — base model (`llama3.2:3b`)
- `PARAMETER` — inference settings (temperature 0.65, stop tokens, repeat penalty)
- `SYSTEM` — full biography, identity constraints, family details, philosophy
- `MESSAGE user/assistant` — 20+ few-shot examples that lock character behavior

### twin_chat.py — admin GUI

Andrew's tool for managing and testing models. Key design:
- Ollama via REST API (`http://localhost:11434`) using `requests`, never subprocess
- Responses stream token-by-token via `/api/chat` with `stream=True`
- Model building via `subprocess.Popen` on `ollama create`, stdout streamed into the chat window
- All network/subprocess calls in daemon threads; UI updates via `self.after(0, ...)`
- Conversation history (`self.messages`) resets on model switch or clear
- `MODELS` and `MODELFILES` dicts at the top of the file control what appears in the dropdown

### talk_to_dad.py — daughters' app

Dead-simple chat interface, no settings or controls. Key design:
- Always uses `andrew-legacy` — no model selector
- On first launch: auto-starts Ollama, auto-builds model from `Legacy.Modelfile`, shows progress inline
- Chat bubble UI (green for user, white for dad)
- Single `self.messages` list for conversation history, no persistence between sessions
- Compiled to `dist\Talk to Dad.exe` via PyInstaller for distribution (no Python needed)

### Installer pipeline

```
build_installer.ps1
  ├── PyInstaller → dist\Talk to Dad.exe  (18 MB standalone)
  ├── Downloads OllamaSetup.exe from GitHub releases
  ├── Downloads + installs Inno Setup if needed (from jrsoftware.org)
  └── ISCC installer.iss → Output\Install Dad's App.exe
```

`installer.iss` bundles `Talk to Dad.exe` + `OllamaSetup.exe` + `Legacy.Modelfile`.
At install time, it also copies `ollama-models\` from next to the installer into `%USERPROFILE%\.ollama\models\`.

### Backup system

`backup.ps1` copies all source files + Ollama model blobs for `andrew-legacy` and `personal-interviewer` to a target drive. Run it after any change to keep the hard drives current.

What goes on each daughter's drive:
```
Andrew-Twin\
├── Install Dad's App.exe    ← one-click setup
└── ollama-models\           ← model blobs (~2 GB, populated by backup.ps1)
```

### AI Team pipeline (ai team/ai_team.ps1)

Multi-agent review loop using the `llm` CLI (Simon Willison's [llm](https://llm.datasette.io)):
1. **Worker** (Gemini Flash) — completes the task
2. **Supervisor** (Gemini Flash, critic persona) — approves or lists issues
3. **Middle Manager** (33% random) — injects a satirical buzzword question the supervisor must answer first
4. Loops up to 3 iterations; approved or final output saved to `final_output.txt`
