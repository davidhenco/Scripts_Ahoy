#!/bin/zsh --no-rcs
# ============================================================
# Name: papercut-launchagent-install.zsh
# Canonical ID: papercut-launchagent-install
#
# Purpose:
#   Creates and loads a macOS LaunchAgent that keeps the
#   PaperCut Client (PCClient.app) running at all times.
#   PCClient.app must already be installed in /Applications/
#   (via a separate installer). Since the vendor-provided
#   app is neither signed nor notarized, this script also corrects
#   its permissions and removes the Gatekeeper quarantine flag.
#
# Scope:
#   - Platform: macOS 11.0+
#   - Architecture: Both
#   - Execution context: Device (root) - the LaunchAgent itself
#     is then bootstrapped into the logged-in user's session
#
# MDM Compatibility:
#   - Jamf: Yes
#   - Intune: Yes
#   - Workspace ONE: Yes
#   - Mosyle: Yes
#   - Iru: Yes
#
# Inputs:
#   None
#
# Outputs:
#   - Logs: stdout (MDM captured)
#   - Files: /Library/LaunchAgents/com.papercut.client.agent.plist
#   - Exit codes:
#       0 = EXIT_OK           LaunchAgent already loaded, or created and loaded successfully
#       1 = EXIT_FAIL         Failed to write/convert the plist, or launchctl bootstrap failed unexpectedly
#       2 = EXIT_PRECONDITION Not root, not macOS, PCClient.app missing, or no logged-in user
#       3 = EXIT_PARTIAL      Plist created but LaunchAgent could not be loaded (will retry on next login)
#       4 = EXIT_NONCOMPLIANT Not used
#
# Safety:
#   - Idempotent: Yes (skips work if already installed and loaded)
#   - Destructive actions: Yes - removes the com.apple.quarantine
#     attribute from PCClient.app, bypassing Gatekeeper's quarantine
#     check for this app. This may be considered borderline from a
#     security standpoint; review your org's policy before deploying.
#   - User impact: None expected; PaperCut Client will run silently
#     in the background for the logged-in user
#
# Rollback:
#   Unload the agent (launchctl bootout gui/<uid> \
#   /Library/LaunchAgents/com.papercut.client.agent.plist) and
#   delete /Library/LaunchAgents/com.papercut.client.agent.plist
#
# References:
#   - docs/scripts/standards/logging-and-exit-codes.md
#   - docs/scripts/standards/template.md
#   - docs/getting-started/conventions/naming-scripts.md
#
# Author:       David Cohen
# Created:      2025-02-27
# Updated:      2026-08-20
# Version:      1.1
# ============================================================

# ============================================================
# Embedded Logging & Exit Codes Template (MANDATORY)
# ============================================================

SCRIPT_NAME="papercut-launchagent-install"
LOG_LEVEL="${LOG_LEVEL:-INFO}"    # DEBUG | INFO | WARN | ERROR
LOG_FILE="${LOG_FILE:-}"          # Optional: /var/log/<org>/<script>.log

EXIT_OK=0
EXIT_FAIL=1
EXIT_PRECONDITION=2
EXIT_PARTIAL=3
EXIT_NONCOMPLIANT=4

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }

level_to_num() {
  case "$1" in
    DEBUG) echo 10 ;;
    INFO)  echo 20 ;;
    WARN)  echo 30 ;;
    ERROR) echo 40 ;;
    *)     echo 20 ;;
  esac
}

log_enabled() { [ "$(level_to_num "$1")" -ge "$(level_to_num "$LOG_LEVEL")" ]; }

log_write() {
  echo "$1"
  if [ -n "$LOG_FILE" ]; then
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    echo "$1" >> "$LOG_FILE" 2>/dev/null || true
  fi
}

log() {
  local level="$1"; shift
  if log_enabled "$level"; then
    log_write "[$(timestamp)] [$level] [$SCRIPT_NAME] $*"
  fi
}

die() {
  local code="$1"; shift
  log ERROR "$*"
  exit "$code"
}

is_macos() { [ "$(uname -s)" = "Darwin" ]; }

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    die "$EXIT_PRECONDITION" "Precondition not met: script must run as root"
  fi
}

# ============================================================
# Script start
# ============================================================

log INFO "Starting $SCRIPT_NAME v1.1"

# Preconditions
log INFO "Checking platform"
is_macos || die "$EXIT_PRECONDITION" "Precondition not met: not running on macOS"

log INFO "Checking for root privileges"
require_root

PLIST_LABEL="com.papercut.client.agent"
PLIST_PATH="/Library/LaunchAgents/${PLIST_LABEL}.plist"
PCCLIENT_APP="/Applications/PCClient.app"
PCCLIENT_BIN="${PCCLIENT_APP}/Contents/MacOS/JavaAppLauncher"

# Precondition: identify the logged-in user (LaunchAgent loads into their session)
log INFO "Checking for a logged-in user"
loggedInUser=$(stat -f %Su /dev/console)

if [[ -z "$loggedInUser" || "$loggedInUser" == "root" ]]; then
  die "$EXIT_PRECONDITION" "Precondition not met: no logged-in user session detected (console user is '${loggedInUser:-unknown}')"
fi

loggedInUserId=$(id -u "$loggedInUser")
log INFO "Logged-in user: $loggedInUser (uid $loggedInUserId)"

# Precondition: PCClient.app must be installed
log INFO "Checking that $PCCLIENT_APP is installed"
if [[ ! -d "$PCCLIENT_APP" ]]; then
  die "$EXIT_PRECONDITION" "Precondition not met: $PCCLIENT_APP not found"
fi

# ============================================================
# Idempotency check: is the LaunchAgent already installed AND loaded?
# ============================================================

plistExists=0
[[ -f "$PLIST_PATH" ]] && plistExists=1

agentLoaded=0
if launchctl asuser "$loggedInUserId" launchctl print "gui/${loggedInUserId}/${PLIST_LABEL}" >/dev/null 2>&1; then
  agentLoaded=1
fi

log INFO "Plist present: $plistExists - Agent loaded: $agentLoaded"

if [[ $plistExists -eq 1 && $agentLoaded -eq 1 ]]; then
  log INFO "LaunchAgent already installed and loaded - nothing to do"
  log INFO "Completed successfully"
  exit "$EXIT_OK"
fi

# ============================================================
# Set permissions and remove quarantine flag
# ============================================================

log INFO "Setting ownership and permissions on $PCCLIENT_APP"
chown -R root:wheel "$PCCLIENT_APP" || die "$EXIT_FAIL" "Failed to set ownership on $PCCLIENT_APP"
chmod -R 755 "$PCCLIENT_APP" || die "$EXIT_FAIL" "Failed to set permissions on $PCCLIENT_APP"

log INFO "Removing quarantine attribute from $PCCLIENT_APP"
xattr -d com.apple.quarantine "$PCCLIENT_APP" 2>/dev/null || log WARN "No quarantine attribute found on $PCCLIENT_APP (already cleared or never set)"

# ============================================================
# Create the LaunchAgent plist (only if it doesn't already exist)
# ============================================================

if [[ $plistExists -eq 0 ]]; then
  log INFO "Writing LaunchAgent plist to $PLIST_PATH"

  PLIST_CONTENT='<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.papercut.client.agent</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Applications/PCClient.app/Contents/MacOS/JavaAppLauncher</string>
    </array>
    <key>KeepAlive</key>
    <true/>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>'

  echo "$PLIST_CONTENT" > "$PLIST_PATH" || die "$EXIT_FAIL" "Failed to write plist to $PLIST_PATH"

  log INFO "Validating and converting plist to binary-safe XML format"
  plutil -convert xml1 "$PLIST_PATH" || die "$EXIT_FAIL" "plutil failed to convert $PLIST_PATH"

  chmod 644 "$PLIST_PATH" || die "$EXIT_FAIL" "Failed to set permissions on $PLIST_PATH"
else
  log INFO "Plist already present at $PLIST_PATH - reusing existing file"
fi

# ============================================================
# Load the LaunchAgent in the logged-in user's session
# ============================================================

log INFO "Bootstrapping LaunchAgent into gui/$loggedInUserId"
if launchctl bootstrap "gui/$loggedInUserId" "$PLIST_PATH" 2>/dev/null; then
  log INFO "LaunchAgent loaded successfully"
  log INFO "Completed successfully"
  exit "$EXIT_OK"
else
  log WARN "launchctl bootstrap failed or agent was already bootstrapped; verifying load state"
  if launchctl asuser "$loggedInUserId" launchctl print "gui/${loggedInUserId}/${PLIST_LABEL}" >/dev/null 2>&1; then
    log INFO "LaunchAgent confirmed loaded"
    log INFO "Completed successfully"
    exit "$EXIT_OK"
  else
    log WARN "Plist created but LaunchAgent could not be confirmed loaded - will likely load at next login"
    exit "$EXIT_PARTIAL"
  fi
fi
