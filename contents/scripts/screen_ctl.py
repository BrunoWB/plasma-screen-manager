#!/usr/bin/env python3
import sys
import os
import re
import shutil
import json
import glob
import subprocess
import signal

CONFIG_DIR = os.path.expanduser("~/.config/plasma-screen-manager")
CACHE_DIR = os.path.expanduser("~/.cache/plasma-screen-manager")
PID_FILE = os.path.join(CACHE_DIR, "inhibit.pid")
ALIASES_FILE = os.path.join(CONFIG_DIR, "aliases.json")

PNP_IDS_PATHS = [
    "/usr/share/hwdata/pnp.ids",
    "/run/host/usr/share/hwdata/pnp.ids",
    "/usr/share/misc/pnp.ids",
    "/run/host/usr/share/misc/pnp.ids",
    "/var/lib/misc/pnp.ids",
    "/run/host/var/lib/misc/pnp.ids",
    "/usr/local/share/hwdata/pnp.ids",
    "/run/host/usr/local/share/hwdata/pnp.ids",
]

GENERIC_WORDS = {
    "inc", "incorporated", "ltd", "limited", "corp", "corporation",
    "co", "company", "gmbh", "sa", "ag", "bv", "llc", "plc",
    "technologies", "technology", "tech", "electronics", "electronic",
    "electric", "computer", "computers", "group", "international",
    "systems", "consumer", "display", "displays",
}

_PNP_DB_CACHE = None

def get_pnp_db():
    global _PNP_DB_CACHE
    if _PNP_DB_CACHE is not None:
        return _PNP_DB_CACHE

    _PNP_DB_CACHE = {}
    for path in PNP_IDS_PATHS:
        if os.path.exists(path):
            try:
                with open(path, "r", encoding="utf-8", errors="ignore") as f:
                    for line in f:
                        line = line.strip()
                        if not line or line.startswith("#"):
                            continue
                        parts = line.split("\t", 1)
                        if len(parts) == 2:
                            code, name = parts[0].strip(), parts[1].strip()
                        else:
                            parts = line.split(None, 1)
                            if len(parts) == 2:
                                code, name = parts[0].strip(), parts[1].strip()
                            else:
                                continue
                        if code and name and code.upper() not in _PNP_DB_CACHE:
                            _PNP_DB_CACHE[code.upper()] = name
                if _PNP_DB_CACHE:
                    break
            except Exception:
                continue

    if not _PNP_DB_CACHE and os.path.exists("/.flatpak-info") and shutil.which("flatpak-spawn"):
        for host_path in ["/usr/share/hwdata/pnp.ids", "/usr/share/misc/pnp.ids", "/var/lib/misc/pnp.ids"]:
            try:
                res = subprocess.run(
                    ["flatpak-spawn", "--host", "cat", host_path],
                    capture_output=True,
                    text=True,
                    errors="ignore"
                )
                if res.returncode == 0 and res.stdout:
                    for line in res.stdout.splitlines():
                        line = line.strip()
                        if not line or line.startswith("#"):
                            continue
                        parts = line.split("\t", 1) if "\t" in line else line.split(None, 1)
                        if len(parts) == 2:
                            code, name = parts[0].strip().upper(), parts[1].strip()
                            if code and code not in _PNP_DB_CACHE:
                                _PNP_DB_CACHE[code] = name
                    if _PNP_DB_CACHE:
                        break
            except Exception:
                continue

    return _PNP_DB_CACHE

def get_vendor_name(pnp_code: str) -> str:
    if not pnp_code:
        return ""
    db = get_pnp_db()
    return db.get(pnp_code.upper().strip(), "")

def clean_device_name(raw_model: str, vendor: str, pnp: str = "") -> str:
    if not raw_model:
        return ""

    vendor_ident_words = set()
    all_vendor_words = set()

    if vendor:
        words = [w.lower() for w in re.findall(r"[A-Za-z0-9]+", vendor)]
        filtered = [w for w in words if w not in GENERIC_WORDS]
        if not filtered:
            filtered = words
        for w in filtered:
            vendor_ident_words.add(w)
            if w.endswith("tek") and len(w) > 5:
                vendor_ident_words.add(w[:-3])
        if len(filtered) >= 2:
            initials = "".join(w[0] for w in filtered)
            if len(initials) >= 2:
                vendor_ident_words.add(initials)
        for w in words:
            all_vendor_words.add(w)

    if pnp:
        vendor_ident_words.add(pnp.lower())
        all_vendor_words.add(pnp.lower())

    s = raw_model.strip()
    stripped_any = False

    while True:
        m = re.match(r"^([A-Za-z0-9]+)([\s\-_:/]*)(.*)$", s)
        if not m:
            break
        word, sep, rest = m.group(1), m.group(2), m.group(3)
        wl = word.lower()

        if not stripped_any:
            if wl in vendor_ident_words:
                stripped_any = True
                if rest.strip():
                    s = rest.strip()
                    continue
                else:
                    return ""
            break
        else:
            if wl in all_vendor_words or wl in GENERIC_WORDS:
                if rest.strip():
                    s = rest.strip()
                    continue
                else:
                    return ""
            break

    return s

def _resolve_cmd(cmd_list):
    cmd = list(cmd_list)
    if not shutil.which(cmd[0]) and os.path.exists("/.flatpak-info") and shutil.which("flatpak-spawn"):
        return ["flatpak-spawn", "--host"] + cmd
    return cmd

def parse_edid(data):
    if len(data) < 128:
        return "", ""
    b1, b2 = data[8], data[9]
    c1 = chr(((b1 >> 2) & 0x1F) + ord("A") - 1)
    c2 = chr((((b1 & 0x3) << 3) | ((b2 >> 5) & 0x7)) + ord("A") - 1)
    c3 = chr((b2 & 0x1F) + ord("A") - 1)
    pnp = f"{c1}{c2}{c3}".upper()
    
    model_name = ""
    for offset in [54, 72, 90, 108]:
        block = data[offset:offset+18]
        if len(block) == 18 and block[0:3] == b"\x00\x00\x00":
            tag = block[3]
            if tag == 0xFC:
                txt = block[5:].split(b"\x0A")[0].split(b"\x00")[0].decode("latin1", errors="ignore").strip()
                if txt:
                    model_name = txt
                    break
            elif tag == 0xFE and not model_name:
                txt = block[5:].split(b"\x0A")[0].split(b"\x00")[0].decode("latin1", errors="ignore").strip()
                if txt:
                    model_name = txt
    return pnp, model_name

def get_edid_map():
    edids = {}
    for p in glob.glob("/sys/class/drm/*/edid"):
        try:
            with open(p, "rb") as f:
                data = f.read()
            if data:
                conn = p.split("/")[-2].split("-", 1)[-1]
                pnp, model = parse_edid(data)
                edids[conn] = {"pnp": pnp, "model": model}
        except Exception:
            pass
    return edids

def get_aliases():
    if os.path.exists(ALIASES_FILE):
        try:
            with open(ALIASES_FILE, "r") as f:
                return json.load(f)
        except Exception:
            pass
    return {}

def set_alias(connector: str, alias: str):
    os.makedirs(CONFIG_DIR, exist_ok=True)
    aliases = get_aliases()
    alias = alias.strip()
    if alias:
        aliases[connector] = alias
    else:
        aliases.pop(connector, None)
    with open(ALIASES_FILE, "w") as f:
        json.dump(aliases, f, indent=2)

def clear_alias(connector: str):
    if os.path.exists(ALIASES_FILE):
        aliases = get_aliases()
        if connector in aliases:
            aliases.pop(connector, None)
            with open(ALIASES_FILE, "w") as f:
                json.dump(aliases, f, indent=2)

def is_presentation_active():
    if os.path.exists(PID_FILE):
        try:
            with open(PID_FILE, "r") as f:
                pid = int(f.read().strip())
            os.kill(pid, 0)
            return True
        except Exception:
            if os.path.exists(PID_FILE):
                try:
                    os.remove(PID_FILE)
                except Exception:
                    pass
    return False

def set_presentation(enable: bool):
    os.makedirs(CACHE_DIR, exist_ok=True)
    if enable:
        if not is_presentation_active():
            proc = subprocess.Popen(
                _resolve_cmd([
                    "systemd-inhibit",
                    "--what=idle:sleep",
                    "--who=PlasmaScreenManager",
                    "--why=Presentation Mode - Keep Screen Awake",
                    "sleep", "infinity"
                ]),
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True
            )
            with open(PID_FILE, "w") as f:
                f.write(str(proc.pid))
            return True
        return True
    else:
        if is_presentation_active():
            try:
                with open(PID_FILE, "r") as f:
                    pid = int(f.read().strip())
                os.kill(pid, signal.SIGTERM)
            except Exception:
                pass
            if os.path.exists(PID_FILE):
                try:
                    os.remove(PID_FILE)
                except Exception:
                    pass
        return False

def get_status():
    try:
        ks_out = subprocess.check_output(_resolve_cmd(["kscreen-doctor", "-j"]), stderr=subprocess.DEVNULL)
        ks_data = json.loads(ks_out)
    except Exception as e:
        return {"error": f"Failed to query kscreen-doctor: {str(e)}", "screens": []}

    edids = get_edid_map()
    aliases = get_aliases()
    outputs = ks_data.get("outputs", [])
    screens = []

    for out in outputs:
        if not out.get("connected", False):
            continue

        conn = out.get("name", "")
        edid = edids.get(conn, {})
        pnp = edid.get("pnp", "")
        raw_model = edid.get("model", "")
        vendor = get_vendor_name(pnp)

        device_name = clean_device_name(raw_model, vendor, pnp)
        if device_name:
            default_name = device_name
        elif vendor:
            default_name = vendor
        else:
            default_name = f"Display {conn}"

        is_custom = bool(conn in aliases and aliases[conn].strip())
        display_name = aliases[conn].strip() if is_custom else default_name

        curr_id = str(out.get("currentModeId"))
        mode_str = ""
        for m in out.get("modes", []):
            if str(m.get("id")) == curr_id:
                w = m.get("size", {}).get("width")
                h = m.get("size", {}).get("height")
                rate = round(m.get("refreshRate", 0))
                mode_str = f"{w}x{h}@{rate}Hz"
                break

        pos = out.get("pos", {"x": 0, "y": 0})
        priority = out.get("priority", 99)
        enabled = out.get("enabled", False)

        screens.append({
            "id": out.get("id"),
            "connector": conn,
            "name": display_name,
            "defaultName": default_name,
            "isCustomName": is_custom,
            "rawModel": raw_model,
            "vendor": vendor,
            "enabled": enabled,
            "isPrimary": (priority == 1),
            "priority": priority,
            "mode": mode_str,
            "x": pos.get("x", 0),
            "y": pos.get("y", 0)
        })

    screens.sort(key=lambda s: s["x"])

    return {
        "screens": screens,
        "presentationMode": is_presentation_active()
    }

def main():
    if len(sys.argv) < 2:
        cmd = "status"
    else:
        cmd = sys.argv[1]

    if cmd == "status":
        print(json.dumps(get_status()))
    elif cmd == "set-alias":
        if len(sys.argv) < 3:
            print(json.dumps({"success": False, "error": "Usage: set-alias <connector> [alias]"}))
            sys.exit(1)
        connector = sys.argv[2]
        alias = " ".join(sys.argv[3:]).strip() if len(sys.argv) > 3 else ""
        set_alias(connector, alias)
        print(json.dumps(get_status()))
    elif cmd == "clear-alias":
        if len(sys.argv) < 3:
            print(json.dumps({"success": False, "error": "Usage: clear-alias <connector>"}))
            sys.exit(1)
        connector = sys.argv[2]
        clear_alias(connector)
        print(json.dumps(get_status()))
    elif cmd == "set-primary":
        if len(sys.argv) < 3:
            print(json.dumps({"success": False, "error": "Missing connector name"}))
            sys.exit(1)
        connector = sys.argv[2]
        res = subprocess.run(_resolve_cmd(["kscreen-doctor", f"output.{connector}.priority.1"]), capture_output=True, text=True, check=False)
        status = get_status()
        if res.returncode != 0:
            status["error"] = res.stderr.strip() or f"kscreen-doctor failed with exit code {res.returncode}"
        print(json.dumps(status))
    elif cmd == "set-enabled":
        if len(sys.argv) < 4:
            print(json.dumps({"success": False, "error": "Usage: set-enabled <connector> <1|0>"}))
            sys.exit(1)
        connector = sys.argv[2]
        enable = sys.argv[3] in ("1", "true", "True")

        curr = get_status()
        screens = curr.get("screens", [])
        active_count = sum(1 for s in screens if s["enabled"])

        if not enable and active_count <= 1:
            target = next((s for s in screens if s["connector"] == connector), None)
            if target and target["enabled"]:
                print(json.dumps({
                    "success": False,
                    "error": "Safety guard: Cannot disable the only active screen."
                }))
                sys.exit(1)

        action = "enable" if enable else "disable"
        res = subprocess.run(_resolve_cmd(["kscreen-doctor", f"output.{connector}.{action}"]), capture_output=True, text=True, check=False)
        status = get_status()
        if res.returncode != 0:
            status["error"] = res.stderr.strip() or f"kscreen-doctor failed with exit code {res.returncode}"
        print(json.dumps(status))
    elif cmd == "toggle-presentation":
        active = is_presentation_active()
        new_state = set_presentation(not active)
        print(json.dumps({"presentationMode": new_state}))
    else:
        print(json.dumps({"error": f"Unknown command: {cmd}"}))
        sys.exit(1)

if __name__ == "__main__":
    main()
