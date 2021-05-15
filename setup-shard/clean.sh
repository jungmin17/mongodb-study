#!/bin/bash

SHARD_REPLICA_SET=3

## ============ config ============
echo -e "Deleting config nodes"
kubectl delete -f  mongo_config.yaml

echo "Waiting config containers"
kubectl get pods | grep "mongocfg"
while [ $? -eq 0 ]
do
  sleep 2
  echo -e "\n\nWaiting the following containers:"
  kubectl get pods | grep "mongocfg"
done

echo -e "\nDeleting config pvc"
for ((i=0; i<$SHARD_REPLICA_SET; i++)) do
    kubectl delete pvc data-mongocfg-$i
done

## ============ shard 1,2,3 ============
echo -e "\nDeleting shard nodes"
for ((rs=0; rs<$SHARD_REPLICA_SET; rs++)) do
    kubectl delete -f  mongo_sh_$rs.yaml
done

echo "Waiting shard containers"
kubectl get pods | grep "mongosh"
while [ $? -eq 0 ]
do
  sleep 2
  echo -e "\n\nWaiting the following containers:"
  kubectl get pods | grep "mongosh"
done

echo -e "\nDeleting shard 1,2,3 pvc"
for ((rs=0; rs<$SHARD_REPLICA_SET; rs++)) do
    for ((i=0; i<$SHARD_REPLICA_SET; i++)) do
      kubectl delete pvc data-mongosh$rs-$i
    done
done

## ============ mongos ============
echo -e "\nDeleting mongos nodes"
kubectl delete -f mongos.yaml

echo "Waiting config containers"
kubectl get pods | grep "mongos"
while [ $? -eq 0 ]
do
  sleep 2
  echo -e "\n\nWaiting the following containers:"
  kubectl get pods | grep -v "mongosh" | grep "mongos"
done

kubectl delete pvc data-mongos-0
