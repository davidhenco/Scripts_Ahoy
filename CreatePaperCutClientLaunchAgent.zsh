#!/bin/zsh

# Do not run this script if LaunchAgent alredy exists
if [[ -f "/Library/LaunchAgents/com.papercut.client.agent.plist" ]]; then
    echo "LaunchAgent alredy exists. Exiting script."
    exit 0
fi

# Do not run this script if /Applications/PCClient.app is not installed
if [ ! -d "/Applications/PCClient.app" ]; then
    echo "Error: /Applications/PCClient.app not found."
    exit 1
fi

# Set Permissions and Unquarantine the App
chown -R root:wheel /Applications/PCClient.app
chmod -R 755 /Applications/PCClient.app
xattr -d com.apple.quarantine /Applications/PCClient.app

# Define the path where the plist file will be created
PLIST_PATH="/Library/LaunchAgents/com.papercut.client.agent.plist"

# Create the plist content
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
</dict>
</plist>'

# Write the plist content to the file
echo "$PLIST_CONTENT" > "$PLIST_PATH"

# Convert to XML and Set the appropriate permissions
plutil -convert xml1 "$PLIST_PATH"
chmod 644 "$PLIST_PATH"

# Load the LaunchAgent as logged-in user
Name_loggedInUser=$(stat -f %Su /dev/console)
UID_loggedInUser=$(id -u $Name_loggedInUser)

launchctl bootstrap gui/$UID_loggedInUser "$PLIST_PATH"

echo "LaunchAgent created, permissions set, loaded, and commands executed successfully."
exit 0