#!/bin/zsh --no-rcs

############
# This script uses the Jamf Pro API to modify a list of policies, based on policy names, and scope each policy to a single exclusion group ID
# Warning: this will overwrite all groups currently included in the exclusion scope
############

# The following URL Tools Add handy command line aliases useful for dealing with URLs
# Taken from: https://ruslanspivak.com/2010/06/02/urlencode-and-urldecode-from-a-command-line/

if [[ $(whence $URLTOOLS_METHOD) = "" ]]; then
    URLTOOLS_METHOD=""
fi

if [[ $(whence node) != "" && ( "x$URLTOOLS_METHOD" = "x"  || "x$URLTOOLS_METHOD" = "xnode" ) ]]; then
    alias urlencode='node -e "console.log(encodeURIComponent(process.argv[1]))"'
    alias urldecode='node -e "console.log(decodeURIComponent(process.argv[1]))"'
elif [[ $(whence python3) != "" && ( "x$URLTOOLS_METHOD" = "x" || "x$URLTOOLS_METHOD" = "xpython" ) ]]; then
    alias urlencode='python3 -c "import sys; del sys.path[0]; import urllib.parse as up; print(up.quote_plus(sys.argv[1]))"'
    alias urldecode='python3 -c "import sys; del sys.path[0]; import urllib.parse as up; print(up.unquote_plus(sys.argv[1]))"'
elif [[ $(whence python2) != "" && ( "x$URLTOOLS_METHOD" = "x" || "x$URLTOOLS_METHOD" = "xpython" ) ]]; then
    alias urlencode='python2 -c "import sys; del sys.path[0]; import urllib as ul; print ul.quote_plus(sys.argv[1])"'
    alias urldecode='python2 -c "import sys; del sys.path[0]; import urllib as ul; print ul.unquote_plus(sys.argv[1])"'
elif [[ $(whence xxd) != "" && ( "x$URLTOOLS_METHOD" = "x" || "x$URLTOOLS_METHOD" = "xshell" ) ]]; then
    function urlencode() {echo $@ | tr -d "\n" | xxd -plain | sed "s/\(..\)/%\1/g"}
    function urldecode() {printf $(echo -n $@ | sed 's/\\/\\\\/g;s/\(%\)\([0-9a-fA-F][0-9a-fA-F]\)/\\x\2/g')"\n"}
elif [[ $(whence ruby) != "" && ( "x$URLTOOLS_METHOD" = "x" || "x$URLTOOLS_METHOD" = "xruby" ) ]]; then
    alias urlencode='ruby -r cgi -e "puts CGI.escape(ARGV[0])"'
    alias urldecode='ruby -r cgi -e "puts CGI.unescape(ARGV[0])"'
elif [[ $(whence php) != "" && ( "x$URLTOOLS_METHOD" = "x" || "x$URLTOOLS_METHOD" = "xphp" ) ]]; then
    alias urlencode='php -r "echo rawurlencode(\$argv[1]); echo \"\n\";"'
    alias urldecode='php -r "echo rawurldecode(\$argv[1]); echo \"\\n\";"'
elif [[ $(whence perl) != "" && ( "x$URLTOOLS_METHOD" = "x" || "x$URLTOOLS_METHOD" = "xperl" ) ]]; then
    if perl -MURI::Encode -e 1&> /dev/null; then
        alias urlencode='perl -MURI::Encode -ep "uri_encode($ARGV[0]);"'
        alias urldecode='perl -MURI::Encode -ep "uri_decode($ARGV[0]);"'
    elif perl -MURI::Escape -e 1 &> /dev/null; then
        alias urlencode='perl -MURI::Escape -ep "uri_escape($ARGV[0]);"'
        alias urldecode='perl -MURI::Escape -ep "uri_unescape($ARGV[0]);"'
    else
        alias urlencode="perl -e '\$new=\$ARGV[0]; \$new =~ s/([^A-Za-z0-9])/sprintf(\"%%%02X\", ord(\$1))/seg; print \"\$new\n\";'"
        alias urldecode="perl -e '\$new=\$ARGV[0]; \$new =~ s/\%([A-Fa-f0-9]{2})/pack(\"C\", hex(\$1))/seg; print \"\$new\n\";'"
    fi
fi

unset URLTOOLS_METHOD

#Define Jamf Pro URL
jssURL="https://YOURDOMAIN.jamfcloud.com"

# Get the Jamf Bearer Token
JamfBearerToken=$(curl -s -H 'Authorization:Basic YOURBASE64ENCODEDLOGIN:PASSWORD' $jssURL/api/v1/auth/token -X POST | plutil -extract token raw -)

# Paste your policy names here, separated by new lines
policyNames=$(cat <<EOF
APP: Brew
APP: Test
APP: Example
EOF
)

# Convert the multi-line string into an array
policyNames=("${(@f)policyNames}")

# Loop through each policy name
for policyName in "${policyNames[@]}"; do
    # URL encode the policy name
    encodedPolicyName=$(urlencode "$policyName")

    # Execute the API call, CHANGE GROUP ID BELOW
    curl -sS -k -H "Authorization: Bearer $JamfBearerToken" "$jssURL/JSSResource/policies/name/$encodedPolicyName" -H "Content-Type: application/xml" -d "<policy><scope><exclusions><computer_groups><computer_group><id>276</id></computer_group></computer_groups></exclusions></scope></policy>" -X PUT
done
