#!/bin/bash

NAGIOSNAME="Nagios"
PROWL_PROVIDERKEY="<GET_THIS_KEY_FROM_PROWLAPP.COM>"
URLBASE="https://localhost/nagios/cgi-bin"
PROWLPLPATH="/usr/local/bin/prowl.pl"

# End of configuration options

DATETIME="${1}" # Date/time of alert
TYPE="${2}" # Host or Service
NOTIFICATION="${3}" # PROBLEM, RESOLVED, etc
STATE="${4}" # OK, WARNING, CRITICAL, UP, DOWN, UNKNOWN
NAME="${5}" # Hostname or Hostname/Service
DESC="${6}" # Host or service description
OUTPUT="${7}" # Check command output

shift 7 # Shift all of the required arguments off

# Check we have everything and that the expected "--" is there
if [ -z "${DATETIME}" ] && [ -z "${TYPE}" ] && [ -z "${NOTIFICATION}" ] && [ -z "${STATE}" ] && [ -z "${NAME}" ] && [ "${1}" != "--" ]; then
	echo "Missing all args" >&2
	exit 1
fi

shift # Get rid of the "--"

# Set the priority level based on the host/service state
PRIORITY="0"
case "${STATE}" in
	[oO][kK])
		PRIORITY="-1" ;;
	[uU][pP])
		PRIORITY="-1" ;;
	[wW][aA][rR][nN][iI][nN][gG])
		PRIORITY="1" ;;
	[cC][rR][iI][tT][iI][cC][aA][lL])
		PRIORITY="2" ;;
	[dD][oO][wW][nN])
		PRIORITY="2" ;;
	[uU][nN][kK][nN][oO][wW][nN])
		PRIORITY="0" ;;
esac

# Set the URL based on whether this a host or service alert
URL=""
case "${TYPE}" in
	[hH][oO][sS][tT])
		URL="${URLBASE}/status.cgi?host=${NAME}" ;;
	[sS][eE][rR][vV][iI][cC][eE])
		URL="${URLBASE}/extinfo.cgi?type=2&host=$(echo "${NAME}" | cut -d / -f 1)&service=$(echo "${NAME}" | cut -d / -f 2 | sed -e 's/ /%20/g')" ;;
esac

# Build a string of comma-separated (no spaces) Prowl API keys
APIKEYS=""
while [ -n "${1}" ]; do
	APIKEYS="${APIKEYS},$(echo "${1}" | grep -o '[a-f0-9][a-f0-9]*' | paste -s -d "")"
	shift
done
APIKEYS="$(echo "${APIKEYS}" | sed -e 's/^,//')"

# Make the prowl.pl call
${PROWLPLPATH} -apikey="${APIKEYS}" -providerkey="${PROWL_PROVIDERKEY}" -application="${NAGIOSNAME}" -priority="${PRIORITY}" -event="${NAME} is ${STATE}" -notification="Date/Time: ${DATETIME} | Description: ${DESC} | Output: ${OUTPUT}" -url="${URL}"
