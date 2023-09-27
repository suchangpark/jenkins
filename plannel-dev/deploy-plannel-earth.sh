#!/bin/bash

WORKING_DIR=$(pwd)
MVN_VERSION="3.8.5"
TARGET_SERVER="10.0.0.17" # earth.plannel.ai
DEPLOY_PATH=/opt/zionex/saas-plannel
LINK_FILE=/opt/zionex/saas-plannel/saas-plannel.jar
REPO_URL="https://github.com/zionex/saas-plannel.git"
CLONE_DIR="saas-plannel"

# Java 버전 확인
JAVA_VERSION=$(java -version 2>&1 | grep -i version | awk -F '"' '/version/ {print $2}' | awk -F. '{print $1}')

# Java 버전이 17인지 확인
if [ "$JAVA_VERSION" -eq 17 ]; then
    echo "Java 17 already installed."
else
	sudo yum install java-17-amazon-corretto -y
fi

# Required packages
required_packages=("wget" "unzip" "zip")
missing_packages=()

# required_packages가 설치되어 있는지 확인
for package in "${required_packages[@]}"; do
    if ! command -v "$package" &> /dev/null; then
        missing_packages+=("$package")
    fi
done

# 설치되지 않은 package 설치
if [ ${#missing_packages[@]} -eq 0 ]; then
    echo "All required packages are already installed."
else
    echo "install ${missing_packages[*]}"
    sudo yum install ${missing_packages[*]} -y
fi

# Maven이 설치되어 있는지 확인
export PATH=$PATH:/opt/apache-maven-$MVN_VERSION/bin
if command -v mvn &> /dev/null; then
    current_maven_version=$(mvn -v | grep "Apache Maven" | awk '{print $3}')
    if [ "$current_maven_version" == "$MVN_VERSION" ]; then
    echo "Maven version : $MVN_VERSION."
	else
    	echo "echo "Maven version mismatch. install maven-$MVN_VERSION""
        # mavne 3.8.5 설치
        cd /opt
        sudo wget https://mirrors.estointernet.in/apache/maven/maven-3/$MVN_VERSION/binaries/apache-maven-$MVN_VERSION-bin.zip
        sudo unzip apache-maven-$MVN_VERSION-bin.zip
        #export PATH=$PATH:/opt/apache-maven-$MVN_VERSION/bin
	fi
else
    echo "Maven not Found. install maven-$MVN_VERSION"
    # mavne 3.8.5 설치
    cd /opt
    sudo wget https://mirrors.estointernet.in/apache/maven/maven-3/$MVN_VERSION/binaries/apache-maven-$MVN_VERSION-bin.zip
    sudo unzip apache-maven-$MVN_VERSION-bin.zip
    #export PATH=$PATH:/opt/apache-maven-$MVN_VERSION/bin
fi

mvn --version
java --version

cd $WORKING_DIR
EXISTS_TAGS=$(git ls-remote --tags --refs $REPO_URL | awk '{print $2}' | cut -d/ -f3)

if [[ -n $TAG && $EXISTS_TAGS == *$TAG* ]]; then
  #echo "tag $TAG exists in saas-plannel repository"
  git clone --branch $TAG --depth 1 $REPO_URL $CLONE_DIR
else
  #echo "Tag $TAG does not exist in saas-plannel repository."
  git clone $REPO_URL $CLONE_DIR
fi

cd $CLONE_DIR/saas-application
mvn clean install
ls -al target/*.jar

ssh-add -l

ssh -o StrictHostKeyChecking=no ec2-user@$TARGET_SERVER "mkdir -p /tmp/deploy/ && rm -rf /tmp/deploy/*" &&
    scp -o StrictHostKeyChecking=no target/*.jar ec2-user@$TARGET_SERVER:/tmp/deploy/

#ssh -o StrictHostKeyChecking=no ec2-user@$TARGET_SERVER '
#    DEPLOY_PATH=/opt/zionex/saas-plannel
#    LINK_FILE=/opt/zionex/saas-plannel/saas-plannel.jar
#    cd $DEPLOY_PATH
#    rm -f /opt/zionex/saas-plannel/saas-plannel.jar
#    mv -f `ls . | grep .jar | grep -v saas-plannel.jar` ./backup/
#    find $DEPLOY_PATH/backup -mtime +7 -name '*.jar' -exec rm {} \;
#    cp /tmp/deploy/*.jar $DEPLOY_PATH/
#    find -maxdepth 1 -name '*.jar' ! -name 'saas-plannel.jar' -exec ln -sf {} $LINK_FILE \;
#    sudo systemctl restart saas-plannel.service
#'
