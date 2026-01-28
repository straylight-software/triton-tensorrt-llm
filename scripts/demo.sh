#!/usr/bin/env bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#                                                              // demo.sh
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#
# Demo script for triton-tensorrt-llm
#
# Starts:
#   - OpenAI Proxy (port 9000) - points to external Triton or mock
#   - Open WebUI (port 3000) - chat interface
#   - Tool Server (port 9001) - code sandbox + attestation
#
# Usage:
#   nix run .#demo
#   nix run .#demo -- --triton-url http://gpu-server:8000
#
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

set -euo pipefail

# Defaults
TRITON_URL="${TRITON_URL:-http://localhost:8000}"
OPENAI_PROXY_PORT="${OPENAI_PROXY_PORT:-9000}"
TOOL_SERVER_PORT="${TOOL_SERVER_PORT:-9001}"
OPEN_WEBUI_PORT="${OPEN_WEBUI_PORT:-3000}"
MODEL_NAME="${MODEL_NAME:-qwen3}"

# Parse args
while [[ $# -gt 0 ]]; do
  case $1 in
    --triton-url)
      TRITON_URL="$2"
      shift 2
      ;;
    --model)
      MODEL_NAME="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: demo.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --triton-url URL   Triton server URL (default: http://localhost:8000)"
      echo "  --model NAME       Model name (default: qwen3)"
      echo ""
      echo "Environment:"
      echo "  TRITON_URL         Same as --triton-url"
      echo "  OPENAI_PROXY_PORT  OpenAI proxy port (default: 9000)"
      echo "  TOOL_SERVER_PORT   Tool server port (default: 9001)"
      echo "  OPEN_WEBUI_PORT    Open WebUI port (default: 3000)"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Banner
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  triton-tensorrt-llm demo"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Model:        $MODEL_NAME"
echo "  Triton:       $TRITON_URL"
echo ""
echo "  Starting services..."
echo ""

# Cleanup on exit
cleanup() {
  echo ""
  echo "Shutting down..."
  kill $PROXY_PID $TOOL_PID $WEBUI_PID 2>/dev/null || true
  wait 2>/dev/null || true
  echo "Done."
}
trap cleanup EXIT

# Start OpenAI Proxy
echo "  [1/3] OpenAI Proxy on :$OPENAI_PROXY_PORT"
TRITON_URL="$TRITON_URL" \
MODEL_NAME="$MODEL_NAME" \
OPENAI_PROXY_PORT="$OPENAI_PROXY_PORT" \
@openaiProxy@/bin/openai-proxy-hs &
PROXY_PID=$!

# Start Tool Server
echo "  [2/3] Tool Server on :$TOOL_SERVER_PORT"
TOOL_SERVER_PORT="$TOOL_SERVER_PORT" \
@toolServer@/bin/tool-server &
TOOL_PID=$!

# Start Open WebUI
echo "  [3/3] Open WebUI on :$OPEN_WEBUI_PORT"
OPENAI_API_BASE_URL="http://localhost:$OPENAI_PROXY_PORT/v1" \
OPENAI_API_KEY="not-needed" \
WEBUI_AUTH="False" \
PORT="$OPEN_WEBUI_PORT" \
@openWebUI@/bin/open-webui serve &
WEBUI_PID=$!

# Wait for startup
sleep 2

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Services running!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Open WebUI:    http://localhost:$OPEN_WEBUI_PORT"
echo "  OpenAI API:    http://localhost:$OPENAI_PROXY_PORT/v1/chat/completions"
echo "  Tool Server:   http://localhost:$TOOL_SERVER_PORT"
echo "  OpenAPI Spec:  http://localhost:$TOOL_SERVER_PORT/openapi.json"
echo ""
echo "  Press Ctrl+C to stop"
echo ""

# Wait for all processes
wait
