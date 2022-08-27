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

The Build job checks out the repository, sets up the docker build action, logs in to Docker Hub, and then builds & pushes each image to Docker Hub.

Imperative construction of pipeline files to maintain DRY and composable code.



- Staging Deployment Description
- Decouple the Repo (Client and Server) to mitigate build congestion
   - Seperating pipelines.
- Make action pipelines more DRY
- Figure out how to get the Server connected to ElastiCache
- Figure out how to automate full revert PR's
