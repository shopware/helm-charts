# Shopware Operator

Useful links
* [Operator Github repository](https://github.com/shopware-redstone/shopware-operator)

## Pre-requisites
* Kubernetes 1.28+
* Helm v3

# Installation

This chart will deploy the Operator Deployment in you Kubernetes cluster.

## Installing the Chart
To install the chart using a dedicated namespace is recommended:

```sh
helm repo add shopware https://shopware-redstone.github.io/helm-charts/
helm install my-operator shopware/operator --version 0.1.0 --namespace my-namespace
```

Checkout the [values.yaml](values.yaml) file to modify the operator deployment. Change it to
your needs and install it:
```sh
helm install operator -f values.yaml shopware/operator
```
