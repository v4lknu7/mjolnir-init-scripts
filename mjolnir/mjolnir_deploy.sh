#!/bin/bash

MJOLNIR_HOME_ENVVAR_NAME="MJOLNIR_PATH"
MJOLNIR_HOME_ENVVAR_VALUE="$HOME/mjolnir"

PIP_HOME="$HOME/.local/bin"

SHELL_FILE="$HOME/.bashrc"

SLEEPTIME=3

GREEN='\033[0;32m'
NC='\033[0m'

RECON_NG_TMP_CMDS_FILE="/tmp/recon-ng.setup.cmds"

MJOLNIR_HOME_TOOLS_FOLDER="${MJOLNIR_HOME_ENVVAR_VALUE}/tools"

ANSIBLE_CONF_FOLDER="${MJOLNIR_HOME_ENVVAR_VALUE}/ansible"
ANSIBLE_INVENTORY_FILE="${ANSIBLE_CONF_FOLDER}/ansible.inventory"
ANSIBLE_INVENTORY_OPENVAS_GROUPNAME="openvas"

printf "\n"
echo "ODg4YiAgICAgZDg4OCAgZDhiICAgICAgICAgIDg4OCAgICAgICAgICBkOGIKODg4OGIgICBkODg4OCAgWThQICAgICAgICAgIDg4OCAgICAgICAgICBZOFAKODg4ODhiLmQ4ODg4OCAgICAgICAgICAgICAgIDg4OAo4ODhZODg4ODhQODg4IDg4ODggIC5kODhiLiAgODg4IDg4ODg4Yi4gIDg4OCA4ODhkODg4Cjg4OCBZODg4UCA4ODggIjg4OCBkODgiIjg4YiA4ODggODg4ICI4OGIgODg4IDg4OFAiCjg4OCAgWThQICA4ODggIDg4OCA4ODggIDg4OCA4ODggODg4ICA4ODggODg4IDg4OAo4ODggICAiICAgODg4ICA4ODggWTg4Li44OFAgODg4IDg4OCAgODg4IDg4OCA4ODgKODg4ICAgICAgIDg4OCAgODg4ICAiWTg4UCIgIDg4OCA4ODggIDg4OCA4ODggODg4CiAgICAgICAgICAgICAgIDg4OAogICAgICAgICAgICAgIGQ4OFAKICAgICAgICAgICAgODg4UCIKCigiQnV0IGZpbmVzdCBvZiB0aGVtIGFsbCwgJ1RoZSBDcnVzaGVyJyBpdCBpcyBjYWxsZWQ6IE1qw7ZsbmlyISBIYW1tZXIgb2YgVGhvciEiKQ==" | base64 -d
printf "\n\n"
printf "${GREEN}initiating...\n${NC}"
sleep $SLEEPTIME

usage() { echo "Usage: $0 -e <dev|prod>" 1>&2; exit 0; }

while getopts ":e:" flags; do
  case "${flags}" in
    e)
      env=${OPTARG}
      ;;
    *)
      usage
      ;;
  esac
done
shift $((OPTIND-1))
if [ -z "${env}" ]; then
        usage
fi
if [[ "${env}" != "dev" ]] && [[ "${env}" != "prod" ]]; then
  usage
fi

printf "${GREEN}\n\n\n*****************************\n"
printf "cloning and configuring mjolnir\n"
printf "*****************************\n\n${NC}"
dopp_git_secret=$(doppler secrets get DOPPSECRET_GITHUB_CREDENTIALS --plain)
git_user=$(echo ${dopp_git_secret} | jq -r ".user")
git_pat=$(echo ${dopp_git_secret} | jq -r ".token")
rm -rf ${MJOLNIR_HOME_ENVVAR_VALUE}
printf "${GREEN}\n\nCloning repo...${NC}\n"
git clone https://${git_pat}@github.com/${git_user}/mjolnir.git ${MJOLNIR_HOME_ENVVAR_VALUE}
printf "${GREEN}\n\nchmoding executable files...${NC}\n"
find ${MJOLNIR_HOME_ENVVAR_VALUE} -name "*.sh" -exec chmod 700 {} \;
printf "${GREEN}\n\nSetting ${MJOLNIR_HOME_ENVVAR_NAME} env variable...${NC}\n"
if grep "export ${MJOLNIR_HOME_ENVVAR_NAME}=" "${SHELL_FILE}"; then
  printf "${GREEN}${MJOLNIR_HOME_ENVVAR_NAME} already set${NC}\n"
else
  echo "export ${MJOLNIR_HOME_ENVVAR_NAME}=${MJOLNIR_HOME_ENVVAR_VALUE}" >> "${SHELL_FILE}"
  printf "${GREEN}${MJOLNIR_HOME_ENVVAR_NAME} was set${NC}\n"
fi

printf "${GREEN}\n\n\nDone. mjolnir configured.\n${NC}"
sleep $SLEEPTIME

printf "${GREEN}\n\n\n*****************************\n"
printf "installing dependencies\n"
printf "*****************************\n\n${NC}"
sudo apt -y install python3 python3-dev python3-pip git bzip2 nmap ansible libpq-dev
export PATH="$PATH:${PIP_HOME}"
if grep "PATH.*${PIP_HOME}" "${SHELL_FILE}"; then
  printf "${GREEN}PIP_HOME already set${NC}\n"
else
  echo "export PATH=\"\$PATH:${PIP_HOME}\"" >> "${SHELL_FILE}"
  printf "${GREEN}PIP_HOME was set${NC}\n"
fi

if grep "${USER}.*nmap" /etc/sudoers; then
  printf "${GREEN}passwordless sudo 'nmap -sU --top-ports' already set${NC}\n"
else
  echo "${USER} ALL=(ALL) NOPASSWD: /usr/bin/nmap -sU --top-ports *" | sudo tee -a /etc/sudoers
  printf "${GREEN}passwordless 'nmap -sU --top-ports' was set${NC}\n"
fi

mkdir -p ${MJOLNIR_HOME_TOOLS_FOLDER}
git clone https://github.com/lanmaster53/recon-ng.git ${MJOLNIR_HOME_TOOLS_FOLDER}/recon-ng
pip3 install -r ${MJOLNIR_HOME_TOOLS_FOLDER}/recon-ng/REQUIREMENTS
pip3 install censys
pip3 install psycopg2

printf "${GREEN}\nDone. Dependencies installed.\n${NC}"
sleep $SLEEPTIME

printf "${GREEN}\n\n\n*****************************\n"
printf "configuring recon-ng\n"
printf "*****************************\n\n${NC}"
printf "%s\n"\
  "marketplace install recon/domains-hosts/hackertarget"\
  "marketplace install recon/domains-hosts/certificate_transparency"\
  "marketplace install reporting/list"\
  "exit" > "${RECON_NG_TMP_CMDS_FILE}"
${MJOLNIR_HOME_TOOLS_FOLDER}/recon-ng/recon-ng -r ${RECON_NG_TMP_CMDS_FILE}
rm -f ${RECON_NG_TMP_CMDS_FILE}
printf "${GREEN}\nDone. recon-ng configured.\n${NC}"
sleep $SLEEPTIME

printf "${GREEN}\n\n\n*****************************\n"
printf "configuring censys\n"
printf "*****************************\n\n${NC}"
dopp_censys_secret=$(doppler secrets get DOPPSECRET_CENSYS_CREDENTIALS --plain)
censys_id=$(echo ${dopp_censys_secret} | jq -r ".id")
censys_apikey=$(echo ${dopp_censys_secret} | jq -r ".token")
echo -e "${censys_id}\n${censys_apikey}\nn" | censys config
printf "${GREEN}\nDone. censys configured.\n${NC}"

printf "${GREEN}\n\n\n*****************************\n"
printf "Configuring '$USER' user ssh key for ansible automation, and store public key at DigitalOcean so other servers can read it and copy it to their authorized_keys \n"
printf "*****************************\n\n${NC}"
key_name="ansible_automation_${env}"
key_file="$HOME/.ssh/$USER.key"
echo -e "y\n" | ssh-keygen -t ed25519 -C ${key_name} -f "${key_file}" -N ""
printf "${GREEN}SSH key created. $(ssh-keygen -l -E md5 -f ${key_file})\n\n${NC}"
for existing_fprint in $(doctl compute ssh-key list -o json | jq '.[] | select(.name == "'"${key_name}"'") | .fingerprint' | tr -d '"'); do
  printf "${GREEN}\n\nDeleting old key with fingerprint ${existing_fprint}...\n${NC}"
  doctl compute ssh-key delete ${existing_fprint} -f
done
printf "${GREEN}Importing ${key_file}.pub to DigitalOcean...\n${NC}"
doctl compute ssh-key import ${key_name} --public-key-file "${key_file}.pub"

printf "${GREEN}\n\n\nDone. key created and stored at DigitalOcean.\n${NC}"
sleep $SLEEPTIME

printf "${GREEN}\n\n\n*****************************\n"
printf "environment definition\n"
printf "*****************************\n\n${NC}"
printf "${GREEN}Droplets @ DigitalOcean:\n${NC}"
doctl compute droplet list --format "Name, PrivateIPv4, Region"
echo
read -p "OpenVAS droplet IP address (if multiple, separate IPs with comma): " openvas_droplets
openvas_inventory_stripspaces="${openvas_droplets//[[:space:]]/}"
openvas_inventory_split="${openvas_inventory_stripspaces//,/$'\n'}"
mkdir -p ${ANSIBLE_CONF_FOLDER}
cat <<EOF > ${ANSIBLE_INVENTORY_FILE}
[${ANSIBLE_INVENTORY_OPENVAS_GROUPNAME}]
${openvas_inventory_split}

[${ANSIBLE_INVENTORY_OPENVAS_GROUPNAME}:vars]
ansible_ssh_common_args="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
ansible_ssh_private_key_file="${key_file}"
EOF
printf "${GREEN}\nansible inventory created at ${ANSIBLE_INVENTORY_FILE}:\n${NC}"

printf "${GREEN}\nDone. Environment configured.\n${NC}"
sleep $SLEEPTIME
