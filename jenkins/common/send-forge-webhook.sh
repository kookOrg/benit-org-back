#!/bin/bash

TZ='Asia/Seoul'
export TZ

# 기본 정보
JOB_NAME="${JOB_NAME}"
BUILD_NUMBER="${BUILD_NUMBER}"
CO_NUMBER="${BRANCH_NAME}"
JOB_URL="${BUILD_URL}"
LOG_URL="${BUILD_URL}consoleText"
COMMIT_HASH="${GIT_COMMIT}"

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
BUILD_LOG=$(curl -u "${JENKINS_USER}:${JENKINS_API_TOKEN}" -s "${BUILD_URL}consoleText" | tail -n 1000 | sed 's/"/\\"/g' | base64 -w 0)

# 빌드 결과
BUILD_JSON=$(curl -s -u "${JENKINS_USER}:${JENKINS_API_TOKEN}" "${BUILD_URL}api/json")
RESULT=$(echo "$BUILD_JSON" | sed -n 's/.*"result":"\([^"]*\)".*/\1/p')
[ -z "$RESULT" ] && RESULT="FAILURE"

# 빌드 시작 / 종료 시간
START_TIMESTAMP=$(echo "$BUILD_JSON" | sed -n 's/.*"timestamp":\([0-9]*\).*/\1/p')
DURATION=$(echo "$BUILD_JSON" | sed -n 's/.*"duration":\([0-9]*\).*/\1/p')
BUILDING=$(echo "$BUILD_JSON" | sed -n 's/.*"building":\([^,}]*\).*/\1/p')

#START_TIME=$(date -d "@$((START_TIMESTAMP/1000))" '+%Y-%m-%d %H:%M:%S')
START_TIME=$(date '+%Y-%m-%d %H:%M:%S')

if [ "$BUILDING" = "true" ] || [ -z "$DURATION" ] || [ "$DURATION" = "0" ]; then
  # 빌드 진행 중이면 종료시간은 '현재'
  END_TIME=$(date '+%Y-%m-%d %H:%M:%S')
else
  # 빌드 완료 후면 timestamp + duration
  END_TIME=$(date -d "@$(( (START_TIMESTAMP + DURATION) / 1000 ))" '+%Y-%m-%d %H:%M:%S')
fi

LOG_TIME=$(date '+%Y-%m-%d %H:%M:%S.%3N')

echo "====  ===="
echo "==== START_TIME: $START_TIME ($LOG_TIME) ===="
sleep 0.1
LOG_TIME2=$(date '+%Y-%m-%d %H:%M:%S.%3N')
echo "==== END_TIME  : $END_TIME ($LOG_TIME2) ===="
echo "====  ===="

cat > jenkins-payload.json <<EOF
{
  "jobName": "$JOB_NAME",
  "buildNumber": $BUILD_NUMBER,
  "result": "$RESULT",
  "coNumber": "$CO_NUMBER",
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
echo "==== jenkins-payload ===="

curl -s -X POST \
  -H "Content-Type: application/json" \
  -H "x-webhook-secret: $WEBHOOK_SECRET" \
  --data-binary @jenkins-payload.json \
  "$WEBHOOK_URL"
