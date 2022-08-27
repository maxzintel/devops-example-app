#!/bin/bash

# Halt this script on non-zero returns codes
# and properly pipe failures
set -eou pipefail

# A script that handles deploying to staging and production dynamically.

export AWS_REGION='us-east-1'
export LAST_DEPLOYED_COMMIT
export KUBECONFIG="$(pwd)/kubeconfig"

main() {
    # Grab kubeconfig. NOTE AWS Account number would be dynamic when we setup Staging.
    aws eks update-kubeconfig --name ${ENV} --role arn:aws:iam::798792373271:role/Admin --kubeconfig $KUBECONFIG

    echo -e "== Initiating Deploy =="
    k8s_deploy
}

k8s_deploy() {
    cd "kube/bases/server/"
    kustomize edit set image "${IMAGE_REPO_SERVER}=:${IMAGE_TAG}"
    cd -
    cd "kube/bases/client/"
    kustomize edit set image "${IMAGE_REPO_CLIENT}=:${IMAGE_TAG}"
    cd -
    cd "kube/overlays/${ENV}/"
    kustomize edit set nameprefix "${DEPLOY_RELEASE}-"
    kustomize edit add label -f release:${DEPLOY_RELEASE}
    kustomize edit add label -f environment:${ENV}
    kustomize edit add label -f app:${APP}

    # get app secrets, output to temp secrets-gen file we look at in kustomization.yaml

    # TRY USING THE REDIS CONFIG IN THIS REPO!
    # REDIS_HOST=${ELASTICACHE_ENDPOINT}/0

    cat >>secrets-gen.env <<- EOF
        REDIS_HOST=${DEPLOY_RELEASE}-redis
        TYPEORM_HOST=${RDS_ENDPOINT}
        TYPEORM_USERNAME=${RDS_UN}
        TYPEORM_PASSWORD=${RDS_PW}
	EOF

    # inject necessary dynamic vals to the configmap(s)
    # cat >>client-config-gen.env <<- EOF
	# 	REACT_APP_BACKEND_URL=${REACT_BACKEND_URL}
	# EOF
    cd -
    # build + apply manifest
    # IF we are deploying to production, run kubectl apply.
    # Else, this is staging, and we just want to output the manifests for now.
    if [[ ${DEPLOY_RELEASE:-x} == "chainlink-production" ]]; then
        kustomize build "kube/overlays/${ENV}/" | kubectl apply -f -
    else 
        kustomize build "kube/overlays/${ENV}/"
    fi
}

main