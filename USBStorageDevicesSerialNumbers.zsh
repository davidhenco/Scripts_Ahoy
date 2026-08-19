#!/bin/zsh --no-rcs
# ============================================================
# Name: usb-devices-collect-sn.zsh
# Canonical ID: usb-devices-collect-sn
#
# Purpose:
#   Collects information about connected removable USB storage
#   devices (name, manufacturer, serial number) from the Apple
#   System Profiler, copies the result to the logged-in user's
#   clipboard, and displays it in a dialog with an optional link
#   to an IT support request form.
#
# Scope:
#   - Platform: macOS 11.0+
#   - Architecture: Both
#   - Execution context: User (must run in the logged-in user's
#     session; do NOT run as root, since pbcopy and the dialog
#     need an active GUI session)
#
# MDM Compatibility:
#   - Jamf: Yes (runs as root by default; script re-launches
#     itself in the logged-in user's context via launchctl asuser)
#   - Intune: Yes
#   - Workspace ONE: Yes
#   - Mosyle: Yes
#   - Iru: Yes
#
# Inputs:
#   - IT_SERVICE_URL (optional): URL opened if the user clicks
#     "Send Request" in the dialog. Default: https://YOUR_IT_SERVICE.com
#
# Outputs:
#   - Logs: stdout (MDM captured)
#   - Clipboard: device list copied via pbcopy
#   - UI: osascript dialog shown to the logged-in user
#   - Exit codes:
#       0 = EXIT_OK           Devices listed successfully (including "none found")
#       1 = EXIT_FAIL         system_profiler failed or produced no usable output
#       2 = EXIT_PRECONDITION Not running on macOS, or no logged-in user
#       3 = EXIT_PARTIAL      Not used
#       4 = EXIT_NONCOMPLIANT Not used
#
# Safety:
#   - Idempotent: Yes (read-only reporting, safe to run repeatedly)
#   - Destructive actions: No
#   - User impact: Shows a dialog to the logged-in user and
#     overwrites their clipboard contents
#
# Rollback:
#   Not applicable (read-only script, no system state is changed)
#
# References:
#   - docs/scripts/standards/logging-and-exit-codes.md
#   - docs/scripts/standards/template.md
#   - docs/getting-started/conventions/naming-scripts.md
#
# Author:       David Cohen
# Created:      2026-01
# Updated:      2026-08-19
# Version:      1.0.0
# ============================================================

# ============================================================
# Embedded Logging & Exit Codes Template (MANDATORY to comply with Amaris mdm-toolbox script standards)
# ============================================================

SCRIPT_NAME="usb-devices-collect-sn"
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

# ============================================================
# Script start
# ============================================================

log INFO "Starting $SCRIPT_NAME v1.0.0"

# Precondition: must be macOS
log INFO "Checking platform"
is_macos || die "$EXIT_PRECONDITION" "Precondition not met: not running on macOS"

# Input: IT service URL (optional, defaults to placeholder)
IT_SERVICE_URL="${IT_SERVICE_URL:-https://YOUR_IT_SERVICE.com}"
log INFO "IT service URL set to: $IT_SERVICE_URL"

# Precondition: identify the logged-in user (clipboard + dialog need a GUI session)
log INFO "Checking for a logged-in user"
loggedInUser=$(stat -f %Su /dev/console)

if [[ -z "$loggedInUser" || "$loggedInUser" == "root" ]]; then
  die "$EXIT_PRECONDITION" "Precondition not met: no logged-in user session detected (console user is '${loggedInUser:-unknown}')"
fi

loggedInUserId=$(id -u "$loggedInUser")
log INFO "Logged-in user: $loggedInUser (uid $loggedInUserId)"

# ============================================================
# Collect USB device information (Data Types accounting for different macOS versions)
# ============================================================

log INFO "Querying system_profiler for USB device information"
usb_output=$(system_profiler SPUSBHostDataType SPUSBDataType 2>/dev/null)

if [[ -z "$usb_output" ]]; then
  die "$EXIT_FAIL" "Failed to retrieve USB device information from system_profiler"
fi

# Initialize outputs
device_list=""
current_device=""
current_connection=""
current_manufacturer=""
current_serial=""
current_removable_media=""

log INFO "Parsing USB device tree for removable storage devices"

# Parse the output line by line
while IFS= read -r line; do

    # Detect device name (line ending with colon, not a property line)
    if [[ $line =~ ^[[:space:]]+[^:]+:[[:space:]]*$ ]] && \
       [[ ! $line =~ (Location ID|Connection Type|Driver|Manufacturer|Serial Number|Link Speed|USB Vendor ID|USB Product ID|USB Product Version|Power Allocated): ]]; then

        # Save previous device if it was removable and not filtered
        if [[ -n $current_device ]] && { [[ $current_connection == "Removable" ]] || [[ $current_removable_media == "Yes" ]]; }; then
            # Exclude devices with "Hub", "LAN", or "Video" in the name
            if [[ ! $current_device =~ (Hub|HUB|LAN|Video) ]]; then
                device_list+="Device: $current_device\n"
                device_list+="Manufacturer: ${current_manufacturer:-Not Available}\n"
                device_list+="Serial Number: ${current_serial:-Not Available}\n"
                device_list+="\n"
            fi
        fi

        # Start new device
        current_device=$(echo "$line" | sed -E 's/^[[:space:]]+(.+):[[:space:]]*$/\1/')
        current_connection=""
        current_manufacturer=""
        current_serial=""
        current_removable_media=""
    fi

    # Parse Connection Type
    if [[ $line =~ Connection\ Type:[[:space:]]*(.+)$ ]]; then
        current_connection=$(echo "${match[1]}" | xargs)
    fi

    # Parse Manufacturer
    if [[ $line =~ Manufacturer:[[:space:]]*(.+)$ ]]; then
        current_manufacturer=$(echo "${match[1]}" | xargs)
    fi

    # Parse Serial Number
    if [[ $line =~ Serial\ Number:[[:space:]]*(.+)$ ]]; then
        current_serial=$(echo "${match[1]}" | xargs)
    fi

    # Parse Removable Media
    if [[ $line =~ Removable\ Media:[[:space:]]*(.+)$ ]]; then
        current_removable_media=$(echo "${match[1]}" | xargs)
    fi
done <<< "$usb_output"

# Check last device
if [[ -n $current_device ]] && { [[ $current_connection == "Removable" ]] || [[ $current_removable_media == "Yes" ]]; }; then
    # Exclude devices with "Hub", "LAN", or "Video" in the name
    if [[ ! $current_device =~ (Hub|HUB|LAN|Video) ]]; then
        device_list+="Device: $current_device\n"
        device_list+="Manufacturer: ${current_manufacturer:-Not Available}\n"
        device_list+="Serial Number: ${current_serial:-Not Available}\n"
    fi
fi

# Remove trailing newlines
device_list=$(echo -e "$device_list" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')

# Mitigate if no removable devices are found
if [[ -z $device_list ]]; then
    log INFO "No removable USB storage devices found"
    device_list="No removable USB devices found."
else
    log INFO "Removable USB storage device(s) found"
fi

# ============================================================
# Present results to the logged-in user
# ============================================================

log INFO "Copying device list to clipboard for user '$loggedInUser'"
launchctl asuser "$loggedInUserId" sudo -u "$loggedInUser" \
  zsh -c "echo -e $(printf '%q' "$device_list") | pbcopy"

echo "$device_list"
log INFO "Device list copied to clipboard"

log INFO "Displaying dialog to user '$loggedInUser'"
launchctl asuser "$loggedInUserId" sudo -u "$loggedInUser" \
  osascript <<EOF
set dlg to display dialog "$device_list" & return & return & ¬
    "All information has been successfully copied to your Clipboard. " & ¬
    "Please paste it in the field of your support request." ¬
    buttons {"Close", "Send Request"} default button "Send Request" ¬
    with title "About your USB Storage Device " giving up after 60

if (gave up of dlg) is false and (button returned of dlg is "Send Request") then
    open location "$IT_SERVICE_URL"
end if
EOF

log INFO "Completed successfully"
exit "$EXIT_OK"
