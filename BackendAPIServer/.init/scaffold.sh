#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/an-infinite-canvas-unpainted-12-87/BackendAPIServer"
cd "$WS"
PKG_MGR=$(cat "$WS/.pkg_mgr" 2>/dev/null || echo npm)
# consider workspace empty if no package.json and no src/ directory
if [ -f package.json ]; then HAS_PKG=1; else HAS_PKG=0; fi
if [ -d src ]; then HAS_SRC=1; else HAS_SRC=0; fi
if [ "$HAS_PKG" -eq 0 ] && [ "$HAS_SRC" -eq 0 ]; then IS_EMPTY=1; else IS_EMPTY=0; fi
# detect typescript files
USE_TS=0
[ -n "$(find "$WS" -maxdepth 4 -name '*.ts' -o -name '*.tsx' -print -quit 2>/dev/null)" ] && USE_TS=1
TEMPLATE_ARG=""
[ "$USE_TS" -eq 1 ] && TEMPLATE_ARG="--template typescript"
if [ "$IS_EMPTY" -eq 1 ]; then
  # prefer local/global create-react-app
  if command -v create-react-app >/dev/null 2>&1; then
    if [ "$PKG_MGR" = "yarn" ]; then
      yarn create react-app . $TEMPLATE_ARG --silent >/tmp/scaffold_cra.log 2>&1 || { tail -n 200 /tmp/scaffold_cra.log 2>/dev/null || true; echo 'CRA failed' >&2; exit 11; }
    else
      create-react-app . $TEMPLATE_ARG >/tmp/scaffold_cra.log 2>&1 || { tail -n 200 /tmp/scaffold_cra.log 2>/dev/null || true; echo 'CRA failed' >&2; exit 11; }
    fi
  elif [ -x node_modules/.bin/create-react-app ]; then
    ./node_modules/.bin/create-react-app . $TEMPLATE_ARG >/tmp/scaffold_cra.log 2>&1 || { tail -n 200 /tmp/scaffold_cra.log 2>/dev/null || true; echo 'CRA failed' >&2; exit 11; }
  else
    # fallback to npx/dlx which may fetch remotely
    if [ "$PKG_MGR" = "yarn" ]; then
      # yarn dlx exists in yarn modern; if not available, fall back to npx
      if command -v yarn >/dev/null 2>&1 && yarn -v >/dev/null 2>&1; then
        yarn dlx create-react-app . $TEMPLATE_ARG --silent >/tmp/scaffold_cra.log 2>&1 || { tail -n 200 /tmp/scaffold_cra.log 2>/dev/null || true; echo 'CRA via dlx failed' >&2; exit 11; }
      else
        npx --yes create-react-app . $TEMPLATE_ARG >/tmp/scaffold_cra.log 2>&1 || { tail -n 200 /tmp/scaffold_cra.log 2>/dev/null || true; echo 'CRA via npx failed' >&2; exit 11; }
      fi
    else
      npx --yes create-react-app . $TEMPLATE_ARG >/tmp/scaffold_cra.log 2>&1 || { tail -n 200 /tmp/scaffold_cra.log 2>/dev/null || true; echo 'CRA via npx failed' >&2; exit 11; }
    fi
  fi
else
  # non-empty: ensure package.json exists, but do not overwrite existing fields
  if [ ! -f package.json ]; then
    if [ "$PKG_MGR" = "yarn" ]; then
      yarn init -y >/dev/null 2>&1 || { echo 'yarn init failed' >&2; exit 12; }
    else
      npm init -y >/dev/null 2>&1 || { echo 'npm init failed' >&2; exit 12; }
    fi
  fi
fi
chmod -R a+rw "$WS" || true
