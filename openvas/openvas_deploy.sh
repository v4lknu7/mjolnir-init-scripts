#!/bin/bash

PIP_HOME="$HOME/.local/bin"
SHELL_FILE="$HOME/.bashrc"

OPENVAS_HOME="$HOME/openvas"
OPENVAS_SCRIPTS_FOLDER="$OPENVAS_HOME/scripts"
OPENVAS_CRON_UPDATE_SCRIPT="$OPENVAS_HOME/cron/update_feeds.sh"
OPENVAS_DOCKER_COMPOSE_FILE="$OPENVAS_HOME/docker/docker-compose.yml"
OPENVAS_DOCKER_PROJECT_NAME="greenbone-community-edition"
OPENVAS_DOCKER_SOCK="/tmp/gvm/gvmd/gvmd.sock"
OPENVAS_API_CONFIGFILE="$OPENVAS_SCRIPTS_FOLDER/.pythongvm"

SLEEPTIME=3
EXTENDED_SLEEPTIME=120

GREEN='\033[0;32m'
NC='\033[0m'

printf "\n"
echo "ODg4YiAgICAgZDg4OCAgZDhiICAgICAgICAgIDg4OCAgICAgICAgICBkOGIKODg4OGIgICBkODg4OCAgWThQICAgICAgICAgIDg4OCAgICAgICAgICBZOFAKODg4ODhiLmQ4ODg4OCAgICAgICAgICAgICAgIDg4OAo4ODhZODg4ODhQODg4IDg4ODggIC5kODhiLiAgODg4IDg4ODg4Yi4gIDg4OCA4ODhkODg4Cjg4OCBZODg4UCA4ODggIjg4OCBkODgiIjg4YiA4ODggODg4ICI4OGIgODg4IDg4OFAiCjg4OCAgWThQICA4ODggIDg4OCA4ODggIDg4OCA4ODggODg4ICA4ODggODg4IDg4OAo4ODggICAiICAgODg4ICA4ODggWTg4Li44OFAgODg4IDg4OCAgODg4IDg4OCA4ODgKODg4ICAgICAgIDg4OCAgODg4ICAiWTg4UCIgIDg4OCA4ODggIDg4OCA4ODggODg4CiAgICAgICAgICAgICAgIDg4OAogICAgICAgICAgICAgIGQ4OFAKICAgICAgICAgICAgODg4UCIKCigiQnV0IGZpbmVzdCBvZiB0aGVtIGFsbCwgJ1RoZSBDcnVzaGVyJyBpdCBpcyBjYWxsZWQ6IE1qw7ZsbmlyISBIYW1tZXIgb2YgVGhvciEiKQ==" | base64 -d
printf "\n\n"
printf "${GREEN}initiating...\n${NC}"
sleep $SLEEPTIME

printf "${GREEN}\n\n\n*****************************\n"
printf "installing dependencies\n"
printf "*****************************\n\n${NC}"
sudo apt -y update
sudo apt -y install python3
#installing Docker using the instructions on https://docs.docker.com/engine/install/debian/
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
  sudo apt -y remove $pkg;
done
sudo apt -y install ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo $VERSION_CODENAME) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt -y update
sudo apt -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo apt -y install python3-pip
export PATH="$PATH:${PIP_HOME}"
if grep "PATH.*${PIP_HOME}" "${SHELL_FILE}"; then
  printf "${GREEN}PIP_HOME already set${NC}\n"
else
  echo "export PATH=\"\$PATH:${PIP_HOME}\"" >> "${SHELL_FILE}"
  printf "${GREEN}PIP_HOME was set${NC}\n"
fi
pip3 install python-gvm gvm-tools fake-useragent
printf "${GREEN}\nDone. Dependencies installed.\n${NC}"
sleep $SLEEPTIME

printf "${GREEN}\n\n\n*****************************\n"
printf "cloning mjolnir-openvas\n"
printf "*****************************\n\n${NC}"
dopp_git_secret=$(doppler secrets get DOPPSECRET_GITHUB_CREDENTIALS --plain)
git_user=$(echo ${dopp_git_secret} | jq -r ".user")
git_pat=$(echo ${dopp_git_secret} | jq -r ".token")
rm -rf ${OPENVAS_HOME}
printf "${GREEN}\n\nCloning repo...${NC}\n"
git clone https://${git_pat}@github.com/${git_user}/mjolnir-openvas.git ${OPENVAS_HOME}
printf "${GREEN}\n\n\nDone. repo cloned.\n${NC}"
sleep $SLEEPTIME

printf "${GREEN}\n\n\n*****************************\n"
printf "deploying openvas docker image\n"
printf "*****************************\n\n${NC}"
sudo usermod -aG docker $USER
mkdir -p /tmp/gvm/gvmd
chmod -R 777 /tmp/gvm
openvas_admin_pass=$(doppler secrets get DOPPSECRET_OPENVAS_ADMIN_CREDENTIALS --plain | jq -r ".password")
dopp_openvas_apiuser_secret=$(doppler secrets get DOPPSECRET_OPENVAS_APIUSER_CREDENTIALS --plain)
openvas_apiuser_name=$(echo ${dopp_openvas_apiuser_secret} | jq -r ".user")
openvas_apiuser_pass=$(echo ${dopp_openvas_apiuser_secret} | jq -r ".password")

#usermod command above placed $USER in the docker group but the change is not effective until a logout/login
#we don't want to logout/login during a script execution, so we're using sudo -u trick to run the docker commands
#in a new shell where the user is already on the new group
sudo -u $USER docker compose -f ${OPENVAS_DOCKER_COMPOSE_FILE} -p ${OPENVAS_DOCKER_PROJECT_NAME} pull
sudo -u $USER docker compose -f ${OPENVAS_DOCKER_COMPOSE_FILE} -p ${OPENVAS_DOCKER_PROJECT_NAME} up -d
printf "${GREEN}\nDocker containers are finishing their initialization. Waiting ${EXTENDED_SLEEPTIME} seconds to complete.\n${NC}"
sleep $EXTENDED_SLEEPTIME
printf "${GREEN}\nChanging admin default password.\n${NC}"
sudo -u $USER docker compose -f ${OPENVAS_DOCKER_COMPOSE_FILE} -p ${OPENVAS_DOCKER_PROJECT_NAME} exec -T -u gvmd gvmd gvmd --user=admin --new-password=${openvas_admin_pass} -v
printf "${GREEN}\nUpdating API config file at ${OPENVAS_API_CONFIGFILE}.\n${NC}"
cat <<EOF > ${OPENVAS_API_CONFIGFILE}
[scannerprefs]
openvasdefaultscanconfigname=Full and fast
openvasdefaultscannername=OpenVAS Default
openvascvescannername=CVE

[apisocket]
openvassocket=${OPENVAS_DOCKER_SOCK}
EOF
printf "${GREEN}\nCreating non admin API user.\n${NC}"
python3 ${OPENVAS_SCRIPTS_FOLDER}/create_user.py -c ${OPENVAS_API_CONFIGFILE} -U admin -P ${openvas_admin_pass} -u ${openvas_apiuser_name} -p ${openvas_apiuser_pass} -r User
printf "${GREEN}\nDone. OpenVAS deployed and should be running.\n${NC}"
sleep $SLEEPTIME

printf "${GREEN}\n\n\n*****************************\n"
printf "adding cron task for daily openvas vulnerability feed updates\n"
printf "*****************************\n\n${NC}"
chmod +x ${OPENVAS_CRON_UPDATE_SCRIPT}
echo "0 4 * * * ${OPENVAS_CRON_UPDATE_SCRIPT}" | crontab -
printf "${GREEN}\nDone. Crontab installed. Current crontab list below:\n${NC}"
crontab -l
sleep $SLEEPTIME

printf "${GREEN}\n\n\n*****************************\n"
printf "installing ssh public key for ansible automation\n"
printf "*****************************\n\n${NC}"
mkdir -p "$HOME/.ssh"
chmod 0700 "$HOME/.ssh"
doppler secrets get DOPPSECRET_ANSIBLE_SSHKEY --plain | jq -r ".pub" > "$HOME/.ssh/authorized_keys"
chmod 0600 "$HOME/.ssh/authorized_keys"
printf "${GREEN}\nDone. Key installed.\n${NC}"

printf "${GREEN}\n\n\n*****************************\n"
printf "Removing passwordless sudo permission\n"
printf "*****************************\n\n${NC}"
sudo sed -i "/${USER}.*NOPASSWD/d" /etc/sudoers

printf "${GREEN}\n\nWARNING: It's highly recommended to logout/login to make unix group changes effective (user $USER was added to docker group)\n${NC}"
sleep $SLEEPTIME
