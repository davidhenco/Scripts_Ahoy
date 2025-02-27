#!/bin/zsh --no-rcs

############
# This MacOS script silently installs a printer from an iPrint server using the iprntcmd CLI command.
# If you wish to use a specific printer driver, you should install it before running this script.
# In an Intune environment, we have chosen to store logs in /Library/Logs/Microsoft/IntuneScripts/InstallXeroxiPrint; modify this as required.
# You should customize the ipp://myiprintserver.mydomain.com/ipp/Xerox-AltaLink argument with your iPrint server's URL and the printer's expected name in iPrint.
# Be warned: This script stores and sends the iPrint username an password in plain text. This may be frowned upon from a security standpoint.
###########

# Define your iPrint username and password
userName="insertusernamehere"
passWord="insertpasswordhere"

# Command to be executed
COMMAND="/usr/local/bin/iprntcmd -a ipp://myiprintserver.mydomain.com/ipp/Xerox-AltaLink"

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
