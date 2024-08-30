# Shopware Helm Chart

## Table of Contents
- [Disclaimer](#Disclaimer)
- [Cluster Installation](#Cluster-Installation)
- [Usage](#Usage)
- [Information](#Information)

# Disclaimer

This Shopware Helm chart is currently in an experimental phase and is not ready for
production use. The services, configurations, and individual steps described in this
repository are still under active development and are not in a final state.
As such, they are subject to change at any time and may contain bugs,
incomplete implementations, or other issues that could affect the stability and performance
of your Shopware installation.

Please be aware that using this Helm chart in a live environment could lead to
unexpected behavior, data loss, or other critical problems. We strongly recommend using
this Helm chart for testing and development purposes only.

By using this software, you acknowledge that you understand these risks and agree not
to hold the developers or maintainers of this repository liable for any damage or
loss that may occur.

If you encounter any issues or have suggestions for improvements, please feel free to
open an issue or contribute to the project.


# Cluster Installation

This Helm chart can be installed locally or within an existing Kubernetes cluster, using tools like ArgoCD.
This guide focuses on a simple local installation to help you get started.
For advanced configurations, please refer to the [Istio example](examples/values_istio.yaml).

This Helm chart installs the Percona Operator along with a MySQL database.
For more information on Percona, visit [Percona's website](https://www.percona.com/).
Currently, this Helm chart supports Percona and S3 MinIO by default.
However, you can modify the configuration to your needs.

> [!WARNING]
> The Percona operator installed with this Helm chart currently does not support ARM64 images.
> Therefore, it is essential to ensure that AMD64 nodes are available within your cluster.
> While it is possible to use a different database system, please note that this Helm chart
> officially supports only Percona. We are aware of this limitation and have included it
> in our development roadmap.

## Existing Cluster
### Prerequisites
- Kubernetes v1.28.0+
- [Helm v3](https://helm.sh/docs/intro/install/)
- S3

If you have an existing cluster make sure the prerequisites are installed and go directly to [Usage](#usage).

## Local Test Cluster
### Prerequisites
- [Kind 0.23.0+](https://kind.sigs.k8s.io/docs/user/quick-start)
- [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [Helm v3](https://helm.sh/docs/intro/install/)

### Install Kind

Kind is a tool for running local Kubernetes clusters using Docker container “nodes”.
It was primarily designed for testing Kubernetes itself but is also useful for local development or CI.

For more information, visit the [Kind documentation](https://kind.sigs.k8s.io/).

To properly set up the network configuration, we provide a baseline [config](kind-config.yaml) file for Kind. To create the cluster, execute:
```
kind create cluster --config kind-config.yaml
```

### Install MinIO Operator

MinIO is a high-performance, S3-compatible object store built for large-scale AI/ML, data lake, and database workloads.
MinIO is used for public assets and private files.

For more information, visit the [MinIO documentation](https://min.io/).

We use MinIO here to force Shopware to use S3, reducing write operations since Shopware is optimized for S3 usage.
You can also use AWS S3.
To disable MinIO, set `minio.enabled` to `false` in the [values.yaml](values.yaml) file.

> [!WARNING]
> Do not use this setup in production!
> mTLS is disabled in the MinIO values because Kind provides a self-signed certificate for MinIO, which is incompatible with Shopware.
> One solution could be to use a proper certificate authority for the cluster.
> With Istio, this is not an issue as mTLS is handled by Istio.

To install the MinIO Operator in your cluster, execute:
```
kubectl apply -k "github.com/minio/operator?ref=v5.0.15"
```

### Install Ingress in Kind

Ingress is a Kubernetes resource that manages external access to services in a cluster, providing load balancing, SSL termination, and name-based virtual hosting.
To enable this, deploy an ingress resource such as NGINX:
```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```

> [!NOTE]
> This setup may take a few seconds. You can either grab a coffee or check the pod ready status with:
> ```
> kubectl wait --namespace ingress-nginx \
>  --for=condition=ready pod \
>  --selector=app.kubernetes.io/component=controller \
>  --timeout=90s
> ```

### ImagePullSecrets

This is only required if your Docker image is not locally available and is behind authentication.
To pull your image from GitHub, create a `docker-registry` secret.
Alternatively, you can avoid this step by pulling your image into your local Docker registry or [building](#Usage#Create Docker Image) it locally.

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

### Load local Images into your cluster

You can use this process to load a local image into your cluster, a common practice for this test environment.
For a complete guide, refer to [Loading an Image into Your Cluster](https://kind.sigs.k8s.io/docs/user/quick-start/#loading-an-image-into-your-cluster).

You can build a local shopware image and load the image into the Kind cluster:
```
kind load docker-image <your-image>
```
If you need guidance on creating a Docker image, please refer to the [Creating a Docker Image](#create-docker-image) section.

> [!NOTE]
> Ensure that the `PullImagePolicy` is not set to `Always`, as this will force the cluster to attempt to pull the image from a remote repository, which may not be available.

# Usage

Once you have a running cluster with S3 and ingress support, you can install this Helm chart.
Customize the installation using the [values.yaml](values.yaml) file.

## Minimal Installation
For a minimal installation, run:
```
helm repo add shopware https://shopware.github.io/helm-charts/
helm install my-shop shopware/shopware --namespace shopware --create-namespace
```

If you want to use your own image use:
```
helm repo add shopware https://shopware.github.io/helm-charts/
helm install my-shop shopware/shopware --namespace shopware --create-namespace --set store.container.image=<image-name>
```

> [!WARNING]
> While a default image is provided with this Helm chart, it is recommended that you do not use it. Instead,
> [create your own custom Docker images](#create-docker-image) and override the default image in the Helm chart.

> [!NOTE]
> The s3 tenant setup may take a few seconds.
> So Shopware is running before the assets are public.

Once the setup job in your cluster is complete and your store is in the ready state, you can access the shop at https://localhost.traefik.me/
If needed, you can modify the domain by updating the values.yaml file.

### Create Docker image

To create a new Shopware project, execute the following command:
```
composer create-project shopware/production test
```
Including the Docker configuration at this stage is optional; it will be added in the next step.

Next, navigate to your project directory and configure Shopware to use the appropriate environment variables
by installing the necessary Shopware packages:
```
cd test
composer require shopware/k8s-meta shopware/docker
```

After completing the configuration, build the Docker image:
```
docker build -t test -f docker/Dockerfile .
```

Finally, load the image into your container registry for the cluster. If you're using Kind, use the following command:
```
kind load docker-image test
```

### TLS with Nginx controller
If you want to enable TLS termination with Traefik and do not require custom certificates,
you can use the following snippet to utilize the public certificates from Traefik for proper TLS termination:
```
# Create a directory to store the certificates
mkdir -p certs

# Download the public certificates from traefik.me
wget -O certs/privkey.pem https://traefik.me/privkey.pem
wget -O certs/fullchain.pem https://traefik.me/fullchain.pem

# Create a Kubernetes secret to store the certificates
kubectl create secret tls traefik-me-cert \
  --cert=certs/fullchain.pem --key=certs/privkey.pem \
  --namespace=ingress-nginx --dry-run=client -o yaml | kubectl apply -f -

# Verify if the default SSL certificate is already set; if not, patch the deployment
kubectl get deployment ingress-nginx-controller -n ingress-nginx -o jsonpath='{.spec.template.spec.containers[0].args}' | grep -q -- '--default-ssl-certificate=ingress-nginx/traefik-me-cert' && echo "Certificate already added" || kubectl patch deployment ingress-nginx-controller -n ingress-nginx --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--default-ssl-certificate=ingress-nginx/traefik-me-cert"}]'
```
This configuration will download the required certificates, create a Kubernetes secret to store them, and ensure that the Ingress controller uses the correct certificate for TLS termination.

> [!WARNING]
> This configuration is not recommended for use in a production environment, as it does not provide secure traffic for your shop.

## Installation With Istio
For a more complex setup with additional prerequisites, you can install this Helm chart with Istio support:

```
kubectl create namespace shopware
kubectl label namespace shopware istio-injection=enabled
helm install my-shop shopware/shopware --namespace shopware --values examples/values_istio.yaml
```

> [!NOTE]
> This process does not include the installation or configuration of Istio itself.
> It assumes that Istio is already set up and configured in your environment.

# Information
### Operator
A Shopware operator is installed for each namespace by default.
You can disable this in the [values.yaml](values.yaml) file if you prefer to use it cluster-wide.
As the operator is still in beta, we advise against using it at the cluster level.

### Shopware Image
While a default image is provided with this Helm chart, it is recommended that you do not use it. Instead, create your own custom
Docker images and override the default image in the Helm chart using a values file.
