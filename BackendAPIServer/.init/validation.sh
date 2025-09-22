#!/usr/bin/env bash
set -euo pipefail
# Validation: build production, serve static build and verify HTTP with robust cleanup
WS="/home/kavia/workspace/code-generation/an-infinite-canvas-unpainted-12-87/BackendAPIServer"
cd "$WS"
# source safe defaults if present
[ -f /etc/profile.d/backendapi_env.sh ] && source /etc/profile.d/backendapi_env.sh || true
PORT=${PORT:-3000}
PKG_MGR=$(cat "$WS/.pkg_mgr" 2>/dev/null || (command -v yarn >/dev/null 2>&1 && echo yarn) || echo npm)
# ensure build script exists
node -e "try{const j=require('./package.json');if(!j.scripts||!j.scripts.build)process.exit(2);process.exit(0);}catch(e){process.exit(2);}" >/dev/null 2>&1 || { echo 'build script missing in package.json' >&2; exit 40; }
# run build
if [ "$PKG_MGR" = "yarn" ]; then
  yarn build > /tmp/build.log 2>&1 || { tail -n 200 /tmp/build.log 2>/dev/null || true; echo 'build failed' >&2; exit 41; }
else
  npm run build > /tmp/build.log 2>&1 || { tail -n 200 /tmp/build.log 2>/dev/null || true; echo 'build failed' >&2; exit 41; }
fi
[ -d build ] || { echo 'build directory missing' >&2; tail -n 200 /tmp/build.log 2>/dev/null || true; exit 42; }
# check port availability (ss preferred, lsof fallback)
if command -v ss >/dev/null 2>&1; then
  if ss -ltn "sport = :$PORT" | grep -q LISTEN; then echo "port $PORT in use" >&2; exit 43; fi
elif command -v lsof >/dev/null 2>&1; then
  if lsof -iTCP:$PORT -sTCP:LISTEN >/dev/null 2>&1; then echo "port $PORT in use" >&2; exit 43; fi
fi
LOG=$(mktemp /tmp/serve_build.XXXXXX)
PID_FILE=$(mktemp /tmp/serve_pid.XXXXXX)
cleanup(){
  PID=$(cat "$PID_FILE" 2>/dev/null || echo "")
  if [ -n "$PID" ]; then
    PGID=$(ps -o pgid= -p "$PID" 2>/dev/null | tr -d ' ' || echo "")
    if [ -n "$PGID" ]; then
      kill -TERM -"$PGID" >/dev/null 2>&1 || true
      sleep 1
      kill -KILL -"$PGID" >/dev/null 2>&1 || true
    else
      kill -TERM "$PID" >/dev/null 2>&1 || true
      sleep 1
      kill -KILL "$PID" >/dev/null 2>&1 || true
    fi
  fi
  rm -f "$PID_FILE" || true
}
trap 'cleanup' EXIT
# prefer project 'serve' if present in package.json
node -e "try{const j=require('./package.json');if((j.devDependencies&&j.devDependencies.serve)||(j.dependencies&&j.dependencies.serve))process.exit(0);process.exit(1);}catch(e){process.exit(1);}" >/dev/null 2>&1 || true
if [ $? -eq 0 ]; then
  if [ -x node_modules/.bin/serve ]; then
    (nohup node_modules/.bin/serve -s build -l "$PORT" >"$LOG" 2>&1 & echo $! > "$PID_FILE")
  else
    (nohup npx --yes serve -s build -l "$PORT" >"$LOG" 2>&1 & echo $! > "$PID_FILE")
  fi
else
  (cd build && nohup python3 -m http.server "$PORT" >"$LOG" 2>&1 & echo $! > "$PID_FILE")
fi
sleep 1
PID=$(cat "$PID_FILE" 2>/dev/null || echo "")
if [ -z "$PID" ]; then echo 'failed to start server' >&2; tail -n 200 "$LOG" 2>/dev/null || true; exit 44; fi
# probe endpoint with retries (curl then wget fallback)
TRIES=0; MAX=6; SLEEP=1; HTTP_STATUS=000
while [ $TRIES -lt $MAX ]; do
  if command -v curl >/dev/null 2>&1; then
    HTTP_STATUS=$(curl -s -o /tmp/serve_http_body -w "%{http_code}" "http://127.0.0.1:$PORT/" || echo 000)
  fi
  if [ "$HTTP_STATUS" = "000" ] && command -v wget >/dev/null 2>&1; then
    wget -q -O /tmp/serve_http_body "http://127.0.0.1:$PORT/" && HTTP_STATUS=200 || HTTP_STATUS=000
  fi
  [ "$HTTP_STATUS" = "200" ] && break
  TRIES=$((TRIES+1)); sleep $SLEEP; SLEEP=$((SLEEP*2))
done
if [ "$HTTP_STATUS" != "200" ]; then
  echo 'app did not respond with 200 within timeout' >&2
  echo "See $LOG and /tmp/build.log" >&2
  tail -n 200 "$LOG" 2>/dev/null || true
  exit 45
fi
# success evidence
echo "BUILD_DIR=$WS/build"
echo "SERVE_LOG=$LOG"
echo "HTTP_STATUS=$HTTP_STATUS"
echo "SERVE_PID=$PID"
# graceful cleanup will be handled by trap
exit 0
