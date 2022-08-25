#!/bin/bash -e

SUB_CMD=$1
NAME=$2
CLUSTER=$3
ENV=$4
NAMESPACE=$5
IGNORE_SECRETS=$6

printUsage() {
  echo ""
  echo "Usage: script.sh <install|template> <NAME> [CLUSTER] [ENV] [NAMESPACE] [IGNORE_SECRETS]"
  echo "Usage: script.sh createns [CLUSTER]"
  echo ""
  echo "  Available actions:"
  echo "    i    install          (default) Installs the helm chart"
  echo "    d    diff             Shows a diff between the current version in the cluster and the new one"
  echo "    t    template         Prints the manifest that the 'install' command applies"
  echo "    cns  createns         Create all namespaces which have a directory in 'namespaces'"
  echo "    h    help             Prints this overview"
  echo ""
  echo "  Available clusters:"
  echo "  INFO: This option should only be used in combination with 'install' or 'template'!"
  echo "    m    main             (default) Use the 'main' directory"
  echo ""
  echo "  Available environments (env):"
  echo "  INFO: This option should only be used in combination with 'install' or 'template'!"
  echo "    p    production       (default) Doing a normal install or template"
  echo "    t    test             Adds test.values.yaml and secrets.test.values.yaml if the exists"
  echo ""
}

if [ -z "$SUB_CMD" ]; then
  printUsage
  exit 1
fi

CMD="helm secrets"

if [[ $SUB_CMD == "install" || $SUB_CMD == "i" ]]; then
  echo "# --> Action: Install chart"
  CMD="$CMD upgrade -i"

elif [[ $SUB_CMD == "diff" || $SUB_CMD == "d" ]]; then
  echo "# --> Action: Print chart template"
  CMD="$CMD diff upgrade"

elif [[ $SUB_CMD == "template" || $SUB_CMD == "t" ]]; then
  echo "# --> Action: Print chart template"
  CMD="$CMD template --include-crds"

elif [[ $SUB_CMD == "cns" || $SUB_CMD == "createns" ]]; then
  echo "# --> Action: Create namespaces"
  for D in main/*; do
    if [ -d "${D}" ]; then
      kubectl create namespace "${D:5}" || sleep 0
    fi
  done

  exit 0

else
  printUsage
  exit 0
fi

# This part will only be reached if the name is required
if [ -z "$NAME" ]; then
  printUsage
  exit 1
fi

if [ -z "$CLUSTER" ]; then
  CLUSTER="main"
fi

if [ "$CLUSTER" == "m" ]; then
  CLUSTER="main"
fi

if [[ -n "$NAMESPACE" ]] && [[ "$NAMESPACE" != "$NAME" || ! -f "$CLUSTER/$NAME/Chart.yaml" ]]; then
  DIR=$NAMESPACE/$NAME
else
  DIR=$NAME
  NAMESPACE=$NAME
fi

echo "# --> Chart: $NAME ($CLUSTER/$DIR)"

if [ ! -d "$CLUSTER/$DIR" ]; then
  echo "Could not find directory '$DIR' please make sure, that this directory exists in the '$CLUSTER' directory!"
  exit 1
fi

# Append deployment name, namespace and path to helm chart
CMD="$CMD $NAME -n $NAMESPACE $CLUSTER/$DIR"

FILES="values.yaml secrets.values.yaml values/values.yaml values/secrets.values.yaml"

for file in $FILES; do
  if [ -f "$CLUSTER/$DIR/$file" ]; then
    if [[ "$file" != *"secrets."* || -z "$IGNORE_SECRETS" ]]; then
      echo "# --> Using: $CLUSTER/$DIR/$file"
      CMD="$CMD -f $CLUSTER/$DIR/$file"
    else
      echo "# --> IGNORING: $CLUSTER/$DIR/$file"
    fi
  fi
done

if [[ $ENV == "t" || $ENV == "test" ]]; then
  TEST_FILES="test.values.yaml secrets.test.values.yaml values/test.values.yaml values/secrets.test.values.yaml"
  for file in $TEST_FILES; do
    if [ -f "$CLUSTER/$DIR/$file" ]; then
      if [[ "$file" != *"secrets."* || -z "$IGNORE_SECRETS" ]]; then
        echo "# --> Using: $CLUSTER/$DIR/$file"
        CMD="$CMD -f $CLUSTER/$DIR/$file"
      else
        echo "# --> IGNORING: $CLUSTER/$DIR/$file"
      fi
    fi
  done
fi

if [[ $SUB_CMD == "template" || $SUB_CMD == "t" ]]; then
  out=$($CMD)
  printf '%s\n' "$out" | sed '/^namespaces\/.*\.dec$/d'
else
  $CMD
fi
