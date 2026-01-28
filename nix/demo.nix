# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#                                                                  // demo.nix
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#
# Demo script that runs the full stack:
#   - OpenAI Proxy (port 9000)
#   - Tool Server (port 9001)
#   - Open WebUI (port 3000)
#
# Usage:
#   nix run .#demo
#   nix run .#demo -- --triton-url http://gpu-server:8000
#
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{ writeShellApplication
, openai-proxy
, tool-server
, open-webui
}:

writeShellApplication {
  name = "triton-trtllm-demo";
  
  runtimeInputs = [ openai-proxy tool-server open-webui ];
  
  text = ''
    # Defaults
    TRITON_URL="''${TRITON_URL:-http://localhost:8000}"
    OPENAI_PROXY_PORT="''${OPENAI_PROXY_PORT:-9000}"
    TOOL_SERVER_PORT="''${TOOL_SERVER_PORT:-9001}"
    OPEN_WEBUI_PORT="''${OPEN_WEBUI_PORT:-3000}"
    MODEL_NAME="''${MODEL_NAME:-qwen3}"

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
        --proxy-only)
          PROXY_ONLY=1
          shift
          ;;
        --help|-h)
          echo "Usage: triton-trtllm-demo [OPTIONS]"
          echo ""
          echo "Starts OpenAI Proxy + Tool Server + Open WebUI"
          echo ""
          echo "Options:"
          echo "  --triton-url URL   Triton server URL (default: http://localhost:8000)"
          echo "  --model NAME       Model name (default: qwen3)"
          echo "  --proxy-only       Only start the proxy (no WebUI/Tool Server)"
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

    # Array to track PIDs
    PIDS=()

    # Cleanup on exit
    cleanup() {
      echo ""
      echo "Shutting down..."
      for pid in "''${PIDS[@]}"; do
        kill "$pid" 2>/dev/null || true
      done
      wait 2>/dev/null || true
      echo "Done."
    }
    trap cleanup EXIT INT TERM

    # Start OpenAI Proxy
    echo "  [1/3] OpenAI Proxy on :$OPENAI_PROXY_PORT"
    TRITON_URL="$TRITON_URL" \
    MODEL_NAME="$MODEL_NAME" \
    OPENAI_PROXY_PORT="$OPENAI_PROXY_PORT" \
    openai-proxy-hs &
    PIDS+=($!)

    if [[ -z "''${PROXY_ONLY:-}" ]]; then
      # Start Tool Server
      echo "  [2/3] Tool Server on :$TOOL_SERVER_PORT"
      TOOL_SERVER_PORT="$TOOL_SERVER_PORT" \
      tool-server &
      PIDS+=($!)

      # Start Open WebUI
      echo "  [3/3] Open WebUI on :$OPEN_WEBUI_PORT"
      OPENAI_API_BASE_URL="http://localhost:$OPENAI_PROXY_PORT/v1" \
      OPENAI_API_KEY="not-needed" \
      WEBUI_AUTH="False" \
      ENABLE_SIGNUP="False" \
      DATA_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/open-webui" \
      PORT="$OPEN_WEBUI_PORT" \
      open-webui serve &
      PIDS+=($!)
    fi

    # Wait for startup
    sleep 3

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Services running!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    if [[ -z "''${PROXY_ONLY:-}" ]]; then
      echo "  Open WebUI:    http://localhost:$OPEN_WEBUI_PORT"
    fi
    echo "  OpenAI API:    http://localhost:$OPENAI_PROXY_PORT/v1/chat/completions"
    if [[ -z "''${PROXY_ONLY:-}" ]]; then
      echo "  Tool Server:   http://localhost:$TOOL_SERVER_PORT"
      echo "  OpenAPI Spec:  http://localhost:$TOOL_SERVER_PORT/openapi.json"
    fi
    echo ""
    echo "  Press Ctrl+C to stop"
    echo ""

    # Wait for any process to exit
    wait
  '';
}
