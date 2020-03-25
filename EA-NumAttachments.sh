#!/bin/bash

jamfProURL="https://jamfpro.acme.net:8443"
jamfProUser="apiuser-logcollection"
jamfProPass="apiuserpassword"

## Grab local serial number
mySerial=$( system_profiler SPHardwareDataType | grep Serial |  awk '{print $NF}' )

## Determine Jamf Pro Device ID
jamfProID=$( curl -k -u $jamfProUser:$jamfProPass $jamfProURL/JSSResource/computers/serialnumber/$mySerial/subset/general | xpath "//computer/general/id/text()" )

## API Lookup for how many attachments are attached to this device record
numAttachments=$( curl -u $jamfProUser:$jamfProPass $jamfProURL/JSSResource/computers/id/$jamfProID -X GET | xmllint -format - | xpath '/computer/purchasing/attachments' | grep "<id>" | wc -l | xargs )

## Echo results for EA
echo "<result>$numAttachments</result>"
