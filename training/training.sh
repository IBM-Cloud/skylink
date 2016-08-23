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
 
echo -e "${RED}Deleting old classifiers${NC}"
CLASSIFIERS=`curl -X GET -H "Accept-Language: en" "https://gateway-a.watsonplatform.net/visual-recognition/api/v3/classifiers?&api_key=${WATSON_VISION_KEY}&version=2016-05-20"`

# echo -e "$CLASSIFIERS"

LINES=`echo "$CLASSIFIERS" | grep classifier_id`
# echo -e "$LINES"

for LINE in $LINES ; do
    if [[ $LINE == *"skylink_"* ]]
    then
        LINE=`echo $LINE | tr -d '"'`
        LINE=`echo $LINE | tr -d ','`
        echo -e "${RED}Deleting: $LINE${NC}"
        curl -X DELETE "https://gateway-a.watsonplatform.net/visual-recognition/api/v3/classifiers/$LINE?api_key=${WATSON_VISION_KEY}&version=2016-05-20"
    fi
done

echo -e "${YELLOW}Training to recognize tennis courts... ${NC}"
curl -X POST -F "tennis_positive_examples=@positive.zip" -F "negative_examples=@negative.zip" -F "name=skylink_tennis" "https://gateway-a.watsonplatform.net/visual-recognition/api/v3/classifiers?api_key=${WATSON_VISION_KEY}&version=2016-05-20"



echo -e "${YELLOW}checking status... ${NC}"
for X in {1..30}
do
    printf "."
	sleep 1
done
echo "."
CLASSIFIERS=`curl -X GET -H "Accept-Language: en" "https://gateway-a.watsonplatform.net/visual-recognition/api/v3/classifiers?&api_key=${WATSON_VISION_KEY}&version=2016-05-20"`
echo -e "${YELLOW}$CLASSIFIERS${NC}"


echo -e "${GREEN}Training Complete${NC}"

