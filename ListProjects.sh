#!/usr/bin/env bash
#Copyright 2023 Google LLC
#
#Licensed under the Apache License, Version 2.0 (the "License");
#you may not use this file except in compliance with the License.
#You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
#Unless required by applicable law or agreed to in writing, software
#distributed under the License is distributed on an "AS IS" BASIS,
#WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#See the License for the specific language governing permissions and
#limitations under the License.

# Required permission: roles/resourcemanager.folderViewer
#Declare functions
function getProjects() {
    gcloud projects list --filter="parent.id=$1" --format="value(PROJECT_ID)" >> organizationsList.txt
}
function getFolders() {
    if [ -z $1 ]
    then
        break
    else
        getProjects $i # Get projects at the current folder level
        for i in $(gcloud resource-manager folders list --folder="$1" --format="value(ID)"); do
            getFolders $i # Recurse to iterate into child folders
        done
    fi
}

gcloud projects list --filter=$1 --format="value(PROJECT_ID)" >> organizationsList.txt
for i in $(gcloud resource-manager folders list --organization=$1 --format="value(ID)"); do
    getFolders $i
done
