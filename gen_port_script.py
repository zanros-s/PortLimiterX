#!/usr/bin/env python3
import sys, os

if len(sys.argv) < 3:
    print("Usage: gen_port_script.py <PORT> <LIMIT_MB> [INTERVAL_SECONDS]")
    sys.exit(1)

port = sys.argv[1]
limit_mb = int(sys.argv[2])
limit_bytes = limit_mb * 1024 * 1024
interval = int(sys.argv[3]) if len(sys.argv) > 3 else 10

install_dir = "/opt/port_limiter"
log_file = f"/var/log/port_limit_{port}.log"
data_file = f"{install_dir}/traffic_{port}.json"
script_path = f"{install_dir}/monitor_{port}.py"
service_path = f"/etc/systemd/system/port-limit-{port}.service"

os.makedirs(install_dir, exist_ok=True)
if not os.path.exists(log_file):
    open(log_file, "a").close()
    os.chmod(log_file, 0o666)

monitor_script = f"""#!/usr/bin/env python3
import time, json, subprocess, os

PORT = {port}
LIMIT = {limit_bytes}
INTERVAL = {interval}
DATA_FILE = "{data_file}"
LOG_FILE = "{log_file}"

def get_bytes(direction):
    try:
        cmd = f"nft list chain inet traffic {{direction}}"
        result = subprocess.getoutput(cmd)
        for line in result.splitlines():
            if f"{{'dport' if direction == 'input' else 'sport'}} {{PORT}}" in line and "counter" in line:
                parts = line.split("bytes")
                if len(parts) > 1:
                    return int(parts[1].split()[0])
    except Exception as e:
        log(f"Error reading bytes: {{e}}")
    return 0

def log(msg):
    try:
        with open(LOG_FILE, 'a') as f:
            f.write(f"[{{time.strftime('%F %T')}}] {{msg}}\n")
    except Exception as e:
        print(f"Logging failed: {{e}}")

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
"""

with open(script_path, "w") as f:
    f.write(monitor_script)

service_code = f"""[Unit]
Description=Traffic Monitor for Port {port}
After=network.target

[Service]
ExecStart=/usr/bin/python3 {script_path}
Restart=always

[Install]
WantedBy=multi-user.target
"""

with open(service_path, "w") as f:
    f.write(service_code)
