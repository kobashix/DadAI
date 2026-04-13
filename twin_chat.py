"""
Andrew Pennington - Digital Twin Chat
A simple GUI to chat with the digital twin models via Ollama.
"""

import tkinter as tk
from tkinter import ttk, messagebox, scrolledtext
import threading
import requests
import json
import subprocess
import os
import sys

OLLAMA_BASE = "http://localhost:11434"

MODELS = {
    "Interviewer  (builds the twin)": "personal-interviewer",
    "Twin  (my-twin)":                "my-twin",
    "Legacy  (full biography)":       "andrew-legacy",
}

MODELFILES = {
    "personal-interviewer": "Interviewer.Modelfile",
    "my-twin":              "StrongTwin.Modelfile",
    "andrew-legacy":        "Legacy.Modelfile",
}

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

# ── colour palette ──────────────────────────────────────────────────────────
BG        = "#1a1a1a"
PANEL     = "#242424"
ACCENT    = "#c8a96e"       # warm gold
USER_CLR  = "#a8d8a8"       # soft green
BOT_CLR   = "#e8e8e8"       # near-white
DIM       = "#666666"
BTN_BG    = "#333333"
BTN_HVR   = "#444444"
FONT_MAIN = ("Segoe UI", 11)
FONT_BOLD = ("Segoe UI", 11, "bold")
FONT_CODE = ("Consolas",  10)


# ── helpers ─────────────────────────────────────────────────────────────────

def model_exists(name: str) -> bool:
    try:
        r = requests.get(f"{OLLAMA_BASE}/api/tags", timeout=5)
        models = [m["name"].split(":")[0] for m in r.json().get("models", [])]
        return name in models
    except Exception:
        return False


def build_model(model_name: str, on_line, on_done, on_error):
    """Run 'ollama create' in a background thread, streaming output."""
    mf = MODELFILES.get(model_name)
    if not mf:
        on_error(f"No Modelfile mapped for '{model_name}'")
        return

    mf_path = os.path.join(SCRIPT_DIR, mf)
    if not os.path.exists(mf_path):
        on_error(f"Modelfile not found:\n{mf_path}")
        return

    def run():
        cmd = ["ollama", "create", model_name, "-f", mf_path]
        try:
            proc = subprocess.Popen(
                cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                text=True, bufsize=1
            )
            for line in proc.stdout:
                on_line(line.rstrip())
            proc.wait()
            if proc.returncode == 0:
                on_done()
            else:
                on_error(f"ollama create exited with code {proc.returncode}")
        except FileNotFoundError:
            on_error("'ollama' command not found. Is Ollama installed and in PATH?")
        except Exception as e:
            on_error(str(e))

    threading.Thread(target=run, daemon=True).start()


def chat_stream(model: str, messages: list, on_token, on_done, on_error):
    """POST to /api/chat and stream response tokens."""
    def run():
        try:
            r = requests.post(
                f"{OLLAMA_BASE}/api/chat",
                json={"model": model, "messages": messages, "stream": True},
                stream=True, timeout=120
            )
            r.raise_for_status()
            for raw in r.iter_lines():
                if not raw:
                    continue
                data = json.loads(raw)
                token = data.get("message", {}).get("content", "")
                if token:
                    on_token(token)
                if data.get("done"):
                    break
            on_done()
        except requests.exceptions.ConnectionError:
            on_error("Cannot connect to Ollama. Make sure it is running.")
        except Exception as e:
            on_error(str(e))

    threading.Thread(target=run, daemon=True).start()


# ── main app ────────────────────────────────────────────────────────────────

class App(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Andrew Pennington — Digital Twin")
        self.geometry("860x640")
        self.minsize(640, 480)
        self.configure(bg=BG)

        self.messages: list[dict] = []   # conversation history for Ollama
        self.is_generating = False

        self._build_ui()
        self._check_models_async()

    # ── UI construction ──────────────────────────────────────────────────────

    def _build_ui(self):
        # ── top bar ──
        top = tk.Frame(self, bg=PANEL, padx=12, pady=8)
        top.pack(fill="x")

        tk.Label(top, text="Digital Twin", bg=PANEL, fg=ACCENT,
                 font=("Segoe UI", 14, "bold")).pack(side="left")

        # model selector
        tk.Label(top, text="  Model:", bg=PANEL, fg=DIM,
                 font=FONT_MAIN).pack(side="left")
        self.model_var = tk.StringVar()
        combo = ttk.Combobox(
            top, textvariable=self.model_var,
            values=list(MODELS.keys()), state="readonly",
            width=32, font=FONT_MAIN
        )
        combo.current(1)      # default to Twin
        combo.pack(side="left", padx=(4, 12))
        combo.bind("<<ComboboxSelected>>", lambda _: self._on_model_change())

        # right-side buttons
        self.build_btn = self._btn(top, "⚙  Build Model", self._on_build, side="right")
        self._btn(top, "🗑  Clear Chat", self._clear_chat, side="right")

        # ── chat area ──
        chat_frame = tk.Frame(self, bg=BG)
        chat_frame.pack(fill="both", expand=True, padx=10, pady=(8, 0))

        self.chat = scrolledtext.ScrolledText(
            chat_frame, bg=PANEL, fg=BOT_CLR,
            font=FONT_CODE, wrap="word",
            relief="flat", bd=0, padx=10, pady=10,
            state="disabled", cursor="arrow"
        )
        self.chat.pack(fill="both", expand=True)

        # configure text tags
        self.chat.tag_configure("user_label", foreground=USER_CLR, font=FONT_BOLD)
        self.chat.tag_configure("user_text",  foreground=USER_CLR, font=FONT_MAIN)
        self.chat.tag_configure("bot_label",  foreground=ACCENT,   font=FONT_BOLD)
        self.chat.tag_configure("bot_text",   foreground=BOT_CLR,  font=FONT_MAIN)
        self.chat.tag_configure("sys_text",   foreground=DIM,      font=("Segoe UI", 10, "italic"))

        # ── input area ──
        inp_frame = tk.Frame(self, bg=BG, padx=10, pady=8)
        inp_frame.pack(fill="x")

        self.input_var = tk.StringVar()
        self.entry = tk.Entry(
            inp_frame, textvariable=self.input_var,
            bg="#2e2e2e", fg=BOT_CLR, insertbackground=ACCENT,
            font=FONT_MAIN, relief="flat", bd=4
        )
        self.entry.pack(side="left", fill="x", expand=True, ipady=6)
        self.entry.bind("<Return>",       lambda _: self._send())
        self.entry.bind("<Shift-Return>", lambda _: None)
        self.entry.focus()

        self.send_btn = self._btn(inp_frame, "Send  ➤", self._send, side="right")

        # ── status bar ──
        self.status_var = tk.StringVar(value="Ready")
        tk.Label(self, textvariable=self.status_var,
                 bg=BG, fg=DIM, font=("Segoe UI", 9),
                 anchor="w", padx=12).pack(fill="x", pady=(0, 4))

    def _btn(self, parent, text, cmd, side="left"):
        b = tk.Button(
            parent, text=text, command=cmd,
            bg=BTN_BG, fg=ACCENT, activebackground=BTN_HVR,
            activeforeground=ACCENT, font=("Segoe UI", 10),
            relief="flat", bd=0, padx=10, pady=4, cursor="hand2"
        )
        b.pack(side=side, padx=4)
        return b

    # ── helpers ─────────────────────────────────────────────────────────────

    def _selected_model_id(self) -> str:
        label = self.model_var.get()
        return MODELS.get(label, "my-twin")

    def _append(self, text: str, tag: str):
        self.chat.configure(state="normal")
        self.chat.insert("end", text, tag)
        self.chat.see("end")
        self.chat.configure(state="disabled")

    def _set_status(self, msg: str):
        self.status_var.set(msg)

    def _lock(self, locked: bool):
        state = "disabled" if locked else "normal"
        self.send_btn.configure(state=state)
        self.entry.configure(state=state)
        self.is_generating = locked

    def _on_model_change(self):
        self._clear_chat()

    def _clear_chat(self):
        self.messages.clear()
        self.chat.configure(state="normal")
        self.chat.delete("1.0", "end")
        self.chat.configure(state="disabled")
        model_id = self._selected_model_id()
        self._append(
            f"Model: {model_id}\n"
            f"Type a message below and press Send or Enter.\n\n",
            "sys_text"
        )
        self._set_status("Ready")

    # ── model building ───────────────────────────────────────────────────────

    def _on_build(self):
        model_id = self._selected_model_id()
        if not messagebox.askyesno(
            "Build Model",
            f"This will run:\n\n  ollama create {model_id}\n\n"
            f"using the corresponding Modelfile.\n\nContinue?"
        ):
            return

        self._lock(True)
        self.build_btn.configure(state="disabled")
        self._append(f"\n── Building {model_id} ──\n", "sys_text")
        self._set_status(f"Building {model_id}…")

        def on_line(line):
            self.after(0, lambda: self._append(line + "\n", "sys_text"))

        def on_done():
            def _():
                self._append(f"\n✓ {model_id} built successfully.\n\n", "sys_text")
                self._set_status("Ready")
                self._lock(False)
                self.build_btn.configure(state="normal")
            self.after(0, _)

        def on_error(msg):
            def _():
                self._append(f"\n✗ Error: {msg}\n\n", "sys_text")
                self._set_status("Error — see chat")
                self._lock(False)
                self.build_btn.configure(state="normal")
            self.after(0, _)

        build_model(model_id, on_line, on_done, on_error)

    # ── sending / receiving ──────────────────────────────────────────────────

    def _send(self):
        if self.is_generating:
            return
        text = self.input_var.get().strip()
        if not text:
            return

        self.input_var.set("")
        model_id = self._selected_model_id()

        # show user bubble
        self._append("\nYou:\n", "user_label")
        self._append(text + "\n", "user_text")

        self.messages.append({"role": "user", "content": text})
        self._lock(True)
        self._set_status("Andrew is thinking…")

        # show bot label immediately, then stream tokens in-place
        self._append("\nAndrew:\n", "bot_label")

        def on_token(tok):
            self.after(0, lambda: self._append(tok, "bot_text"))

        full_response = []

        def on_done():
            reply = "".join(full_response)
            self.messages.append({"role": "assistant", "content": reply})

            def _():
                self._append("\n", "bot_text")
                self._set_status("Ready")
                self._lock(False)
                self.entry.focus()
            self.after(0, _)

        def on_error(msg):
            def _():
                self._append(f"\n[Error: {msg}]\n", "sys_text")
                self._set_status("Error")
                self._lock(False)
            self.after(0, _)

        # wrap callbacks so we also accumulate tokens for history
        def _on_token(tok):
            full_response.append(tok)
            on_token(tok)

        chat_stream(model_id, self.messages, _on_token, on_done, on_error)

    # ── startup check ────────────────────────────────────────────────────────

    def _check_models_async(self):
        def run():
            missing = []
            for label, mid in MODELS.items():
                if not model_exists(mid):
                    missing.append(mid)
            if missing:
                self.after(0, lambda: self._warn_missing(missing))
            else:
                self.after(0, lambda: self._clear_chat())

        self._clear_chat()
        self._set_status("Checking Ollama models…")
        threading.Thread(target=run, daemon=True).start()

    def _warn_missing(self, missing: list):
        self._clear_chat()
        names = "\n  ".join(missing)
        self._append(
            f"⚠  The following models have not been built yet:\n\n"
            f"  {names}\n\n"
            f"Select a model from the dropdown and click ⚙ Build Model to create it.\n\n",
            "sys_text"
        )
        self._set_status("Some models need to be built first")


# ── entry point ─────────────────────────────────────────────────────────────

if __name__ == "__main__":
    app = App()
    app.mainloop()
