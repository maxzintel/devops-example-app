# DevOps Example

**Table of Contents:**

* Requirements
  * Stretch Goals
* Project Overview
  * The `.github` Directory
    * Staging Deployments: How They Would Work
  * The `kube` Directory
    * The Terraform
* Miscellaneous Issues/Improvements

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
managed in code & deployment of the application has to be
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

A note: since we use open source images for Redis and Postgres locally, it was logical for this pipeline to focus solely on building the Client and Server docker images for the moment. If we were to add automated tests for the applications however, we would want to implement a CI docker-compose.yml that automates building all four images within the build job so as to include tests relevant to Redis and Postgres.

The Build job checks out the repository, sets up the docker build action, logs in to Docker Hub, and then builds & pushes each image to Docker Hub. At the moment the build steps for the Client and Server are tightly coupled, which is likely not optimal. In the case where there is, for example, a frontend feature team and backend feature team working on this code base, it would make more sense to decouple them in the following ways:

* **Option 1:** Keep them in the same repository, but decouple the workflows so changes to the Client code triggers only a build, push, and deploy of the new Client image. You could do this with the GitHub Action feature `on.push.paths["client/**"]`. You'd do the same for the Server code. This way, you save money & time on CI/CD without significant changes to how these services are structured and tested in tandem.
* **Option 2:** Break them out into separate repositories. This obviously decouples them entirely, and would mitigate CI/CD congestion during high development hours, but would require a more significant restructure of the codebase(s) to ensure proper testing. I would likely do this by having a mirror of the main branch that can be tested against in the staging environment such that for a given change PR for the Client repository, a staging deployment would be automatically deployed alongside a the latest Server image running in production (though we would obviously have separate stateful resources for the staging Server deployments to read and write to - more on this later). Similarly, locally, instead of building the image for the Server from local code, grab it instead from our remote registry.

The Deploy job requires the Build job to successfully complete before it runs, thus preventing deployment of code that would not build successfully. It then checks out our codebase (and since we have to do this so frequently, it would be interesting to figure out if there's a way to set something like `beforeEach` in GitHub actions that says to always check out the code at the beginning of each job), then  grabs our AWS Credentials from the repository secrets, and finally runs our deploy & monitor scripts.

As a note, the AWS Credentials here are for a generic Admin role. This is bad. For everything RBAC/IAM, we always want to follow the principal of **Least Privilege** - something I did not do anywhere in this project except I believe the TerraformStateManager role. This was one area where I saved some time and reduced scope for this project but would never do for a real project. In reality, I would create a module in Terraform that creates application specific IAM roles for use in these deployment scripts. This has many benefits, but mainly increases security and improves our ability to audit our environment as it is more clear where and when a given role should be used.

The Deploy script (`.github/scripts/deploy.sh`) is pretty straightforward and designed to work dynamically for either our Staging or Production deployments. First, we grab our kubeconfig to configure access to our cluster. Then we use some of the environment variables we set in the workflow spec to set the image, nameprefix (`chainlink-production` for production deploys and `chainlink-pr${PR_NUM}` for staging), and labels named release, environment, and app to allow for easy searching and filtering when interacting with the Kubernetes API. After that we create a temporary secrets-gen.env file (that we will later use to dynamically inject application secrets into K8s) and have a quick conditional that normally would not need to be here, but since Staging deployments are not implemented I set this up so you can see what the Kubernetes manifests would look like for a Staging deploy.

The last piece of our production pipeline (`.github/scripts/monitor.sh`) is responsible for monitoring our deployments and rolling back deployed resources to the last version in case we have an application error soon after the deploy. This is a very simple implementation for the moment and can definitely be improved. For now, it looks at all deployments in the `default` namespace in our cluster (so here, the client, server, and redis deployments), and if it sees an Error status will 'undo' the most recent rollout to that deployment. An easy way to test this is going to `kube/bases/server/deployment.yaml` and changing the `command:` from `yarn start` to something non-functional, like `yarn foo`. Then merge that to `main`. What will happen is the Kubernetes manifests will properly build and apply, but as soon as it tries its startup command it will `Error` and begin to crashloop. When the script sees that, it logs it in the Action console, rolls back the deployment, and `exit 1` to draw attention to the issue.

Some ways to improve this:

* Add this to staging deploys as well so issues are caught by devs before a merge to main.
* Only monitor for the specific deploys handled in this workflow.
* Add liveness and readiness probes to the deployments to better inform the Kubernetes API when a pod is unhealthy.
* Figure out how to fully revert the merge to main. There may be a third-party workflow for this built already, but basically you'd need to capture every commit from the last rollout that was not on main before, trigger a revert PR given those commits, and automatically merge it.
* Trigger an alert to Slack and/or PagerDuty to draw further attention to an issue.

Now, let's chat about the `pipeline-staging.yml` file. This was a stretch goal I did not completely implement to reduce some scope, but I would like to describe how I would have:

### Staging Deployments: How They Would Work

This workflow is a lot like the production one, but has some key differences. First, its only triggered when changes are made to directories relevant to actually building and deploying the application(s) when a PR is opened against main. Next, the deploy job includes a quick script to grab the PR Number to inject it into our Kubernetes resources later.

To get this working well, we'd need to do a lot on the terraform/infrastructure side. The most secure way would be a separate AWS account and the thing to focus on when setting up resources here would be maintaining environment parity as much as possible. This would mean heavy utilization of re-usable modules in terraform for both the prod and staging accounts such that, most (or all) of the time, there is a single point of truth for most settings across both accounts. This ensures the staging environments we do test and QA work on are as similar to production as possible, minimizing surprises and maintenance complexity. The module would need to create (among other things) an A record, specific to the PR, pointed at the Staging EKS cluster's load balancer for the client and server hosts (ex: `chainlink-pr123-server.example.com`).

To implement statefulness we'd again want to focus on parity. Here though it is a bit more of a challenge. We'd want to setup a (probably daily) cronjob that clones the production database and both trims its data to reduce size and anonymizes it somehow. There are some third-party tools for this, one my team has used in the past is called Tonic. That clone should then be made available to the staging account such that we may create and update daily a 'default' database in the Staging RDS instance. Then, using a Terraform module and GitHub workflow, when each environment is staged we would trigger an environment specific database creation for that environment. Looking something like this:

```tf
resource "postgresql_database" "staging_chainlink" {
  name       = "chainlink_staging_${var.env_name}"
  owner      = "chainlink"
  template   = "chainlink_clone"
  encoding   = "UTF8"
  lc_collate = "en_US.UTF-8"
  lc_ctype   = "en_US.UTF-8"
}
```

Once the database is created, we would trigger the Kubernetes deploymnent. Another cool way to do this would be having a GitHub action that waits for a specific label to be added to a PR. Example: `Stage`. That way, devs can put up PR's, and discuss the changes amongst themselves while it is still a work in progress and only actually deploy resources when needing to test and QA their changes live in the staging cluster. This would save money and reduce pipeline congestion.

One last thing to note here is we would have to add additional, staging specific, environment variables to the workflow to ensure the deploy script is pointed at the staging AWS account, cluster, and associated staging secrets.

### The `kube` Directory

Let's move on to the Kubernetes bits! Directory structure:

```txt
kube
  ├─bases
  |   ├─base
  |   ├─client
  |   ├─redis
  |   └─server
  └─overlays
      ├─production
      └─staging
```

The reason its structured like this is that we are using a tool called 'Kustomize' to keep our manifests as DRY, explicit, and maintainable as possible.

The bases are the bones of the resources we are deploying. They contain the applcation specific resources we want to deploy with a `kustomization.yaml` file that tells kubectl which files we want to include when referencing this base.

The base within bases grabs all of those application specific objects and adds any high level common labels.

The overlays are environment specific. In this case, we have staging and production overlays, but in practice we may also want one called `beta` that includes special ingress objects defining a canary deployment .of a new, higher risk, version of the application such that we could test the new version in production but with a small % of traffic. You can do this using special annotations on the Nginx Ingress objects! 

These overlays are where we would utilize the kustomize resources `patches`, `generators`, and `vars`.

We don't have any patches currently, but I'll discuss a use case and example of one for posterity. Let's say in production our deployments have a ton of traffic and thus need a lot of scale. To create this scale, we set the replica count in our deployments to 50, telling the K8s API to deploy and maintain 50 pods for each of these deployments. It is almost certain, however, that we don't need that much scale in staging. If this is true, we can use a patch to set that in the staging environment specifically in a simple, semi-declarative way. In `kube/overlays/staging/` we would create a file called `patch-replicas.yml` and in it add:

```yml
- op: replace
  path: /spec/replicas
  value: 2
```

Then, in `kube/overlays/staging/kustomization.yml` we define what resources to apply this patch to:

```yml
patchesJson6902:
- path: patch-replicas.yml
  target:
    group: apps
    version: v1
    kind: Deployment
    name: server
- path: patch-replicas.yml
  target:
    group: apps
    version: v1
    kind: Deployment
    name: client
```

One thing to keep in mind for this example is ensuring our rolloutStrategy settings do not inhibit us from deploying to staging here. If they do, either change the replica count to a value that works with the percentages in the strategy or add a patch for the strategy as well!

The second kustomize feature I mentioned, `generators`, is used to create configMaps and secrets for your deployments. In our case, we append the temp `secrets-gen.env` file we created in the deploy script to an otherwise empty secret, then reference it as the environment in our deployment manifests. This strategy is highly useful for deploying environments dynamically, like we would for automated staging deploys.

The third and last kustomize feature I will describe is `vars`. If you look in the staging overlay kustomization file there's a good example of this. Kustomize is generally good at knowing how to combine names, prefixes, labels, etc... in your objects automatically. However, one place where it doesn't (and we need it to, to deploy to staging) is in `kube/overlays/staging/ingress.yml`. Here, we need the Ingress `host` to set it self up to handle requests for the aforementioned A records we'd automatically create as a part of the staging deploy. To do this, we tell Kustomize (using the vars object) to replace anywhere it sees `$(DEPLOY_RELEASE)` in the manifests with the value it reads from the label: `release` on the client deployment (which we set = to `pr${{ env.PR_NUMBER }}` in the CI/CD).

### The Terraform

As a reminder this is all contained in the other repository: `maxzintel/chainlink-infra`. The reason I separated these is that most of the resources in here are generic to the account, and not specific to the application deployment. Thus in a realistic situation, we wouldn't want them to reside in the same repository most likely.

This repository is pretty basic. It has no automated CI/CD (I just dealt with remote state management with CLI commands locally), only uses one custom (made by me) module (for EKS cluster creation), and under-utilizes things like variables and other DRY and Least Privilege principals.

As I alluded to in my description of how automated staging would work, this would much more heavily utilize common modules and variables across environments if I had implemented that as well. Some ways to do that would be utilizing `tfvars`, `variables.tf`, and `output.tf` files more frequently and/or using an overlay like Terragrunt.

Another few things to note are:

* I would normally use ElastiCache for a production Redis cluster implementation, but ran into issues getting it working with the sample application (I described these issues in Slack). Thus, my elasticache code is commented out.
* The ECR resources are commented out because there is a compatibility issue with Docker's GitHub Actions for building and pushing. My understanding is that these actions utilize multi-layer caching, which ECR does not support. This is why I am using Docker Hub regitries at present (though I would prefer figuring out a workaround so we could use ECR private registries instead).
* The RDS instance is NOT stored as a declarative Terraform resource. The reason being: keeping it out maximizes agility in issue resolution and any automatic updates by AWS will not be accidentally reverted by the Terraform state being unaware of them.

## Miscellaneous Issues/Improvements

A few are described above so here I will (mostly) limit what I identify as issues or improvements to what has yet to be mentioned.

* The website should utilize HTTPS
* Least Privilege RBAC should be used everywhere
  * Everything should use a Role or User specific to the usecase rather than the group accounts with admin permissions I use here.
* There are not enough branch protections
  * The GitHub repositories have no rules on them requiring PR's or passing CI/CD.
* Workflows could be more DRY and composable
  * The tradeoff is that they become less declarative, but if there was a way to reduce repeated code and repeated steps in the workflows, that would be best.
* For production, we should figure out how to get the Server connected to ElastiCache
* Add Liveness and Readiness Probes to all deployments to promote availability/uptime
* Implement Atuomated Horizontal Autoscaling of Node Group & Deployment Replicas in Production.
* Implement automated monitoring and logging throughout the cluster
  * Plus automated alerts to slack and pagerDuty depending on metrics and issues from above.
* Implement automated unit and frontend testing as a part of the CI/CD
* The REACT_APP_BACKEND_URL is hardcoded in the client Dockerfile, that's bad practice and I would default that to localhost and dynamically inject the Server URL given more time.
* Plus many other things depending on scope, timelines, and resources.

**If you've gotten this far, thank you so much for reading! Please reach out with any questions.**
