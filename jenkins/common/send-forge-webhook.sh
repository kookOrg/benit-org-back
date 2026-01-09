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

# 빌드 결과
BUILD_JSON=$(curl -s -u "${JENKINS_USER}:${JENKINS_API_TOKEN}" "${BUILD_URL}api/json")
RESULT=$(echo "$BUILD_JSON" | sed -n 's/.*"result":"\([^"]*\)".*/\1/p')
[ -z "$RESULT" ] && RESULT="UNKNOWN"

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

echo "==== jenkins-payload ===="
cat jenkins-payload.json

curl -s -X POST \
  -H "Content-Type: application/json" \
  -H "x-webhook-secret: $WEBHOOK_SECRET" \
  --data-binary @jenkins-payload.json \
  "$WEBHOOK_URL"
