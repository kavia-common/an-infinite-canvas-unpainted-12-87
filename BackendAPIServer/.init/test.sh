#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/an-infinite-canvas-unpainted-12-87/BackendAPIServer"
cd "$WS"
PKG_MGR=$(cat "$WS/.pkg_mgr" 2>/dev/null || echo npm)
mkdir -p src/__tests__ || true
[ -f src/__tests__/sanity.test.js ] || cat > src/__tests__/sanity.test.js <<'EOF'
test('sanity',()=>{expect(1+1).toBe(2)})
EOF
# if not CRA (react-scripts absent) ensure jest present using node exit codes
node -e "try{const j=require('./package.json'); if(j && j.dependencies && j.dependencies['react-scripts']) process.exit(0); if(j && ((j.devDependencies && j.devDependencies.jest) || (j.dependencies && j.dependencies.jest))) process.exit(0); process.exit(1);}catch(e){process.exit(1);}"
if [ $? -eq 1 ]; then
  if [ "$PKG_MGR" = "yarn" ]; then
    yarn add -D jest >/tmp/jest_install.log 2>&1 || { tail -n 200 /tmp/jest_install.log 2>/dev/null || true; echo 'jest install failed' >&2; exit 30; }
  else
    npm i -D jest --no-audit --no-fund >/tmp/jest_install.log 2>&1 || { tail -n 200 /tmp/jest_install.log 2>/dev/null || true; echo 'jest install failed' >&2; exit 30; }
  fi
fi
# run tests non-interactively with a timeout
export CI=1
if [ "$PKG_MGR" = "yarn" ]; then
  timeout 120s yarn test --silent --testPathPattern src/__tests__/sanity.test.js --watchAll=false || { echo 'tests failed' >&2; exit 31; }
else
  timeout 120s npm test --silent -- --testPathPattern src/__tests__/sanity.test.js --watchAll=false || { echo 'tests failed' >&2; exit 31; }
fi
