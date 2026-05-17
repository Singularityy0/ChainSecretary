#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ -f "setup.sh" ]; then
	echo "Running setup.sh..."
	bash setup.sh
fi

npm install --silent --no-save --no-package-lock --no-audit --no-fund jest@29 ts-jest@29 typescript@5 @types/jest@29 @types/node

npx jest --ci --runInBand --config '{"transform":{"^.+\\.tsx?$":"ts-jest"},"testEnvironment":"node","testMatch":["<rootDir>/test/**/*.spec.ts"],"moduleFileExtensions":["ts","js","json"],"roots":["<rootDir>/test"]}'
