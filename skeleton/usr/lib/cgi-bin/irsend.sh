#!/bin/sh
cat << EOF
Content-Type: text/plain

EOF
DEBUG=n
[[ ! -z $DEBUG ]] && echo
[[ ! -z $DEBUG ]] && echo "DEBUG MODE..."
[[ ! -z $DEBUG ]] && echo "SERVER_NAME: $SERVER_NAME"
[[ ! -z $DEBUG ]] && echo "REQUEST_URI: $REQUEST_URI"
[[ ! -z $DEBUG ]] && echo "REQUEST_METHOD: $REQUEST_METHOD"

BUTTONNAME=$REQUEST_URI
#replace the equal sign by a space:
BUTTONNAME=`echo $BUTTONNAME | sed "s/=/ /"`
[[ ! -z $DEBUG ]] && echo "BUTTONNAME: $BUTTONNAME";
#now take the second word
BUTTONNAME=`echo $BUTTONNAME | cut -f 2 -d " "`
[[ ! -z $DEBUG ]] && echo "BUTTONNAME: $BUTTONNAME";

#replace all non alphanumeric characters by a space for safety
BUTTONNAME=`echo $BUTTONNAME | sed "s/[^a-zA-Z0-9_-]/ /g"`
[[ ! -z $DEBUG ]] && echo "BUTTONNAME: $BUTTONNAME";
#now take the first word
BUTTONNAME=`echo $BUTTONNAME | cut -f 1 -d " "`
[[ ! -z $DEBUG ]] && echo "BUTTONNAME: $BUTTONNAME";

irsend SEND_ONCE RCDymond $BUTTONNAME

