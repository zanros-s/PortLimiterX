# 🔥 PortLimiterX

Smart and flexible port traffic limiter using nftables + systemd on Linux.

## 🚀 Features

- Set bandwidth caps for individual TCP ports
- Uses `nftables` counters for accurate per-port traffic accounting
- Automatically blocks port when limit is reached
- CLI tool with colors, stats, and interactive menu
- Interval configuration for each port monitor

## 🛠 Installation

```bash
chmod +x install_portx.sh
sudo ./install_portx.sh
```

Then launch using:

```bash
portx
```

## 📂 File Structure

- `portlimiterx.sh` – Main CLI script
- `gen_port_script.py` – Generator for Python monitoring + systemd
- `install_portx.sh` – Auto installer

---

Made with ❤️ to keep your ports under control.
