#!/bin/bash

# A script that handles deploying to staging and production dynamically.

# Halt this script on non-zero returns codes
# and properly pipe failures

export AWS_REGION='us-east-1'
export LAST_DEPLOYED_COMMIT

main() {
    # Add function here to create git ancestry verification.

    # Function here to determine which type of branch we are on and thus which vars to use when deploying.

    # Grab kubeconfig somehow
    aws eks update-kubeconfig --name $ENV --role arn:aws:iam::798792373271:role/Admin

    echo -e "+++ :k8s: Initiating Deploy"
    k8s_deploy

    # echo -e "+++ :k8s: Monitor Rollout"
    # kubectl rollout status "deployment/${DEPLOY_RELEASE}-server"
}

k8s_deploy() {
    echo -e "+++ :k8s: Deploy Env."
    echo ${ENV}
    cd "kube/overlays/${ENV}/"
    kustomize edit set image "${IMAGE_REPO}=:${IMAGE_TAG}"
    kustomize edit set nameprefix "${DEPLOY_RELEASE}-"
    kustomize edit add label -f release:${DEPLOY_RELEASE}
    kustomize edit add label -f environment:staging
    kustomize edit add label -f app:${APP}

    # get app secrets, output to temp secrets-gen file we look at in kustomization.yaml
    #  > secrets-gen.env

    # inject necessary dynamic vals to the configmap
    # cat >>config-gen.env <<- EOF
	# 	ENVIRONMENT=staging-${ENV_ID}
	# EOF
    # popd
    cd -
    # build + apply manifest
    kustomize build "kube/overlays/${ENV}/" # | kubectl apply -f -
}

main