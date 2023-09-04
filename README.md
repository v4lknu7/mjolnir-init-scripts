# mjolnir-init-scripts

## Init asgaard mgmt droplet

Init VM: (1) unset HISTFILE && bash -c "$(curl -fsSL https://github.com/v4lknu7/mjolnir-init-scripts/raw/main/mgmt_vm_init.sh)" mgmt_vm_init.sh -t DOPPLER_SVC_TOKEN

Init axiom (w/ non-root user): (2) bash -c "$(curl -fsSL https://github.com/v4lknu7/mjolnir-init-scripts/raw/main/mjolnir/axiom_deploy.sh)" axiom_deploy.sh -e dev

Init mjonir (w/ non-root user): (3) bash -c "$(curl -fsSL https://github.com/v4lknu7/mjolnir-init-scripts/raw/main/mjolnir/mjolnir_deploy.sh)" && source $HOME/.bashrc

## Init openvas droplet

Init VM: (1) unset HISTFILE && bash -c "$(curl -fsSL https://github.com/v4lknu7/mjolnir-init-scripts/raw/main/mgmt_vm_init.sh)" mgmt_vm_init.sh -t DOPPLER_SVC_TOKEN

Init OpenVAS (w/ non-root user): (2) bash -c "$(curl -fsSL https://github.com/v4lknu7/mjolnir-init-scripts/raw/main/openvas/openvas_deploy.sh)" openvas_deploy.sh -e dev && source $HOME/.bashrc
