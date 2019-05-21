#!/bin/bash
set -euo pipefail

CONFIG_PATH=''
BROKERS=''
SECRET_ID=''

show_usage() {
  echo "Usage: visualization.sh --config <config_path>"
  echo "Config should be in the following format, then base64 encoded:\n"
  echo "BROKERS=myeventhubnamespace.servicebus.windows.net:9093"
  echo "SECRET_ID=https://mykeyvault.vault.azure.net/secrets/mysecret/myversion"
  echo "GF_AUTH_GENERIC_OAUTH_CLIENT_ID=11111111-1111-1111-1111-1111111111"
  echo "GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=aaaabbbbccccdddd"
  echo "GF_SERVER_ROOT_URL=https://vm-12345.westus2.cloudapp.azure.com"
  echo "GF_AUTH_GENERIC_OAUTH_AUTH_URL=https://login.microsoftonline.com/22222222-2222-2222-2222222222/oauth2/authorize"
  echo "GF_AUTH_GENERIC_OAUTH_TOKEN_URL=https://login.microsoftonline.com/22222222-2222-2222-2222222222/oauth2/token"
}

parse_arguments() {
  PARAMS=""
  while (( $# )); do
    case "$1" in
      -h|--help)
        show_usage
        exit 0
        ;;
      -c|--config)
        CONFIG_PATH=$2
        shift 2
        ;;
      --)
        shift
        break
        ;;
      -*|--*)
        echo "Unsupported flag $1" >&2
        exit 1
        ;;
      *)
        PARAMS="$PARAMS $1"
        shift
        ;;
    esac
  done
}

validate_arguments() {
  if [[ -z $CONFIG_PATH ]]; then
    show_usage
    exit 1
  fi

  CONFIG=$(cat $CONFIG_PATH | base64 -d)
  eval $CONFIG

  if [[ -z $BROKERS || -z $SECRET_ID ]]; then
    show_usage
    exit 1
  fi
}

start() {
    # Retrieve secrets for pipeline
    az login --identity --allow-no-subscriptions
    export PIPELINE_EH_BROKERS=$BROKERS
    export PIPELINE_EH_CONNSTRING=`az keyvault secret show --id $SECRET_ID --query value --output tsv`

    # Append grafana variables to grafana-server
    grafana_server_file=/etc/sysconfig/grafana-server
    if grep -q GF_* $grafana_server_file ; then
      echo "Skip appending Grafana AAD Environment variables"
    else
      echo "Appending Grafana AAD Environment variables"

      # Retreive secrets for Grafana AAD auth
      grafana_aad_secret=`az keyvault secret show --id $GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET_KV_ID --query value --output tsv`

      echo "GF_AUTH_GENERIC_OAUTH_CLIENT_ID=$GF_AUTH_GENERIC_OAUTH_CLIENT_ID" >> $grafana_server_file
      echo "GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=$grafana_aad_secret" >> $grafana_server_file
      echo "GF_SERVER_ROOT_URL=$GF_SERVER_ROOT_URL" >> $grafana_server_file
      echo "GF_AUTH_GENERIC_OAUTH_AUTH_URL=$GF_AUTH_GENERIC_OAUTH_AUTH_URL" >> $grafana_server_file
      echo "GF_AUTH_GENERIC_OAUTH_TOKEN_URL=$GF_AUTH_GENERIC_OAUTH_TOKEN_URL" >> $grafana_server_file

      # Restart grafana
      systemctl restart grafana-server.service
    fi

    # Launch pipeline
    touch /etc/pipeline/pipeline.log
    /etc/pipeline/pipeline -log=/etc/pipeline/pipeline.log -config=/etc/pipeline/pipeline.conf -pem=/etc/pipeline/pipeline.pem
}

parse_arguments "$@"
validate_arguments
start