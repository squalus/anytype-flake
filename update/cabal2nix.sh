#!/usr/bin/env bash
scriptDir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd "$scriptDir"
cabal2nix . > unwrapped.nix
