#!/bin/sh -x
unsealed=false

if [ "$BAO_KEYS" == "" ];then
  BAO_KEYS=ibm-edge-auth
fi
bao_keys=$BAO_KEYS

while true
do
  init_status=`vault status  2>/dev/null |grep "Initialized"|awk '{print $2}'|tr -d '\r'`
  seal_status=`vault status  2>/dev/null |grep "Sealed"|awk '{print $2}'|tr -d '\r'`
  if [ "$init_status" != "true" ];then
    output="Bao is not initialized"
  elif [ "$seal_status" == "false" ];then
    output="Bao is unsealed"
    unsealed=true
  elif  [ `kubectl get secret |grep "$bao_keys" |wc -l` == 0 ]; then
    output="Unseal tokens are not found."
  else 

    set +x
    keys=`kubectl get secret $bao_keys -o=jsonpath='{.data.bao-unseal-keys}'|base64 -d`
    IFS=$',' keys=( $keys )
    for var in ${keys[@]}  
    do    
      vault operator unseal $var
    done
    set -x

    output="Unseal keys were submitted."
  fi
  dataStr=`date`
  if [ "$unsealed" == "true" ];then
    echo "$dataStr [Auto-Unseal] $output"
    exit 0
  fi
  echo "$dataStr [Auto-Unseal] $output. Waiting 10 seconds for the next try."
  sleep 10
done
