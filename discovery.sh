#!/usr/bin/env bash

#### Dynamic AWS EC2 Prometheus discovery for file_sd_config via AWS Tags:
#### e.g. Key: prom/scrape:9100/metrics Value: node_exporter
#### It's more flexible then the aws_sd_config as it allows to set dynamically the number of scrapes per instance and requires no static port (count) configuration.

#### ec2 tag pattern:
#### Key: prom/scrape:<port>/<metrics_path>
#### Value: <name>
#### e.g. Key: prom/scrape:9100/metrics Value: node_exporter

#### There must be one tag with Key: "Name" and a value
#### Currently it takes only privateIpAddress, this can be changed to a non privateIpAddress

#### [ {"PrivateIpAddress": "", "Tags": [{"Key": "", "Value": ""}] } ]
instances=$(aws ec2 describe-instances --filters 'Name=tag-key,Values=prom/scrape*' --query "Reservations[*].Instances[*].{PrivateIpAddress:PrivateIpAddress,Tags:Tags}" --output json | jq '.[0] // []')

fileSdConfig="[]"

for row in $(echo "${instances}" | jq -r '.[] | @base64'); do
    _jq() {
     echo ${row} | base64 --decode | jq -r ${1}
    }

    ip=$(_jq '.PrivateIpAddress')
    tags=$(_jq '.Tags')
    filteredTags="$(echo "${tags}" | jq -c '[ .[] | select(.Key|test("prom/scrape.")) ]')"
    instanceName=$(echo ${tags} | jq '.[] | select(.Key | ascii_upcase=="NAME") | .Value ' -r)

    >&2 echo "[DEBUG] (`date '+%Y-%m-%d %H:%M:%S'`) - InstanceName:   ${instanceName}"
    for k in $(echo ${filteredTags} | jq '. | keys | .[]'); do
      tagKey=$(echo "${filteredTags}" | jq ".[${k}]" | jq ".Key" -r)
      tagValue=$(echo "${filteredTags}" | jq ".[${k}]" | jq ".Value" -r)

      portPath=$(echo ${tagKey//prom\/scrape:/})
      path="/$(echo "${portPath}" | cut -d/ -f2-)"
      port=$(echo "${portPath}" | cut -d/ -f1)
      address="${ip}:${port}"

      >&2 echo "[DEBUG] (`date '+%Y-%m-%d %H:%M:%S'`) - Name:           ${tagValue}"
      >&2 echo "[DEBUG] (`date '+%Y-%m-%d %H:%M:%S'`) - Port:           ${port}"
      >&2 echo "[DEBUG] (`date '+%Y-%m-%d %H:%M:%S'`) - Path:           ${path}"
      >&2 echo "[DEBUG] (`date '+%Y-%m-%d %H:%M:%S'`) - IP:             ${ip}"
      >&2 echo "[DEBUG] (`date '+%Y-%m-%d %H:%M:%S'`) - Scrape:         http://${ip}:${port}${path}"

      fileSdConfig=$(echo "${fileSdConfig}" | jq ". |= . + [{\"targets\": [\"${address}\"], \"labels\": {\"instanceName\": \"${instanceName}\", \"instanceIp\": \"${ip}\", \"name\": \"${tagValue}\", \"__metrics_path__\": \"${path}\", \"__address__\": \"${address}\"}}]")
    done
done

>&2 echo "[DEBUG] (`date '+%Y-%m-%d %H:%M:%S'`) - Update configmap:    ${CONFIGMAP_NAME}"
>&2 echo "[DEBUG] (`date '+%Y-%m-%d %H:%M:%S'`) - Update namespace:    ${CONFIGMAP_NAMESPACE}"
>&2 echo "[DEBUG] (`date '+%Y-%m-%d %H:%M:%S'`) - Update field:        ${CONFIGMAP_FIELD}"

kubectl get configmap ${CONFIGMAP_NAME} --namespace ${CONFIGMAP_NAMESPACE} -o json \
        | jq --arg key "${CONFIGMAP_FIELD}" --arg value "${fileSdConfig}" '.data[$key] = $value' \
        | kubectl apply --namespace ${CONFIGMAP_NAMESPACE} -f -
