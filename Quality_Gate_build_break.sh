#!/bin/bash
#1) Call the /api/ce/task?id=${ceTaskId} web service to retrieve analysisId. You can get the ceTaskId from /report-task.txt under your working directory.
#2) If the CE Task Status is PENDING or IN_PROGRESS, the script should wait, and repeat step 1
#3) If the CE Task Status is SUCCESS, we save the analysisId and proceed to step 5
#4) If the CE Task Status is FAILED or CANCELED, we break the build
#5) Call the /api/qualitygates/project_status?analysisId=${analysisId} web service to check the status of the quality gate
#6) If the quality gate status is OK or WARN, allow the build to pass. If the quality gate status is ERROR, we break the build.

set -o errexit
set -o pipefail
set -o nounset

sleep 5

source ./.scannerwork/report-task.txt

echo "Quality_Gate -> Sonar Project URL: $dashboardUrl"
echo "Quality_Gate -> Project Key: $projectKey"

if [ -z ${ceTaskId} ]
then
	echo "Quality_Gate -> No Task Id found"
fi

wait_for_success=true
count=0
max=10
while [[ "${wait_for_success}" = "true" && ${count} -lt ${max} ]]
do
	ceTaskStatus=$(curl -s ${ceTaskUrl} |  /home/rohit.kumar/jq/jq -r .task.status)
    echo ${ceTaskUrl}
    if [ "${ceTaskStatus}" = "PENDING" ] || [ "${ceTaskStatus}" = "IN_PROGRESS" ] ; then
    	echo "Quality_Gate -> Task Id ${ceTaskId} status is : ${ceTaskStatus} -- waiting 60 Sec before Next Check"
        sleep 60
        count=$((count + 1))
    fi
    if [ "${ceTaskStatus}" = "SUCCESS" ]; then
    	echo "Quality_Gate -> Task Id ${ceTaskId} status is : ${ceTaskStatus}"
        wait_for_success=false
    fi
    
done
if [[ "$count" -eq ${max} ]];then
	exit 1
    echo "sonar is taking more time please increase the waiting time"
fi
analysisId=$(curl -s ${ceTaskUrl} |  /home/rohit.kumar/jq/jq -r .task.analysisId)
echo "Quality_Gate -> Analysis ID is: $analysisId"
echo ${serverUrl}/api/qualitygates/project_status?analysisId="${analysisId}"
QG_Status=$(curl -s ${serverUrl}/api/qualitygates/project_status?analysisId="${analysisId}" |  /home/pawan.kumar/jq/jq -r .projectStatus.status)
if [ "${QG_Status}" != "OK" ]; then
	echo "Quality_Gate -> Quality Gate is Not OK. Breaking the build"
    exit 1
fi
