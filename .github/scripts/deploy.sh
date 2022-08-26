#!/bin/bash

# A script that handles deploying to staging and production dynamically.

# Halt this script on non-zero returns codes
# and properly pipe failures

export AWS_REGION='us-east-1'
export LAST_DEPLOYED_COMMIT
export KUBECONFIG="($pwd)/kubeconfig"

main() {
    # Add function here to create git ancestry verification.

    # Function here to determine which type of branch we are on and thus which vars to use when deploying.

    # Grab kubeconfig somehow
    aws eks update-kubeconfig --name production --role arn:aws:iam::798792373271:role/Admin --kubeconfig $KUBECONFIG

    echo -e "+++ :k8s: Initiating Deploy"
    k8s_deploy

    echo -e "+++ :k8s: Monitor Rollout"
    kubectl rollout status "deployment/${DEPLOY_RELEASE}-server"
    kubectl rollout status "deployment/${DEPLOY_RELEASE}-client"
    kubectl rollout status "deployment/${DEPLOY_RELEASE}-redis"
}

k8s_deploy() {
    echo -e "+++ :k8s: Deploy Env."
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