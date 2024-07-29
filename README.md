# Shopware Helm Charts

![Shopware Helm Charts](shopware.svg)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Overview

This repository contains Helm charts for the following components.

* [Shopware Operator](charts/shopware-operator/)
* [Shopware](charts/shopware/)

Useful links:

* [About Shopware Operator](https://github.com/shopware/shopware-operator)

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

## Installation

You will need [Helm v3](https://github.com/helm/helm) for the installation.
See detailed installation instructions in the README file of each chart.

## Contributing

Shopware welcomes and encourages community contributions to help improve Shopware Operator as well as other Shopware projects.

See the [Contribution Guide](CONTRIBUTING.md) for more information.

### Submitting Bug Reports

If you find a bug related to one of these Helm charts, please submit a bug report to the appropriate repository:

* [Shopware](https://github.com/shopware/helm-charts/issues)
* [Shopware Operator](https://github.com/shopware/shopware-operator/issues)

Learn more about submitting bugs, new feature ideas, and improvements in the [Contribution Guide](CONTRIBUTING.md).

### Join Shopware Kubernetes TaskForce!

```
                                     ,/(((((((*.
                             ,((/(/(/(/(/(/(/(/(/(/(/((
                         /////////////////////////////////(,
                      ((/(/(/(/(/(/(/(/(/(/(/(/(((/(///////(/(*
                   ,//////////////////((,
                 ./(/(/(/(/(/(/(/(/*
                (////////////////
               (/(/(/(/(/(/(/((
              ////////////////                   ./((//(((*,
             (/(/(/(/(/(/(/(/                 /(/(/(/(/(/(/(/(/(/(*
            ,///////////////.                (///////////////////////(
            ((/(/(/(/(/(/(/(                 (/(/(/(/(/(/(/(/(/(/(/(/(/(.
            (///////////////.                 ,/////////////////////////,
            ((/(/(/(/(/(/(/(/                     /(/(/(/(/(/(/(/(/(/(/(.
            .////////////////(                         ./(/////////////(
             //(/(/(/(/(/(/(/(/*                              *(/(/(/(/*
              (//////////////////(                                 .///
               (/(/(/(/(/(/(/(/(/(/((*
                /////////////////////////(*
                  /(/(/(/(/(/(/(/(/(/(/(/(/(/(/(*
                    (///////////////////////////////(/.
                      *(/(/(/(/(/(/(/(/(/(/(/(/(/(/(/(/(/(/
                         .(////////////////////////////////
                              *(/(/(/(/(/(/(/(/(/(/(/(.
                                       ..,,,.


                     ____  _
                    / ___|| |__   ___  _ ____      ____ _ _ __ ___
                    \___ \| '_ \ / _ \| '_ \ \ /\ / / _` | '__/ _ \
                     ___) | | | | (_) | |_) \ V  V / (_| | | |  __/
                    |____/|_| |_|\___/| .__/ \_/\_/ \__,_|_|  \___|
                _    ___        _____ |_|     _    _____
               | | _( _ ) ___  |_   _|_ _ ___| | _|  ___|__  _ __ ___ ___
               | |/ / _ \/ __|   | |/ _` / __| |/ / |_ / _ \| '__/ __/ _ \
               |   < (_) \__ \   | | (_| \__ \   <|  _| (_) | | | (_|  __/
               |_|\_\___/|___/   |_|\__,_|___/_|\_\_|  \___/|_|  \___\___|

```
