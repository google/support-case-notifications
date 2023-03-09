#!/bin/bash
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

# Enable Cloud Run, and Cloud Scheduler, Cloud Logging, Cloud Support API, Cloud Monitoring
gcloud services enable --project "${PROJECT_ID}" cloudbuild.googleapis.com run.googleapis.com cloudscheduler.googleapis.com cloudsupport.googleapis.com monitoring.googleapis.com logging.googleapis.com

# Create Service Accounts for Cloud Scheduler Job and Support API
gcloud iam service-accounts create sa-support-notif-scheduler --description="Run Cloud Run Service on behalf of Cloud Scheduler"
gcloud iam service-accounts create sa-support-api --description="Call the support case API from within code"

#Set permissions for Cloud Scheduler service account with Cloud Run invoker role
gcloud projects add-iam-policy-binding ${PROJECT_ID} --member=serviceAccount:sa-support-notif-scheduler@${PROJECT_ID}.iam.gserviceaccount.com --role=roles/run.invoker

# Set permissions for service account that will call the support API
#organization viewer
gcloud organizations add-iam-policy-binding \
organizations/$1 \
--role roles/resourcemanager.organizationViewer \
--member serviceAccount:sa-support-api@${PROJECT_ID}.iam.gserviceaccount.com
#tech support editor
gcloud organizations add-iam-policy-binding \
organizations/$1 \
--role roles/cloudsupport.techSupportEditor \
--member serviceAccount:sa-support-api@${PROJECT_ID}.iam.gserviceaccount.com
#log writer permissions
gcloud projects add-iam-policy-binding ${PROJECT_ID} --member=serviceAccount:sa-support-api@${PROJECT_ID}.iam.gserviceaccount.com --role=roles/logging.logWriter
#resource folder viewer
gcloud organizations add-iam-policy-binding $1 --member=serviceAccount:sa-support-api@${PROJECT_ID}.iam.gserviceaccount.com --role=roles/resourcemanager.folderViewer
# Create a key for the Service Account for initiliazing the Cloud SDK 
gcloud iam service-accounts keys create --iam-account sa-support-api@${PROJECT_ID}.iam.gserviceaccount.com key.json

#create bucket, TicketResult.txt and upload it to the bucket
gsutil mb -p ${PROJECT_ID} -c NEARLINE -l US-EAST1 -b on "gs://${PROJECT_ID}-supportnotification/"
touch TicketResults.txt
echo -e "0\n0" > TicketResults.txt
gsutil cp TicketResults.txt "gs://${PROJECT_ID}-supportnotification/"
gcloud storage buckets add-iam-policy-binding  gs://${PROJECT_ID}-supportnotification --member=serviceAccount:sa-support-api@${PROJECT_ID}.iam.gserviceaccount.com --role=roles/storage.objectAdmin

#create new alert policy
gcloud alpha monitoring policies create --policy-from-file="logBasedAlerting.json"