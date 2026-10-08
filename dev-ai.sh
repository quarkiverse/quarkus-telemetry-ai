#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 <ports> [extra Maven args...]"
  echo "  ports: comma-separated list of app ports, e.g. 8081,8082"
  exit 1
fi

PORTS=$1
shift

./mvnw quarkus:dev --projects :telemetry-ai-core --also-make -DskipCompanion -Dapp.ports="$PORTS" "$@"
