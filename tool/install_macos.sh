#!/bin/bash
# Compatibility wrapper — matches the Starter Repo device-deploy SOP naming
# (deploy_{ios,android,macos}). Delegates to deploy_macos.sh.
exec "$(dirname "$0")/deploy_macos.sh" "$@"
