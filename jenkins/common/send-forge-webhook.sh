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
if [ "$BUILD_USER_ID" = "timer" ]; then
  TRIGGER_TYPE="스케줄"
elif [ -n "$BUILD_USER_ID" ]; then
  TRIGGER_TYPE="수동"
else
  TRIGGER_TYPE="기타"
fi

# 상세 로그
#MAX_LOG_BYTES=500
#BUILD_LOG=$(curl -u "${JENKINS_USER}:${JENKINS_API_TOKEN}" -s "${BUILD_URL}consoleText" | tail -c "$MAX_LOG_BYTES" | base64 -w 0)

# 상세 로그 (앞 20% + 뒤 80%, base64 인코딩)
HEAD_BYTES=200
TAIL_BYTES=800
FULL_LOG=$(curl -u "${JENKINS_USER}:${JENKINS_API_TOKEN}" -s "${BUILD_URL}consoleText")
FULL_LOG_SIZE=$(echo "$FULL_LOG" | wc -c | tr -d ' ')
if [ "$FULL_LOG_SIZE" -le $((HEAD_BYTES + TAIL_BYTES)) ]; then
  BUILD_LOG=$(echo "$FULL_LOG" | base64 -w 0)
else
  LOG_HEAD=$(echo "$FULL_LOG" | head -c "$HEAD_BYTES")
  LOG_TAIL=$(echo "$FULL_LOG" | tail -c "$TAIL_BYTES")
  BUILD_LOG=$(printf '%s\n\n... (중략) ...\n\n%s' "$LOG_HEAD" "$LOG_TAIL" | base64 -w 0)
fi

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
