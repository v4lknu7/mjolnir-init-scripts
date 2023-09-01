#!/bin/bash

DEFAULT_LOCALE="en_US.UTF-8"
APPUSER="thor"
SLEEPTIME=3

GREEN='\033[0;32m'
NC='\033[0m'

printf "\n"
echo "ODg4YiAgICAgZDg4OCAgZDhiICAgICAgICAgIDg4OCAgICAgICAgICBkOGIKODg4OGIgICBkODg4OCAgWThQICAgICAgICAgIDg4OCAgICAgICAgICBZOFAKODg4ODhiLmQ4ODg4OCAgICAgICAgICAgICAgIDg4OAo4ODhZODg4ODhQODg4IDg4ODggIC5kODhiLiAgODg4IDg4ODg4Yi4gIDg4OCA4ODhkODg4Cjg4OCBZODg4UCA4ODggIjg4OCBkODgiIjg4YiA4ODggODg4ICI4OGIgODg4IDg4OFAiCjg4OCAgWThQICA4ODggIDg4OCA4ODggIDg4OCA4ODggODg4ICA4ODggODg4IDg4OAo4ODggICAiICAgODg4ICA4ODggWTg4Li44OFAgODg4IDg4OCAgODg4IDg4OCA4ODgKODg4ICAgICAgIDg4OCAgODg4ICAiWTg4UCIgIDg4OCA4ODggIDg4OCA4ODggODg4CiAgICAgICAgICAgICAgIDg4OAogICAgICAgICAgICAgIGQ4OFAKICAgICAgICAgICAgODg4UCIKCigiQnV0IGZpbmVzdCBvZiB0aGVtIGFsbCwgJ1RoZSBDcnVzaGVyJyBpdCBpcyBjYWxsZWQ6IE1qw7ZsbmlyISBIYW1tZXIgb2YgVGhvciEiKQ==" | base64 -d
printf "\n\n"
printf "${GREEN}initiating...\n${NC}"
sleep $SLEEPTIME

usage() { echo "Usage: $0 [-d (enable if you want to install doctl at init stage)]" 1>&2; exit 0; }

install_doctl=false
while getopts "d" flags; do
  case "${flags}" in
    d)
      install_doctl=true
      ;;
    *)
      usage
      ;;
  esac
done
shift $((OPTIND-1))

printf "${GREEN}\n\n\n*****************************\n"
printf "apt update, dist-upgrade, install locales-all and jq set default locale\n"
printf "*****************************\n\n${NC}"
export DEBIAN_FRONTEND=noninteractive #useful for 100% unattended apt dist-upgrade
apt update
apt -y install locales-all jq
apt update && apt -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade && apt -y autoremove && apt -y clean
printf "LANG=$DEFAULT_LOCALE\nLC_ALL=$DEFAULT_LOCALE" > /etc/default/locale
printf "${GREEN}\nDone. packages and distro updated and default locale set to $DEFAULT_LOCALE\n${NC}"
sleep $SLEEPTIME

printf "${GREEN}\n\n\n*****************************\n"
printf "Installing and configuring Doppler client\n"
printf "*****************************\n\n${NC}"
apt update && apt install -y apt-transport-https ca-certificates curl gnupg
curl -sLf --retry 3 --tlsv1.2 --proto "=https" 'https://packages.doppler.com/public/cli/gpg.DE2A7741A397C129.key' | gpg --dearmor -o /usr/share/keyrings/doppler-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/doppler-archive-keyring.gpg] https://packages.doppler.com/public/cli/deb/debian any-version main" | tee /etc/apt/sources.list.d/doppler-cli.list
apt update && apt install doppler
echo
read -s -p "Doppler service token: " doppler_svc_token
echo
echo ${doppler_svc_token} | doppler configure set token --scope $(pwd)
printf "${GREEN}\nDone. Doppler installed and configured\n${NC}"
sleep $SLEEPTIME

printf "${GREEN}\n\n\n*****************************\n"
printf "Creating '$APPUSER' user and set their password\n"
printf "*****************************\n\n${NC}"
if id "$APPUSER" &>/dev/null; then
  printf "${GREEN}user $APPUSER already exists. Skipping.\n${NC}"
else
  useradd -d /home/$APPUSER -m -G sudo -s /bin/bash $APPUSER
  printf "${GREEN}\nDone. User $APPUSER added\n${NC}"
fi
printf "${GREEN}\nSet a password for user $APPUSER:\n${NC}"
userpass=$(doppler secrets get DOPPSECRET_UNIX_APPUSER_CREDENTIALS --plain | jq -r ".password")
echo -e "${userpass}\n${userpass}" | passwd $APPUSER
#root will never need to run doppler anymore. Delete config folder
rm -rf .doppler/
printf "${GREEN}\nConfiguring doppler for user $APPUSER\n${NC}"
appuser_home=$(getent passwd $APPUSER | cut -d: -f6)
su - $APPUSER -c "echo ${doppler_svc_token} | doppler configure set token --scope ${appuser_home}"
sleep $SLEEPTIME

printf "${GREEN}\n\n\n*****************************\n"
printf "Install and configure doctl for user '$APPUSER'\n"
printf "*****************************\n\n${NC}"
#There is no way to download the 'latest' version. We need to specify the version number to download.
#Worth checking periodically if there are newer versions available
if [ ${install_doctl} = true ] ; then
  printf "${GREEN}\n\n\n*****************************\n"
  printf "installing doctl\n"
  printf "*****************************\n\n${NC}"
  wget -O /tmp/doctl.tar.gz https://github.com/digitalocean/doctl/releases/download/v1.97.1/doctl-1.97.1-linux-amd64.tar.gz && tar -xvzf /tmp/doctl.tar.gz && sudo mv doctl /usr/bin/doctl && rm /tmp/doctl.tar.gz
  sudo -u $APPUSER doctl auth init
  printf "${GREEN}\nDone. doctl installed\n${NC}"
  sleep $SLEEPTIME
fi

printf "${GREEN}\nDone. doctl configured\n${NC}"
sleep $SLEEPTIME

printf "${GREEN}\n\n\nFinished. rebooting in $SLEEPTIME seconds...\n${NC}"
sleep $SLEEPTIME
reboot
