#!/usr/bin/env python3
import sys
import os
import json
import glob
import subprocess
import signal

CONFIG_DIR = os.path.expanduser("~/.config/plasma-screen-manager")
CACHE_DIR = os.path.expanduser("~/.cache/plasma-screen-manager")
PID_FILE = os.path.join(CACHE_DIR, "inhibit.pid")
ALIASES_FILE = os.path.join(CONFIG_DIR, "aliases.json")

PNP_VENDORS = {
    "SAM": "Samsung", "SEC": "Epson", "DEL": "Dell", "LGX": "LG",
    "LGD": "LG", "GSM": "LG", "AUS": "ASUS", "ASU": "ASUS",
    "ACR": "Acer", "BNQ": "BenQ", "AOC": "AOC", "SNY": "Sony",
    "VSC": "ViewSonic", "HPQ": "HP", "HWP": "HP", "LEN": "Lenovo",
    "APP": "Apple", "MSI": "MSI", "PHL": "Philips", "GIG": "Gigabyte",
    "IVM": "Iiyama", "NEC": "NEC", "SHP": "Sharp", "TOS": "Toshiba",
    "BOE": "BOE", "INN": "InnoLux", "AUO": "AUO"
}

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
            if tag in (0xFC, 0xFE):
                txt = block[5:].split(b"\x0A")[0].decode("latin1", errors="ignore").strip()
                if txt and not model_name:
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
                [
                    "systemd-inhibit",
                    "--what=idle:sleep",
                    "--who=PlasmaScreenManager",
                    "--why=Presentation Mode - Keep Screen Awake",
                    "sleep", "infinity"
                ],
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
        ks_out = subprocess.check_output(["kscreen-doctor", "-j"], stderr=subprocess.DEVNULL)
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
        vendor = PNP_VENDORS.get(pnp, pnp)

        if conn in aliases and aliases[conn].strip():
            display_name = aliases[conn].strip()
        elif raw_model:
            if vendor and vendor.lower() not in raw_model.lower():
                display_name = f"{vendor} {raw_model}"
            else:
                display_name = raw_model
        elif vendor:
            display_name = f"{vendor} Display"
        else:
            display_name = f"Display {conn}"

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
    elif cmd == "set-primary":
        if len(sys.argv) < 3:
            print(json.dumps({"success": False, "error": "Missing connector name"}))
            sys.exit(1)
        connector = sys.argv[2]
        subprocess.run(["kscreen-doctor", f"output.{connector}.priority.1"], check=False)
        print(json.dumps(get_status()))
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
        subprocess.run(["kscreen-doctor", f"output.{connector}.{action}"], check=False)
        print(json.dumps(get_status()))
    elif cmd == "toggle-presentation":
        active = is_presentation_active()
        new_state = set_presentation(not active)
        print(json.dumps({"presentationMode": new_state}))
    else:
        print(json.dumps({"error": f"Unknown command: {cmd}"}))
        sys.exit(1)

if __name__ == "__main__":
    main()
