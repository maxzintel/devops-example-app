#!/bin/bash

# A script that handles deploying to staging and production dynamically.
#!/bin/bash

# Halt this script on non-zero returns codes
# and properly pipe failures
set -eou pipefail

export APP=""
export IMAGE_REPO=""

export KUBECONFIG="$(pwd)/kubeconfig"
export AWS_REGION='us-east-1'
DCR_CMD="docker-compose -f docker-compose-ci.yml run --rm"
export LAST_DEPLOYED_COMMIT

main() {
    # Add function here to create git ancestry verification.

    build-static
    sync-static

    # Function here to determine which type of branch we are on and thus which vars to use when deploying.

    # Grab kubeconfig somehow

    echo -e "+++ :k8s: Initiating Deploy"
    k8s_deploy

    echo -e "+++ :k8s: Monitor Rollout"
    kubectl rollout status "deployment/${DEPLOY_RELEASE}-web"
    kubectl rollout status "deployment/${DEPLOY_RELEASE}-worker"
    kubectl rollout status "deployment/${DEPLOY_RELEASE}-redis"
}

k8s_deploy() {
    echo -e "+++ :k8s: Deploy Env."

    pushd "kube/overlays/${DEPLOY_ENVIRONMENT}/"
    kustomize edit set image "${IMAGE_REPO}=:${IMAGE_TAG}"
    kustomize edit set nameprefix "${DEPLOY_RELEASE}-"
    kustomize edit add label -f release:${DEPLOY_RELEASE}
    kustomize edit add label -f environment:staging
    kustomize edit add label -f app:${APP}

    # get app secrets, output to temp secrets-gen file we look at in kustomization.yaml
     > secrets-gen.env

    # inject necessary dynamic vals to the configmap
    cat >>config-gen.env <<- EOF
		ENVIRONMENT=staging-${ENV_ID}
	EOF
    popd

    # build + apply manifest
    kustomize build "kube/overlays/${DEPLOY_ENVIRONMENT}/" | kubectl apply -f -
}

main