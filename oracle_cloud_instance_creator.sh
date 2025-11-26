#!/bin/bash

source .env

if [[ -z "${TENANCY_ID}" ]]; then
    echo "TENANCY_ID is unset or empty. Please change in .env file"
    exit 1
else
    echo "TENANCY_ID is set correctly"
fi

# To verify that the authentication with Oracle cloud works
echo "Checking Connection with this request: "
oci iam compartment list
if [ $? -ne 0 ]; then
    echo "Connection to Oracle cloud is not working. Check your setup and config again!"
    exit 1
else
    echo "Connection to Oracle cloud is working!"
fi

# ----------------------CUSTOMIZE---------------------------------------------------------------------------------------

# Don't go too low or you run into 429 TooManyRequests
requestInterval=60 # seconds

# VM params
cpus=4 # max 4 cores
ram=24 # max 24gb memory
bootVolume=150 # disk size in gb

profile="DEFAULT"

# ----------------------ENDLESS LOOP TO REQUEST AN ARM INSTANCE---------------------------------------------------------

while true; do
    echo "Requesting new ARM instance with $cpus OCPU(s), $ram GB RAM and $bootVolume GB boot volume..."

    output=$(oci compute instance launch --no-retry \
        --display-name big-arm \
        --image-id "$IMAGE_ID" \
        --subnet-id "$SUBNET_ID" \
        --availability-domain "$AVAILABILITY_DOMAIN" \
        --shape 'VM.Standard.A1.Flex' \
        --shape-config "{'ocpus':$cpus,'memoryInGBs':$ram}" \
        --boot-volume-size-in-gbs "$bootVolume" \
        --compartment-id "$TENANCY_ID" \
        --ssh-authorized-keys-file "$PATH_TO_PUBLIC_SSH_KEY" 2>&1)

    echo "------------------ CLI OUTPUT ------------------"
    echo "$output"
    echo "-----------------------------------------------"

    # Retry only if message contains "Out of host capacity."
    if echo "$output" | grep -q '"message": "Out of host capacity."' ; then
        echo "Out of host capacity detected. Retrying in $requestInterval seconds..."
        sleep $requestInterval
    else
        echo "Message is different from 'Out of host capacity.'. Exiting loop."
        break
    fi
done
