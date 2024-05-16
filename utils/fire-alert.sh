#!/usr/bin/env bash

name=fooAlert-15509
#$RANDOM
url="${1}/api/v1/alerts"
bold=$(tput bold)
normal=$(tput sgr0)

generate_post_data() {
  cat <<EOF
[{
  "status": "$1",
  "labels": {
    "alertName": "${name}",
    "alertTargetHosts": "my-service",
    "severity":"warning",
    "alertMessage": "Test Alert $name"
  },
  "annotations": {
    "summary": "High latency is high!"
  },
  "generatorURL": "http://local-example-alert/$name"
  $2
  $3
}]
EOF
}

echo "${bold}Firing alert ${name} ${normal}"
printf -v startsAt ',"startsAt" : "%s"' $(date --rfc-3339=seconds | sed 's/ /T/')
POSTDATA=$(generate_post_data 'firing' "${startsAt}")
curl -v $url --data "$POSTDATA" #--trace-ascii /dev/stdout
echo -e "\n"

echo "${bold}Press enter to resolve alert ${name} ${normal}"
read

echo "${bold}Sending resolved ${normal}"
printf -v endsAt ',"endsAt" : "%s"' $(date --rfc-3339=seconds | sed 's/ /T/')
POSTDATA=$(generate_post_data 'resolved' "${startsAt}" "${endsAt}")
curl -v $url --data "$POSTDATA" #--trace-ascii /dev/stdout
echo -e "\n"
