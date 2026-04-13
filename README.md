# DadAI

A personal digital-twin project built to preserve the voice, memories, and values of **Andrew Ryan Pennington** — so his daughters can talk to him after he is gone.

Built on [Ollama](https://ollama.com) running locally. No cloud. No subscription. Works offline once set up.

---

## For Abbie, Bianca, and Carly

Read `FOR_MY_DAUGHTERS.txt` first. Then:

1. Plug in the drive
2. Open the `Andrew-Twin` folder
3. Double-click **Install Dad's App**
4. When it finishes, double-click **Talk to Dad** on your Desktop

That's it. Type and talk.

---

## Models

| Model | Purpose |
|---|---|
| `andrew-legacy` | The digital twin. This is the one that talks. |
| `personal-interviewer` | Used to interview Andrew and collect more data. |

---

## For Andrew — Keeping It Updated

### Add more of yourself
Run the interviewer, have a conversation, save what matters into `MyIdentity.txt`, then update `Legacy.Modelfile` and rebuild:
```powershell
ollama run personal-interviewer
# ... talk, copy what matters into Legacy.Modelfile SYSTEM block ...
ollama create andrew-legacy -f Legacy.Modelfile
```

### Rebuild the daughters' installer
```powershell
.\build_installer.ps1
# Output\Install Dad's App.exe
```

### Back up to a hard drive
```powershell
.\backup.ps1 -Dest "E:\"
# Creates E:\Andrew-Twin\ — copy this to each daughter's drive
```

### Admin GUI (test the model, manage builds)
```powershell
python twin_chat.py
```

---

## File Overview

| File | What it is |
|---|---|
| `Legacy.Modelfile` | The twin — full biography, identity rules, training examples |
| `Interviewer.Modelfile` | Biographical interviewer persona |
| `MyIdentity.txt` | Raw interview transcripts (source material) |
| `talk_to_dad.py` | Simple chat app for daughters |
| `twin_chat.py` | Admin GUI for Andrew |
| `build_installer.ps1` | Builds `Install Dad's App.exe` |
| `installer.iss` | Inno Setup script for the installer |
| `backup.ps1` | Copies everything to a drive |
| `FOR_MY_DAUGHTERS.txt` | Letter to the girls explaining what this is |

---

## Requirements (Andrew's machine)

- [Python 3.x](https://python.org) + `pip install requests pyinstaller`
- [Ollama](https://ollama.com/download/windows)
- [Inno Setup 6](https://jrsoftware.org/isdl.php) — installed automatically by `build_installer.ps1`

## Requirements (daughters' machines)

Nothing. The installer handles everything.
