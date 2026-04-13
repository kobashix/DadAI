"""
Talk to Dad
A dead-simple chat interface for Abbie, Bianca, and Carly.
No settings. No buttons to figure out. Just type and talk.
"""

import tkinter as tk
from tkinter import font as tkfont
import threading
import requests
import json
import subprocess
import time
import sys
import os

OLLAMA_BASE  = "http://localhost:11434"
MODEL_NAME   = "andrew-legacy"
MODELFILE    = os.path.join(os.path.dirname(os.path.abspath(__file__)), "Legacy.Modelfile")

BG          = "#f5f0ea"        # warm off-white
BUBBLE_DAD  = "#ffffff"        # dad bubbles: white
BUBBLE_YOU  = "#4a7c59"        # your bubbles: forest green
TEXT_DAD    = "#1a1a1a"
TEXT_YOU    = "#ffffff"
TEXT_DIM    = "#999999"
ACCENT      = "#4a7c59"
HEADER_BG   = "#2c2c2c"
HEADER_FG   = "#f5f0ea"
SEND_BG     = "#4a7c59"
SEND_FG     = "#ffffff"
INPUT_BG    = "#ffffff"


def ensure_ollama_running():
    """Start ollama serve if not already up."""
    try:
        requests.get(f"{OLLAMA_BASE}/api/tags", timeout=2)
        return True
    except Exception:
        pass
    try:
        subprocess.Popen(
            ["ollama", "serve"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
        )
        for _ in range(15):
            time.sleep(1)
            try:
                requests.get(f"{OLLAMA_BASE}/api/tags", timeout=2)
                return True
            except Exception:
                pass
    except FileNotFoundError:
        pass
    return False


def model_exists() -> bool:
    try:
        r = requests.get(f"{OLLAMA_BASE}/api/tags", timeout=5)
        return any(m["name"].split(":")[0] == MODEL_NAME for m in r.json().get("models", []))
    except Exception:
        return False


def build_model_blocking(on_line):
    """Build the model synchronously, calling on_line for each status line."""
    if not os.path.exists(MODELFILE):
        on_line("ERROR: Legacy.Modelfile not found next to this app.")
        return False
    cmd = ["ollama", "create", MODEL_NAME, "-f", MODELFILE]
    try:
        proc = subprocess.Popen(
            cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, bufsize=1,
            creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
        )
        for line in proc.stdout:
            on_line(line.rstrip())
        proc.wait()
        return proc.returncode == 0
    except Exception as e:
        on_line(f"Error building model: {e}")
        return False


class TalkToDad(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Talk to Dad")
        self.geometry("480x700")
        self.minsize(360, 500)
        self.configure(bg=BG)
        self.resizable(True, True)

        self.messages   = []
        self.generating = False

        self._build_ui()
        self._startup()

    # ── UI ───────────────────────────────────────────────────────────────────

    def _build_ui(self):
        # header
        hdr = tk.Frame(self, bg=HEADER_BG, pady=14)
        hdr.pack(fill="x")
        tk.Label(hdr, text="Dad", bg=HEADER_BG, fg=HEADER_FG,
                 font=("Segoe UI", 16, "bold")).pack()
        tk.Label(hdr, text="Andrew Ryan Pennington", bg=HEADER_BG, fg="#888888",
                 font=("Segoe UI", 9)).pack()

        # scrollable chat canvas
        self.canvas = tk.Canvas(self, bg=BG, bd=0, highlightthickness=0)
        self.scrollbar = tk.Scrollbar(self, orient="vertical", command=self.canvas.yview)
        self.canvas.configure(yscrollcommand=self.scrollbar.set)
        self.scrollbar.pack(side="right", fill="y")
        self.canvas.pack(fill="both", expand=True, padx=0, pady=0)

        # inner frame that holds all bubbles
        self.chat_frame = tk.Frame(self.canvas, bg=BG)
        self.canvas_window = self.canvas.create_window((0, 0), window=self.chat_frame, anchor="nw")

        self.chat_frame.bind("<Configure>", self._on_frame_resize)
        self.canvas.bind("<Configure>", self._on_canvas_resize)
        self.canvas.bind_all("<MouseWheel>", self._on_mousewheel)

        # input row
        inp_row = tk.Frame(self, bg="#e8e3dd", pady=8, padx=8)
        inp_row.pack(fill="x", side="bottom")

        self.entry = tk.Text(
            inp_row, height=3, bg=INPUT_BG, fg="#1a1a1a",
            font=("Segoe UI", 12), relief="flat", bd=0,
            wrap="word", padx=8, pady=6,
            insertbackground=ACCENT
        )
        self.entry.pack(side="left", fill="both", expand=True,
                        ipady=2, padx=(0, 8))
        self.entry.bind("<Return>",       self._on_enter)
        self.entry.bind("<Shift-Return>", lambda e: None)

        self.send_btn = tk.Button(
            inp_row, text="Send", command=self._send,
            bg=SEND_BG, fg=SEND_FG, activebackground="#3a6b49",
            activeforeground=SEND_FG, font=("Segoe UI", 12, "bold"),
            relief="flat", bd=0, padx=16, pady=10, cursor="hand2"
        )
        self.send_btn.pack(side="right", fill="y")

        # status label (shown during setup/loading)
        self.status_var = tk.StringVar(value="")
        self.status_lbl = tk.Label(
            self, textvariable=self.status_var,
            bg=BG, fg=TEXT_DIM, font=("Segoe UI", 10, "italic"),
            pady=4
        )
        # don't pack yet — shown only during startup

    def _on_frame_resize(self, event):
        self.canvas.configure(scrollregion=self.canvas.bbox("all"))

    def _on_canvas_resize(self, event):
        self.canvas.itemconfig(self.canvas_window, width=event.width)

    def _on_mousewheel(self, event):
        self.canvas.yview_scroll(-1 * (event.delta // 120), "units")

    def _scroll_bottom(self):
        self.canvas.update_idletasks()
        self.canvas.yview_moveto(1.0)

    # ── bubble rendering ─────────────────────────────────────────────────────

    def _add_bubble(self, text: str, sender: str) -> tk.Label:
        """Add a chat bubble. sender = 'dad' or 'you'. Returns the label."""
        is_dad  = sender == "dad"
        anchor  = "w" if is_dad else "e"
        bg      = BUBBLE_DAD if is_dad else BUBBLE_YOU
        fg      = TEXT_DAD   if is_dad else TEXT_YOU
        padx    = (12, 60) if is_dad else (60, 12)

        row = tk.Frame(self.chat_frame, bg=BG)
        row.pack(fill="x", pady=3, padx=padx, anchor=anchor)

        lbl = tk.Label(
            row, text=text, bg=bg, fg=fg,
            font=("Segoe UI", 12), wraplength=320,
            justify="left", anchor="w",
            padx=12, pady=8, relief="flat",
            bd=0
        )
        lbl.pack(anchor=anchor)
        self._round_bubble(lbl)
        self.update_idletasks()
        self._scroll_bottom()
        return lbl

    def _round_bubble(self, lbl):
        """Approximate rounded corners via a thin frame."""
        pass   # tkinter doesn't support border-radius natively; shape is fine as-is

    def _add_status_bubble(self, text: str):
        """Centered dim status line (not a chat bubble)."""
        row = tk.Frame(self.chat_frame, bg=BG)
        row.pack(fill="x", pady=2)
        tk.Label(row, text=text, bg=BG, fg=TEXT_DIM,
                 font=("Segoe UI", 9, "italic")).pack()
        self._scroll_bottom()

    # ── startup sequence ─────────────────────────────────────────────────────

    def _startup(self):
        """Check Ollama + model availability in background, show status."""
        self._set_input_enabled(False)
        self._add_status_bubble("Starting up…")

        def run():
            # 1. start ollama
            self.after(0, lambda: self._update_last_status("Connecting to Ollama…"))
            ok = ensure_ollama_running()
            if not ok:
                self.after(0, lambda: self._fatal(
                    "Ollama isn't installed or couldn't start.\n\n"
                    "Please run setup.bat from the Andrew-Twin folder on the drive."
                ))
                return

            # 2. check / build model
            if not model_exists():
                self.after(0, lambda: self._update_last_status(
                    "First-time setup: loading Dad's data… (this takes about a minute)"
                ))
                ok = build_model_blocking(
                    lambda line: self.after(0, lambda l=line: self._update_last_status(l))
                )
                if not ok:
                    self.after(0, lambda: self._fatal(
                        "Could not load Dad's data.\n\n"
                        "Make sure Legacy.Modelfile is in the same folder as this app,\n"
                        "then try again."
                    ))
                    return

            # 3. ready
            self.after(0, self._ready)

        threading.Thread(target=run, daemon=True).start()

    def _update_last_status(self, text: str):
        """Update the last status bubble text."""
        # find last status label and update it, or add a new one
        children = self.chat_frame.winfo_children()
        if children:
            last = children[-1]
            labels = last.winfo_children()
            if labels and labels[0].cget("font") and "italic" in str(labels[0].cget("font")):
                labels[0].configure(text=text)
                self._scroll_bottom()
                return
        self._add_status_bubble(text)

    def _ready(self):
        # remove setup status bubble
        for child in self.chat_frame.winfo_children():
            child.destroy()

        # opening message
        self._add_bubble(
            "Hey. I'm here. Ask me anything.",
            "dad"
        )
        self._set_input_enabled(True)
        self.entry.focus()

    def _fatal(self, msg: str):
        for child in self.chat_frame.winfo_children():
            child.destroy()
        self._add_status_bubble("Something went wrong:")
        self._add_bubble(msg, "dad")

    # ── sending / receiving ───────────────────────────────────────────────────

    def _on_enter(self, event):
        self._send()
        return "break"      # prevent newline in Text widget

    def _send(self):
        if self.generating:
            return
        text = self.entry.get("1.0", "end").strip()
        if not text:
            return

        self.entry.delete("1.0", "end")
        self._add_bubble(text, "you")
        self.messages.append({"role": "user", "content": text})

        self._set_input_enabled(False)
        self.generating = True

        # placeholder bubble we'll stream into
        placeholder = self._add_bubble("…", "dad")

        tokens = []

        def on_token(tok):
            tokens.append(tok)
            combined = "".join(tokens)
            self.after(0, lambda: placeholder.configure(text=combined))
            self.after(0, self._scroll_bottom)

        def on_done():
            reply = "".join(tokens)
            self.messages.append({"role": "assistant", "content": reply})
            self.after(0, lambda: self._set_input_enabled(True))
            self.after(0, lambda: setattr(self, "generating", False))
            self.after(0, lambda: self.entry.focus())

        def on_error(msg):
            self.after(0, lambda: placeholder.configure(
                text="I'm having trouble responding right now. Try again in a moment."
            ))
            self.after(0, lambda: self._set_input_enabled(True))
            self.after(0, lambda: setattr(self, "generating", False))

        self._stream_chat(on_token, on_done, on_error)

    def _stream_chat(self, on_token, on_done, on_error):
        def run():
            try:
                r = requests.post(
                    f"{OLLAMA_BASE}/api/chat",
                    json={"model": MODEL_NAME, "messages": self.messages, "stream": True},
                    stream=True, timeout=120
                )
                r.raise_for_status()
                for raw in r.iter_lines():
                    if not raw:
                        continue
                    data = json.loads(raw)
                    tok = data.get("message", {}).get("content", "")
                    if tok:
                        on_token(tok)
                    if data.get("done"):
                        break
                on_done()
            except Exception as e:
                on_error(str(e))

        threading.Thread(target=run, daemon=True).start()

    def _set_input_enabled(self, enabled: bool):
        state = "normal" if enabled else "disabled"
        self.entry.configure(state=state)
        self.send_btn.configure(
            state=state,
            bg=SEND_BG if enabled else "#aaaaaa"
        )


if __name__ == "__main__":
    app = TalkToDad()
    app.mainloop()
