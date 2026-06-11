#!/usr/bin/env bash
# =============================================================================
# Claude Code quota → tmux status-right
# =============================================================================
# Displays official Claude Code usage quota right in your tmux status bar:
#   Claude Code quotas  5h 42% ▰▰▱▱▱ ⟳ 14:35 │ 7d 18% ▰▱▱▱▱ ⟳ 08.06 12:00
#
# Data source: the exact same endpoint Claude Code itself uses for /usage:
#   GET https://api.anthropic.com/api/oauth/usage   (read-only, does NOT consume quota)
#
# Results are cached and refreshed in the background → tmux never hangs.
# Token is read fresh from ~/.claude/.credentials.json (picks up auto-refresh).
# Colors and block-scale are tuned for a GREEN status bar (bg=green, fg=black).
# =============================================================================

CACHE="${TMPDIR:-/tmp}/claude_quota.txt"
LOCKDIR="${TMPDIR:-/tmp}/claude_quota.lock"
MAXAGE=120                            # seconds between actual network calls
CREDS="$HOME/.claude/.credentials.json"
UA="claude-cli/2.1.158 (external, cli)"  # impersonate Claude Code
# Use TZ env var if set; otherwise Python uses system local timezone

# ---------------------------------------------------------------------------
# fetch — calls the API and writes a formatted string to $CACHE
# ---------------------------------------------------------------------------
fetch() {
  # single-flight: if another instance is already fetching, bail out
  mkdir "$LOCKDIR" 2>/dev/null || return
  trap 'rmdir "$LOCKDIR" 2>/dev/null' EXIT

  local token json out
  token=$(python3 -c "import json;print(json.load(open('$CREDS'))['claudeAiOauth']['accessToken'])" 2>/dev/null)
  [ -z "$token" ] && return

  json=$(curl -s --max-time 8 \
    "https://api.anthropic.com/api/oauth/usage" \
    -H "Authorization: Bearer $token" \
    -H "anthropic-beta: oauth-2025-04-20" \
    -H "anthropic-version: 2023-06-01" \
    -H "x-app: cli" \
    -H "User-Agent: $UA")
  [ -z "$json" ] && return

  # Build python invocation: pass TZ only if user explicitly set it
  local tz_env=""
  [ -n "${TZ:-}" ] && tz_env="TZ=$TZ"

  out=$(printf '%s' "$json" | eval "$tz_env" python3 -c '

import json,sys,datetime
try:
    d=json.load(sys.stdin)
except Exception:
    sys.exit(0)
if not isinstance(d,dict) or "five_hour" not in d:
    sys.exit(0)   # bad response (e.g. 401) → keep previous cache

# colors tuned for GREEN background (bg=green, contrast with fg=black)
def col(p):
    p=p or 0
    if p>=90: return "#[bg=colour196,fg=colour231,bold]"  # red bg, white text — critical
    if p>=75: return "#[fg=colour196,bold]"               # red
    if p>=50: return "#[fg=colour17,bold]"                # dark blue
    return "#[fg=black]"                                    # calm, default

# battery-style 5-block scale
def blocks(p):
    p=p or 0
    n=int(round(p/20))
    n=min(max(n,0),5)
    return "▰"*n + "▱"*(5-n)

def part(label,node,with_date):
    if not node: return None
    u=node.get("utilization") or 0
    s="#[fg=black]%s %s%d%% %s#[default]" % (label, col(u), int(round(u)), blocks(u))
    r=node.get("resets_at")
    if r:
        try:
            dt=datetime.datetime.fromisoformat(r).astimezone()
            s+=dt.strftime(" #[fg=black]⟳ %d.%m %H:%M" if with_date else " #[fg=black]⟳ %H:%M")
        except Exception:
            pass
    return s

segs=[]
p=part("5h", d.get("five_hour"), False)
if p: segs.append(p)
p=part("7d", d.get("seven_day"), True)
if p: segs.append(p)
op=d.get("seven_day_opus")
if op:
    p=part("opus", op, True)
    if p: segs.append(p)
print("#[fg=colour17,bold]Claude Code quotas #[default]" + " #[fg=black]│ ".join(segs)+"#[default]")
')
  [ -n "$out" ] && printf '%s' "$out" > "$CACHE"
}

# ---------------------------------------------------------------------------
# main — fast cache read (tmux does NOT wait for network)
# ---------------------------------------------------------------------------
age=999999
[ -f "$CACHE" ] && age=$(( $(date +%s) - $(stat -c %Y "$CACHE" 2>/dev/null || echo 0) ))
if [ "$age" -ge "$MAXAGE" ]; then
  ( fetch ) >/dev/null 2>&1 </dev/null &
fi

if [ -f "$CACHE" ]; then
  cat "$CACHE"
else
  printf '#[fg=black]CC …'
fi
