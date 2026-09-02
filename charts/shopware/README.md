# Shopware Helm Chart

## Table of Contents

- [Cluster Installation](#cluster-installation)
- [Usage](#usage)
- [Information](#information)

# Cluster Installation

This Helm chart can be installed locally or within an existing Kubernetes cluster, using tools like ArgoCD.
This guide focuses on a simple local installation to help you get started.

This Helm chart installs the Percona Operator along with a MySQL database and RustFS for S3-compatible object storage.
For more information on Percona, visit [Percona's website](https://www.percona.com/).
For more information on RustFS, visit the [RustFS GitHub repository](https://github.com/rustfs/rustfs).
Currently, this Helm chart supports Percona and RustFS by default.
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
- S3 based api ([More Details](https://developer.shopware.com/docs/guides/hosting/infrastructure/filesystem.html#amazon-s3))

If you have an existing cluster make sure the prerequisites are installed and go directly to [Usage](#usage).

## Local Test Cluster

### Prerequisites

- [Kind 0.32.0+](https://kind.sigs.k8s.io/docs/user/quick-start)
- [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [Helm v3](https://helm.sh/docs/intro/install/)

### Install Kind

Kind is a tool for running local Kubernetes clusters using Docker container “nodes”.
It was primarily designed for testing Kubernetes itself but is also useful for local development or CI.

For more information, visit the [Kind documentation](https://kind.sigs.k8s.io/).

To properly set up the network configuration, we provide a baseline [config](kind-config.yaml) file for Kind. To create the cluster, execute:

```sh
kind create cluster --config kind-config.yaml

# Install Gateway API CRDs
kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.1/standard-install.yaml
```

### Install Ingress in Kind

Ingress is a Kubernetes resource that manages external access to services in a cluster, providing load balancing, SSL termination, and name-based virtual hosting.
To enable this, deploy an ingress resource such as NGINX:

```sh
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```

> [!NOTE]
> This setup may take a few seconds. You can either grab a coffee or check the pod ready status with:
>
> ```sh
> kubectl wait --namespace ingress-nginx \
>  --for=condition=ready pod \
>  --selector=app.kubernetes.io/component=controller \
>  --timeout=90s
> ```

### Load local Images into your cluster

You can use this process to load a local image into your cluster, a common practice for this test environment.
For a complete guide, refer to [Loading an Image into Your Cluster](https://kind.sigs.k8s.io/docs/user/quick-start/#loading-an-image-into-your-cluster).

You can build a local shopware image and load the image into the Kind cluster:

```sh
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

```sh
helm repo add shopware https://shopware.github.io/helm-charts/
helm install operator shopware/operator --namespace shopware --create-namespace
helm install my-shop shopware/shopware --namespace shopware --create-namespace
```

If you want to use your own image use:

```sh
helm repo add shopware https://shopware.github.io/helm-charts/
helm install operator shopware/operator --namespace shopware --create-namespace
helm install my-shop shopware/shopware --namespace shopware --create-namespace --set store.container.image=<image-name>
```

> [!WARNING]
> While a default image is provided with this Helm chart, it is recommended that you do not use it. Instead,
> [create your own custom Docker images](#create-docker-image) and override the default image in the Helm chart.

After applying the Helm chart, you can monitor the status of the store resource using:

```sh
kubectl get stores -n shopware --watch
```

> [!NOTE]
> The RustFS storage and database setup may take a few seconds, that's why you can run into setup errors.

Once the setup job in your cluster is complete and your store is in the ready state, you can access the shop at <https://localhost.traefik.me/>
If needed, you can modify the domain by updating the values.yaml file.

### Create Docker image shopware-cli

For shopware running in a docker container we have a new way of supporting this.
You can find the starting documentation in our [docs](https://developer.shopware.com/docs/guides/hosting/installation-updates/docker.html).

```sh
shopware-cli project create test -n --docker --version 6.7.13.1
cd test
composer require shopware/k8s-meta --ignore-platform-reqs
```

Currently we also need to update the Dockerfile manually, make sure that
you use `-otel` for the base-image and add the extension enabled to your line.

```sh
printf '%s' '#syntax=docker/dockerfile:1.4
ARG PHP_VERSION=8.4
# We use otel in kubernetes so make sure we set this also in this image.
FROM ghcr.io/shopware/docker-base:$PHP_VERSION-caddy-otel AS base-image
FROM ghcr.io/shopware/shopware-cli:latest-php-$PHP_VERSION AS shopware-cli

FROM shopware-cli AS build
 
# We need open telemetry for the build process, so we need to enable it here.
RUN docker-php-ext-enable opentelemetry

ADD . /src
WORKDIR /src

RUN /usr/local/bin/entrypoint.sh shopware-cli project ci /src

FROM base-image AS final

COPY --from=build --chown=82 --link /src /var/www/html
' > Dockerfile
```

After adding the Dockerfile create two tagged versions for the repository like this:

```sh
docker build -t test:v1 -f Dockerfile .
docker build -t test:v2 -f Dockerfile .
```

Then, load the images into your container registry for the cluster. If you're using Kind, use the following command:

```sh
kind load docker-image test:v1
kind load docker-image test:v2
```

Finally, patch the current installation or install it from base and patch the `values.yaml` file with the docker image:

```sh
helm upgrade my-shop shopware/shopware --namespace shopware --set store.container.image=test:v1
kubectl get stores -n shopware --watch
```

If you now patch the image again you can see a migration happening in the shopware-operator. Image updates with a new different image
always triggers a new update and a migration job to happen. This will then use the deployment-helper under the hood.

```sh
helm upgrade my-shop shopware/shopware --namespace shopware --set store.container.image=test:v2
kubectl get stores -n shopware --watch
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

### Operator

As the operator is still in beta, we advise against using it at the cluster level.

The operator chart renders its Custom Resource Definitions (CRDs) as regular templates, so `helm install` and `helm upgrade`
install and update the CRDs together with the operator. No separate CRD installation step is required.

If you prefer to manage the CRD lifecycle yourself, you can still split the installation into two steps:

```sh
# Step 1: Install only the CRDs
helm template shopware/operator --set crds.installOnly=true | kubectl apply --server-side -f -

# Step 2: Install the operator without CRDs
helm install operator shopware/operator --namespace shopware --create-namespace --set crds.install=false
```

### Shopware Image

While a default image is provided with this Helm chart, it is recommended that you do not use it. Instead, create your own custom
Docker images and override the default image in the Helm chart using a values file.

### RustFS S3 Storage

RustFS is automatically installed as part of the Shopware chart and provides S3-compatible object storage.

**Default Credentials:**

- Access Key: `rustfsadmin`
- Secret Key: `rustfsadmin`

**Access URLs:**

- S3 API: <https://s3.traefik.me>
- Console UI: <https://s3-console.traefik.me>

**Default Setup:**

- **Mode**: Standalone (1 pod)
- **Storage Class**: `standard`
- **Credentials**: `rustfsadmin` / `rustfsadmin`
- **S3 API**: <https://s3.traefik.me> (port 9000)
- **Console**: <https://s3-console.traefik.me> (port 9001)

**Important:**

- Buckets (`shopware-private`, `shopware-public`) are created automatically
- Internal cluster communication uses: `http://<release>-rustfs-svc.<namespace>.svc.cluster.local:9000`
- Public CDN URL: `https://s3.traefik.me/shopware-public`

**Switching to AWS S3:**

```yaml
rustfs:
  enabled: false

store:
  s3Storage:
    endpointURL: https://s3.amazonaws.com
    privateBucketName: my-private-bucket
    publicBucketName: my-public-bucket
    region: us-east-1
    accessKeyRef:
      name: aws-credentials
      key: access_key
    secretAccessKeyRef:
      name: aws-credentials
      key: secret_key
```

**Customizing Credentials:**
Set in `values.yaml`:

```yaml
rustfs:
  secret:
    rustfs:
      access_key: your-access-key
      secret_key: your-secret-key
```

### Blackfire

The chart can deploy a [Blackfire](https://www.blackfire.io/) agent alongside the store for profiling PHP requests.

Two values are required. `store.blackfire.enabled` writes the agent address into the `Store` resource, so the operator injects `BLACKFIRE_AGENT_SOCKET` into the storefront, admin and worker containers. `blackfire.serverIDRef` and `blackfire.serverTokenRef` reference the Secret keys holding the agent credentials:

```yaml
store:
  blackfire:
    enabled: true

blackfire:
  serverIDRef:
    name: blackfire-credentials
    key: server-id
  serverTokenRef:
    name: blackfire-credentials
    key: server-token
```

**The Secret is not created by this chart.** Create it beforehand, using the Server ID and Server Token from your Blackfire account:

```bash
kubectl -n <namespace> create secret generic blackfire-credentials \
  --from-literal=server-id=<server-id> \
  --from-literal=server-token=<server-token>
```

Both references carry their own `name` and `key`, so the two values may live in separate Secrets if needed.

**Optional values:**

- `blackfire.image` — agent image, defaults to `blackfire/blackfire:2`
- `blackfire.port` — agent port, defaults to `8307`
- `blackfire.resources` — resource requests and limits for the agent container

The agent is deployed as `shopware-blackfire` and exposed as a Service named `blackfire`.

> [!WARNING]
> The Blackfire probe (the `blackfire` PHP extension) must already be present in your Shopware image.
> This chart configures where the probe sends its data, it does not install the probe itself.

> [!NOTE]
> Blackfire and OpenTelemetry tracing are not supported at the same time. Configuring both makes
> template rendering fail with an explicit error.

**Service mesh:** if the namespace enforces a default-deny authorization policy, allow ingress to the agent on port `8307`. Without it the connection is accepted and then immediately closed, and the probe reports `Error reading on socket : EOF` while the agent logs nothing at all.

**CDN:** profiling requests must reach PHP. A response served from cache never runs the probe, and Blackfire reports that the probe could not be found. Configure the CDN to bypass its cache for any request carrying an `X-Blackfire-Query` header.
