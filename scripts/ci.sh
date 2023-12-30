#!/usr/bin/env bash

set -euo pipefail

scriptDir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

cd "$scriptDir"/..

set -x

nix flake check -L
