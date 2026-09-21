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
- Optional: [KEDA](https://keda.sh/) operator and CRDs, if you want the worker deployments to scale on queue length ([More Details](#worker-autoscaling-with-keda))
- Optional: [cert-manager](https://cert-manager.io/), if you want to enable the validating webhook of the operator ([More Details](#operator))

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

The Operator is not designed to be used on a cluster level. Each namespace should have its own operator
installation. The operator is responsible for managing the lifecycle of Shopware stores, including creating
and updating deployments, services, and other resources. It is installed with the operator chart, see
[Minimal Installation](#minimal-installation).

The operator chart renders its Custom Resource Definitions (CRDs) as regular templates, so `helm install`
and `helm upgrade` install and update the CRDs together with the operator. No separate CRD installation
step is required.

Optional features are disabled by default and have to be activated in the operator chart:

- `metrics.enabled=true` exposes an HTTP endpoint with store metrics and the queue length API. A
  `ServiceMonitor` for Prometheus can be enabled on top of it.
- `webhook.enabled=true` installs a `ValidatingWebhookConfiguration` that validates the schemaless
  container override fields of a `Store` on create and update. This requires cert-manager in the cluster.
- `keda.enabled=true` lets the operator manage [KEDA](https://keda.sh/) resources for the worker
  deployments, see [Worker autoscaling with KEDA](#worker-autoscaling-with-keda). This requires the KEDA
  CRDs and `metrics.enabled=true`.

For the CRD lifecycle, the available values and a more advanced setup, see the
[operator chart README](https://github.com/shopware/helm-charts/tree/main/charts/shopware-operator).

#### Worker autoscaling with KEDA

> [!IMPORTANT]
> Worker autoscaling requires shopware-operator 1.9.0 or newer. Older operator versions ship a `Store`
> CRD without the KEDA fields, so `spec.worker.enableKedaScaling` and the tuning fields below are pruned
> by the API server and the setting has no effect.

The operator can scale the Shopware message queue workers based on the queue length using
[KEDA](https://keda.sh/). This is optional. Without KEDA the operator creates a single worker deployment
that consumes all queues (`failed`, `async` and `low_priority`) and uses the fixed replica count from
`store.container.replicas` or `store.workerDeploymentContainer.replicas`.

With KEDA enabled the operator creates one worker deployment per queue and a KEDA `ScaledObject` for each
of them, which scales on the queue length read from the operator metrics endpoint. Additional transports
configured in your shop are picked up automatically once the operator has collected the queue statistics
from the admin pod.

KEDA has to be enabled in two places: in the operator chart, so the operator watches the KEDA resources,
and in this chart for the store, so the operator creates the per queue deployments and `ScaledObject`
resources for it. To use it you need to:

1. Install the KEDA operator together with its CRDs and enable `keda.enabled=true` and
   `metrics.enabled=true` in the operator chart (1.9.0 or newer), see the
   [operator chart README](https://github.com/shopware/helm-charts/tree/main/charts/shopware-operator).

2. Install this chart with KEDA scaling enabled for the store:

   ```sh
   helm install my-shop shopware/shopware --namespace shopware --create-namespace \
     --set store.worker.enableKedaScaling=true
   ```

   Or in your values file:

   ```yaml
   store:
     worker:
       enableKedaScaling: true
       # Optional, the defaults of the Store resource are used when they are not set
       maxReplicas: 3
       minReplicas: 0
       cooldownPeriod: 30
       pollingInterval: 10
       targetQueueLength: 100
   ```

After the store is ready you can inspect the created resources:

```sh
kubectl get deployments -n shopware -l shop.shopware.com/store.app=shopware-worker
kubectl get scaledobjects -n shopware
```

> [!NOTE]
> The replica count from `store.container.replicas` and `store.workerDeploymentContainer.replicas` is only
> used as the initial value for the worker deployments when KEDA is enabled. KEDA takes over the scaling afterwards.
> The queue statistics are collected from the admin pod, so the admin deployment must be running for the workers to scale.

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

### Tideways

The chart can deploy a [Tideways](https://tideways.com/) daemon alongside the store for profiling and monitoring PHP requests.

Two values are required. `store.tideways.enabled` writes the daemon address into the `Store` resource, so the operator injects `TIDEWAYS_CONNECTION`, `TIDEWAYS_SERVICE` and `TIDEWAYS_APIKEY` into the storefront, admin and worker containers. `tideways.apiKeyRef` references the Secret key holding the API key:

```yaml
store:
  tideways:
    enabled: true

tideways:
  apiKeyRef:
    name: tideways-credentials
    key: api-key
```

**The Secret is not created by this chart.** Create it beforehand, using the API key from your Tideways organisation:

```bash
kubectl -n <namespace> create secret generic tideways-credentials \
  --from-literal=api-key=<api-key>
```

**Optional values:**

- `tideways.image` — daemon image, defaults to `tideways/daemon:latest`
- `tideways.port` — daemon port, defaults to `9135`
- `tideways.service` — service name reported to Tideways, defaults to `shopware`
- `tideways.environment` — environment name passed to the daemon as `--env`
- `tideways.resources` — resource requests and limits for the daemon container

The daemon is deployed as `shopware-tideways` and exposed as a Service named `tideways`.

> [!WARNING]
> The Tideways probe (the `tideways` PHP extension) must already be present in your Shopware image.
> This chart configures where the probe sends its data, it does not install the probe itself.

> [!NOTE]
> Tideways and OpenTelemetry tracing are not supported at the same time, and neither are Tideways
> and Blackfire. Configuring both makes template rendering fail with an explicit error.

**Service mesh:** if the namespace enforces a default-deny authorization policy, allow ingress to the daemon on port `9135`.
