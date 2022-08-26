#!/bin/bash
set -eou pipefail

while true; do
    sleep 20
    deployments=$(kubectl get deployments --no-headers -o custom-columns=":metadata.name")
    echo "====== $(date) ======"
    for deployment in ${deployments}; do
        if ! kubectl rollout status deployment ${deployment} --timeout=10s 1>/dev/null 2>&1; then
            echo "Error: ${deployment} - rolling back!"
            kubectl rollout undo deployment ${deployment}
        else
            echo "Ok: ${deployment}"
        fi
    done
done