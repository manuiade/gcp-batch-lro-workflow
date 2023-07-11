#!/bin/bash


x=2
y=$1

while [[ $x -le $y ]]
do
    let LIMIT=$x-1
    for ((a=2; a <= LIMIT ; a++))
        do
            let check=$x%$a
            if [[ $check -eq 0 ]]
            then
                    #echo "$x is not prime"
                    break
            fi
        done
    if [[ $a -gt $LIMIT ]]
    then
        echo "$x is a prime number"
    fi
    let x=$x+1
done

### Callback for Workflow
if [[ ! -z $CALLBACK_URL ]]; then
    echo "Done: making callback.."
    TOKEN=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token | jq -r .access_token)
    curl -H "Authorization: Bearer $TOKEN" $CALLBACK_URL
fi