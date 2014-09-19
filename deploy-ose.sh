#!/bin/bash 

#------------------------------------------------------------------------------------# 
# File: deploy-ose.sh                                                                # 
# Date: 2014-09-18                                                                   # 
# Desc: Script to simplify deployment of OpenShift Enterprise across a distributed   #
#       (e.g. 3 broker, 3 node) environment. Script uses a small set of environment  #
#       variables (described below) that are passed to openshift.sh.                 #
#       To use:                                                                      #
#          1. Copy/save this script to the first broker host (primary)               # 
#          2. Modify the following environment variables as appropriate:             # 
#             - DOMAIN                                                               # 
#             - BROKER1, BROKER2, BROKER3  (add/delete to match number of brokers)   # 
#             - NODE1, NODE2, NODE3        (add/delete to match number of nodes)     # 
#             - CONF_NAMED_IP_ADDR=ip_address_of_IdM_server                          # 
#             - CONF_ACTIVEMQ_REPLICANTS   (add/delete to match number of brokers)   #
#             - CONF_DATASTORE_REPLICANTS  (add/delete to match number of brokers)   #
#          3. For Node hosts only:                                                   # 
#             If a load balancer is in use for broker hosts, then configure 'broker' #
#             to that name:                                                          #
#                           export BROKER_HOSTNAME="broker.${DOMAIN}"                # 
#             otherwise, set to any valid broker host name:                          #
#                           export BROKER_HOSTNAME="broker1.${DOMAIN}"               #
#             Only set this value at line 137 in the script.                         # 
#          4. Set the script execute permissions (e.g. chmod 755, chmod u+x, etc.)   # 
#          5. Copy this script to each of the remaining broker hosts, node hosts     # 
#          6. Run the script as root on each host according to type, in this order:  # 
#             - Secondary broker hosts:                                              # 
#                    ./deploy-ose.sh secondary (e.g. - broker2, broker3, etc.)       # 
#             - Primary broker host:                                                 # 
#                    ./deploy-ose.sh primary   (e.g. - broker1)                      # 
#             - All node hosts:                                                      # 
#                    ./deploy-ose.sh node      (e.g. - node1, node2, etc.)           # 
#          7. Post deployment, run the script as root on the Primary broker host:    #
#             - Primary broker host only:                                            #
#                    ./deploy-ose.sh post-deploy                                     # 
# Note: Script is provided as a supplement to the Red Hat Reference Architecture:    # 
#       "Integrating OpenShift Enterprise with Identity Management (IdM)             #
#        in Red Hat Enterprise Linux". For more details see:                         # 
#             http://www.redhat.com/resourcelibrary/reference-architectures/         #
#------------------------------------------------------------------------------------# 

# 
# Add/delete/modify according to your environment: 
# 
DOMAIN="interop.example.com" 
BROKER1="broker1.${DOMAIN}" 
BROKER2="broker2.${DOMAIN}" 
BROKER3="broker3.${DOMAIN}" 
NODE1="node1.${DOMAIN}" 
NODE2="node2.${DOMAIN}" 
NODE3="node3.${DOMAIN}" 


# 
# Applies to all host types - do not modify: 
# 
export CONF_INSTALL_METHOD="none" 
export CONF_DOMAIN=${DOMAIN} 
export CONF_KEEP_HOSTNAME="true" 

#-----------------# 
# Broker details: # 
#-----------------# 

# Set CONF_NAMED_IP_ADDRESS to use IdM server for lookups 
export CONF_NAMED_IP_ADDR="10.19.140.101"
export BROKER_HOSTNAME=`/bin/hostname`
export CONF_BROKER_HOSTNAME="${BROKER_HOSTNAME}" 
export CONF_ACTIVEMQ_HOSTNAME=`/bin/hostname`
export CONF_DATASTORE_HOSTNAME=`/bin/hostname`

# Add/delete according to the number of brokers in your environment: 
export CONF_ACTIVEMQ_REPLICANTS="${BROKER1},${BROKER2},${BROKER3}" 
export CONF_DATASTORE_REPLICANTS="${BROKER1}:27017,${BROKER2}:27017,${BROKER3}:27017" 

# 
# Set username/passwords according to your environment security policies: 
# 
export CONF_OPENSHIFT_USER1="user1" 
export CONF_OPENSHIFT_PASSWORD1="password" 
export CONF_MONGODB_BROKER_USER="openshift" 
export CONF_MONGODB_BROKER_PASSWORD="mongopass" 
export CONF_MONGODB_ADMIN_USER="admin1"
export CONF_MONGODB_ADMIN_PASSWORD="mongopass"
export CONF_MONGODB_REPLSET="ose"
export CONF_MONGODB_KEY="OSEnterprise"
export CONF_MCOLLECTIVE_USER="mcollective" 
export CONF_MCOLLECTIVE_PASSWORD="mcollective" 
export CONF_ACTIVEMQ_ADMIN_PASSWORD="password" 
export CONF_ACTIVEMQ_AMQ_USER_PASSWORD="password" 

#------# 
# Main # 
#------# 

function usage { 
  printf "\n\tusage:  $0 primary|secondary|node|post-deploy\n\n" 
  exit 1 
} 

if [ "`whoami`" != "root" ] 
then 
  printf "\n\t*** Must be root to run ***\n\n" 
  exit 2 
fi 

if [ $# != 1 ] 
then 
  usage 
fi 

# 
# Set installation target type 
# 
case $1 in 
  primary) 
    TARGET="the *Primary* Broker" 
    # secondary brokers must be fully running before replica set is initiated 
    export CONF_INSTALL_COMPONENTS="broker,activemq,datastore" 
    export CONF_ACTIONS="do_all_actions,configure_datastore_add_replicants" 
    ;; 

  secondary) 
    TARGET="a *Secondary* Broker" 
    export CONF_INSTALL_COMPONENTS="broker,activemq,datastore" 
    export CONF_ACTIONS="do_all_actions"
    ;; 

  node) 
    TARGET="a *Node*" 
    export CONF_INSTALL_COMPONENTS="node" 
    export CONF_ACTIONS="do_all_actions"
    NODE=`/bin/hostname`
    export CONF_NODE_HOSTNAME="${NODE}" 
    # Adjust accordingly to match whether or not load balancer in use:
    export BROKER_HOSTNAME="broker.${DOMAIN}"
    ;; 

  post-deploy) 
    TARGET="" 
    TYPE=$1
    ;; 

  *) 
    usage 
    ;; 
esac 

# 
#-------------------------------------------------------------------# 
# Download and run openshift.sh using the previously set variables: # 
#-------------------------------------------------------------------# 
# 
printf "\nDeploying OpenShift Enterprise in a distributed environment\n" 
printf "\n\t...Installation type set to *${1}*...\n" 
sleep 2 
if [ $1 != "post-deploy" ]
then 
   printf "\n*** Control-C now if this is not ${TARGET} or the wrong host ***\n" 
   sleep 8 
   printf "\n\t...Continuing with installation...\n" 
else
   printf "\n\t...Continuing with post deployment tasks...\n" 
fi

printf "\n\t...Downloading openshift.sh script...\n\n" 
sleep 5 

curl https://raw.githubusercontent.com/openshift/openshift-extras/enterprise-2.1/enterprise/install-scripts/generic/openshift.sh -o openshift.sh 
if [ $? != 0 ] 
then 
  printf "\n\t*** Can not complete download ***\n"  
  printf "\nThe openshift.sh script (or site) is currently not accessible.\n"  
  exit 3 
fi 

printf "\n\t* Script download complete *\n"  
chmod 755 openshift.sh 2>&1 | tee /tmp/openshift.out 

if [ $1 != "post-deploy" ]
then 
   printf "\n\t...Beginning installation - `date` ...\n\n" 
   ./openshift.sh 
   printf "\n\t* Installation completed - `date` * \n\n"
else
   printf "\n\t...Beginning post deployment tasks - `date` ...\n" 
   ./openshift.sh "actions=post_deploy" 
   printf "\n\t* Post deployment tasks completed - `date` * \n\n"
fi

exit 0
