# mjolnir-init-scripts

## Init asgaard mgmt droplet

Init VM: (1) unset HISTFILE && bash -c "$(curl -fsSL https://github.com/v4lknu7/mjolnir-init-scripts/raw/main/mgmt_vm_init.sh)" -t <doppler service token>

Init axiom (w/ non-root user): (2) read -s -p "Github access token: " gh_token && bash -c "$(curl -fsSL -H "Authorization: token $gh_token" https://raw.githubusercontent.com/v4lknu7/mjolnir/main/init/mjolnir/axiom_deploy.sh)" axiom_deploy.sh -e dev

Init mjonir (w/ non-root user): (3) read -s -p "Github access token: " gh_token && bash -c "$(curl -fsSL -H "Authorization: token $gh_token" https://raw.githubusercontent.com/v4lknu7/mjolnir/main/init/mjolnir/mjolnir_deploy.sh)" mjolnir_deploy.sh -e dev && source $HOME/.bashrc

## Init openvas droplet

Init VM: (1) unset HISTFILE && bash -c "$(curl -fsSL https://github.com/v4lknu7/mjolnir-init-scripts/raw/main/mgmt_vm_init.sh)" mgmt_vm_init.sh -d -t <doppler service token>

Init OpenVAS (w/ non-root user): (2) bash -c "$(curl -fsSL https://github.com/v4lknu7/mjolnir-init-scripts/raw/main/openvas/openvas_deploy.sh)" openvas_deploy.sh -e dev && source $HOME/.bashrc
