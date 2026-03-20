#!/bin/bash

aws eks update-kubeconfig \
--region ap-south-1 \
--name cloudcart-eks

kubectl get nodes
