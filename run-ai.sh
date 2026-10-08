#!/bin/bash

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
  echo "Usage: $0 <ports> <grafana-endpoint> <tempo-mcp-endpoint> [extra JVM args...]"
  echo "  ports:              comma-separated list of app ports, e.g. 8081,8082"
  echo "  grafana-endpoint:   Grafana URL, e.g. http://localhost:3000"
  echo "  tempo-mcp-endpoint: Tempo MCP URL, e.g. http://localhost:3200"
  exit 1
fi

PORTS=$1
GRAFANA_ENDPOINT=$2
TEMPO_MCP_ENDPOINT=$3
shift 3

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
JAR=$(find "$SCRIPT_DIR/ai/target" -name "telemetry-ai-core-*-runner.jar" -not -name "*sources*" | head -1)

if [ -z "$JAR" ]; then
  echo "Runner jar not found in ai/target/. Build first: ./mvn.ai.sh package -DskipTests"
  exit 1
fi

java -Dapp.ports="$PORTS" -Dgrafana.endpoint="$GRAFANA_ENDPOINT" -Dtempo-mcp.endpoint="$TEMPO_MCP_ENDPOINT" "$@" -jar "$JAR"
