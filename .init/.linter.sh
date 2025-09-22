#!/bin/bash
cd /home/kavia/workspace/code-generation/an-infinite-canvas-unpainted-12-87/BackendAPIServer
source venv/bin/activate
flake8 .
LINT_EXIT_CODE=$?
if [ $LINT_EXIT_CODE -ne 0 ]; then
  exit 1
fi

