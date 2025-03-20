#!/bin/zsh --no-rcs

# This script installs the Zscaler root certificate and merges it with the Mozilla CA bundle.
# Customize the ZScaler Root CA between -----BEGIN CERTIFICATE----- and -----END CERTIFICATE----- before using.
# It then configures various tools (cURL, Git, NPM, Python, Visual Studio Code, IntelliJ IDEA, and Azure CLI)
# to use the custom CA bundle for SSL/TLS connections.

# Get the currently logged-in user
CURRENT_USER=$(stat -f "%Su" /dev/console)

# Check if a user is logged in
if [ -z "$CURRENT_USER" ]; then
	echo "No user is currently logged in. Exiting script."
	exit 1
fi

# Get the home directory of the current user
USER_HOME=$(eval echo "~$CURRENT_USER")

# Create the directory if it doesn't exist
if [ ! -d "$USER_HOME/ca_certs" ]; then
	mkdir -p "$USER_HOME/ca_certs"
	echo "Directory $USER_HOME/ca_certs created."
else
	echo "Directory $USER_HOME/ca_certs already exists."
fi

# Define paths for the certificate and Mozilla bundle
CERT_NAME="ZscalerRootCert-2048-SHA256.pem"
CERT_PATH="/private/tmp/$CERT_NAME"
CERT_INSTALL_PATH="$USER_HOME/ca_certs"
MOZILLA_CA_BUNDLE="$CERT_INSTALL_PATH/cacert.pem"
COMBINED_CA_BUNDLE="$CERT_INSTALL_PATH/ca-bundle.pem"

# Create the Zscaler certificate file with the specified data
echo "Creating Zscaler certificate file at $CERT_PATH..."
cat <<EOL > "$CERT_PATH"

Zscaler Root CA
=========================
-----BEGIN CERTIFICATE-----

-----END CERTIFICATE-----

EOL

# Check if the Zscaler certificate already exists
if [ -f "$CERT_INSTALL_PATH/$CERT_NAME" ]; then
	echo "Zscaler certificate already exists in $CERT_INSTALL_PATH. Skipping move operation."
else
	# Move the Zscaler certificate if it exists in /private/tmp
	if [ -f "$CERT_PATH" ]; then
		mv "$CERT_PATH" "$CERT_INSTALL_PATH/"
		if [ $? -eq 0 ]; then
			echo "Certificate moved to $USER_HOME/ca_certs."
		else
			echo "Failed to move certificate."
			exit 1
		fi
	else
		echo "Certificate file not found in /private/tmp."
		exit 1
	fi
fi

# Download Mozilla CA bundle
echo "Downloading Mozilla CA bundle..."
curl -o "$MOZILLA_CA_BUNDLE" https://curl.se/ca/cacert.pem

# Check if the download was successful
if [ $? -eq 0 ]; then
	echo "Mozilla CA bundle downloaded successfully."
	
	# Merge Mozilla CA bundle with Zscaler certificate
	cat "$MOZILLA_CA_BUNDLE" "$CERT_INSTALL_PATH/$CERT_NAME" > "$COMBINED_CA_BUNDLE"
	echo "Zscaler certificate appended to Mozilla CA bundle at $COMBINED_CA_BUNDLE."
else
	echo "Failed to download Mozilla CA bundle."
	exit 1
fi

echo "Certificate installation and merging complete."

# Define certificate paths
CERT_NAME="ca-bundle.pem"
CA_BUNDLE_PATH="$CERT_INSTALL_PATH/$CERT_NAME"

# Ensure CA bundle exists (merged with Zscaler certificate)
if [ ! -f "$CA_BUNDLE_PATH" ]; then
	echo "CA bundle not found. Please make sure the Zscaler certificate is merged with Mozilla CA bundle."
	exit 1
fi

# Ensure .bashrc exists
if [ ! -f "$USER_HOME/.bashrc" ]; then
	echo "Creating .bashrc for Bash profile..."
	touch "$USER_HOME/.bashrc"
fi

# Set environment variables and configure tools

# cURL Configuration
sed -i '' '/export CURL_CA_BUNDLE/d' "$USER_HOME/.bashrc"
sed -i '' '/export CURL_CA_BUNDLE/d' "$USER_HOME/.zshrc"
echo "export CURL_CA_BUNDLE=$CA_BUNDLE_PATH" | tee -a "$USER_HOME/.bashrc" "$USER_HOME/.zshrc"
echo "cURL configured to use custom CA bundle."

# Git Configuration
git config --global http.sslCAInfo "$CA_BUNDLE_PATH"
echo "Git configured to use custom CA bundle."

# NPM Configuration
sed -i '' '/export NODE_EXTRA_CA_CERTS/d' "$USER_HOME/.bashrc"
sed -i '' '/export NODE_EXTRA_CA_CERTS/d' "$USER_HOME/.zshrc"
echo "export NODE_EXTRA_CA_CERTS=$CA_BUNDLE_PATH" | tee -a "$USER_HOME/.bashrc" "$USER_HOME/.zshrc"
echo "NPM configured to use custom CA bundle."

# Python Configuration
sed -i '' '/export SSL_CERT_FILE/d' "$USER_HOME/.bashrc"
sed -i '' '/export SSL_CERT_FILE/d' "$USER_HOME/.zshrc"
echo "export SSL_CERT_FILE=$CA_BUNDLE_PATH" | tee -a "$USER_HOME/.bashrc" "$USER_HOME/.zshrc"
echo "Python configured to use custom CA bundle."

sed -i '' '/export REQUESTS_CA_BUNDLE/d' "$USER_HOME/.bashrc"
sed -i '' '/export REQUESTS_CA_BUNDLE/d' "$USER_HOME/.zshrc"
echo "export REQUESTS_CA_BUNDLE=$CA_BUNDLE_PATH" | tee -a "$USER_HOME/.bashrc" "$USER_HOME/.zshrc"
echo "Python Requests library configured to use custom CA bundle."

# IntelliJ IDEA Configuration
INTELLIJ_SETTINGS_PATH="$USER_HOME/Library/Application Support/JetBrains/IntelliJIdea*/idea.vmoptions"
if [ ! -f "$INTELLIJ_SETTINGS_PATH" ]; then
	echo "Creating IntelliJ IDEA settings file..."
	mkdir -p "$(dirname "$INTELLIJ_SETTINGS_PATH")"
	touch "$INTELLIJ_SETTINGS_PATH"
fi

# Add -Djavax.net.ssl.trustStore to IntelliJ IDEA settings
if grep -q '-Djavax.net.ssl.trustStore' "$INTELLIJ_SETTINGS_PATH"; then
	sed -i '' "s|-Djavax.net.ssl.trustStore=.*|-Djavax.net.ssl.trustStore=$CA_BUNDLE_PATH|" "$INTELLIJ_SETTINGS_PATH"
else
	echo "-Djavax.net.ssl.trustStore=$CA_BUNDLE_PATH" | tee -a "$INTELLIJ_SETTINGS_PATH"
fi
echo "IntelliJ IDEA configured to use custom CA bundle."

# Azure CLI Configuration
sed -i '' '/export AZURE_CLI_CA_BUNDLE/d' "$USER_HOME/.bashrc"
sed -i '' '/export AZURE_CLI_CA_BUNDLE/d' "$USER_HOME/.zshrc"
echo "export AZURE_CLI_CA_BUNDLE=$CA_BUNDLE_PATH" | tee -a "$USER_HOME/.bashrc" "$USER_HOME/.zshrc"
echo "Azure CLI configured to use custom CA bundle."

# Visual Studio Code Configuration
VSCODE_SETTINGS_PATH="$USER_HOME/Library/Application Support/Code/User/settings.json"
if [ ! -f "$VSCODE_SETTINGS_PATH" ]; then
	echo "Creating Visual Studio Code settings file..."
	mkdir -p "$(dirname "$VSCODE_SETTINGS_PATH")"
	touch "$VSCODE_SETTINGS_PATH"
fi

# Add NODE_EXTRA_CA_CERTS to Visual Studio Code settings
if grep -q '"NODE_EXTRA_CA_CERTS"' "$VSCODE_SETTINGS_PATH"; then
	sed -i '' "s|\"NODE_EXTRA_CA_CERTS\": \".*\"|\"NODE_EXTRA_CA_CERTS\": \"$CA_BUNDLE_PATH\"|" "$VSCODE_SETTINGS_PATH"
else
	sed -i '' 's|{|{\n  "NODE_EXTRA_CA_CERTS": "'"$CA_BUNDLE_PATH"'",|' "$VSCODE_SETTINGS_PATH"
fi
echo "Visual Studio Code configured to use custom CA bundle."

# Final output
echo "All tools have been configured to use the Zscaler root certificate."
