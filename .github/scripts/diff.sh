#!/bin/bash -e

path=$1

IFS='/' read -ra path_parts <<< "$path"

cluster=${path_parts[0]}
chart_name=${path_parts[1]}
namespace=${path_parts[1]}

if [[ "${#path_parts[@]}" != 2 ]]; then
  chart_name=${path_parts[2]}
fi

cd live || exit 1
echo " --> Building Helm dependencies in \`live\`"
helm dep update "$path"
resources_live=$(./script.sh template "$chart_name" "$cluster" production "$namespace" ignore-secrets)

cd ../pr || exit 1
echo " --> Building Helm dependencies in \`pr\`"
helm dep update "$path"
resources_pr=$(./script.sh template "$chart_name" "$cluster" production "$namespace" ignore-secrets)

if [ "$conf_ignore_known_labels_containing_versions" = "true" ]; then
  labels='.metadata.labels."helm.sh/chart"'
  labels+=',.metadata.labels.chart'
  labels+=',.metadata.labels."app.kubernetes.io/version"'
  labels+=',.spec.template.metadata.labels."helm.sh/chart"'
  labels+=',.spec.template.metadata.labels.chart'
  labels+=',.spec.template.metadata.labels."app.kubernetes.io/version"'
  labels+=',.spec.template.metadata.annotations."checksum/configuration"'
  labels+=',.spec.template.metadata.annotations."checksum/config"'
  labels+=',.spec.template.metadata.annotations."checksum/sc-dashboard-provider-config"'
  labels+=',.spec.template.metadata.annotations."checksum/secret"'
  labels+=',.spec.template.metadata.annotations."checksum/secrets"'
  labels+=',.spec.template.metadata.annotations."checksum/configmap"'
  labels+=',.spec.template.metadata.annotations."checksum/health"'
  labels+=',.spec.template.metadata.annotations."checksum/scripts"'
  labels+=',.spec.template.metadata.annotations."checksum/ojbstore-configuration"'
  labels+=',.spec.template.metadata.annotations."checksum/secret-file"'
  labels+=',.spec.template.metadata.annotations."checksum/worker-config"'
  labels+=',.spec.template.metadata.annotations."checksum/config-nginx"'
  labels+=',.. | select(select(has("name")).name == "CONFIG_CHECKSUM")'
  resources_live=$(echo "$resources_live" | yq e "del($labels)" -)
  resources_pr=$(echo "$resources_pr" | yq e "del($labels)" -)
fi

diff=$( (diff -u <(echo "$resources_live") <(echo "$resources_pr") || true) | tail +3)
echo "$diff"
message="Path: \`$path\`"
message="$message"$'\n'$'\n'
if [ -z "$diff" ]; then
  message="$message"'```'$'\n'"No changes in resources detected"$'\n''```'
else
  echo "::set-output name=changes::true"
  message="$message"'```diff'$'\n'"$diff"$'\n''```'
fi
echo "::set-output name=message::$(echo "$message" | jq --raw-input --slurp)"
