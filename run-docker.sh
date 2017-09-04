#!/bin/bash

__ScriptVersion="1.0"

set -x

function usage ()
{
	echo "Usage :  $0 [options] [--]

    Options:
    -h|help       Display this message
    -v|version    Display script version
	-p|port		  Set port for intercepting proxy
	-m|mode       Mode is one of proxy,scan: start proxy or scan application
	-i|image      Docker image of ZAP to use
	-r|report     Directory to copy report to (default: /tmp/report), has to be writable for zap user
	-s|session    Directory to store session information (default: /tmp/session), has to be writable for zap user
	-l|policy	  Name of scan policy (without extension), must exist in ZAP image (/home/zap/.ZAP/policies)"

}

#-----------------------------------------------------------------------
#  Handle command line arguments
#-----------------------------------------------------------------------
PROXY_PORT=8090
IMAGE=owasp/zap2docker-weekly
POLICY=""

while getopts ":hvm:p:i:r:s:" opt
do
  case $opt in

	h|help     )  usage; exit 0   ;;

	v|version  )  echo "$0 -- Version $__ScriptVersion"; exit 0   ;;

	m|mode     )  COMMAND=$OPTARG ;;

	p|port	   )  PROXY_PORT=$OPTARG ;;

	i|image	   )  IMAGE=$OPTARG		;;

	r|report   )  REPORTDIR=$OPTARG	;;

	s|session  )  SESSIONDIR=$OPTARG ;;

	l|policy   )  POLICY=$OPTARG ;;

	* )  echo -e "\n  Option does not exist : $OPTARG\n"
		  usage; exit 1   ;;

  esac    # --- end of case ---
done
shift $(($OPTIND-1))

if [[ "$COMMAND" != "scan" && "$COMMAND" != "proxy" ]]; then
	usage
fi

if [ ! -d $REPORTDIR ]; then
	echo "Report destination is not a directory: $REPORTDIR"
	exit 1
fi

if [ ! -d $SESSIONDIR ]; then
	echo "Session destination is not a directory: $SESSIONDIR"
	exit 1
fi

if [ "$COMMAND" == "proxy" ]; then
	KEY=${RANDOM}${RANDOM}${RANDOM}
	echo $KEY > api_key
	REPORT_VOLUME=""
	if [ ! -z $REPORTDIR ]; then
		REPORT_VOLUME="-v $REPORTDIR:/home/zap/report:rw"
	fi

	SESSION_VOLUME=""
	if [ ! -z $SESSIONDIR ]; then
		SESSION_VOLUME="-v $SESSIONDIR:/home/zap/.ZAP/session:rw"
	fi

	CONTAINER_ID=$(docker run -u zap -p ${PROXY_PORT}:8080 $REPORT_VOLUME $SESSION_VOLUME -d $IMAGE zap.sh -daemon -port 8080 -host 0.0.0.0 -config api.key=$KEY -config scanner.attackOnStart=true -config view.mode=attack -config connection.dnsTtlSuccessfulQueries=-1 -config connection.timeoutInSecs=5 -config api.addrs.addr.name=.* -config api.addrs.addr.regex=true)
	echo $CONTAINER_ID > container_id
	# hack to workaround lack of option for specifying Scan policy in zap-cli
	if [ ! -z $POLICY ]; then
		sleep 5 && docker exec $CONTAINER_ID cp "/home/zap/.ZAP/policies/$POLICY.policy" "/home/zap/.ZAP/policies/Default\ Policy.policy"
	fi
	exit
fi

CONTAINER_ID=`cat container_id`
KEY=$(cat api_key)

if [ -z $CONTAINER_ID ]; then
	echo "ERROR: Container ID is not set!"
	exit 1
fi

echo "Container id is $CONTAINER_ID"

if [ -z $KEY ]; then
	echo "ERROR: API Key is not set!"
	exit 1
fi

# the target URL for ZAP to scan
for TARGET_URL in "$@"
do
	docker exec $CONTAINER_ID zap-cli -v --api-key $KEY -p 8080 status -t 120 && docker exec $CONTAINER_ID zap-cli -v --api-key $KEY -p 8080 open-url $TARGET_URL
	docker exec $CONTAINER_ID curl http://localhost:8080/JSON/httpSessions/view/sites/?apikey=$KEY
	docker exec $CONTAINER_ID zap-cli -v --api-key $KEY -p 8080 spider $TARGET_URL
	docker exec $CONTAINER_ID zap-cli -v --api-key $KEY -p 8080 active-scan -r $TARGET_URL
done

docker exec $CONTAINER_ID zap-cli -v --api-key $KEY -p 8080 alerts

docker exec $CONTAINER_ID zap-cli -v --api-key $KEY -p 8080 report -o /home/zap/report/report.html -f html
docker exec $CONTAINER_ID zap-cli -v --api-key $KEY -p 8080 report -o /home/zap/report/report.xml -f xml

# docker logs [container ID or name]
divider==================================================================
printf "\n"
printf "$divider"
printf "ZAP-daemon log output follows"
printf "$divider"
printf "\n"

docker logs $CONTAINER_ID

docker stop $CONTAINER_ID

