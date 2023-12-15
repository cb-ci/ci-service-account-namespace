# About

This is a simple script which create a Kubernetes ServiceAccount in a specific namespace.
It does also the Rolebinding and creation of a Kubeconfigfile for this ServiceAccount.
At least it deploys a test pod to the namespace using the created Service Account
The script will delete all the created resources at the end.

Inside the script you can adjust the namespace name and the name of the ServiceAccount

Oriented by 
* https://dev.to/thenjdevopsguy/creating-a-kubernetes-service-account-to-run-pods-3ef9
* https://docs.d2iq.com/dkp/2.4/create-a-kubeconfig-file-for-your-cluster

