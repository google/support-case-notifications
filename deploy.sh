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

#Replace the frequency or region with your preference
#The script will run by default every 10 minutes in us-central1
FREQUENCY='*/10 * * * *'
REGION='us-central1'

#Create a Cloud Run job with the image
gcloud beta run jobs create supportnotification --image gcr.io/${PROJECT_ID}/supportnotification --region ${REGION}

#Create Cloud Scheduler job with the service account that has cloud run invoker permissions. 
gcloud scheduler jobs create http supportnotification-scheduler-trigger \
  --location ${REGION} \
  --schedule ${FREQUENCY}\
  --uri "https://${REGION}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${PROJECT_ID}/jobs/supportnotification:run" \
  --http-method POST \
  --oauth-service-account-email sa-support-notif-scheduler@${PROJECT_ID}.iam.gserviceaccount.com

