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

import googleapiclient.discovery
import yaml
from numpy import loadtxt
import subprocess
from google.cloud import storage
import google.cloud.logging
import os

#log event
def logEvent():
    logging_client = google.cloud.logging.Client()
    log_name = "supportLog"
    logger = logging_client.logger(log_name)
    text = "A new support case has been created."
    logger.log_text(text, severity="WARNING")

#read and parse configuration file
def readConfigFile(IDs): 
    with open('Configuration.yaml') as file:
        try:
            databaseConfig = yaml.safe_load(file)   
            IDs["project"] = databaseConfig["project"]
            IDs["organization"] = databaseConfig["organization"]
            IDs["onlyProject"] = databaseConfig["onlyProject"]
        except yaml.YAMLError as exc:
            print(exc)

def generateProjectIDs(organizationID):
    subprocess.check_call(["./ListProjects.sh " + organizationID],shell=True)

#Checks if the current number of tickets match the old results. Returns True if should send email, False otherwise
def sendEmail(closed, openNum, fileName, bucketName):
    storage_client = storage.Client()
    bucket = storage_client.bucket(bucketName)
    blob = bucket.blob(fileName)
    with blob.open("r") as f:
        results = f.readlines()
    if (int(results[0][0]) < openNum):
        # a new support ticket created
        return True
    elif (int(results[0]) == openNum and int(results[1]) < closed):
        #edge case where new ticket created and old ticket closed
        return True
    return False

#Updates the results values in the yaml file that is passed in
def updateValues(closed, openNum, fileName, bucketName):
    storage_client = storage.Client()
    bucket = storage_client.bucket(bucketName)
    blob = bucket.blob(fileName)
    with blob.open("w") as f:
        f.write(str(openNum) + "\n")
        f.write(str(closed) + "\n")

#Returns the number of tickets given the project, state, and isOrganization
def getNumTicket(project, state, isOrg):
    SERVICE_NAME = "Support API"
    API_VERSION = "v2beta"
    API_DEFINITION_URL = "https://cloudsupport.googleapis.com/$discovery/rest?version=" + API_VERSION

    supportApiService = googleapiclient.discovery.build(
        serviceName=SERVICE_NAME,
        version=API_VERSION,
        discoveryServiceUrl=API_DEFINITION_URL)

    if (isOrg):
        case_list = supportApiService.cases().list(parent="organizations/" + project, filter="state=" + state, pageSize=100).execute()
    else:
        case_list = supportApiService.cases().list(parent="projects/" + project, filter="state=" + state, pageSize=100).execute()
    if (len(case_list) > 0):
        #check if the values changed, and update the new values
        return len(case_list["cases"])
    else:
        return 0
    return case_list 

#Returns list of projects under an organization
def getProjectsList():
    #get list of support tickets
    with open('organizationsList.txt') as f:
        projectsList = [line for line in f]
    with open('organizationsList.txt') as f:
        projectsList= [line.rstrip() for line in f]
    return projectsList

#gets number of open and closed cases and stores it in TicketResults.txt
def countForAllStates(project, organization, storageBucket, onlyProject):
    if (onlyProject == "False"):
        #notifications on for all projects
        numOpenTickets = 0
        numClosedTickets = 0
        projectsList = getProjectsList()
        #get the organization support tickets first
        numOpenTickets += getNumTicket(organization, "OPEN", True)
        numClosedTickets += getNumTicket(organization, "CLOSED", True)
        #get all the projects' support tickets
        for projectID in projectsList:
            numOpenTickets += getNumTicket(projectID, "OPEN", False)
            numClosedTickets += getNumTicket(projectID, "CLOSED", False)
        #check if the results are different from before
        shouldSendEmail = sendEmail(numClosedTickets, numOpenTickets, "TicketResults.txt", storageBucket)
        #update the ticket result values with the new values
        updateValues(numClosedTickets, numOpenTickets, "TicketResults.txt", storageBucket)
        return shouldSendEmail
    else:
        numOpenTickets = getNumTicket(project,"OPEN", False)
        numClosedTickets = getNumTicket(project, "CLOSED", False)
        shouldSendEmail = sendEmail(numClosedTickets, numOpenTickets, "TicketResults.txt", storageBucket)
        updateValues(numClosedTickets, numOpenTickets, "TicketResults.txt", storageBucket)
        return shouldSendEmail

def main():
    os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "key.json"
    IDs = {'project': "", 'organization': "", 'onlyProject': ""}
    readConfigFile(IDs)
    if (IDs["onlyProject"] == "False"):
        #need to generate list of organizations
        open('organizationsList.txt', 'w').close()
        generateProjectIDs(IDs["organization"])
    newTicketOpened = countForAllStates(IDs["project"], IDs["organization"], IDs["project"] + "-supportnotification", IDs["onlyProject"])
    if (newTicketOpened):
        logEvent()
main()
