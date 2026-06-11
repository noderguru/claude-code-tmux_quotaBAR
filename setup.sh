#!/usr/bin/env bash
# =============================================================================
# Claude Code tmux quotaBAR — auto-installer
# =============================================================================
# Usage:
#   chmod +x setup.sh && ./setup.sh
#
# What it does:
#   1. Checks dependencies (bash, curl, python3, tmux)
#   2. Copies quota-tmux.sh → ~/.claude/
#   3. Adds/updates the config block in ~/.tmux.conf
#   4. Applies settings to the running tmux server (if any)
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()  { echo -e "  ${GREEN}✓${NC} $1"; }
warn(){ echo -e "  ${YELLOW}⚠${NC} $1"; }
err() { echo -e "  ${RED}✗${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BLOCK_START="# >>> claude-quota-block >>>"
BLOCK_END="# <<< claude-quota-block <<<"

echo ""
echo "=============================================="
echo "  Claude Code tmux quotaBAR  —  installer"
echo "=============================================="
echo ""

# ---------------------------------------------------------------------------
# Step 1 — dependencies
# ---------------------------------------------------------------------------
echo "[1/4] Checking dependencies..."

MISSING=()
for cmd in bash curl python3 tmux; do
  if command -v "$cmd" &>/dev/null; then
    ok "$cmd — $(command -v $cmd)"
  else
    err "$cmd — NOT FOUND"
    MISSING+=("$cmd")
  fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
  echo ""
  echo "ERROR: missing: ${MISSING[*]}"
  echo "Install them (apt install tmux curl python3) and re-run setup.sh."
  exit 1
fi

# ---------------------------------------------------------------------------
# Step 2 — check Claude Code credentials
# ---------------------------------------------------------------------------
echo ""
echo "[2/4] Checking ~/.claude/.credentials.json..."

CREDS="$HOME/.claude/.credentials.json"
if [ -f "$CREDS" ]; then
  ok "credentials file found"
  if python3 -c "import json; d=json.load(open('$CREDS')); assert d.get('claudeAiOauth',{}).get('accessToken')" 2>/dev/null; then
    ok "accessToken OK"
  else
    warn "cannot read accessToken (you may need a fresh login: claude login)"
  fi
else
  warn "~/.claude/.credentials.json not found"
  echo "       Make sure you are logged into Claude Code (claude login)"
fi

# ---------------------------------------------------------------------------
# Step 3 — copy the script
# ---------------------------------------------------------------------------
echo ""
echo "[3/4] Installing quota-tmux.sh → ~/.claude/..."

mkdir -p "$HOME/.claude"
cp "$SCRIPT_DIR/quota-tmux.sh" "$HOME/.claude/quota-tmux.sh"
chmod +x "$HOME/.claude/quota-tmux.sh"
ok "~/.claude/quota-tmux.sh installed"

# ---------------------------------------------------------------------------
# Step 4 — configure tmux
# ---------------------------------------------------------------------------
echo ""
echo "[4/4] Configuring ~/.tmux.conf..."

TMUXCONF="$HOME/.tmux.conf"
BLOCK=$(cat <<'EOF'
# >>> claude-quota-block >>>
# Claude Code: quota (5h/7d) in the tmux status bar
# Installed by claude-code-tmux_quotaBAR (setup.sh)
set -g status-style bg=green,fg=black
set -g status-interval 30
set -g status-right-length 140
set -g status-right "#(HOME/.claude/quota-tmux.sh) #[fg=black]%H:%M %d-%b"
# <<< claude-quota-block <<<
EOF
)

# Replace HOME placeholder with actual path
BLOCK="${BLOCK//HOME/$HOME}"

if [ -f "$TMUXCONF" ]; then
  if grep -qF "$BLOCK_START" "$TMUXCONF" 2>/dev/null; then
    # Block already exists — replace it in-place
    tmp=$(mktemp)
    awk -v start="$BLOCK_START" -v end="$BLOCK_END" '
      BEGIN { skip=0 }
      $0 == start { skip=1; next }
      $0 == end   { skip=0; next }
      !skip { print }
    ' "$TMUXCONF" > "$tmp"
    printf '%s\n' "$BLOCK" >> "$tmp"
    mv "$tmp" "$TMUXCONF"
    ok "block updated in ~/.tmux.conf"
  else
    printf '\n%s\n' "$BLOCK" >> "$TMUXCONF"
    ok "block added to ~/.tmux.conf"
  fi
else
  printf '%s\n' "$BLOCK" > "$TMUXCONF"
  ok "~/.tmux.conf created"
fi

# Apply to live tmux server
if [ -n "${TMUX:-}" ] || tmux info &>/dev/null 2>&1; then
  tmux source-file "$TMUXCONF" 2>/dev/null && \
    ok "config loaded into running tmux server" || \
    warn "could not apply to live tmux (restart your session)"
else
  warn "no tmux server running — settings will apply on next start"
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
echo "=============================================="
echo "  DONE!"
echo "=============================================="
echo ""
echo "  Status bar: green background, Claude Code quotas on the left, clock on the right."
echo "  Refresh: every 30s (network — every 120s)."
echo ""
echo "  To see it:  tmux new -s test  (or reattach your current session)"
echo ""
