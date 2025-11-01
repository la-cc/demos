## OpenChoreo Demo - Single Cluster Setup

This is a short demo, of OpenChoreo in a single kind cluster setup.
You will need have install:

- Docker or similar container runtime - I am using Orbstack on Mac
- [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/)
- [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

TOC:

- [Start with OpenChoreo](#start)
- [Deploy example applications](#deploy-example-applications)
- [Customize your OpenChoreo Setup](#customize-your-openchoreo-setup---tbd)
- [Further Steps](#further-steps)
- [Additional Resources](#additional-resources)



## Start

### 1. Setup Kind Cluster with OpenChoreo + Planes
Just execute the following script to setup a kind cluster with OpenChoreo and all Planes installed. It will take about 10 minutes to complete.
If it fails, just execute the script again.

```bash
./scripts/setup-kind-cluster.sh
```
### 2. Access OpenChoreo and start to explore

after everything is installed, you can access the OpenChoreo Planes with:

```bash
kubectl get namespaces
```

### 3. Acces OpenChoreo UI - Backstage

```bash
kubectl port-forward backstage-demo-.... 7007:7007
```

Open your browser and go to: `http://localhost:7007`

Have fun exploring OpenChoreo!

### 4. Cleanup

To delete the kind cluster, just run:

```bash
kind delete cluster --name openchoreo-demo
```


## Deploy example applications

### Deploy the greeter service

```bash
kubectl apply -f https://raw.githubusercontent.com/openchoreo/openchoreo/release-v0.3/samples/from-image/go-greeter-service/greeter-service.yaml --namespace default
```

### Deploy the reading list service
```bash
kubectl apply -f https://raw.githubusercontent.com/openchoreo/openchoreo/release-v0.3/samples/from-source/services/go-google-buildpack-reading-list/reading-list-service.yaml --namespace default
```

You can explore more here...


### Cleanup

### Delete the greeter service

```bash
kubectl delete -f https://raw.githubusercontent.com/openchoreo/openchoreo/release-v0.3/samples/from-image/go-greeter-service/greeter-service.yaml --namespace default
```

###  Delete the reading list service
```bash
kubectl delete -f https://raw.githubusercontent.com/openchoreo/openchoreo/release-v0.3/samples/from-source/services/go-google-buildpack-reading-list/reading-list-service.yaml --namespace default
```

## Customize your OpenChoreo Setup - TBD

FIXME


## Further Steps

As every plane comes as helm chart, I would recommend your
to add to your Stack, so you can deploy the Planes based on your topology setup with GitOps e.g. ArgoCD or FluxCD.


## Additional Resources

FIXME