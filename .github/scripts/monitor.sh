#!/bin/bash

set -eou pipefail

export KUBECONFIG="$(pwd)/kubeconfig"

aws eks update-kubeconfig --name ${ENV} --role arn:aws:iam::798792373271:role/Admin --kubeconfig $KUBECONFIG

ROLLED_BACK="False"

export TIME=0
while [ $TIME -le 30 ]; do
    echo "waiting for 10s..."
    sleep 10
    export TIME=$(( $TIME + 10 ))
    deployments=$(kubectl get deployments --no-headers -o custom-columns=":metadata.name")
    echo "====== $(date) ======"
    for deployment in ${deployments}; do
        if ! kubectl rollout status deployment ${deployment} --timeout=10s 1>/dev/null 2>&1; then
            echo "Error: ${deployment} - rolling back!"
            kubectl rollout undo deployment ${deployment}
            export ROLLED_BACK="True"
        else
            echo "Ok: ${deployment}"
        fi
    done
done

if [ $ROLLED_BACK == "True" ]; then
  echo "== A ROLLBACK OCCURRED. FORCING FAILURE OF PIPELINE FOR VISIBILITY. =="
  exit 1
fi
