 # Scripts_Ahoy
 ## Scripts and CP's to make the life of MacAdmins easier. 
If you enjoy these, drop me a line on the Macadmins' Slack *@David Cohen* .
 ### CreatePaperCutClientLaunchAgent.zsh

 This script creates and loads a MacOS LaunchAgent that keeps the PaperCut Client (PCCLient.app) alive at all times.
 Since PCClient.app lives in /Applications/, you may previously install it from a custom pkg or dmg. 
 Since the provided PCClient app is neither signed nor notarized, this script also corrects permissions and unquarantines the app. 
 Be warned that this may be considered borderline from a security standpoint in your organization.

### InstallPrinterFromiPrintServer.zsh

 This MacOS script silently installs a printer from an iPrint server using the iprntcmd CLI command.
 If you wish to use a specific printer driver, you should install it before running this script.
 In an Intune environment, we have chosen to store logs in /Library/Logs/Microsoft/IntuneScripts/InstallXeroxiPrint; modify this as required.
 You should customize the ipp://myiprintserver.mydomain.com/ipp/Xerox-AltaLink argument with your iPrint server's URL and the printer's expected name in iPrint.
 Be warned: This script stores and sends the iPrint username an password in plain text. This may be frowned upon from a security standpoint.


### JamfApiExcludeGroupPolicyID

 This script uses the Jamf Pro API to add an exclusion group to the scope of a policy
 Warning: this will overwrite all groups in the exclusion scope


### JamfApiExcludeGroupPolicyName.zsh

 This script uses the Jamf Pro API to add an exclusion group to the scopes of a list of policies,
 based on the policy names you provide below
 Warning: this will overwrite all groups in the exclusion scope


### JamfEAListLocalAccounts

 Get a list of local user accounts with UIDs above 500
 Exclude specific accounts: Management_JamF, localadmin, nobody


### NetSupportSchoolPostInstall.zsh

 This script triggers headless installation of NetSupport School on MacOS. It then cleans up by deleting the installation bundle and licence file. 
 In an Intune environment, we have chosen to store logs in /Library/Logs/Microsoft/IntuneScripts/InstalNSS.log; modify as required.
 We are installing from the NetSupport School 15.00.0001 installer; for other versions change the installer name where applicable.
 We make the asssumption that the installer and NSW.LIC licence have previously been copied to the /Users/Shared directory. You may build a custom pkg to accomplish this and include this code as a post-install script. 
 You should also deploy the nsl.mdm.mobileconfig profile provided by NetSupport to handle the multiple TCC requirements.


### USBStorageDevicesSerialNumbers.zsh

 This macOS script collects USB Removable Storage Devices information from the Apple System Profiler
 January 2026 David Cohen


### ZscalerSSLInspectionCompatibility.zsh

 This script installs the Zscaler root certificate and merges it with the Mozilla CA bundle.
 Customize the ZScaler Root CA between -----BEGIN CERTIFICATE----- and -----END CERTIFICATE----- before using.
 It then configures various tools (cURL, Git, NPM, Python, Visual Studio Code, IntelliJ IDEA, and Azure CLI)
 to use the custom CA bundle for SSL/TLS connections.
