#!/bin/bash
# One-time setup for the Claude bridge: checks Claude Code, backs the bridge up to a
# private GitHub repo, and starts the runner.
# Run it in Terminal:  bash ~/Developer/claude-bridge/_system/install.sh
# Safe to run again: it skips whatever is already done.

BRIDGE="${BRIDGE_DIR:-$HOME/Developer/claude-bridge}"
SYS="$BRIDGE/_system"
REPO_NAME="claude-bridge"
MIN_VERSION="2.1.285"

ok()   { printf '  OK   %s\n' "$*"; }
warn() { printf '  !!   %s\n' "$*"; }
info() { printf '       %s\n' "$*"; }
step() { printf '\n%s\n' "$*"; }
ask()  { # ask "question" default(y/n) -> returns 0 for yes
  if [ -t 0 ]; then
    printf '  ??   %s ' "$1"; read -r a
    [ -z "$a" ] && a="$2"
  else
    a="$2"
  fi
  case "$a" in [Yy]*) return 0 ;; *) return 1 ;; esac
}

# version_ge A B: true when version A >= version B (numbers separated by dots)
version_ge() {
  a1=$(echo "$1" | cut -d. -f1); a2=$(echo "$1" | cut -d. -f2); a3=$(echo "$1" | cut -d. -f3)
  b1=$(echo "$2" | cut -d. -f1); b2=$(echo "$2" | cut -d. -f2); b3=$(echo "$2" | cut -d. -f3)
  [ "${a1:-0}" -gt "${b1:-0}" ] && return 0; [ "${a1:-0}" -lt "${b1:-0}" ] && return 1
  [ "${a2:-0}" -gt "${b2:-0}" ] && return 0; [ "${a2:-0}" -lt "${b2:-0}" ] && return 1
  [ "${a3:-0}" -ge "${b3:-0}" ]
}

find_claude() {
  c=$(command -v claude 2>/dev/null)
  if [ -n "$c" ]; then echo "$c"; return 0; fi
  for c in "$HOME/.local/bin/claude" "$HOME/.claude/local/claude" /opt/homebrew/bin/claude /usr/local/bin/claude "$HOME/.npm-global/bin/claude" "$HOME"/.nvm/versions/node/*/bin/claude; do
    if [ -x "$c" ]; then echo "$c"; return 0; fi
  done
  return 1
}

echo "Claude bridge setup"
[ -d "$BRIDGE" ] || { warn "The bridge folder $BRIDGE is missing."; exit 1; }
cd "$BRIDGE" || exit 1

# ---------------------------------------------------------------- 1
step "1. Claude Code"
CLAUDE=$(find_claude)
if [ -z "$CLAUDE" ]; then
  warn "Claude Code's command-line tool is not installed on this Mac."
  info "Install it with Anthropic's installer (see https://code.claude.com/docs/en/setup):"
  info "    curl -fsSL https://claude.ai/install.sh | bash"
  info "Then run 'claude' once to sign in, and run this setup again."
  exit 1
fi
ver=$("$CLAUDE" --version 2>/dev/null | head -1 | sed 's/[^0-9.].*//')
if [ -n "$ver" ] && ! version_ge "$ver" "$MIN_VERSION"; then
  info "Claude Code $ver is older than $MIN_VERSION. Updating..."
  "$CLAUDE" update || true
  ver=$("$CLAUDE" --version 2>/dev/null | head -1 | sed 's/[^0-9.].*//')
fi
ok "Found $CLAUDE (version ${ver:-unknown})"
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  info "Note: ANTHROPIC_API_KEY is set in this Terminal. The runner removes it for its runs, so they use your Claude subscription."
fi

# ---------------------------------------------------------------- 2
step "2. Sign-in check (one tiny Claude Code run)"
chk="$SYS/runs/install-check.json"
mkdir -p "$SYS/runs"
( exec env -u ANTHROPIC_API_KEY "$CLAUDE" -p "Reply with the single word READY and nothing else." --output-format json --max-turns 1 --no-session-persistence ) >"$chk" 2>"$SYS/runs/install-check.err" &
pid=$!
n=0
while kill -0 "$pid" 2>/dev/null && [ "$n" -lt 36 ]; do sleep 5; n=$((n + 1)); done
if kill -0 "$pid" 2>/dev/null; then kill -TERM "$pid" 2>/dev/null; fi
wait "$pid" 2>/dev/null
if grep -q 'READY' "$chk" 2>/dev/null && ! grep -q '"is_error" *: *true' "$chk" 2>/dev/null; then
  ok "Claude Code answered, so it is signed in."
else
  warn "Claude Code did not answer the test. It is probably not signed in for Terminal use."
  info "Run 'claude' in Terminal, sign in with your Claude account, type /exit, then run this setup again."
  info "Details: $chk and $SYS/runs/install-check.err"
  exit 1
fi

# ---------------------------------------------------------------- 3
step "3. Private GitHub backup"
if [ ! -f .gitignore ]; then
  printf '%s\n' '.DS_Store' '_system/runs/' '_system/.runner.lock/' > .gitignore
  ok "Added .gitignore (run logs stay on this Mac)."
fi
if ! command -v git >/dev/null 2>&1; then
  warn "git is not installed, so the GitHub backup was skipped. The runner still works on this Mac."
else
  if [ ! -d .git ]; then
    git init -q && git symbolic-ref HEAD refs/heads/main
    git add -A
    if git commit -q -m "Claude bridge: first version" 2>/dev/null; then
      ok "Started version history for the bridge."
    else
      warn "git could not save the first version. It may need your name and email:"
      info "    git config --global user.name \"Your Name\""
      info "    git config --global user.email \"you@example.com\""
      info "Then run this setup again."
      exit 1
    fi
  fi
  if git remote get-url origin >/dev/null 2>&1; then
    ok "Already linked to $(git remote get-url origin)"
    if command -v gh >/dev/null 2>&1; then
      u=$(git remote get-url origin)
      if [ "$(gh repo view "${u%.git}" --json visibility -q .visibility 2>/dev/null)" != "PRIVATE" ]; then
        warn "That repo is not a private GitHub repo (or gh could not check it), so the runner will not sync to it."
      fi
    fi
  elif command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    login=$(gh api user -q .login 2>/dev/null)
    if [ -z "$login" ]; then
      warn "Could not read your GitHub user name from gh. Skipping the backup."
    elif gh repo view "$login/$REPO_NAME" >/dev/null 2>&1; then
      if [ "$(gh repo view "$login/$REPO_NAME" --json visibility -q .visibility 2>/dev/null)" != "PRIVATE" ]; then
        warn "github.com/$login/$REPO_NAME exists but is not private, so the bridge was not linked to it."
        info "Make that repo private, or change REPO_NAME at the top of this file, then run this setup again."
      else
        git remote add origin "https://github.com/$login/$REPO_NAME.git"
        if GIT_TERMINAL_PROMPT=0 git push -q -u origin HEAD 2>/dev/null; then
          ok "Linked to the existing private repo github.com/$login/$REPO_NAME"
        else
          warn "github.com/$login/$REPO_NAME already exists and has other history. Ask Claude Code to merge it; the runner works without it meanwhile."
        fi
      fi
    else
      if gh repo create "$login/$REPO_NAME" --private --source "$BRIDGE" --remote origin --push \
           --description "Shared desk between Claude chat and Claude Code" >/dev/null 2>&1; then
        ok "Created the private repo github.com/$login/$REPO_NAME and uploaded the bridge."
      else
        warn "Could not create the GitHub repo. The runner still works on this Mac. Try again later."
      fi
    fi
  else
    warn "The GitHub command-line tool (gh) is not set up, so the backup was skipped."
    info "To add it later: brew install gh, then gh auth login, then run this setup again."
  fi
fi

# ---------------------------------------------------------------- 4
step "4. Runner files"
cmd="$SYS/Start Bridge Runner.command"
if [ ! -f "$cmd" ]; then
  printf '%s\n' '#!/bin/bash' '# Double-click to start the Claude bridge runner in Terminal.' \
    'exec /bin/bash "$HOME/Developer/claude-bridge/_system/runner.sh"' > "$cmd"
fi
# Files saved by an app can carry macOS's "downloaded" flag, which would make
# Finder question the double-click starter. These files were made for this Mac.
command -v xattr >/dev/null 2>&1 && xattr -dr com.apple.quarantine "$BRIDGE" 2>/dev/null
chmod +x "$SYS/runner.sh" "$SYS/install.sh" "$cmd" 2>/dev/null
ok "Runner ready: $SYS/runner.sh"

# ---------------------------------------------------------------- 5
step "5. Start the runner"
running=""
if [ -f "$SYS/.runner.lock/pid" ]; then
  p=$(cat "$SYS/.runner.lock/pid" 2>/dev/null)
  [ -n "$p" ] && kill -0 "$p" 2>/dev/null && running="$p"
fi
if [ -n "$running" ]; then
  ok "The runner is already running (process $running)."
elif ask "Start the runner now in a new Terminal window? [Y/n]" y; then
  open "$cmd" && ok "Started in a new Terminal window. Keep that window open (it can sit in the background)."
else
  info "Start it any time by double-clicking: $cmd"
fi
if ask "Start the runner automatically every time you log in to this Mac? [y/N]" n; then
  if osascript -e "tell application \"System Events\" to make login item at end with properties {path:\"$cmd\", hidden:false}" >/dev/null 2>&1; then
    ok "Added to your Login Items."
  else
    warn "macOS did not allow adding it automatically."
    info "Add it by hand: System Settings, General, Login Items, the + button, then choose $cmd"
  fi
fi

echo
echo "Done. Claude chat can now file tasks marked 'Run: auto' in $BRIDGE/tasks/ and the runner starts Claude Code on them."
echo "Results go into each task file and log.md. You get a notification when a task finishes or needs you."
if ! grep -q "setup done" "$BRIDGE/log.md" 2>/dev/null; then
  echo
  echo "Next: open Claude Code in any project and send this one line:"
  echo "    Read ~/Developer/claude-bridge/SETUP-FOR-CLAUDE-CODE.md and do the setup steps in it."
fi
