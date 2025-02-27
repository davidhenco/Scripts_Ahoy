#!/bin/zsh

# Define your iPrint username and password
userName="1234567"
passWord="Cegep_01"

# Command to be executed
COMMAND="/usr/local/bin/iprntcmd -a ipp://iris.cegeprdl.ca/ipp/Xerox-AltaLink"

# Logging folder and files
logFolder="/Library/Logs/Microsoft/IntuneScripts/InstallXeroxiPrint"
LOGFILE="${logFolder}/InstallXeroxiPrint.log"
mkdir -p "$logFolder"
exec &> >(tee -a "$LOGFILE")

# Log the start of the script with a timestamp
echo "Script started at: $(date)" | tee -a "$LOGFILE"

# Use expect to automate the interaction and echo the prompts and responses
/usr/bin/expect <<EOF
    log_file $LOGFILE
    log_user 1
    set timeout 62
    spawn $COMMAND
    expect {
        "username" {
            send $userName
            send "\r"
            exp_continue
        } 
        "password" {
            send $passWord
            send "\r"
            exp_continue
        } 
        timeout {
            puts "Timed out waiting for username prompt, exiting script"
            exit 1
        } 
    } 
    expect eof
    exit
EOF

# Log the end of the script with a timestamp
echo "You've Reached the End of the Script at: $(date)" | tee -a "$LOGFILE"
exit 0
