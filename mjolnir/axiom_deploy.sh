#!/bin/bash
SLEEPTIME=3


GREEN='\033[0;32m'
NC='\033[0m'

CURR_DATE=$(date +%Y%m%d_%H%M%S)

printf "\n"
echo "ODg4YiAgICAgZDg4OCAgZDhiICAgICAgICAgIDg4OCAgICAgICAgICBkOGIKODg4OGIgICBkODg4OCAgWThQICAgICAgICAgIDg4OCAgICAgICAgICBZOFAKODg4ODhiLmQ4ODg4OCAgICAgICAgICAgICAgIDg4OAo4ODhZODg4ODhQODg4IDg4ODggIC5kODhiLiAgODg4IDg4ODg4Yi4gIDg4OCA4ODhkODg4Cjg4OCBZODg4UCA4ODggIjg4OCBkODgiIjg4YiA4ODggODg4ICI4OGIgODg4IDg4OFAiCjg4OCAgWThQICA4ODggIDg4OCA4ODggIDg4OCA4ODggODg4ICA4ODggODg4IDg4OAo4ODggICAiICAgODg4ICA4ODggWTg4Li44OFAgODg4IDg4OCAgODg4IDg4OCA4ODgKODg4ICAgICAgIDg4OCAgODg4ICAiWTg4UCIgIDg4OCA4ODggIDg4OCA4ODggODg4CiAgICAgICAgICAgICAgIDg4OAogICAgICAgICAgICAgIGQ4OFAKICAgICAgICAgICAgODg4UCIKCigiQnV0IGZpbmVzdCBvZiB0aGVtIGFsbCwgJ1RoZSBDcnVzaGVyJyBpdCBpcyBjYWxsZWQ6IE1qw7ZsbmlyISBIYW1tZXIgb2YgVGhvciEiKQ==" | base64 -d
printf "\n\n"
printf "${GREEN}Configuring axiom for the very first time...\n${NC}"
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

digocn_api_token=$(doppler secrets get DOPPSECRET_DIGOCN_APITOKEN --plain)

AXIOM_PATH="$HOME/.axiom"
AXIOM_PROVISIONER="default"
AXIOM_DO_PROVIDER="do"
if [[ "${env}" == "dev" ]]; then
  DIGOCN_DFLT_REGION="fra1"
  DIGOCN_DFLT_DROPLETSIZE="s-1vcpu-1gb"
else
  DIGOCN_DFLT_REGION="lon1"
  DIGOCN_DFLT_DROPLETSIZE="s-8vcpu-16gb"
fi

printf "\n\n\n${GREEN}${env} environment was selected.\n\tDefault DigitalOcean region: ${DIGOCN_DFLT_REGION};\n\tDefault droplet size: ${DIGOCN_DFLT_DROPLETSIZE}\n${NC}\n"
sleep $SLEEPTIME

GOLDEN_IMAGE_NAME="axiom-goldenimage-${env}-${CURR_DATE}-$(cat /proc/sys/kernel/random/uuid)"

#create a new SSH key to embed on the golden image (force overwite if other key already exists)
printf "${GREEN}\n\n\n*****************************\n"
printf "Creating a new SSH key to embed on the golden image\n"
printf "*****************************\n\n${NC}"
KEYFILE="axiom_${env}key"
echo -e "y\n" | ssh-keygen -t ed25519 -C "axiom-${env}-${CURR_DATE}" -f "$HOME/.ssh/${KEYFILE}" -N ""
printf "${GREEN}\nDone. SSH key stored in $HOME/.ssh/${KEYFILE}\n${NC}"
sleep $SLEEPTIME

AXIOM_CONFIG="{\"do_key\":\"${digocn_api_token}\",\"region\":\"${DIGOCN_DFLT_REGION}\",\"provider\":\"${AXIOM_DO_PROVIDER}\",\"default_size\":\"${DIGOCN_DFLT_DROPLETSIZE}\",\"appliance_name\":\"\",\"appliance_key\":\"\",\"appliance_url\":\"\",\"email\":\"\",\"sshkey\":\"${KEYFILE}\",\"op\":\"\",\"imageid\":\"${GOLDEN_IMAGE_NAME}\",\"provisioner\":\"${AXIOM_PROVISIONER}\"}"
AXIOM_PROFILE_NAME="axiom_conf_${env}"
AXIOM_CONFIG_OUTPUT_FILE="${AXIOM_PATH}/accounts/${AXIOM_PROFILE_NAME}.json"

printf "${GREEN}\n\n\n*****************************\n"
printf "Executing axiom-configure\n"
printf "*****************************\n\n${NC}"
rm -f "${AXIOM_PATH}/axiom.json"
curl -fsSL https://raw.githubusercontent.com/pry0cc/axiom/master/interact/axiom-configure | bash -s -- --shell bash --unattended --config ${AXIOM_CONFIG}
#copy profile config to correct folder and meaningful name
cp "${AXIOM_PATH}/axiom.json" "${AXIOM_CONFIG_OUTPUT_FILE}"
printf "${GREEN}\nDone. Account configuration stored in ${AXIOM_CONFIG_OUTPUT_FILE}\n${NC}"
sleep $SLEEPTIME

printf "${GREEN}\n\n\n*****************************\n"
printf "Executing axiom-account to enable config\n"
printf "*****************************\n\n${NC}"
bash ${AXIOM_PATH}/interact/axiom-account ${AXIOM_PROFILE_NAME}

printf "${GREEN}\n\n\nConfiguration summary:\n${NC}"
cat ${AXIOM_CONFIG_OUTPUT_FILE} | jq
sleep $SLEEPTIME

printf "${GREEN}\n\n\n*****************************\n"
printf "Executing axiom-build\n"
printf "*****************************\n\n${NC}"
$AXIOM_PATH/interact/axiom-build "${AXIOM_PROVISIONER}"
sleep $SLEEPTIME

printf "${GREEN}\n\n\n*****************************\n"
printf "Renaming snapshot for better comprehension\n"
printf "*****************************\n\n${NC}"
current_image_name=$(jq -r '.imageid' $AXIOM_PATH/axiom.json)
image_id=$(doctl compute image list | grep "${current_image_name}" | awk '{ print $1 }')
doctl compute image update ${image_id} --image-name ${GOLDEN_IMAGE_NAME}
account_path=$(ls -la $AXIOM_PATH/axiom.json | rev | cut -d " " -f 1 | rev)
jq '.imageid="'${GOLDEN_IMAGE_NAME}'"' < "$account_path" > "$AXIOM_PATH"/tmp.json ; mv "$AXIOM_PATH"/tmp.json "$account_path"
printf "${GREEN}\nDone. Image should be now named '${GOLDEN_IMAGE_NAME}'.\n${NC}"

sleep $SLEEPTIME

printf "${GREEN}\n\n\n'op' user password is: $(jq -r '.op' $AXIOM_PATH/axiom.json)\n"
printf "SSH key to access axiom boxes stored in ~/.ssh/${KEYFILE}\n"
printf "WARNING: YOU MAY WANT TO SAVE THE PASSWORD AND SSH PRIVATE KEY IF YOU WANT TO ACCESS AXIOM BOXES!!!!\n${NC}"
sleep $SLEEPTIME
