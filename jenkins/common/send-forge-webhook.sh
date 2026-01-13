#!/bin/bash

TZ='Asia/Seoul'
export TZ

# 기본 정보
JOB_NAME="${JOB_NAME}"
BUILD_NUMBER="${BUILD_NUMBER}"
BRANCH="${GIT_BRANCH}"
JOB_URL="${BUILD_URL}"
LOG_URL="${BUILD_URL}consoleText"
COMMIT_HASH="${GIT_COMMIT}"

# 시작/종료 시간
START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
END_TIME=$(date '+%Y-%m-%d %H:%M:%S')

# 빌드 유저
STARTED_BY="${BUILD_USER_ID:-"-"}"
STARTED_BY_EMAIL="${BUILD_USER_EMAIL:-"-"}"

# 트리거 타입
if [ -n "$BUILD_USER_ID" ]; then
  TRIGGER_TYPE="수동"
elif [ -n "$CHANGE_ID" ]; then
  TRIGGER_TYPE="PR"
else
  TRIGGER_TYPE="스케줄"
fi

# 상세 로그
BUILD_LOG=$(curl -u "${JENKINS_USER}:${JENKINS_API_TOKEN}" -s "${BUILD_URL}consoleText" | tail -n 1000 | sed 's/"/\\"/g')
#BUILD_LOG=$(curl -s -u "${JENKINS_USER}:${JENKINS_API_TOKEN}" "${BUILD_URL}consoleText" | sed '/jenkins\/common\/send-forge-webhook.sh/,$d' | tail -n 1000)
#SAFE_BUILD_LOG=$(jq -Rs . <<< "$BUILD_LOG")

echo "BUILD_LOG length: ${#BUILD_LOG}"
echo "SAFE_BUILD_LOG=[$SAFE_BUILD_LOG]"

# 빌드 결과
BUILD_JSON=$(curl -s -u "${JENKINS_USER}:${JENKINS_API_TOKEN}" "${BUILD_URL}api/json")
RESULT=$(echo "$BUILD_JSON" | sed -n 's/.*"result":"\([^"]*\)".*/\1/p')
[ -z "$RESULT" ] && RESULT="FAILURE"

jq -n \
  --arg jobName "$JOB_NAME" \
  --argjson buildNumber "$BUILD_NUMBER" \
  --arg result "$RESULT" \
  --arg branch "$BRANCH" \
  --arg commitHash "$COMMIT_HASH" \
  --arg startedBy "$STARTED_BY" \
  --arg startedByEmail "$STARTED_BY_EMAIL" \
  --arg startTime "$START_TIME" \
  --arg endTime "$END_TIME" \
  --arg triggerType "$TRIGGER_TYPE" \
  --arg buildLog "$BUILD_LOG" \
  --arg jobUrl "$JOB_URL" \
  --arg logUrl "$LOG_URL" \
  --arg projectKey "$PROJECT_KEY" \
  --arg issueType "$ISSUE_TYPE" \
'{
  jobName: $jobName,
  buildNumber: $buildNumber,
  result: $result,
  branch: $branch,
  commitHash: $commitHash,
  startedBy: $startedBy,
  startedByEmail: $startedByEmail,
  startTime: $startTime,
  endTime: $endTime,
  triggerType: $triggerType,
  buildLog: $buildLog,
  jobUrl: $jobUrl,
  logUrl: $logUrl,
  projectKey: $projectKey,
  issueType: $issueType
}' > jenkins-payload.json

echo "==== jenkins-payload ===="
cat jenkins-payload.json
echo "==== jenkins-payload ===="

curl -s -X POST \
  -H "Content-Type: application/json" \
  -H "x-webhook-secret: $WEBHOOK_SECRET" \
  --data-binary @jenkins-payload.json \
  "$WEBHOOK_URL"
