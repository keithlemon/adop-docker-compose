#!/bin/bash -e

echo ' 
      ###    ########   #######  ########  
     ## ##   ##     ## ##     ## ##     ## 
    ##   ##  ##     ## ##     ## ##     ## 
   ##     ## ##     ## ##     ## ########  
   ######### ##     ## ##     ## ##        
   ##     ## ##     ## ##     ## ##        
   ##     ## ########   #######  ##        
'

echo '
*****************************************************
*                  EVALUATION MODE                  *
*****************************************************
* Quickstart is designed to get you up and running  *
* with the DevOps Platform as quickly as possible.  *
* As such it is not a "production" ready deployment *
* and therefore we brand it as "evaluation mode".   *
* In using quickstart you are acknowledging this,   *
* along with the lack of proper security, backups,  *
* patching, and other operational considerations.   *
*****************************************************
'

usage(){
   cat <<END_USAGE

Usage:
        ./quickstart.sh 
	    -t local 
	    [-m <MACHINE_NAME>] 
	    [-u <INITIAL_ADMIN_USER>] 
	    [-p <INITIAL_ADMIN_PASSWORD>]

        ./quickstart.sh 
	    -t aws 
	    -m <MACHINE_NAME> 
	    -c <AWS_VPC_ID> 
	    -r <AWS_DEFAULT_REGION> 
	    [-z <AVAILABILITY_ZONE_LETTER>] 
	    [-a <AWS_ACCESS_KEY>] 
	    [-s <AWS_SECRET_ACCESS_KEY>] 
	    [-u <INITIAL_ADMIN_USER>] 
	    [-p <INITIAL_ADMIN_PASSWORD>]

        ./quickstart.sh 
	    -t azure
	    -i <AZURE_SUBSCIPTION_ID>
	    [-m <MACHINE_NAME>]
	    [-l <AZURE_LOCATION>]
	    [-g <AZURE_RESOURCE_GROUP>]
	    [-u <INITIAL_ADMIN_USER>] 
	    [-p <INITIAL_ADMIN_PASSWORD>]

END_USAGE
}

provision_local() {
    if [ -z ${MACHINE_NAME} ]; then
        MACHINE_NAME=adop
    fi

    # Allow script to continue if error returned by docker-machine command
    set +e

    # Create Docker machine if one doesn't already exist with the same name
    docker-machine ip ${MACHINE_NAME} > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "Docker machine '$MACHINE_NAME' already exists"
    else
	# To run adop stack locally atleast 6144 MB is required.
        docker-machine create --driver virtualbox --virtualbox-memory 6144 ${MACHINE_NAME}
    fi

    # Reenable errexit
    set -e

}

provision_azure() {
    if [ -z ${AZURE_SUBSCIPTION_ID} ]; then
        echo "ERROR: Mandatory parameters missing!"
        usage
        exit 1
    fi

    if [ -z ${MACHINE_NAME} ]; then
        echo "No machine name specified - using default [adop]."
        MACHINE_NAME=adop
    fi

    if [ -z ${AZURE_LOCATION} ]; then
        echo "No Azure Location specified - using default [westeurope]."
        AZURE_LOCATION=westeurope
    fi

    if [ -z ${AZURE_RESOURCE_GROUP} ]; then
        echo "No resource group name specified - using default [docker-machine]."
        AZURE_RESOURCE_GROUP=docker-machine
    fi

    # Allow script to continue if error returned by docker-machine command
    set +e

    # Create Docker machine if one doesn't already exist with the same name
    docker-machine ip ${MACHINE_NAME} > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "Docker machine '$MACHINE_NAME' already exists"
    else
        docker-machine create --driver azure \
          --azure-subscription-id "${AZURE_SUBSCIPTION_ID}" \
          --azure-location "${AZURE_LOCATION}" \
          --azure-resource-group "${AZURE_RESOURCE_GROUP}" \
          --azure-size Standard_DS3_v2 \
          --azure-open-port 80 ${MACHINE_NAME}
    fi

    # Reenable errexit
    set -e

}


# Function to create AWS-specific environment variables file
source_aws() {  
  AWS_FILE='./conf/provider/env.provider.aws.sh'

  if [ -f ${AWS_FILE} ]; then  
    echo "Your AWS parameters file already exists, deleting it..."
    rm -f ${AWS_FILE}
  fi
    
  echo "Creating a new AWS variables file..."
  cp ./conf/provider/examples/env.provider.aws.sh.example ${AWS_FILE}

  # AWS-specific environment variables
  if [ -z ${AWS_VPC_ID} ]; then
    usage
    exit 1
  else    
    sed -i'' -e "s/###AWS_VPC_ID###/$AWS_VPC_ID/g" ${AWS_FILE}
  fi

  if [ -z ${AWS_KEYPAIR} ]; then
    sed -i'' -e "s/###AWS_KEYPAIR###/$MACHINE_NAME/g" ${AWS_FILE}
  else
    sed -i'' -e "s/###AWS_KEYPAIR###/$AWS_KEYPAIR/g" ${AWS_FILE}
  fi

  if [ -z ${AWS_INSTANCE_TYPE} ]; then
    sed -i'' -e "s/###AWS_INSTANCE_TYPE###/t2.large/g" ${AWS_FILE}
  else
    sed -i'' -e "s/###AWS_INSTANCE_TYPE###/$AWS_INSTANCE_TYPE/g" ${AWS_FILE}
  fi

  if [ -z ${AWS_SUBNET_ID} ]; then
    sed -i'' -e "s/###AWS_SUBNET_ID###/default/g" ${AWS_FILE}
  else
    sed -i'' -e "s/###AWS_SUBNET_ID###/$AWS_SUBNET_ID/g" ${AWS_FILE}
  fi
  
  sed -i'' -e "s/###AWS_DEFAULT_REGION###/$AWS_DEFAULT_REGION/g" ${AWS_FILE}

}

provision_aws() {
    if [ -z ${MACHINE_NAME} ] | \
       [ -z ${AWS_VPC_ID} ] | \
       [ -z ${AWS_DEFAULT_REGION} ]; then
        echo "ERROR: Mandatory parameters missing!"
        usage
        exit 1
    fi

    if [ -z ${VPC_AVAIL_ZONE} ]; then
        echo "No availability zone specified - using default [a]."
        export VPC_AVAIL_ZONE=a
    elif [[ ! ${VPC_AVAIL_ZONE} =~ ^[a-e]{1,1}$ ]]; then
            echo "Availability zone can only be a single lower case char, 'a' to 'e'. Exiting..."
            exit 1
    fi

    if [ -z ${AWS_ACCESS_KEY_ID} ];
    then
      echo "WARN: AWS_ACCESS_KEY_ID not set (externally or with -a), delegating to Docker Machine"
    fi

    if [ -z ${AWS_SECRET_ACCESS_KEY} ];
    then
      echo "WARN: AWS_SECRET_ACCESS_KEY not set (externally or with -s), delegating to Docker Machine"
    fi
    
    if [ -z ${AWS_DOCKER_MACHINE_SIZE} ]; then
    	export AWS_DOCKER_MACHINE_SIZE="m4.xlarge"
    fi

    # Create a file with AWS parameters
    source_aws

    # Allow script to continue if error returned by docker-machine command
    set +e

    # Create Docker machine if one doesn't already exist with the same name
    docker-machine ip ${MACHINE_NAME} > /dev/null 2>&1
    rc=$?
    
    # Reenable errexit
    set -e
    
    if [ ${rc} -eq 0 ]; then
        echo "Docker machine '$MACHINE_NAME' already exists"
    else
        MACHINE_CREATE_CMD="docker-machine create \
                    --driver amazonec2 \
                    --amazonec2-vpc-id ${AWS_VPC_ID} \
                    --amazonec2-zone $VPC_AVAIL_ZONE \
                    --amazonec2-instance-type ${AWS_DOCKER_MACHINE_SIZE} \
                    --amazonec2-root-size ${AWS_ROOT_SIZE:-32}"

        if [ -n "${AWS_ACCESS_KEY_ID}" ] && [ -n "${AWS_SECRET_ACCESS_KEY}" ] && [ -n "${AWS_DEFAULT_REGION}" ]; then
            MACHINE_CREATE_CMD="${MACHINE_CREATE_CMD} \
                        --amazonec2-access-key ${AWS_ACCESS_KEY_ID} \
                        --amazonec2-secret-key ${AWS_SECRET_ACCESS_KEY} \
                        --amazonec2-region ${AWS_DEFAULT_REGION}"
        fi

        MACHINE_CREATE_CMD="${MACHINE_CREATE_CMD} ${MACHINE_NAME}"
        ${MACHINE_CREATE_CMD}
    fi
}

while getopts "t:m:a:s:c:z:r:u:p:i:l:g:h" opt; do
  case ${opt} in
    t)
      export MACHINE_TYPE=${OPTARG}
      ;;
    m)
      export MACHINE_NAME=${OPTARG}
      ;;
    a)
      export AWS_ACCESS_KEY_ID=${OPTARG}
      ;;
    s)
      export AWS_SECRET_ACCESS_KEY=${OPTARG}
      ;;
    c)
      export AWS_VPC_ID=${OPTARG}
      ;;
    z)
      export VPC_AVAIL_ZONE=${OPTARG}
      ;;
    r)
      export AWS_DEFAULT_REGION=${OPTARG}
      ;;
    u)
      export INITIAL_ADMIN_USER=${OPTARG}
      ;;
    p)
      export INITIAL_ADMIN_PASSWORD_PLAIN=${OPTARG}
      ;;      
    i)
      export AZURE_SUBSCIPTION_ID=${OPTARG}
      ;;      
    l)
      export AZURE_LOCATION=${OPTARG}
      ;;      
    g)
      export AZURE_RESOURCE_GROUP=${OPTARG}
      ;;      
    h)
      usage
      exit
      ;;
    *)
      echo "Invalid parameter(s) or option(s)."
      usage
      exit 1
      ;;
  esac
done

if [ -z ${MACHINE_TYPE} ]; then
    echo "Please specify a machine type to create during quickstart"
    usage
    exit 1
fi

CLI_COMPOSE_OPTS=""

# Switch based on the machine type
case ${MACHINE_TYPE} in
    "local")
        provision_local
        ;;
    "aws")
        provision_aws
        CLI_COMPOSE_OPTS="-f etc/aws/default.yml"
        ;;
    "azure")
        provision_azure
        ;;
    *)
        echo "Invalid parameter(s) or option(s)."
        usage
        exit 1
        ;;
esac

# Use the ADOP CLI
eval $(docker-machine env ${MACHINE_NAME})

./adop compose -m "${MACHINE_NAME}" ${CLI_COMPOSE_OPTS} init

# Generate and export Self-Signed SSL certificate for Docker Registry, applicable only for AWS type
if [ ${MACHINE_TYPE} == "aws" ]; then
    ./adop certbot gen-export-certs "registry.$(docker-machine ip ${MACHINE_NAME}).nip.io" registry
fi
