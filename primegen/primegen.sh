#!/bin/bash

# Check if the environment variable EXISTS
if [[ -z "${PRIME_NUMBER_LIMIT}" ]]; then
    echo "Error: Environment variable PRIME_NUMBER_LIMIT is not set."
    exit 1
fi

# Check if the number is positive (greater than 0)
if [[ "${PRIME_NUMBER_LIMIT}" -le 0 ]]; then
    echo "Error: PRIME_NUMBER_LIMIT must be a positive integer."
    exit 1
fi

x=2
y=${PRIME_NUMBER_LIMIT}

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

# Exit 0 to confirm the job terminated successfully
exit 0

# ### Callback for Workflow (not needed since we are using workflow connector polling policy)
# if [[ ! -z $CALLBACK_URL ]]; then
#     echo "Done: making callback.."
#     TOKEN=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token | jq -r .access_token)
#     curl -H "Authorization: Bearer $TOKEN" $CALLBACK_URL
# fi