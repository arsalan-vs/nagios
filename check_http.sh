#!/bin/sh
#
# Nagios script to check website is up and responding in a timely manner
# Written by Chris Freeman (cfree6223@gmail.com)
# Version 1.1
# (c) GPLv2 2011
#
# Special thanks to dkwiebe and Konstantine Vinogradov for suggestions and feedback 
#
# Modified by Leo to check string and use curl rather than wget


### Environment paths
DATE=/bin/date
WGET=/usr/bin/wget
CURL=/usr/bin/curl
ECHO=/bin/echo
AWK=/usr/bin/awk
CKSUM=/usr/bin/cksum
TR=/usr/bin/tr
MKTEMP=/bin/mktemp
GREP=/bin/grep
RM=/bin/rm

# Temp file
WGETOUT=/tmp/wgetoutput
MAINTENANCE='<div class="maintenance-title">Sorry down for maintenance.</div><div class="maintenance-description">We’re currently working to make things better, we’ll be back shortly.</div>'


### Functions
# Check dependencies and paths
checkpaths(){
        for PATH in $DATE $WGET $ECHO $AWK $CKSUM $TR $CURL $MKTEMP $GREP $RM; do
                if [ ! -f "$PATH" ]; then
                        STATUS=UNKNOWN
                        OUTMSG="ERROR: $PATH does does not exist"
                        output
                fi
        done
}

# Check inputs and formats
checkinputs(){
        if [ ! -n "$WARN" ]; then
                ERROR="Warning not set"
                usage
        fi
        case $WARN in
                *[!0-9]*)
                ERROR="Warning must be an integer in milliseconds"
                usage
        esac
        if [ ! -n "$CRIT" ]; then
                ERROR="Critical not set"
                usage
        fi
        case $CRIT in
                *[!0-9]*)
                ERROR="Critical must be an integer in milliseconds"
                usage
        esac
        if [ "$CRIT" -lt "$WARN" ]; then
                ERROR="Critical must be greater than Warning"
                usage
        fi
        if [ ! -n "$URL" ]; then
                ERROR="URL not set"
                usage
        fi
}

# Make temp file unique for URL
mktmpfile(){
	TMPFILE=$(${MKTEMP} /tmp/check_http.${$}.XXXXX)
}

# Print usage statement
usage(){
        $ECHO "RESPONSE: UNKNOWN - Error: $ERROR"
        $ECHO "Usage: check_website_response.sh -w <warning milliseconds> -c <critical milliseconds> -H <host> -u <url> -s <string> [ -nocert ]"
        exit 3
}

# Check if URL resolves, port is open and webpage contains data
checkopen(){
        # Determine PORT from scheme
       # SCHEME=`$ECHO $URL |$AWK -F: '{print $1}'| $TR [:upper:] [:lower:]`

        # Strip scheme out of URL
       # case $URL in
       #         *://*)
       #                 SHORTURL=`$ECHO $URL |$AWK -F"://" '{print $2}'`;;
       #         *)
       #                 SHORTURL=$URL;;
       # esac

       # # Strip path out of URL
       # case $SHORTURL in
       #         */*)
       #                 SHORTURL=`$ECHO $SHORTURL |$AWK -F/ '{print $1}'`;;
       # esac

        # if no scheme check for ports in SHORTURL or else default to 80
       # case $SHORTURL in
       #         *:*@*:*)
       #                 if [ ! -n "$PORT" ]; then
       #                         PORT=`$ECHO $SHORTURL |$AWK -F: '{print $3}'`
       #                 fi
       #                 SHORTURL=`$ECHO $SHORTURL |$AWK -F@ '{print $2}'`
       #                 SHORTURL=`$ECHO $SHORTURL |$AWK -F: '{print $1}'`;;
       #         *:*@*)
       #                 if [ ! -n "$PORT" ]; then
       #                         PORT=80
       #                 fi
       #                 SHORTURL=`$ECHO $SHORTURL |$AWK -F@ '{print $2}'`;;
       #        *:*)
       #                 if [ ! -n "$PORT" ]; then
       #                         PORT=`$ECHO $SHORTURL |$AWK -F: '{print $2}'`
       #                 fi
       #                 SHORTURL=`$ECHO $SHORTURL |$AWK -F: '{print $1}'`;;
       #         *)
       #                 if [ "$SCHEME" = "https" ]; then
       #                         PORT=443
       #                 fi
       #                 if [ ! -n "$PORT" ]; then
       #                         PORT=80
       #                 fi;;
       # esac

	FULLURL="http://${HOST}${URL}"	

        # Check if page can be loaded and contains data
        if [ -n "$NOCERT" ]; then
		$CURL -L -s -o ${TMPFILE} ${FULLURL} 2>/dev/null
        else
		$CURL -L -s -o ${TMPFILE} ${FULLURL} 2>/dev/null
        fi


        if [ ! -s "$TMPFILE" ]; then
                OUTMSG="$URL does not contain any data"
                STATUS=CRITICAL
                output
        fi

	RES=$(${GREP} -i ${STRING} ${TMPFILE})
	if [ "$?" -ne "0" ];
	then
		MAINTENANCE_RES=$(${GREP} -i MAINTENANCE ${TMPFILE})
                if [ "$?" -eq "0" ];
                then
                        echo "${FULLURL} is in maintenance mode"
                        STATUS=WARNING
                else
                        echo "String ${STRING} not found in ${URL}"
                        STATUS=CRITICAL
                fi
		${RM} -f ${TMPFILE}
		output
	fi

	${RM} -f ${TMPFILE}
}

# Check page response time
pageload(){
        if [ -n "$NOCERT" ]; then
                STARTTIME=$($DATE +%s%N)
                $WGET --no-check-certificate -q $URL
                ENDTIME=$($DATE +%s%N)
        else
                STARTTIME=$($DATE +%s%N)
                $WGET -q $URL
                ENDTIME=$($DATE +%s%N)
        fi
        TIMEDIFF=$((($ENDTIME-$STARTTIME)/1000000))
        if [ "$TIMEDIFF" -lt "$WARN" ]; then
                STATUS=OK
        elif [ "$TIMEDIFF" -ge "$WARN" ] && [ "$TIMEDIFF" -lt "$CRIT" ]; then
                STATUS=WARNING
        elif [ "$TIMEDIFF" -ge "$CRIT" ]; then
                STATUS=CRITICAL
        fi
        OUTMSG="$TIMEDIFF ms"
}

# Output statement and exit
output(){
        $ECHO "RESPONSE: $STATUS - $OUTMSG""|Response="$TIMEDIFF"ms;"$WARN";"$CRIT";0"
        if [ "$STATUS" = "OK" ]; then
                exit 0
        elif [ "$STATUS" = "WARNING" ]; then
                exit 1
        elif [ "$STATUS" = "CRITICAL" ]; then
                exit 2
        fi
        exit 3
}

### Main
# Input variables
while getopts w:c:u:s:H:n: option
        do case "$option" in
		w) WARN=$(($OPTARG * 1000));;
		c) CRIT=$(($OPTARG * 1000));;
                u) URL=$OPTARG;;
                s) STRING=$OPTARG;;
                H) HOST=$OPTARG;;
                n) NOCERT=$OPTARG;;
                *) ERROR="Illegal option used"
                        usage;;
        esac
done

checkpaths
checkinputs
mktmpfile
checkopen
pageload
output

