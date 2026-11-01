# COB Live: Terraform CI/CD for the dev data platform

This repository deploys a small AWS data platform for the Data Engineering team. It uses the COB Terraform modules from the `cob-modules` repo, and AWS is changed only through a GitHub Actions pipeline. Every change is checked, planned, reviewed, approved and then applied. Nobody runs `terraform apply` by hand.

# Architecture

Repositories

 Repo  Purpose 

cob-modules The platform: 7 reusable Terraform modules, released with git tags (currently v1.0.0) 
cob-live (this repo) | The dev deployment, the state configuration and the CI/CD pipeline 

*Flow: Pull request, then checks and plan, then review and merge, then approval, then apply to AWS.

**Infrastructure (us-east-1):** a VPC with public and private subnets, an internet gateway and a NAT gateway. The private subnets hold an ECS service, an RDS PostgreSQL database and an EC2 instance. Two S3 buckets, a Glue table and an Athena workgroup make up the data platform.

**Supporting setup: Terraform state is stored in a versioned, encrypted, locked S3 bucket. GitHub authenticates to AWS with OIDC, so no AWS keys are stored anywhere.

## What gets deployed (53 resources)

 Module  Resources  What it provides 

 network  19  VPC, subnets, gateways, route tables, security group 
 storage 5 Data bucket with versioning, encryption and lifecycle rule 
 iam | 3 Workload role with access to the data bucket 
 compute-ecs  8  ECS cluster and service running nginx 
 database  5 RDS PostgreSQL, reachable only from the ECS service 
 compute-ec2  6  EC2 instance with SSM access 
 data-platform  7  Glue table, Athena workgroup and a results bucket 

## How the pipeline works

**1. Continuous integration (on every pull request)**
The pipeline runs format check, init, validate and plan. Any failure turns the check red. The plan is posted on the PR with the summary line first, and the full plan is saved as an artifact.

**2. Review and approval**
Branch protection requires a pull request and a passing check before merging, and it applies to admins too. Merging does not deploy anything by itself.

**3. Continuous delivery (after merge to main)**
A plan job runs first. If there are no changes, the apply is skipped. If there are changes, the apply job pauses until an authorised reviewer approves it on the `dev` environment. It then re-plans, confirms the plan matches what was reviewed, applies, and reports success or failure.

**Safeguards**
- Only the `main` branch can deploy.
- The S3 state lock and a workflow concurrency group prevent two deployments at once.
- If the plan changes after review, the apply stops.

## How to use it

1. Create a branch and edit the Terraform code.
2. Open a pull request and wait for the checks.
3. Read the plan comment. Confirm the numbers are what you intended.
4. Merge the pull request.
5. Open the Terraform Apply run in the Actions tab, read the plan, and approve the `dev` deployment.
6. Check the run summary for success or failure.

To upgrade modules, change the version tag in the module sources in `main.tf` and open a pull request. To roll back, revert the merged PR through a new PR.

## Demonstration

 Scenario  What was done  Result 

| First deployment  PR #1 added the pipeline, and the plan showed 53 to add  53 resources created 
| A: valid change | PR #2 added a CostCenter tag to the storage module. The plan showed 0 to add, 1 to change, 0 to destroy.  Merged, approved and applied |
| B: invalid Terraform | PR #3 used an undeclared variable on purpose | Validate failed, the merge was blocked, and the PR was closed unmerged |
| C: no changes | A manual run with the infrastructure already up to date | The plan found no changes and the apply was skipped 

## Production controls

- No long-lived AWS keys: GitHub OIDC with a role that only this repo can use
- The pipeline role cannot change its own permissions
- The database password is a GitHub secret, never committed, and state files are gitignored
- State is versioned, encrypted, private and locked
- Terraform, provider and module versions are all pinned
- Pull request and passing checks required, enforced for admins
- Human approval required before every apply
- Full audit trail in PRs, plan comments, artifacts and the Deployments log

## Known limitations

- The pipeline role has broad IAM permissions. A production setup would narrow them.
- There is one reviewer and self-review is allowed, which suits a solo project and not a team.
- The apply check compares plan counts and not the full plan text.
- The pipeline never destroys anything. Teardown is manual.
- The ECS service has no load balancer, so nginx is not reachable from the internet.
- Data is loaded into S3 outside Terraform.

## Cost and teardown

The NAT gateway, RDS instance and EC2 instance bill by the hour. To tear down, back up the data, empty both S3 buckets including old versions, run terraform destroy, and confirm that nothing is left.

## Troubleshooting

 Problem  Cause  Fix 

 AWS login fails in the pipeline  The trust policy does not match GitHub's token  Update the trust policy to the repo's real subject 
 BucketAlreadyExists  A leftover bucket from an earlier deployment  Back it up, delete it, run again 
 Permission denied for an IAM action | The pipeline role lacks it  Add the action to the role's policy 
 A run stays pending  Another run holds the lock, often waiting for approval  Approve or cancel the older run 
 Plan comment is cut off  GitHub's comment size limit  Download the plan artifact from the run 
