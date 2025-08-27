#!/usr/bin/env python3
#
# Author  : Anthony Woodward
# Date    : 26 August 2025
# Updated : 26 August 2025
# Purpose : Ham-Scripts user configuration utility

"""
Ham‑Scripts User Configuration App (GUI + CLI)
- Stores canonical station info at: ~/.config/ham-scripts/config.yaml
- Applies Callsign and Grid to WSJT‑X, JS8Call, and JS8Spotter when present
- Backups original app configs with a timestamped .bak suffix
1.
2.
3.
4.
5.
4
- Non-interactive flags: --apply, --callsign, --grid, --operator, --qth, --rig
"""

import os
import sys
import json
import time
import glob
import argparse
import configparser
from pathlib import Path
from typing import Dict, Tuple


# Optional GUI (Tk) and YAML
try:
    import tkinter as tk
    from tkinter import ttk, messagebox
except Exception:
    tk = None

try:
    import yaml
except Exception:
    yaml = None
    
CONFIG_DIR = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
CANON_DIR = CONFIG_DIR / "ham-scripts"
CANON_FILE = CANON_DIR / "config.yaml"

# ---------------- Utilities ----------------

def ensure_dir(p: Path) -> None:
    p.mkdir(parents=True, exist_ok=True)


def ts_suffix() -> str:
    return time.strftime("%Y%m%d-%H%M%S")


def backup(path: Path) -> None:
    if path.exists():
        b = path.with_suffix(path.suffix + "." + ts_suffix() + ".bak")
        b.write_bytes(path.read_bytes())


def load_canon() -> Dict:
    if not CANON_FILE.exists():
        return {}
    try:

        if yaml is not None:
            data = yaml.safe_load(CANON_FILE.read_text())
            return data or {}
    except Exception:
        pass
    try:
        return json.loads(CANON_FILE.read_text())
    except Exception:
        return {}
    
    
def save_canon(d: Dict) -> None:
    ensure_dir(CANON_DIR)
    backup(CANON_FILE)
    if yaml is not None:
        CANON_FILE.write_text(yaml.safe_dump(d, sort_keys=False))
    else:
        CANON_FILE.write_text(json.dumps(d, indent=2))

# ---------------- App updaters ----------------

def update_wsjt_x(cfg: Dict) -> Tuple[bool, str]:
    candidates = [
        CONFIG_DIR / "WSJT-X.ini",
        CONFIG_DIR / "WSJT-X" / "WSJT-X.ini",
    ]
    changed = False
    for path in candidates:
        if not path.exists():
            continue
        backup(path)
        cp = configparser.ConfigParser(interpolation=None)
        cp.optionxform = str
        try:
            cp.read(path)
            if not cp.has_section("Configuration"):
                cp.add_section("Configuration")
            cp.set("Configuration", "MyCall", cfg.get("callsign", ""))
            cp.set("Configuration", "MyGrid", cfg.get("grid", ""))
            with path.open("w") as f:
                cp.write(f)
            changed = True
        except Exception:
            pass
    return changed, ("WSJT‑X updated" if changed else "WSJT‑X not found; skipped")
    
    
def update_js8call(cfg: Dict) -> Tuple[bool, str]:
    candidates = [
        CONFIG_DIR / "JS8Call.ini",
        CONFIG_DIR / "JS8Call" / "JS8Call.ini",
    ]
    changed = False
    for path in candidates:
        if not path.exists():
            continue
        backup(path)
        cp = configparser.ConfigParser(interpolation=None)
        cp.optionxform = str
        try:
            cp.read(path)
            if not cp.has_section("Configuration"):
                cp.add_section("Configuration")
            cp.set("Configuration", "MyCall", cfg.get("callsign", ""))
            cp.set("Configuration", "MyGrid", cfg.get("grid", ""))
            with path.open("w") as f:
                cp.write(f)
            changed = True
        except Exception:
            pass
    return changed, ("JS8Call updated" if changed else "JS8Call not found; skipped")
    
    
def update_js8spotter(cfg: Dict) -> Tuple[bool, str]:
    root = CONFIG_DIR / "JS8Spotter"
    if not root.exists():
        return False, "JS8Spotter not found; skipped"
    changed_any = False
    for p in root.glob("*.json"):
        try:
            data = json.loads(p.read_text())
        except Exception:
            continue
        before = json.dumps(data, sort_keys=True)
        for k in ["myCall", "callsign", "MyCall", "stationCall", "call"]:
            if k in data or "callsign" in data:
                data[k] = cfg.get("callsign", data.get(k, ""))
        for k in ["myGrid", "grid", "MyGrid", "locator", "maidenhead"]:
            if k in data or "grid" in data:
                data[k] = cfg.get("grid", data.get(k, ""))
        after = json.dumps(data, sort_keys=True)
        if after != before:
            backup(p)
            p.write_text(json.dumps(data, indent=2))
            changed_any = True
    return changed_any, ("JS8Spotter updated" if changed_any else "JS8Spotter not changed (no matching JSON)")

TARGETS = [
    ("WSJT‑X", update_wsjt_x),
    ("JS8Call", update_js8call),
    ("JS8Spotter", update_js8spotter),
]

# ---------------- Validation & apply ----------------

def _is_valid_callsign(cs: str) -> bool:
    cs2 = (cs or "").strip().upper()
    return len(cs2) >= 3 and all(ch.isalnum() for ch in cs2)


def _is_valid_grid(g: str) -> bool:
    if not g:
        return True
    s = g.strip().upper()
    if len(s) not in (4, 6, 8):
        return False
    try:
        return (
            s[0] >= "A" and s[0] <= "R" and
            s[1] >= "A" and s[1] <= "R" and
            s[2].isdigit() and s[3].isdigit()
        )
    except Exception:
        return False


def save_and_apply(payload: Dict) -> str:
    cs = (payload.get("callsign") or "").strip().upper()
    grid = (payload.get("grid") or "").strip().upper()
    operator = (payload.get("operator") or "").strip()
    qth = (payload.get("qth") or "").strip()
    rig = (payload.get("rig") or "").strip()

    if not _is_valid_callsign(cs):
        raise ValueError("Invalid callsign format")
    if not _is_valid_grid(grid):
        raise ValueError("Invalid grid square format")

    canon = {"callsign": cs, "grid": grid, "operator": operator, "qth": qth, "rig": rig}
    save_canon(canon)

    results = []
    for name, fn in TARGETS:
        changed, msg = fn(canon)
        results.append("- " + name + ": " + msg)

    return "Saved to " + str(CANON_FILE) + os.linesep + os.linesep.join(results)

# ---------------- CLI / GUI ----------------

def run_cli_interactive() -> Dict:
    print("Ham-Scripts User Configuration (CLI)")
    callsign = input("Callsign (e.g., KL5HZ): ").strip()
    grid = input("Grid square (e.g., BP64): ").strip()
    operator = input("Operator name (optional): ").strip()
    qth = input("QTH/City (optional): ").strip()
    rig = input("Rig/Notes (optional): ").strip()
    return {"callsign": callsign, "grid": grid, "operator": operator, "qth": qth, "rig": rig}


def run_gui() -> None:
    if tk is None:
        payload = run_cli_interactive()
        try:
            summary = save_and_apply(payload)
        except Exception as e:
            print("Error:", e)
            sys.exit(2)
        print(summary)
        return

    root = tk.Tk()
    root.title("Ham‑Scripts: User Configuration")

    frm = ttk.Frame(root, padding=16)
    frm.grid()

    state = {
        "callsign": tk.StringVar(value=""),
        "grid": tk.StringVar(value=""),
        "operator": tk.StringVar(value=""),
        "qth": tk.StringVar(value=""),
        "rig": tk.StringVar(value=""),
    }

    # preload existing
    existing = load_canon()
    for k, v in existing.items():
        if k in state and isinstance(v, str):
            state[k].set(v)

    def row(lbl, var, hint=""):
        r = ttk.Frame(frm)
        r.grid(sticky="ew", pady=6)
        ttk.Label(r, text=lbl, width=18).grid(row=0, column=0, sticky="w")
        entry = ttk.Entry(r, textvariable=var, width=32)
        entry.grid(row=0, column=1, sticky="w")
        if hint:
            ttk.Label(r, text=hint, foreground="#666").grid(row=1, column=1, sticky="w")
        return entry

    row("Callsign *", state["callsign"], "Example: KL5HZ")
    row("Grid square", state["grid"], "Maidenhead e.g. BP64")
    row("Operator", state["operator"], "Optional")
    row("QTH / City", state["qth"], "Optional")
    row("Rig / Notes", state["rig"], "Optional")

    output = tk.Text(frm, height=8, width=60)
    output.grid(sticky="ew", pady=(8, 0))

    def on_save():
        payload = {k: v.get() for k, v in state.items()}
        try:
            summary = save_and_apply(payload)
        except Exception as e:
            messagebox.showerror("Validation error", str(e))
            return
        output.delete("1.0", tk.END)
        output.insert(tk.END, summary)
        messagebox.showinfo("Saved", "Configuration saved and applied.")

    btns = ttk.Frame(frm)
    btns.grid(sticky="e", pady=10)
    ttk.Button(btns, text="Save & Apply", command=on_save).grid(row=0, column=1, padx=6)
    ttk.Button(btns, text="Quit", command=root.destroy).grid(row=0, column=2)

    root.mainloop()

# ---------------- Args / entry ----------------

def parse_args(argv=None):
    p = argparse.ArgumentParser(description="Ham-Scripts user configuration")
    p.add_argument("--apply", action="store_true", help="Apply existing canonical config to all apps")
    p.add_argument("--callsign", help="Set callsign non-interactively and apply")
    p.add_argument("--grid", help="Set grid non-interactively and apply")
    p.add_argument("--operator", help="Optional operator name")
    p.add_argument("--qth", help="Optional QTH/city")
    p.add_argument("--rig", help="Optional rig/notes")
    return p.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)

    # Non-interactive set via flags
    if any([args.callsign, args.grid, args.operator, args.qth, args.rig]):
        payload = {
            "callsign": args.callsign or "",
            "grid": args.grid or "",
            "operator": args.operator or "",
            "qth": args.qth or "",
            "rig": args.rig or "",
        }
        if not payload["callsign"]:
            print("Error: --callsign is required when using non-interactive flags", file=sys.stderr)
            return 2
        try:
            print(save_and_apply(payload))
        except Exception as e:
            print("Error:", e, file=sys.stderr)
            return 2
        return 0

    # Apply-only
    if args.apply:
        existing = load_canon()
        if existing.get("callsign"):
            try:
                print(save_and_apply(existing))
                return 0
            except Exception as e:
                print("Error:", e, file=sys.stderr)
                return 2
        else:
            print("No existing canonical config. Launching interactive UI...")

    # GUI vs CLI
    if os.environ.get("HAM_SCRIPTS_HEADLESS") == "1" or (sys.platform != "win32" and not os.environ.get("DISPLAY")):
        payload = run_cli_interactive()
        try:
            print(save_and_apply(payload))
        except Exception as e:
            print("Error:", e, file=sys.stderr)
            return 2
        return 0
    else:
        run_gui()
        return 0

if __name__ == "__main__":
    raise SystemExit(main())

