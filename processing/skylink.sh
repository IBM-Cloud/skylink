#!/bin/bash
#
# Copyright 2016 IBM Corp. All Rights Reserved.
# 
# Licensed under the Apache License, Version 2.0 (the “License”);
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#  https://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an “AS IS” BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
 
# Color vars to be used in shell script output
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'
 
# load configuration variables
source local.env

# capture the namespace where actions will be created
# as we need to pass it to our change listener
CURRENT_NAMESPACE=`wsk property get --namespace | awk '{print $3}'`
echo "Current namespace is $CURRENT_NAMESPACE."

function usage() {
  echo -e "${YELLOW}Usage: $0 [--install,--uninstall,--reinstall,--env]${NC}"
}

function install() {
  echo -e "${YELLOW}Installing..."
  
  echo "Creating overwatch package"
  wsk package create overwatch
  
  echo "Adding VCAP_SERVICES as parameter"
  wsk package update overwatch\
    -p cloudantUrl https://$CLOUDANT_username:$CLOUDANT_password@$CLOUDANT_host\
    -p alchemyKey $ALCHEMY_key\
    -p watsonUsername $WATSON_username\
    -p watsonPassword $WATSON_password\
    -p cloudantDbName $CLOUDANT_db
    
  # we will need to listen to cloudant event
  echo "Binding cloudant"
  # /whisk.system/cloudant
  wsk package bind /whisk.system/cloudant \
    overwatch-cloudant\
    -p username $CLOUDANT_username\
    -p password $CLOUDANT_password\
    -p host $CLOUDANT_host

  echo "Creating trigger"
  wsk trigger create overwatch-cloudant-trigger --feed overwatch-cloudant/changes -p dbname $CLOUDANT_db -p includeDoc true

  echo "Creating actions"
  wsk action create overwatch/analysis analysis.js
  
  echo "Creating change listener action"
  wsk action create overwatch-cloudant-changelistener changelistener.js\
   -p targetNamespace $CURRENT_NAMESPACE
    
  echo "Enabling change listener"
  wsk rule create overwatch-rule overwatch-cloudant-trigger overwatch-cloudant-changelistener --enable
  
  echo -e "${GREEN}Install Complete${NC}"
  wsk list
}

function uninstall() {
  echo -e "${RED}Uninstalling..."
  
  echo "Removing actions..."
  wsk action delete overwatch/analysis
  
  echo "Removing rule..."
  wsk rule disable overwatch-rule
  wsk rule delete overwatch-rule
  
  echo "Removing change listener..."
  wsk action delete overwatch-cloudant-changelistener
  
  echo "Removing trigger..."
  wsk trigger delete overwatch-cloudant-trigger
  
  echo "Removing packages..."
  wsk package delete overwatch-cloudant
  wsk package delete overwatch
  
  echo -e "${GREEN}Uninstall Complete${NC}"
  wsk list
}

function showenv() {
  echo -e "${YELLOW}"
  echo CLOUDANT_username=$CLOUDANT_username
  echo CLOUDANT_password=$CLOUDANT_password
  echo CLOUDANT_host=$CLOUDANT_host
  echo CLOUDANT_db=$CLOUDANT_db
  echo ALCHEMY_key=$ALCHEMY_key
  echo WATSON_username=$WATSON_username
  echo WATSON_password=$WATSON_password
  echo -e "${NC}"
}

case "$1" in
"--install" )
install
;;
"--uninstall" )
uninstall
;;
"--update" )
update
;;
"--reinstall" )
uninstall
install
;;
"--env" )
showenv
;;
* )
usage
;;
esac