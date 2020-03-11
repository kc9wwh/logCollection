# logCollection
Script to upload client device logs to Jamf Pro

Simple script that can be used via Self Service and/or via Policy to grab logs from a Mac and attach them to the computer record in Jamf Pro. By default, the following log files are grabbed:
- /var/log/jamf.log
- /var/log/install.log (and all rollovers)
- /var/log/system.log (and all rollovers)

I'd recommend using the Jamf Pro Script Variables ($4-$7) to make this more flexible, but otherwise its a pretty straight forward setup. If you have suggestions or questions, please open an issue.

~Josh
