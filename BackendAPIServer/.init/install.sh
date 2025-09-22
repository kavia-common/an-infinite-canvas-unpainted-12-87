#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/an-infinite-canvas-unpainted-12-87/BackendAPIServer"
cd "$WS"
PKG_MGR=$(cat "$WS/.pkg_mgr" 2>/dev/null || echo npm)
[ -f package.json ] || { echo 'package.json missing' >&2; exit 20; }
# inject only missing scripts using node with process.exit codes; preserve devDependencies
node -e "const f='package.json';const fs=require('fs');let j=JSON.parse(fs.readFileSync(f));j.scripts=j.scripts||{};if(!j.scripts.start)j.scripts.start='react-scripts start';if(!j.scripts.build)j.scripts.build='react-scripts build';if(!j.scripts.test)j.scripts.test='react-scripts test --watchAll=false';fs.writeFileSync(f,JSON.stringify(j,null,2));process.exit(0);" >/tmp/pkg_update.log 2>&1 || { tail -n 200 /tmp/pkg_update.log 2>/dev/null || true; echo 'package.json update failed' >&2; exit 21; }
# ensure eslint/prettier config exist
[ -f .eslintrc.json ] || cat > .eslintrc.json <<'EOF'
{"extends":["react-app","eslint:recommended"],"rules":{}}
EOF
[ -f .prettierrc ] || cat > .prettierrc <<'EOF'
{"singleQuote":true,"trailingComma":"none"}
EOF
# detect if 'serve' present using node exit code
node -e "try{const j=require('./package.json');if((j.devDependencies&&j.devDependencies.serve)||(j.dependencies&&j.dependencies.serve))process.exit(0);else process.exit(1);}catch(e){process.exit(1);}"
if [ $? -eq 1 ]; then
  if [ "$PKG_MGR" = "yarn" ]; then
    yarn add -D serve >/tmp/serve_add.log 2>&1 || { tail -n 200 /tmp/serve_add.log 2>/dev/null || true; echo 'yarn add serve failed' >&2; exit 22; }
  else
    npm i -D serve --no-audit --no-fund --silent >/tmp/serve_add.log 2>&1 || { tail -n 200 /tmp/serve_add.log 2>/dev/null || true; echo 'npm add serve failed' >&2; exit 22; }
  fi
fi
# perform install: handle lockfile compatibility and yarn v1 vs v2+
if [ "$PKG_MGR" = "yarn" ]; then
  YARN_V=$(yarn -v 2>/dev/null || echo "0")
  YARN_MAJOR=${YARN_V%%.*}
  if [ -f yarn.lock ] && [ "$YARN_MAJOR" -ge 1 ]; then
    # yarn v1 and v2+: prefer frozen lockfile if lock exists
    yarn install --frozen-lockfile --non-interactive > /tmp/deps_install.log 2>&1 || { tail -n 200 /tmp/deps_install.log 2>/dev/null || true; echo 'yarn install failed' >&2; exit 23; }
  else
    yarn install --non-interactive > /tmp/deps_install.log 2>&1 || { tail -n 200 /tmp/deps_install.log 2>/dev/null || true; echo 'yarn install failed' >&2; exit 23; }
  fi
else
  if [ -f package-lock.json ]; then
    npm ci --no-audit --no-fund --silent > /tmp/deps_install.log 2>&1 || { tail -n 200 /tmp/deps_install.log 2>/dev/null || true; echo 'npm ci failed' >&2; exit 24; }
  else
    npm i --no-audit --no-fund --silent > /tmp/deps_install.log 2>&1 || { tail -n 200 /tmp/deps_install.log 2>/dev/null || true; echo 'npm install failed' >&2; exit 25; }
  fi
fi
