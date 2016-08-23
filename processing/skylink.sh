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
  
  echo "Creating skylink-swift package"
  wsk package create skylink-swift
  
  echo "Adding VCAP_SERVICES as parameter"
  wsk package update skylink-swift\
    -p cloudantUrl https://$CLOUDANT_username:$CLOUDANT_password@$CLOUDANT_host\
    -p cloudantUsername $CLOUDANT_username\
    -p cloudantPassword $CLOUDANT_password\
    -p cloudantHost $CLOUDANT_host\
    -p cloudantDbName $CLOUDANT_db\
    -p targetNamespace $CURRENT_NAMESPACE\
    -p watsonKey $WATSON_key
    
  # we will need to listen to cloudant event
  echo "Binding cloudant"
  # /whisk.system/cloudant
  wsk package bind /whisk.system/cloudant \
    skylink-swift-cloudant\
    -p username $CLOUDANT_username\
    -p password $CLOUDANT_password\
    -p dbname $CLOUDANT_db\
    -p host $CLOUDANT_host

  echo "Creating trigger"
  wsk trigger create skylink-swift-cloudant-update-trigger --feed skylink-swift-cloudant/changes -p dbname $CLOUDANT_db -p includeDoc true


  echo "Creating analysis actions"

  echo "Creating change listener action"
   wsk action create --kind swift:3 skylink-swift-cloudant-changelistener actions/ChangeListener.swift -t 300000\
   -p targetNamespace $CURRENT_NAMESPACE

  echo "Enabling change listener"
  wsk rule create skylink-swift-rule skylink-swift-cloudant-update-trigger skylink-swift-cloudant-changelistener --enable
  
  wsk action create --kind swift:3 skylink-swift/watsonAnalysis actions/WatsonVisualRecognition.swift -t 300000
  wsk action create --kind swift:3 skylink-swift/cloudantRead actions/CloudantRead.swift -t 300000
  wsk action create --kind swift:3 skylink-swift/cloudantWrite actions/CloudantWrite.swift -t 300000
  wsk action create --kind swift:3 skylink-swift/processImage actions/Orchestrator.swift -t 300000
  wsk action create skylink-swift/generateThumbnails actions/GenerateThumbnail.js -t 300000
  
  echo -e "${GREEN}Install Complete${NC}"
  wsk list
}

function uninstall() {
  echo -e "${RED}Uninstalling..."
  
  echo "Removing current actions..."
  wsk action delete skylink-swift/watsonAnalysis
  wsk action delete skylink-swift/cloudantRead
  wsk action delete skylink-swift/cloudantWrite
  wsk action delete skylink-swift/processImage
  wsk action delete skylink-swift/generateThumbnails
  
  
  echo "Removing rules..."
  wsk rule disable skylink-swift-rule
  wsk rule delete skylink-swift-rule
  
  echo "Removing change listener..."
  wsk action delete skylink-swift-cloudant-changelistener
  
  echo "Removing trigger..."
  wsk trigger delete skylink-swift-cloudant-update-trigger

  echo "Removing packages..."
  wsk package delete skylink-swift-cloudant
  wsk package delete skylink-swift
  
  echo -e "${GREEN}Uninstall Complete${NC}"
  wsk list
}

function showenv() {
  echo -e "${YELLOW}"
  echo CLOUDANT_username=$CLOUDANT_username
  echo CLOUDANT_password=$CLOUDANT_password
  echo CLOUDANT_host=$CLOUDANT_host
  echo CLOUDANT_db=$CLOUDANT_db
  echo WATSON_key=$WATSON_key
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