#!/bin/bash
set -e

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

# 기본 상태는 SUCCESS
RESULT="SUCCESS"

# 시작 시간
START_TIME=$(date '+%Y-%m-%d %H:%M:%S')

# 빌드 유저 정보
STARTED_BY="${BUILD_USER_ID:-"-"}"
STARTED_BY_EMAIL="${BUILD_USER_EMAIL:-"-"}"

# 프로젝트/이슈 생성 정보
#PROJECT_KEY="JEN"
#ISSUE_TYPE="Task"

# 트리거 타입 판단
if [ -n "$BUILD_USER_ID" ]; then
  TRIGGER_TYPE="MANUAL"
elif [ -n "$CHANGE_ID" ]; then
  TRIGGER_TYPE="PR"
else
  TRIGGER_TYPE="SCHEDULE"
fi

echo "JENKINS_USER: $JENKINS_USER"
echo "JENKINS_API_TOKEN: $JENKINS_API_TOKEN"
echo "WEBHOOK_SECRET: $WEBHOOK_SECRET"
echo "PROJECT_KEY: $PROJECT_KEY"
echo "ISSUE_TYPE: $ISSUE_TYPE"

# 로그 추출
BUILD_LOG=$(curl -u "${JENKINS_USER}:${JENKINS_API_TOKEN}" -s "${BUILD_URL}consoleText" | tail -n 1000 | sed 's/"/\\"/g')

# Webhook URL
WEBHOOK_URL="https://9b0901cb-05cd-4272-84b3-8b47898c1ace.hello.atlassian-dev.net/x1/l68YiQz6kbyGJkCnm-xs1sA_5QY"

# Payload 생성 및 전송 함수
send_payload() {
  echo "[INFO] Webhook payload 전송"

  # 종료 시간
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
  echo "========================================="
  cat /tmp/webhook_response.log

  if [ "$RESPONSE" -ne 200 ]; then
    echo "[ERROR] Webhook 호출 실패 (HTTP $RESPONSE)"
    exit 1
  fi
}

# 종료 시점에 실패 여부 판단 후 payload 보내기
trap '
  EXIT_CODE=$?

  if [ "$EXIT_CODE" -ne 0 ]; then
    RESULT="FAILURE"
  fi

  send_payload
' EXIT

# 실패 테스트
#echo "[TEST] 강제로 빌드를 실패"
#exit 1