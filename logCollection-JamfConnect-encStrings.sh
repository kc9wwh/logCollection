#!/bin/bash

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# Copyright (c) 2021 Jamf.  All rights reserved.
#
#       Redistribution and use in source and binary forms, with or without
#       modification, are permitted provided that the following conditions are met:
#               * Redistributions of source code must retain the above copyright
#                 notice, this list of conditions and the following disclaimer.
#               * Redistributions in binary form must reproduce the above copyright
#                 notice, this list of conditions and the following disclaimer in the
#                 documentation and/or other materials provided with the distribution.
#               * Neither the name of the Jamf nor the names of its contributors may be
#                 used to endorse or promote products derived from this software without
#                 specific prior written permission.
#
#       THIS SOFTWARE IS PROVIDED BY JAMF SOFTWARE, LLC "AS IS" AND ANY
#       EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
#       WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
#       DISCLAIMED. IN NO EVENT SHALL JAMF SOFTWARE, LLC BE LIABLE FOR ANY
#       DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
#       (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
#       LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
#       ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
#       (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
#       SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# This script was designed to be used in a Self Service policy to allow the facilitation
# or log collection by the end-user and upload the logs to the device record in Jamf Pro
# as an attachment.
#
# REQUIREMENTS:
#           - Jamf Pro
#           - macOS Clients running version 10.13 or later
#
#
# For more information, visit https://github.com/kc9wwh/logCollection
#
# Written by: Joshua Roskos | Jamf
#
#
# Revision History
# 2020-12-01: Added support for macOS Big Sur
# 2021-02-24: Fixed missing variables
#
# Modified by: July Flanakin | Jamf
# 2022-06-01: Added Jamf Connect log collection functionality
# 2022-06-02: Added Bearer Token Functionality
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

## User Variables
jamfProURL="$4"
jamfProUser="$5"
jamfProPassEnc="$6"
logFiles="$7"

## System Variables
mySerial=$( system_profiler SPHardwareDataType | grep Serial |  awk '{print $NF}' )
currentUser=$( stat -f%Su /dev/console )
compHostName=$( scutil --get LocalHostName )
timeStamp=$( date '+%Y-%m-%d-%H-%M-%S' )
osMajor=$(/usr/bin/sw_vers -productVersion | awk -F . '{print $1}')
osMinor=$(/usr/bin/sw_vers -productVersion | awk -F . '{print $2}')
jamfProPass=$( echo "$6" | /usr/bin/openssl enc -aes256 -d -a -A -S "$8" -k "$9" )
apiBasicPass=$( printf "$jamfProUser:$jamfProPass" | /usr/bin/iconv -t ISO-8859-1 | /usr/bin/base64 -i - )
getToken=$( curl -L -X POST $jamfProURL/api/v1/auth/token --header "Authorization: Basic $apiBasicPass" )
authToken=$(/usr/bin/plutil -extract token raw -o - - <<< "$getToken")

## Collect Jamf Connect Logs
log show --style compact --predicate ‘subsystem == “com.jamf.connect”’ --debug > /private/tmp/JamfConnect.log
log show --style compact --predicate ‘subsystem == “com.jamf.connect.login”’ --debug > /private/tmp/JamfConnectLogin.log
connectMenu="/private/tmp/JamfConnect.log"
connectLogin="/private/tmp/JamfConnectLogin.log"
connectDebug="/private/tmp/jamf_login.log"

## Log Collection
fileName=$compHostName-$currentUser-$timeStamp.zip
zip /private/tmp/$fileName $logFiles $connectDebug $connectMenu $connectLogin

## Upload Log File
if [[ "$osMajor" -ge 11 ]]; then
    jamfProID=$( curl -k -L $jamfProURL/JSSResource/computers/serialnumber/$mySerial/subset/general --header 'Content-Type: application/xml' --header "Authorization: Bearer ${authToken}" | xpath -e "//computer/general/id/text()" )
elif [[ "$osMajor" -eq 10 && "$osMinor" -gt 12 ]]; then
    jamfProID=$( curl -k -L $jamfProURL/JSSResource/computers/serialnumber/$mySerial/subset/general --header 'Content-Type: application/xml' --header "Authorization: Bearer ${authToken}" | xpath "//computer/general/id/text()" )
fi

curl -k -L $jamfProURL/JSSResource/fileuploads/computers/id/$jamfProID -F name=@/private/tmp/$fileName -X POST --header 'Accept: application/xml' --header "Authorization: Bearer ${authToken}" 

## Cleanup
rm /private/tmp/$fileName
rm /private/tmp/JamfConnect.log
rm /private/tmp/JamfConnectLogin.log
exit 0
