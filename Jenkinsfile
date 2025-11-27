// Jenkinsfile
import groovy.json.JsonOutput

pipeline {
  agent any

  environment {
    WEBHOOK_URL = 'https://9b0901cb-05cd-4272-84b3-8b47898c1ace.hello.atlassian-dev.net/x1/l68YiQz6kbyGJkCnm-xs1sA_5QY'
    TZ          = 'Asia/Seoul'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Build') {
      steps {
        sh './mvnw clean package'
      }
    }
  }

  post {
    // 성공/실패 모두 Jira 전송
    always {
      // 👉 실행자 정보(BUILD_USER_*)를 쓰려면 무조건 wrap 안에서
      wrap([$class: 'BuildUser']) {
        script {
          // 기본 빌드 정보
          def result      = currentBuild.currentResult      // SUCCESS / FAILURE
          def jobName     = env.JOB_NAME
          def buildNumber = env.BUILD_NUMBER as int
          def branch      = env.GIT_BRANCH ?: 'main'
          def jobUrl      = env.BUILD_URL
          def logUrl      = "${env.BUILD_URL}consoleText"

          // 시작/종료 시간
          def startTime = new Date(currentBuild.startTimeInMillis).format("yyyy-MM-dd HH:mm:ss", TimeZone.getTimeZone(env.TZ))
          def endTime   = new Date().format("yyyy-MM-dd HH:mm:ss", TimeZone.getTimeZone(env.TZ))

          // 실행자 (플러그인에서 주입)
          def startedBy = env.BUILD_USER_ID ?: env.BUILD_USER ?: "-"

          // 🔥 트리거 타입 판별 (수동 / PR / 스케줄/SCM)
          def triggerType = detectTriggerType()

          //def logLines = currentBuild.rawBuild.getLog(100)
          //def buildLog = logLines.join("\n")

          def fullLog = currentBuild.rawBuild.getLog()
          def last100 = fullLog.takeRight(100)
          def buildLog = last100.join("\n")

          def payload = [
            jobName     : jobName,
            buildNumber : buildNumber,
            result      : result,
            branch      : branch,
            startedBy   : startedBy,
            jobUrl      : jobUrl,
            logUrl      : logUrl,
            startTime   : startTime,
            endTime     : endTime,
            triggerType : triggerType,
            buildLog    : buildLog
          ]

          def jsonText = JsonOutput.prettyPrint(JsonOutput.toJson(payload))
          writeFile file: 'jenkins-payload.json', text: jsonText
          echo "==== 보내는 JSON ===="
          echo jsonText

          sh """
            curl -X POST \\
              -H "Content-Type: application/json" \\
              --data-binary @jenkins-payload.json \\
              "$WEBHOOK_URL"
          """
        }
      }
    }
  }
}

/**
 * 빌드 Cause 보고 트리거 타입을 사람이 보기 좋게 변환
 *  - MANUAL  : 사용자가 UI에서 직접 실행
 *  - SCHEDULE: cron, Timer, SCM 변경 등
 *  - PR      : Pull Request 기반 빌드 (GitHub/GitLab 플러그인 등)
 */
@NonCPS
String detectTriggerType() {
  def causes = currentBuild.rawBuild.getCauses()

  // 기본값
  String type = "UNKNOWN"

  for (c in causes) {
    def desc = c?.shortDescription?.toLowerCase() ?: ""

    if (desc.contains("started by user")) {
      type = "MANUAL"
    } else if (desc.contains("timer") || desc.contains("cron")) {
      type = "SCHEDULE"
    } else if (desc.contains("scm change")) {
      type = "SCHEDULE"   // 필요하면 "SCM" 으로 따로 분리해도 됨
    } else if (desc.contains("pull request") || desc.contains("pr")) {
      type = "PR"
    }
  }

  return type
}