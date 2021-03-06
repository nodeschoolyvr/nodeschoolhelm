pipeline {
  agent {
    docker {
      image 'quay.io/roboll/helmfile:v0.143.0'
      args '-u 0:0'
    }
  }

  options {
    buildDiscarder(logRotator(numToKeepStr: '10'))
    ansiColor('xterm')
    timeout(time: 60, unit: 'MINUTES')
    disableConcurrentBuilds(abortPrevious: true)
  }

  triggers {
    cron(env.BRANCH_NAME == 'master' ? 'H/30 * * * *' : '')
  }

  environment {
    USER="root" // fake to allow doctl to run
    DIGITALOCEAN_ACCESS_TOKEN = credentials('halkeye-digitalocean')
    PGP_PRIVATE_KEY = credentials('jenkins-gpg-secret')
    GPG_TRUST = credentials('jenkins-gpg-ownertrust')
    GPG_PASSPHRASE = credentials('jenkins-gpg-passphrase')
  }

  stages {
    stage('Prepare Environment'){
      steps {
        sh 'wget -O - https://github.com/digitalocean/doctl/releases/download/v1.70.0/doctl-1.70.0-linux-amd64.tar.gz | tar xvzf - -C /usr/bin'
        sh 'wget -O $(which sops) https://github.com/mozilla/sops/releases/download/v3.7.1/sops-v3.7.1.linux'
        sh 'apk add gnupg'
        sh 'doctl kubernetes cluster kubeconfig save 689501a5-76c6-4ce8-b5ed-2e4e9e67369a'
        sh 'kubectl cluster-info > /dev/null'
        sh '''
          cat "${PGP_PRIVATE_KEY}" | gpg --batch --import || true
          echo "${GPG_PASSPHRASE}" | gpg --batch --always-trust --yes --passphrase-fd 0 --pinentry-mode=loopback -s > /dev/null
        '''
      }
    }
    stage('Make sure cert-manager is installed'){
      when { branch 'main' }
      steps {
        sh 'kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.7.1/cert-manager.yaml'
        sh 'sops -d cert-manager-cluster-issuer-secrets.yml | kubectl apply -f -'
      }
    }
    stage('Helmfile Lint'){
      steps {
        sh 'helmfile lint'
      }
    }
    stage('Diff on Pull Request'){
      when { changeRequest() }
      steps {
        script {
          def diff = sh(
            script:'helmfile --no-color diff --suppress-secrets --skip-deps --context=2 --concurrency=8',
            returnStdout: true,
          ).trim()
          // Note the GitHub markdown formatting for the diff, to have syntax coloration
          publishChecks name: "helmfile-diff", title: "Helmfile Diff", text: '```diff\n' + diff + '\n```'
        }
      }
    }
    stage('Apply'){
      when { branch 'main' }
      steps {
        sh 'helmfile apply --suppress-secrets --concurrency=8'
      }
    }
  }
  post {
    unsuccessful {
      script {
        if (env.BRANCH_NAME == "main") {
          withCredentials([string(credentialsId: 'discord-webhook', variable: 'WEBHOOK_URL')]) {
            discordSend description: "Jenkins Pipeline Build", link: env.BUILD_URL, result: currentBuild.currentResult, title: env.JOB_NAME, webhookURL: env.WEBHOOK_URL
          }
        }
      }
    }
    fixed {
      script {
        if (env.BRANCH_NAME == "main") {
          withCredentials([string(credentialsId: 'discord-webhook', variable: 'WEBHOOK_URL')]) {
            discordSend description: "Jenkins Pipeline Build", link: env.BUILD_URL, result: currentBuild.currentResult, title: env.JOB_NAME, webhookURL: env.WEBHOOK_URL
          }
        }
      }
    }
  }
}


