<p align="center">
  <img src="https://raw.githubusercontent.com/zanros-s/PortLimiterX/main/logo.png" width="200" alt="PortLimiterX Logo" />
</p>

# 🔥 PortLimiterX

Smart and flexible traffic limiter per TCP port using `nftables` + `systemd`.

---

## ✅ Features

- Set bandwidth limits per TCP port
- Uses `nftables` counters (no packet capture)
- Auto-blocks ports when limit reached
- Fully automated with CLI + systemd + log support
- Custom interval (e.g. check every 10s or 60s)
- Live usage stats in MB with logs

---

## ⚡️ Quick Install (1-line)

Run this command to install directly from GitHub:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/zanros-s/PortLimiterX/main/install.sh)
```

Then run the tool using:

```bash
portx
```

---

## 📂 File Overview

| File              | Purpose                         |
|-------------------|----------------------------------|
| `install.sh`      | One-line installer from GitHub  |
| `portlimiterx.sh` | Main CLI interface              |
| `gen_port_script.py` | Generator per-port monitor & systemd |
| `logo.txt`        | ASCII banner                    |
| `README.md`       | This documentation              |

---

## 📝 License

MIT — Feel free to use, modify, and share.

Made with ❤️ by [zanros-s](https://github.com/zanros-s)
