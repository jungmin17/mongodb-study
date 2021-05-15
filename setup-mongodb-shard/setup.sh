#!/bin/bash

SHARD_REPLICA_SET=3

## ============ config ============
kubectl create -f  mongo_config.yaml

echo "Waiting config containers"
kubectl get pods | grep "mongocfg" | grep -v "Running"
while [ $? -eq 0 ]
do
  sleep 2
  echo -e "\n\nWaiting the following containers:"
  kubectl get pods | grep "mongocfg" | grep -v "Running"
done

sleep 2

echo -e "\n\n---------------------------------------------------"
echo "Initializing config"

dns_result=$(kubectl -it exec mongocfg-0 -- cat /etc/resolv.conf | grep search)
myarray=()
for word in $dns_result; do
    myarray+=($word)
done

CMD="rs.initiate({ _id : \"cfgrs\", configsvr: true, members: [{ _id : 0, host : \"mongocfg-0.mongocfg-svc.${myarray[1]}:27017\" },{ _id : 1, host : \"mongocfg-1.mongocfg-svc.${myarray[1]}:27017\" },{ _id : 2, host : \"mongocfg-2.mongocfg-svc.${myarray[1]}:27017\" }]})"
echo $CMD
kubectl exec -it mongocfg-0 -- bash -c "mongo --eval '$CMD'"


## ============ shard 1,2,3 ============
for ((rs=0; rs<$SHARD_REPLICA_SET; rs++)) do
    kubectl create -f  mongo_sh_$rs.yaml
done

echo "Waiting shard containers"
kubectl get pods | grep "mongosh" | grep -v "Running"
while [ $? -eq 0 ]
do
  sleep 2
  echo -e "\n\nWaiting the following containers:"
  kubectl get pods | grep "mongosh" | grep -v "Running"
done

sleep 2

for ((rs=0; rs<$SHARD_REPLICA_SET; rs++)) do
    echo -e "\n\n---------------------------------------------------"
    echo "Initializing mongodb sh$rs"

    CMD="rs.initiate({ _id : \"rs$rs\", members: [{ _id : 0, host : \"mongosh$rs-0.mongosh$rs-svc.${myarray[1]}:27017\" },{ _id : 1, host : \"mongosh$rs-1.mongosh$rs-svc.${myarray[1]}:27017\" },{ _id : 2, host : \"mongosh$rs-2.mongosh$rs-svc.${myarray[1]}:27017\" }]})"
    echo $CMD
    kubectl exec -it mongosh$rs-0 -- bash -c "mongo --eval '$CMD'"
done

## ============ mongos ============

echo -e "\n\n---------------------------------------------------"
echo "configDB to mongos"

result="cfgrs/mongocfg-0.mongocfg-svc.${myarray[1]}:27017,mongocfg-1.mongocfg-svc.${myarray[1]}:27017,mongocfg-2.mongocfg-svc.${myarray[1]}:27017"

sed -i "" "s@cfgrs@$result@g" mongos.yaml

kubectl create -f mongos.yaml

echo "Waiting mongos containers"
kubectl get pods | grep "mongos" | grep -v "Running"
while [ $? -eq 0 ]
do
  sleep 1
  echo -e "\n\nWaiting the following containers:"
  kubectl get pods | grep "mongos" | grep -v "Running"
done

sed -i "" "s@$result@cfgrs@g" mongos.yaml

sleep 2

for ((rs=0; rs<$SHARD_REPLICA_SET; rs++)) do
    echo -e "\n\n---------------------------------------------------"
    echo "Adding shard $rs to router"

    CMD="sh.addShard(\"rs$rs/mongosh$rs-0.mongosh$rs-svc.${myarray[1]}:27017,mongosh$rs-1.mongosh$rs-svc.${myarray[1]}:27017,mongosh$rs-2.mongosh$rs-svc.${myarray[1]}:27017\")"
    echo $CMD
    kubectl exec -it mongos-0 -- bash -c "mongo --eval '$CMD'"
done

echo "mongodb shard done!!!"
