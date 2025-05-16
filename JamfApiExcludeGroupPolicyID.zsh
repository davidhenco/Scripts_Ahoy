#!/bin/zsh --no-rcs

# This script uses the Jamf Pro API to modify a policy based on its ID, and scope it to a single exclusion group ID
# Warning: this will overwrite all groups currently included in the exclusion scope

jssURL="https://YOURDOMAIN.jamfcloud.com"

JamfBearerToken=$(curl -s -H 'Authorization:Basic YOURBASE64ENCODEDLOGIN:PASSWORD' $jssURL/api/v1/auth/token -X POST | plutil -extract token raw -)

policyID=73 #CHANGE POLICY ID HERE AND GROUP ID BELOW

curl -sS -k -H "Authorization: Bearer $JamfBearerToken" $jssURL/JSSResource/policies/id/$policyID -H "Content-Type: application/xml" -d "<policy><scope><exclusions><computer_groups><computer_group><id>276</id></computer_group></computer_groups></exclusions></scope></policy>" -X PUT