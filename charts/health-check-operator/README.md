# Health Check Operator Helm Chart

This chart deploys the Health Check Operator and installs its CRDs.

## Local Install

Build and push the image to the local Zot registry:

```sh
IMG=your-local-registry/shopware/health-check-operator:local

docker buildx build \
  --output=type=registry,registry.insecure=true \
  --push \
  -t "$IMG" \
  .
```

Install or upgrade the chart:

```sh
helm upgrade --install health-check-operator ./chart \
  --namespace health-check-operator-system \
  --create-namespace \
  --set image.repository=your-local-registry/shopware/health-check-operator \
  --set image.tag=local
```

For production, prefer an immutable manager image digest:

```sh
helm upgrade --install health-check-operator ./chart \
  --namespace health-check-operator-system \
  --create-namespace \
  --set image.repository=ghcr.io/shopware/health-check-operator \
  --set image.digest=sha256:<manager-digest> \
  --set customResourceCheck.luaRunnerImage=ghcr.io/shopware/health-check-operator-lua-runner:5.4.8@sha256:<runner-digest>
```

Build and push the Lua runner image from the repository before setting `customResourceCheck.luaRunnerImage`. The operator can start without this value for `HTTPCheck` and `NATSTrigger`, but `CustomResourceCheck` Jobs will report a status error until a digest-pinned runner image is configured. CustomResourceCheck authors cannot override this image from their CRs.

```sh
make lua-runner-docker-build LUA_RUNNER_IMG=ghcr.io/shopware/health-check-operator-lua-runner:5.4.8
make lua-runner-docker-push LUA_RUNNER_IMG=ghcr.io/shopware/health-check-operator-lua-runner:5.4.8
docker buildx imagetools inspect ghcr.io/shopware/health-check-operator-lua-runner:5.4.8
```

Verify:

```sh
kubectl get pods -n health-check-operator-system
kubectl logs -n health-check-operator-system deploy/health-check-operator-controller-manager -c manager -f
```

For local NATS publishing, create a Secret in the namespace where the `NATSTrigger` lives:

```sh
kubectl create secret generic health-check-operator-nats-creds \
  --from-file=CREDS=your-local-nats-creds-file
```

Then reference it from the trigger:

```yaml
spec:
  url: nats://nats-core.nats.svc.cluster.local:4222
  subject: health-check-operator.checks
  credentialsSecretRef:
    name: health-check-operator-nats-creds
    key: CREDS
```

For token authentication, create a Secret containing the NATS token:

```sh
kubectl create secret generic health-check-operator-nats-token \
  --from-literal=TOKEN='your-token'
```

Then reference it from the trigger instead of `credentialsSecretRef`:

```yaml
spec:
  url: nats://nats-core.nats.svc.cluster.local:4222
  subject: health-check-operator.checks
  tokenSecretRef:
    name: health-check-operator-nats-token
    key: TOKEN
```

For username/password authentication, create a Secret containing both values:

```sh
kubectl create secret generic health-check-operator-nats-user-pass \
  --from-literal=username='health-check-operator' \
  --from-literal=password='your-password'
```

Then reference it from the trigger instead of `credentialsSecretRef`:

```yaml
spec:
  url: nats://nats-core.nats.svc.cluster.local:4222
  subject: health-check-operator.checks
  usernamePasswordSecretRef:
    name: health-check-operator-nats-user-pass
    usernameKey: username
    passwordKey: password
```

The same `usernamePasswordSecretRef` is used when the NATS server stores the password as bcrypt; bcrypt verification happens server-side.

Alternatively, for NKEY challenge authentication, create a Secret containing a NATS user seed:

```sh
kubectl create secret generic health-check-operator-nats-nkey \
  --from-file=NKEY=/path/to/user.nk
```

Then reference it from the trigger instead of `credentialsSecretRef`:

```yaml
spec:
  url: nats://nats-core.nats.svc.cluster.local:4222
  subject: health-check-operator.checks
  nkeySecretRef:
    name: health-check-operator-nats-nkey
    key: NKEY
```

For TLS certificate authentication, create a Kubernetes TLS Secret in the namespace where the `NATSTrigger` lives:

```sh
kubectl create secret tls health-check-operator-nats-tls \
  --cert=/path/to/tls.crt \
  --key=/path/to/tls.key
```

If the NATS server certificate is signed by a private CA, create the Secret with the CA certificate too:

```sh
kubectl create secret generic health-check-operator-nats-tls \
  --from-file=tls.crt=/path/to/tls.crt \
  --from-file=tls.key=/path/to/tls.key \
  --from-file=ca.crt=/path/to/ca.crt
```

Then reference it from the trigger instead of `credentialsSecretRef` or `nkeySecretRef`:

```yaml
spec:
  url: tls://nats-core.nats.svc.cluster.local:4222
  subject: health-check-operator.checks
  tlsSecretRef:
    name: health-check-operator-nats-tls
    certKey: tls.crt
    keyKey: tls.key
    caKey: ca.crt
```

Uninstall:

```sh
helm uninstall health-check-operator -n health-check-operator-system
```

CRDs are rendered as regular chart templates from `chart/templates/crds`, so `helm upgrade` applies CRD changes. They carry the `helm.sh/resource-policy: keep` annotation and are therefore not removed by `helm uninstall`; delete them manually if you really want them gone (this deletes all HttpCheck/CustomResourceCheck/NatsTrigger resources).

CRD rendering can be controlled via values (same contract as the shopware-operator chart):

```yaml
crds:
  # Install and upgrade CRDs
  install: true
  # This will install only the crd's
  installOnly: false
```

Use `crds.installOnly=true` for a CRDs-only release (e.g. a bootstrap/GitOps application that manages CRDs separately), and `crds.install=false` to skip CRDs entirely when they are managed out of band.

Note for installs that predate this layout (CRDs from the former `chart/crds` directory): Helm refuses to adopt existing unmanaged resources. Re-label them once before upgrading:

```sh
for crd in httpchecks customresourcechecks natstriggers; do
  kubectl annotate crd $crd.healthcheck.shopware.com \
    meta.helm.sh/release-name=<release> meta.helm.sh/release-namespace=<namespace> --overwrite
  kubectl label crd $crd.healthcheck.shopware.com app.kubernetes.io/managed-by=Helm --overwrite
done
```
