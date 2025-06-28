#!/usr/bin/env python3
import sys
import os

if len(sys.argv) < 3:
    print("Usage: python3 gen_port_script.py <port> <limit_mb> [interval]")
    sys.exit(1)

PORT = int(sys.argv[1])
LIMIT_MB = int(sys.argv[2])
INTERVAL = int(sys.argv[3]) if len(sys.argv) > 3 else 10

INSTALL_DIR = "/opt/port_limiter"
MONITOR_SCRIPT = f"{INSTALL_DIR}/monitor_{PORT}.py"
SERVICE_FILE = f"/etc/systemd/system/port-limit-{PORT}.service"
DATA_FILE = f"{INSTALL_DIR}/traffic_{PORT}.json"
LOG_FILE = f"/var/log/port_limit_{PORT}.log"

LIMIT_BYTES = LIMIT_MB * 1024 * 1024

# ایجاد جدول و زنجیره‌ها اگر نبودند
os.system("nft list table inet traffic || nft add table inet traffic")
os.system("nft list chain inet traffic input || nft add chain inet traffic input '{ type filter hook input priority 0; }'")
os.system("nft list chain inet traffic output || nft add chain inet traffic output '{ type filter hook output priority 0; }'")

# افزودن rule شمارشگر
os.system(f"nft add rule inet traffic input tcp dport {PORT} counter")
os.system(f"nft add rule inet traffic output tcp sport {PORT} counter")

# تولید اسکریپت مانیتور
with open(MONITOR_SCRIPT, "w") as f:
    f.write(f"""#!/usr/bin/env python3
import time, json, subprocess, os

PORT = {PORT}
LIMIT = {LIMIT_BYTES}
INTERVAL = {INTERVAL}
DATA_FILE = "{DATA_FILE}"
LOG_FILE = "{LOG_FILE}"

def get_bytes(direction):
    try:
        cmd = f"nft list chain inet traffic {{direction}}"
        result = subprocess.getoutput(cmd)
        for line in result.splitlines():
            if f"{{'dport' if direction == 'input' else 'sport'}} {{PORT}}" in line and "counter" in line:
                parts = line.split("bytes")
                if len(parts) > 1:
                    return int(parts[1].split()[0])
        log(f"No matching counter found in '{{direction}}' for port {{PORT}}")
    except Exception as e:
        log(f"Error reading bytes: {{e}}")
    return 0

def log(msg):
    try:
        with open(LOG_FILE, 'a') as f:
            f.write(f"[{{time.strftime('%F %T')}}] {{msg}}\\n")
    except Exception as e:
        print(f"Logging failed: {{e}}")

log("🟢 Started monitoring...")

if not os.path.exists(DATA_FILE):
    in_b = get_bytes("input")
    out_b = get_bytes("output")
    with open(DATA_FILE, "w") as f:
        json.dump({{"last_in": in_b, "last_out": out_b, "total_mb": 0}}, f)

while True:
    try:
        in_b = get_bytes("input")
        out_b = get_bytes("output")
        with open(DATA_FILE, "r") as f:
            data = json.load(f)
        delta = (in_b - data.get("last_in", 0)) + (out_b - data.get("last_out", 0))
        total = data.get("total_mb", 0) + delta / 1024 / 1024
        data = {{
            "last_in": in_b,
            "last_out": out_b,
            "total_mb": round(total, 2)
        }}
        with open(DATA_FILE, "w") as f:
            json.dump(data, f)
        log(f"Port {{PORT}} usage: {{data['total_mb']:.2f}} MB")
        if total >= LIMIT / 1024 / 1024:
            subprocess.call(f"nft delete rule inet traffic input tcp dport {{PORT}}", shell=True)
            subprocess.call(f"nft delete rule inet traffic output tcp sport {{PORT}}", shell=True)
            log(f"⛔ Port {{PORT}} blocked. Usage reached: {{total:.2f}} MB")
            break
    except Exception as e:
        log(f"Error: {{e}}")
    time.sleep(INTERVAL)
""")

os.chmod(MONITOR_SCRIPT, 0o755)

# ساخت فایل سرویس systemd
service_content = f"""[Unit]
Description=PortLimiterX monitor for port {PORT}
After=network.target

[Service]
ExecStart=/usr/bin/python3 {MONITOR_SCRIPT}
Restart=always

[Install]
WantedBy=multi-user.target
"""

with open(SERVICE_FILE, "w") as f:
    f.write(service_content)
