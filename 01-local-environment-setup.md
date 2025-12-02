# Phase 1: Local Environment Setup

Before deploying the GKE cluster, you need to install several tools on your local machine to interact with Google Cloud and the cluster toolkit.

## 1. [Install Google Cloud CLI](https://docs.cloud.google.com/sdk/docs/install-sdk)

## 2. [Install Terraform](https://developer.hashicorp.com/terraform)

## 3. [Install Packer](https://developer.hashicorp.com/packer/install)

## 4. [Install Go](https://go.dev/doc/install)

## 5. Set up a GOPATH 
Set up a GOPATH by running the following command:
```bash
export PATH=$PATH:$(go env GOPATH)/bin
```

## 6. [Install git](https://github.com/git-guides/install-git)

## 7. Install pip3
Check that a Python 3 release of pip is installed by running pip3. If pip3 is not available, review the [Python documentation](https://docs.python.org/3/installing/index.html).

## 8. Install Make
```bash
# for debian/ubuntu
apt-get -y install make

# for CentOS/RHEL
yum install -y make
```

## 9. Set up Google Cloud Cluster Toolkit

The GKE cluster in this guide is provisioned using the Google Cloud Cluster Toolkit (formerly Cloud HPC Toolkit). This open-source tool makes it simple to deploy complex AI/ML and HPC environments following Google Cloud best practices.

It provides a modular, reliable way to deploy all the necessary components for your Dynamo deployment. We highly recommend exploring its GitHub repository for other blueprints and modules that can help accelerate your future experimentation.

Official Documentation: [Google Cloud Cluster Toolkit Overview](https://docs.cloud.google.com/cluster-toolkit/docs/setup/configure-environment)

GitHub Repository: [GoogleCloudPlatform/cluster-toolkit](https://github.com/GoogleCloudPlatform/cluster-toolkit?tab=readme-ov-file)



