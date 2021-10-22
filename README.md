# Digital Ocean deployment
This Terraform code creates a deployment on Digital Ocean as described on this tutorial:

[**How to Configure a Droplet as a VPC Gateway**](https://docs.digitalocean.com/products/networking/vpc/resources/droplet-as-gateway/)

![Deployment diagram](https://github.com/ahmed-abdelazim/shadid/blob/main/deployment.png?raw=true)
## Prerequisites
- In your Digital Ocean account you must add ssh key must be named `gateway`
- Create Terraform cloud account
https://www.terraform.io/cloud
## Steps:
1. Get your Digital Ocean token from: https://cloud.digitalocean.com/account/api/tokens make sure that you are on the correct team. Token must have read / write access. Token is shown for single time only, please save it.
2. Connect this Repo to Terraform cloud folowing this tutorial https://learn.hashicorp.com/tutorials/terraform/cloud-workspace-create?in=terraform/cloud-get-started
3. on the last step of the previous tutorial set the variables as follows:

`do_token`: YOUR_DIGITALOCEAN_TOKEN

`do_count`: Number of back droplets
## Notes:
- You will be able to access back droplets only throug the Gateway
- Back droplets will communicate on the internet using gateway ip
