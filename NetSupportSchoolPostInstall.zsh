#!/bin/zsh --no-rcs

############
# This script triggers headless installation of NetSupport School on MacOS. It then cleans up by deleting the installation bundle and licence file. 
# In an Intune environment, we have chosen to store logs in /Library/Logs/Microsoft/IntuneScripts/InstalNSS.log; modify as required.
# We are installing from the NetSupport School 15.00.0001 installer; for other versions change the installer name where applicable.
# We make the asssumption that the installer and NSW.LIC licence have previously been copied to the /Users/Shared directory. 
# You may build a custom pkg to accomplish this and include this code as a post-install script. 
# You should also deploy the nsl.mdm.mobileconfig profile provided by NetSupport to handle the multiple TCC requirements.
###########

# Log file path
LOG_FILE="/Library/Logs/Microsoft/IntuneScripts/InstalNSS.log"

# Create the log directory if it doesn't exist
mkdir -p /Library/Logs/Microsoft/IntuneScripts

# Redirect stdout and stderr to the log file
exec > >(tee -a "$LOG_FILE") 2>&1

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log "Script started."

# Change to the specified directory
log "Changing directory to /Users/Shared/NetSupport School 15.00.0001.app/Contents/MacOS/"
cd /Users/Shared/NetSupport\ School\ 15.00.0001.app/Contents/MacOS/ || { log "Failed to change directory."; exit 1; }

# Run the installbuilder.sh script in the background
log "Running installbuilder.sh script."
./installbuilder.sh --mode unattended --installer-language fr --InstallationTypeSelection typical --uninstall 1 &
INSTALL_PID=$!

# Timeout value in seconds
TIMEOUT=30

# Function to wait for the process with a timeout
wait_with_timeout() {
    local pid=$1
    local timeout=$2
    local start_time=$(date +%s)
    while kill -0 $pid 2>/dev/null; do
        sleep 1
        local current_time=$(date +%s)
        if [ $(($current_time - $start_time)) -ge $timeout ]; then
            log "Timeout reached after $timeout seconds."
            return 1
        fi
    done
    return 0
}

# Wait for the installbuilder.sh process with a timeout
if wait_with_timeout $INSTALL_PID $TIMEOUT; then
    log "installbuilder.sh completed within the timeout."
else
    log "installbuilder.sh timed out."
fi

    # Quit the permissions utility
     log "Quitting MacOSSecurityPreferences."
     killall MacOSSecurityPreferences

    # Delete the specified files after 10 seconds
    log "Waiting 10s after quitting MacOSSecurityPreferences for installation of NetSupport to complete."
    sleep 10
    log "Deleting /Users/Shared/NetSupport School 15.00.0001.app/."
    rm -rf "/Users/Shared/NetSupport School 15.00.0001.app/"
    
    log "Deleting /Users/Shared/NSW.LIC."
    rm -f "/Users/Shared/NSW.LIC"
    
    # Exit the script with code 0
    log "Script completed successfully."
    exit 0
