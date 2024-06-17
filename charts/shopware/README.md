# Shopware Helm Chart

![Shopware Helm Operator](shopware.svg)

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

## Table of Contents
- [Installation](#installation)
- [Usage](#usage)
- [Information](#Information)

# Installation

This Helm chart can be installed locally or within an existing Kubernetes cluster, using tools like ArgoCD.
This guide focuses on a simple local installation to help you get started.
For advanced configurations, please refer to the [Istio example](examples/values_istio.yaml).

This Helm chart installs the Percona Operator along with a MySQL database.
For more information on Percona, visit [Percona's website](https://www.percona.com/).
Currently, this Helm chart supports Percona and S3 MinIO by default.
However, you can modify the configuration to your needs.

### Existing Cluster
#### Prerequisites
- Kubernetes v1.28.0+
- [Helm v3](https://helm.sh/docs/intro/install/)
- S3

If you have an existing cluster make sure the prerequisites are installed and go directly to [Usage](#usage).

### Local Test Cluster
#### Prerequisites
- [Kind 0.23.0+](https://kind.sigs.k8s.io/docs/user/quick-start)
- [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [Helm v3](https://helm.sh/docs/intro/install/)

#### Install Kind

Kind is a tool for running local Kubernetes clusters using Docker container “nodes”.
It was primarily designed for testing Kubernetes itself but is also useful for local development or CI.

For more information, visit the [Kind documentation](https://kind.sigs.k8s.io/).

To properly set up the network configuration, we provide a baseline [config](kind-config.yaml) file for Kind. To create the cluster, execute:
```
kind create cluster --config kind-config.yaml
```

#### Install MinIO Operator

MinIO is a high-performance, S3-compatible object store built for large-scale AI/ML, data lake, and database workloads.
MinIO is used for public assets and private files.

For more information, visit the [MinIO documentation](https://min.io/).

We use MinIO here to force Shopware to use S3, reducing write operations since Shopware is optimized for S3 usage.
You can also use AWS S3.
To disable MinIO, set `minio.enabled` to `false` in the [values.yaml](values.yaml) file.

> **Warning:**
> Do not use this setup in production!
> mTLS is disabled in the MinIO values because Kind provides a self-signed certificate for MinIO, which is incompatible with Shopware.
> One solution could be to use a proper certificate authority for the cluster.
> With Istio, this is not an issue as mTLS is handled by Istio.

To install the MinIO Operator in your cluster, execute:
```
kubectl apply -k "github.com/minio/operator?ref=v5.0.15"
```

#### Install Ingress in Kind

Ingress is a Kubernetes resource that manages external access to services in a cluster, providing load balancing, SSL termination, and name-based virtual hosting.
To enable this, deploy an ingress resource such as NGINX:
```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```

> **Note:**
> This setup may take a few seconds. You can either grab a coffee or check the pod ready status with:
> ```
> kubectl wait --namespace ingress-nginx \
>  --for=condition=ready pod \
>  --selector=app.kubernetes.io/component=controller \
>  --timeout=90s
> ```

#### ImagePullSecrets

This is only required if your Docker image is not locally available and is behind authentication.
To pull your image from GitHub, create a `docker-registry` secret.
Alternatively, you can avoid this step by pulling your image into your local Docker registry or building it locally.

For instructions on loading images into the Kind cluster, see [Loading an Image into Your Cluster](https://kind.sigs.k8s.io/docs/user/quick-start/#loading-an-image-into-your-cluster).

To create the secret for GitHub, use:
```
kubectl create secret docker-registry regcred --docker-server=ghcr.io --docker-username=<your-username> \
  --docker-password=<your-package-read-token> --docker-email=<your-email> --namespace <your-namespace>
```

To use image pull secrets, update the values in this Helm chart as follows:
```
store:
  container:
    imagePullSecrets:
      - name: <secret-name>
```

#### Load local Images into your cluster

You can use this process to load a local image into your cluster, a common practice for this test environment.
For a complete guide, refer to [Loading an Image into Your Cluster](https://kind.sigs.k8s.io/docs/user/quick-start/#loading-an-image-into-your-cluster).

You can build a local shopware image and load the image into the Kind cluster:
```
kind load docker-image <your-image>
```

> **Note:**
> Ensure that the `PullImagePolicy` is not set to `Always`, as this will force the cluster to attempt to pull the image from a remote repository, which may not be available.

# Usage

Once you have a running cluster with S3 and ingress support, you can install this Helm chart.
Customize the installation using the [values.yaml](values.yaml) file.

## Minimal Installation
For a minimal installation, run:

[//]: # (TODO: Before the official release, ensure to update this command pointing to the public repository.)
```
helm install shopware . --namespace shopware --create-namespace
```

> **Note:**
> The s3 tenant setup may take a few seconds.
> So Shopware is running before the assets are public.

## Installation With Istio
For a more complex setup with additional prerequisites, you can install this Helm chart with Istio support:

```
kubectl create namespace shopware
kubectl label namespace shopware istio-injection=enabled
helm install shopware . --namespace shopware --values examples/values_istio.yaml
```

> **Note:**
> This process does not include the installation or configuration of Istio itself.
> It assumes that Istio is already set up and configured in your environment.

# Information
### TLS and Certificates on Kind
If the shop is unable to load styles from MinIO, you may need to accept the certificate in your browser.
To verify this, try opening the `all.css` file directly in your browser. You can locate the URL in your browser's network debugging tab.

### Naming Conventions
Each customer namespace contains only one store and is identified by a unique name.
It uses the format `<organization-name>-<project-name>-<application-name>`, e.g., `shopware-staging`.

### Operator
A Shopware operator is installed for each namespace by default.
You can disable this in the [values.yaml](values.yaml) file if you prefer to use it cluster-wide.
As the operator is still in beta, we advise against using it at the cluster level.
