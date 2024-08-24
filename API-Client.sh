​#!/bin/bash
​
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# Copyright (c) 2020 Jamf.  All rights reserved.
#
#       Redistribution and use in source and binary forms, with or without
#       modification, are permitted provided that the following conditions are met:
#               * Redistributions of source code must retain the above copyright
#                 notice, this list of conditions and the following disclaimer.
#               * Redistributions in binary form must reproduce the above copyright
#                 notice, this list of conditions and the following disclaimer in the
#                 documentation and/or other materials provided with the distribution.
#               * Neither the name of the Jamf nor the names of its contributors may be
#                 used to endorse or promote products derived from this software without
#                 specific prior written permission.
#
#       THIS SOFTWARE IS PROVIDED BY JAMF SOFTWARE, LLC "AS IS" AND ANY
#       EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
#       WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
#       DISCLAIMED. IN NO EVENT SHALL JAMF SOFTWARE, LLC BE LIABLE FOR ANY
#       DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
#       (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
#       LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
#       ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
#       (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
#       SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
​
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# This script was designed to be used in a Self Service policy to allow the facilitation
# or log collection by the end-user and upload the logs to the device record in Jamf Pro
# as an attachment.
#
# REQUIREMENTS:
#           - Jamf Pro
#           - macOS Clients running version 10.13 or later
#
#
# For more information, visit https://github.com/kc9wwh/logCollection
#
# Written by: Joshua Roskos | Jamf
# Revised by: Alton Brailovskiy + 
# Martin Cox (Jamf) 
#
# Revision History
# 2024-08-2024: Added API Client Support - (API Role Permissions: Read Computers & Create Computers)
# 2024-08-2024: Updated Token Invalidation + Retry Logic
# 2024-07-23: Updated Script
# 2023-11-30: Added support for bearer auth and invalidating bearer token once done.
# 2020-12-01: Added support for macOS Big Sur
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
​
# User Variables
# Ensure not to include the / at the end of the JamfProURL parameter. ex https://instance.jamfcloud.com is the parameter NOT https://instance.jamfcloud.com/
# Suggested Logs to pull: /private/var/log/install.log* /private/var/log/jamf.log* /private/var/log/system.log*
​
jamfProURL="$4"
client_id="$5"
client_secret="$6"
logFiles="$7"

BearerTokenResponse=$(curl --location --request POST "${jamfProURL}/api/oauth/token" \
    --header "Content-Type: application/x-www-form-urlencoded" \
    --data-urlencode "client_id=${client_id}" \
    --data-urlencode "grant_type=client_credentials" \
    --data-urlencode "client_secret=${client_secret}")

access_token=$(echo "$BearerTokenResponse" | awk -F'"access_token":"' '{print $2}' | awk -F'"' '{print $1}')
​bearerToken=$(echo "$access_token")

# System Variables
mySerial=$(system_profiler SPHardwareDataType | grep 'Serial Number' | awk '{print $NF}')
currentUser=$( stat -f%Su /dev/console )
compHostName=$( scutil --get LocalHostName )
timeStamp=$( date '+%Y-%m-%d-%H-%M-%S' )
osMajor=$(/usr/bin/sw_vers -productVersion | awk -F . '{print $1}')
osMinor=$(/usr/bin/sw_vers -productVersion | awk -F . '{print $2}')
​
# Log Collection
fileName=$compHostName-$currentUser-$timeStamp.zip
zip /private/tmp/$fileName $logFiles

# Upload Log File
if [[ "$osMajor" -ge 11 ]]; then
	jamfProID=$( curl -k -H "Authorization: Bearer ${bearerToken}" $jamfProURL/JSSResource/computers/serialnumber/$mySerial/subset/general | xpath -e "//computer/general/id/text()" )
elif [[ "$osMajor" -eq 10 && "$osMinor" -gt 12 ]]; then
	jamfProID=$( curl -k -H "Authorization: Bearer ${bearerToken}" $jamfProURL/JSSResource/computers/serialnumber/$mySerial/subset/general | xpath "//computer/general/id/text()" )
fi

curl -k -H "Authorization: Bearer ${bearerToken}" $jamfProURL/JSSResource/fileuploads/computers/id/$jamfProID -F name=@/private/tmp/$fileName -X POST

# Cleanup
rm /private/tmp/$fileName
​
# Invalidate the bearer token with retry logic
while true; do
    responseCode=$(curl -w "%{http_code}" -H "Authorization: Bearer ${bearerToken}" "$jamfProURL/api/v1/auth/invalidate-token" -X POST -s -o /dev/null)
    echo "Response Code: $responseCode"
    
    if [[ ${responseCode} -eq 204 ]]; then
        echo "Token successfully invalidated."
        bearerToken=""
        echo "Exiting script..."
        exit 0
        
    elif [[ ${responseCode} -eq 401 ]]; then
        echo "Token already invalid."
        echo "Exiting script..."
        exit 0
        
    else
        echo "An unknown error occurred invalidating the token."
        
        retryCount=$((retryCount + 1))
        if [[ ${retryCount} -ge ${maxRetries} ]]; then
            echo "Maximum retries reached. Exiting script..."
            exit 1
        fi
        
        echo "Retrying in ${retryInterval} seconds..."
        sleep ${retryInterval}
    fi
done
​
exit 0
