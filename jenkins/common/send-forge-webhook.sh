#!/bin/bash

TZ='Asia/Seoul'
export TZ

JOB_NAME="${JOB_NAME}"
BUILD_NUMBER="${BUILD_NUMBER}"
BRANCH="${GIT_BRANCH}"
JOB_URL="${BUILD_URL}"
LOG_URL="${BUILD_URL}consoleText"
COMMIT_HASH="${GIT_COMMIT}"

#RESULT="${BUILD_RESULT:-UNKNOWN}"

START_TIME=$(date '+%Y-%m-%d %H:%M:%S')

STARTED_BY="${BUILD_USER_ID:-"-"}"
STARTED_BY_EMAIL="${BUILD_USER_EMAIL:-"-"}"

if [ -n "$BUILD_USER_ID" ]; then
  TRIGGER_TYPE="수동"
elif [ -n "$CHANGE_ID" ]; then
  TRIGGER_TYPE="PR"
else
  TRIGGER_TYPE="스케줄"
fi

BUILD_LOG=$(curl -u "${JENKINS_USER}:${JENKINS_API_TOKEN}" -s \
  "${BUILD_URL}consoleText" | tail -n 1000 | sed 's/"/\\"/g')

END_TIME=$(date '+%Y-%m-%d %H:%M:%S')

cat > jenkins-payload.json <<EOF
{
  "jobName": "$JOB_NAME",
  "buildNumber": $BUILD_NUMBER,
  "result": "$RESULT",
  "branch": "$BRANCH",
  "commitHash": "$COMMIT_HASH",
  "startedBy": "$STARTED_BY",
  "startedByEmail": "$STARTED_BY_EMAIL",
  "startTime": "$START_TIME",
  "endTime": "$END_TIME",
  "triggerType": "$TRIGGER_TYPE",
  "buildLog": "$BUILD_LOG",
  "jobUrl": "$JOB_URL",
  "logUrl": "$LOG_URL",
  "projectKey": "$PROJECT_KEY",
  "issueType": "$ISSUE_TYPE"
}
EOF

echo "BUILD_RESULT: ${BUILD_RESULT}"

curl -s -X POST \
  -H "Content-Type: application/json" \
  -H "x-webhook-secret: $WEBHOOK_SECRET" \
  --data-binary @jenkins-payload.json \
  "$WEBHOOK_URL"
