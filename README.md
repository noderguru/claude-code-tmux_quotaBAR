# claude-code-tmux_quotaBAR

Display your **official Claude Code usage quota** right in a green tmux status bar:

```
Claude Code quotas  5h 42% ▰▰▱▱▱ ⟳ 14:35 │ 7d 18% ▰▱▱▱▱ ⟳ 08.06 12:00  11:35 11-Jun
```

- **5h** — 5-hour rolling window usage % + reset time
- **7d** — 7-day limit usage % + reset date/time
- **▰▱ blocks** — battery-style visual gauge (5 blocks, each = 20%)
- **Colors** — green (<50%), dark blue (50–74%), red (75–89%), red bg (≥90%)

<img width="1886" height="256" alt="image" src="https://github.com/user-attachments/assets/ba8d823e-deac-46aa-8a5e-e5f75f034d2e" />


## How it works

The script calls the same API that Claude Code itself uses — `GET https://api.anthropic.com/api/oauth/usage` (read‑only, **does NOT consume quota**). It uses your OAuth token from `~/.claude/.credentials.json` — the exact same token that powers `/usage` inside the CLI.

- **Cached in memory** — actual HTTP call once every 120 seconds
- **Background fetch** — tmux never freezes waiting for network
- **Single‑flight** — concurrent redraws don't spawn duplicate requests
- **Attached‑only** — when all clients are detached (`Ctrl+B D`), zero network calls

## Quick install

```bash
git clone https://github.com/neoneye/claude-code-tmux_quotaBAR.git
cd claude-code-tmux_quotaBAR
chmod +x setup.sh
./setup.sh
```

**setup.sh** checks:
- ✅ bash, curl, python3, tmux — installed
- ✅ `~/.claude/.credentials.json` — exists and readable
- Copies `quota-tmux.sh` → `~/.claude/quota-tmux.sh`
- Adds the config block to `~/.tmux.conf`
- Applies settings to your running tmux server

## Manual install

If you prefer not to run setup.sh:

```bash
cp quota-tmux.sh ~/.claude/quota-tmux.sh
chmod +x ~/.claude/quota-tmux.sh
```

Then add to `~/.tmux.conf`:

```
set -g status-style bg=green,fg=black
set -g status-interval 30
set -g status-right-length 140
set -g status-right "#($HOME/.claude/quota-tmux.sh) #[fg=black]%H:%M %d-%b"
```

Then reload: `tmux source-file ~/.tmux.conf`

## Requirements

| Component | Why |
|-----------|-----|
| `bash` 4+ | script shell |
| `curl` | HTTP request to Anthropic API |
| `python3` | JSON parsing and credentials handling |
| `tmux` | status bar rendering |
| `claude` (Claude Code) | must be logged in (`claude login`) — token lives in `~/.claude/.credentials.json` |

## Timezone

Reset times are displayed in **your system's local timezone** by default. To override:

```bash
export TZ="America/New_York"   # in ~/.bashrc before starting tmux
```

## Visual reference

| Usage | Color | Scale |
|-------|-------|-------|
| 0–49% | black (calm) | `▰▰▱▱▱` |
| 50–74% | dark blue bold | `▰▰▰▱▱` |
| 75–89% | red bold | `▰▰▰▰▱` |
| 90–100% | red bg, white text | `▰▰▰▰▰` |

## FAQ

### Is this safe?

The script uses **your personal OAuth token** from `~/.claude/.credentials.json` and only calls a read‑only endpoint. It sends no data anywhere except `api.anthropic.com`. The call does **not** consume your quota — `/api/oauth/usage` does not count as model usage.

### Does this violate Anthropic's ToS?

The script impersonates Claude Code's own behavior (same headers, same endpoint, same token). The endpoint is not officially documented for external use, but it is used read‑only and does not add infrastructure load. Risk to your account is minimal.

### Why a green bar?

High contrast, instantly visible, doesn't blend into a dark terminal background. You can change the color in `~/.tmux.conf` (find `status-style bg=green`).

### I'm on Pro. Will it show the Opus quota?

No. `seven_day_opus` is only available on the Max plan. On Pro that segment is simply not displayed.

### Can I use this without a green background?

Sure — edit the `status-style bg=…` line in `~/.tmux.conf`. Dark backgrounds work fine; the script's colors (black, dark blue, red) are tuned for contrast against green and dark themes alike.

## License

MIT — do whatever you want.
