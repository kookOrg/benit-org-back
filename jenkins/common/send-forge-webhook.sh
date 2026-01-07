#!/bin/bash

# ❗ set -e 제거 (우리가 직접 실패 판단)
# set -e

# 타임존 설정
TZ='Asia/Seoul'
export TZ

# 기본 정보
JOB_NAME="${JOB_NAME}"
BUILD_NUMBER="${BUILD_NUMBER}"
BRANCH="${GIT_BRANCH}"
JOB_URL="${BUILD_URL}"
LOG_URL="${BUILD_URL}consoleText"
COMMIT_HASH="${GIT_COMMIT}"

# 시작 시간
START_TIME=$(date '+%Y-%m-%d %H:%M:%S')

# 빌드 유저 정보
STARTED_BY="${BUILD_USER_ID:-"-"}"
STARTED_BY_EMAIL="${BUILD_USER_EMAIL:-"-"}"

# 트리거 타입 판단
if [ -n "$BUILD_USER_ID" ]; then
  TRIGGER_TYPE="수동"
elif [ -n "$CHANGE_ID" ]; then
  TRIGGER_TYPE="PR"
else
  TRIGGER_TYPE="스케줄"
fi

# -----------------------------
# 실제 빌드 수행
# -----------------------------
echo "[INFO] 실제 빌드 수행 시작"

# 예시 (이미 다른 Build Step에서 수행했다면 제거)
# mvn clean package
# BUILD_EXIT_CODE=$?

# 👉 프리스타일에서 이미 앞 단계에서 실패했다면
BUILD_EXIT_CODE=$?

# 결과 판단
if [ "$BUILD_EXIT_CODE" -eq 0 ]; then
  RESULT="SUCCESS"
else
  RESULT="FAILURE"
fi

# 로그 추출
BUILD_LOG=$(curl -u "${JENKINS_USER}:${JENKINS_API_TOKEN}" -s "${BUILD_URL}consoleText" \
  | tail -n 1000 | sed 's/"/\\"/g')

# -----------------------------
# Payload 전송
# -----------------------------
echo "[INFO] Webhook payload 전송"

END_TIME=$(date "+%Y-%m-%d %H:%M:%S")

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

echo "==== 보내는 JSON ===="
cat jenkins-payload.json

RESPONSE=$(curl -s -w "%{http_code}" -o /tmp/webhook_response.log -X POST \
  -H "Content-Type: application/json" \
  -H "x-webhook-secret: $WEBHOOK_SECRET" \
  --data-binary @jenkins-payload.json \
  "$WEBHOOK_URL")

echo "[INFO] Webhook 응답코드: $RESPONSE"
cat /tmp/webhook_response.log

# Jenkins 빌드 결과 반영
exit "$BUILD_EXIT_CODE"