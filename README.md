# Max's CRE/DevOps Trial Project

Firstly, I would like to say thank you for taking a look at my work. This entire interview process has been an incredible learning experience; an opportunity to learn GitHub Actions, deploy an application from scratch without any pre-built patterns or infrastructure in place, and thus solve some problems I have not yet had experience with.

Secondly, another thank you. I know this has taken a couple weeks due to my crazy schedule, so I truly appreciate your understanding throughout the process.

Below I will reiterate the requirements of this project, describe how I fulfilled each of those, and discuss improvements I would make given more time.

## Requirements

A brief description of the requirements, I will go into more detail in the following sections.

1. Application deployed needs to have some form of external state, a database
or cache. *Used sample application with **both** a database and cache*.
2. On each commit to master, the application is built
then deployed via any deployment approach. *See GitHub Actions in `.github/workflows/`.*
3. If the application fails to build or errors, then a rollback is performed. *See `.github/scripts/monitor.sh` implemented in `.github/workflows/pipeline-production.yaml`.*
4. The audit history of build & deployments has to be visible in GIT, to allow for
auditable history. *This is tracked on the Actions screen in the GitHub UI.*
5. All the dependent deployment of infrastructure has to be
managed in code. - Deployment of the application has to be
publicly reachable. *Please see my other repository, `maxzintel/chainlink-infra` for the Infrastructure as Code & the frontend site: client.quantumwerke.com.*

### Stretch Goals

1. Automated Staging Deployments. *Described further below*.
2. Any dependent infrastructure changes are also applied as part of any pull
request. *Not implemented due to scope and time constraints.*

## Project Overview

As mentioned above, I used the sample application from the beginning of my technical assessments. It is publicly reachable at client.quantumwerke.com.

I did not make any changes to the application code itself, all of my changes reside in the `.github` folder, `kube` folder, and in this README. I will describe the contents of each below.

### The `.github` Directory

This is where the CI/CD lives. Lets first talk about the `workflows` folder, specifically the `pipeline-production.yml` therein since it fulfills requirements (2), (3), and (4). 

Since we use open source images for Redis and Postgres locally, it was logical for this pipeline to focus solely on building the Client and Server docker images for the moment. If we were to add automated tests for the applications however, we would want to implement a CI docker-compose.yml that automates building all four images within the build job so as to include tests relevant to Redis and Postgres.

The Build job checks out the repository, sets up the docker build action, logs in to Docker Hub, and then builds & pushes each image to Docker Hub. At the moment the build steps for the Client and Server are tightly coupled, which is likely not optimal. In the case where there is, for example, a frontend feature team and backend feature team working on this code base, it would make more sense to decouple them in the following ways:

* Option 1: Keep them in the same repository, but decouple the workflows so changes to the Client code triggers only a build, push, and deploy of the new Client image. You could do this with the GitHub Action feature `on.push.paths["client/**"]`. You'd do the same for the Server code. This way, you save money & time on CI/CD without significant changes to how these services are structured and tested in tandem.
* Option 2: Break them out into separate repositories. This obviously decouples them entirely, and would prevent CI/CD congestion during high development hours, but would require a more significant restructure of the codebase(s) to ensure proper testing. I would likely do this by having a mirror of the main branch that can be tested against in the staging environment such that for a given change PR for the Client repository, a staging deployment would be automatically deployed alongside a the latest Server image running in production (though we would obviously have separate stateful resources for the staging Server deployments to read and write to - more on this later).

The Deploy job requires the Build job to successfully complete before it runs, thus preventing deployment of code that would not build successfully. It then checks out our codebase (and since we have to do this so frequently, it would be interesting to figure out if there's a way to set something like `beforeEach` in GitHub actions that says to always check out the code at the beginning of each job), then  grabs our AWS Credentials from the repository secrets, and finally runs our deploy & monitor scripts.

As a note, the AWS Credentials here are for a Generic Admin role. This is bad. For everything RBAC/IAM, we always want to follow the principal of **Least Privilege** - something I did not do anywhere in this project except I believe the TerraformStateManager role. This was one area where I saved some time and reduced scope for this project but would never do for a real project. In reality, I would create a module in Terraform that creates application specific IAM roles for use in these deployment scripts. This has many benefits, but mainly increases security and improves our ability to audit our environment as it is more clear where and when a given role should be used.

The Deploy script (`.github/scripts/deploy.sh`) is pretty straightforward and designed to work dynamically for either our Staging or Production deployments. First, we grab our kubeconfig to configure access to our cluster. Then we use some of the environment variables we set in the workflow spec to set the image, nameprefix (`chainlink-production` for production deploys and `chainlink-pr${PR_NUM}` for staging), and labels named release, environment, and app to allow for easy searching and filtering when interacting with the Kubernetes API. After that we create a temporary secrets-gen.env file (that we will later use to dynamically inject application secrets into K8s) and have a quick conditional that normally would not need to be here, but since Staging deployments are not implemented at the moment I set this up so you can see what the Kubernetes manifests would look like for a Staging deploy.

The last piece of our production pipeline (`.github/scripts/monitor.sh`) is responsible for monitoring our deployments and rolling back deployed resources to the last version in case we have an application error soon after the deploy. This is a very simple implementation for the moment and can definitely be improved. For now, it looks at all deployments in the `default` namespace in our cluster (so here, the client, server, and redis deployments), and if it sees an Error status will 'undo' the most recent rollout to that deployment. An easy way to test this is going to `kube/bases/server/deployment.yaml` and changing the `command:` from `yarn start` to something non-functional, like `yarn foo`. Then merge that to `main`. What will happen is the Kubernetes manifests will properly build and apply, but as soon as it tries its startup command it will `Error` and begin to crashloop. When the script sees that, it logs it in the Action console, rolls back the deployment, and `exit 1` to draw attention to the issue.

Some ways to improve this:

* Add this to staging deploys as well so it is caught by devs earlier.
* Only monitor for the specific deploys handled in the workflow.
* Add liveness and readiness probes to the deployments to better inform the Kubernetes API when a pod is unhealthy.
* Figure out how to fully revert the merge to main. There may be a third-party workflow for this built already, but basically you'd need to capture every commit from the last rollout that was not on main before, trigger a revert PR given those commits, and automatically merge it.
* Trigger an alert to Slack and/or PagerDuty to draw further attention to the issue.
 
### The `kube` Directory

Imperative construction of pipeline files to maintain DRY and composable code.



- Staging Deployment Description
- Decouple the Repo (Client and Server) to mitigate build congestion
   - Seperating pipelines.
- Make action pipelines more DRY
- Figure out how to get the Server connected to ElastiCache
- Figure out how to automate full revert PR's
