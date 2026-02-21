pipeline {
    agent any

    environment {
        GOOGLE_APPLICATION_CREDENTIALS = credentials('gcp-service-account')
        GOOGLE_CLOUD_PROJECT = credentials('gcp-project-id')
        IMAGE_TAG = "1.0.${currentBuild.number}"
        GITHUB_TOKEN = credentials('github-token')
        SCANNER_HOME = tool 'sonar'
    }

    stages {
        stage('Clean Workspace') {
            steps {
                cleanWs()
            }
        }

        stage('Git Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/saahil-ops/testcicd.git'
            }
        }

        stage('Authenticate with Google Cloud') {
            steps {
                sh """
                    gcloud auth activate-service-account --key-file=${GOOGLE_APPLICATION_CREDENTIALS}
                    gcloud config set project ${GOOGLE_CLOUD_PROJECT}
                    gcloud auth configure-docker us-central1-docker.pkg.dev
                """
            }
        }

        stage('Scan Filesystem using Trivy') {
            steps {
                sh "trivy fs ."
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('sonar-server') {
                    sh """
                    $SCANNER_HOME/bin/sonar-scanner -Dsonar.projectName=app \
                    -Dsonar.projectKey=app
                    """
                }
            }
        }

        stage('Quality Gate') {
            steps {
                script {
                    waitForQualityGate abortPipeline: false, credentialsId: 'Sonar-token'
                }
            }
        }

        stage('Pull Docker Image') {
            steps {
                script {
                    sh 'cat $GOOGLE_APPLICATION_CREDENTIALS | docker login -u _json_key --password-stdin https://us-central1-docker.pkg.dev'
                    sh "docker pull nginx:latest"
                }
            }
        }

        stage('Tag & Push Docker Image to GCP Artifact Registry') {
            steps {
                script {
                    sh """
                    docker tag nginx:latest us-central1-docker.pkg.dev/${GOOGLE_CLOUD_PROJECT}/docker-repo/hello:${IMAGE_TAG}
                    docker push us-central1-docker.pkg.dev/${GOOGLE_CLOUD_PROJECT}/docker-repo/hello:${IMAGE_TAG}
                    docker tag nginx:latest us-central1-docker.pkg.dev/${GOOGLE_CLOUD_PROJECT}/docker-repo/hello:latest
                    docker push us-central1-docker.pkg.dev/${GOOGLE_CLOUD_PROJECT}/docker-repo/hello:latest
                    docker rmi nginx:latest || true
                    docker rmi us-central1-docker.pkg.dev/${GOOGLE_CLOUD_PROJECT}/docker-repo/hello:${IMAGE_TAG} || true
                    docker volume prune -f
                    """
                }
            }
        }

        stage('Scan Latest Docker Image using Trivy') {
            steps {
                sh "trivy image us-central1-docker.pkg.dev/${GOOGLE_CLOUD_PROJECT}/docker-repo/hello:${IMAGE_TAG}"
            }
        }

        stage('Clean Workspace for CD Repo') {
            steps {
                cleanWs()
            }
        }

        stage('Checkout K8s YAML Repo') {
            steps {
                git branch: 'main', credentialsId: 'github-token', url: 'https://github.com/saahil-ops/testcicd.git'
            }
        }

        stage('Update helm values.yaml with New Docker Image') {
            environment {
                GIT_REPO_NAME = "testcicd"
                GIT_USER_NAME = "saahil-ops"
            }
            steps {
                withCredentials([string(credentialsId: 'github-token', variable: 'GITHUB_TOKEN')]) {
                    sh """
                    set -e

                    git config user.email "saahiltanwar@example.com"
                    git config user.name "${GIT_USER_NAME}"

                    echo "=== BEFORE ==="
                    cat helm/values.yaml

                    grep "image:" helm/values.yaml || echo "Pattern not found. Proceeding with replacement."

                    sed -i "s|image: us-central1-docker.pkg.dev/.*/docker-repo/hello:.*|image: us-central1-docker.pkg.dev/${GOOGLE_CLOUD_PROJECT}/docker-repo/hello:${IMAGE_TAG}|" helm/values.yaml

                    echo "=== AFTER ==="
                    cat helm/values.yaml

                    if git diff --quiet; then
                        echo "No changes to commit. Skipping commit."
                    else
                        git add helm/values.yaml
                        git commit -m "Updated helm values.yaml to version ${IMAGE_TAG}"
                        git push https://${GITHUB_TOKEN}@github.com/${GIT_USER_NAME}/${GIT_REPO_NAME}.git HEAD:main
                    fi
                    """
                }
            }
        }

        stage('Updated Image tag for CD') {
            steps {
                echo 'Successfully updated Docker Image tag for Continuous Deployment'
            }
        }
    }
}
