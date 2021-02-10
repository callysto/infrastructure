CURDIR := $(shell pwd)
UNAME = $(shell uname)
TF_PATH := ${CURDIR}/terraform
ANSIBLE_PATH := ${CURDIR}/ansible
PACKER_PATH := ${CURDIR}/packer
DEHYDRATED_PATH := ${CURDIR}/vendor/dehydrated/dehydrated
export TUTOR_PATH := ${CURDIR}/tutor
export PATH := ${CURDIR}/bin:${CURDIR}/bin/${UNAME}:${PATH}:${HOME}/.local/bin

SHELL := /bin/bash

undefine USER

# Callysto-specific information
export OPENRC_PATH := /home/ptty2u/work/rc/openrc
export ADMIN_EMAIL := sysadmin@callysto.ca
export SUPPORT_EMAIL := support@callysto.ca

export DEV_CALLYSTO_DOMAINNAME := callysto.farm
export TF_VAR_DEV_CALLYSTO_DOMAINNAME := ${DEV_CALLYSTO_DOMAINNAME}
export DEV_CALLYSTO_SSL_DIR_NAME := star_callysto_farm
export DEV_CALLYSTO_ZONE_ID := fb1e23f2-5eb9-43e9-aa37-60a5bd7c2595
export TF_VAR_DEV_CALLYSTO_ZONE_ID := ${DEV_CALLYSTO_ZONE_ID}
#export DEV_CALLYSTO_SSL_CERT_DIRECTORY := ./../../../letsencrypt/dev/certs/${DEV_CALLYSTO_SSL_DIR_NAME}
export DEV_CALLYSTO_SSL_CERT_DIRECTORY := $(CURDIR)/letsencrypt/dev/certs/${DEV_CALLYSTO_SSL_DIR_NAME}

export PROD_CALLYSTO_DOMAINNAME := callysto.ca
export TF_VAR_PROD_CALLYSTO_DOMAINNAME := ${PROD_CALLYSTO_DOMAINNAME}
export PROD_CALLYSTO_SSL_DIR_NAME := star_callysto_ca
export PROD_CALLYSTO_ZONE_ID := 1cf42d24-a04e-431b-a715-1701f297100e
export TF_VAR_PROD_CALLYSTO_ZONE_ID := ${PROD_CALLYSTO_ZONE_ID}
export PROD_CALLYSTO_SSL_CERT_DIRECTORY := $(CURDIR)/letsencrypt/prod/certs/${PROD_CALLYSTO_SSL_DIR_NAME}
export CALLYSTO_LCRYPT_BASE := /home/ptty2u/work/callysto-infra/letsencrypt

# edX static hostname
export DEV_EDX_HOSTNAME := dev-edx
export TF_VAR_DEV_EDX_HOSTNAME := ${DEV_EDX_HOSTNAME}

# SSH information
KEY_DIR := ${CURDIR}/keys
PRIVATE_KEY := ${KEY_DIR}/id_rsa
PUBLIC_KEY := ${KEY_DIR}/id_rsa.pub
SSH_CMD := ssh -i ${PRIVATE_KEY} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no

# Ansible information
PLAYBOOK_CMD := TF_STATE=${TF_PATH}/${ENV} ansible-playbook --private-key=${PRIVATE_KEY} -i ./inventory
ANSIBLE_CMD := TF_STATE=${TF_PATH}/${ENV} ansible --private-key=${PRIVATE_KEY} -i ./inventory
ANSIBLE_EXEC_CMD := TF_STATE=${TF_PATH}/${ENV} ansible -b --private-key=${PRIVATE_KEY} -i ./inventory

# Packer information
PACKER_CMD := packer

# Global tasks
help: tasks

tasks:
	@grep -A1 ^HELP Makefile | sed -e ':begin;$$!N;s/HELP: \(.*\)\n\(.*:\).*/\2 \1/;tbegin;P;D' | grep -v \\\-\\\- | sort | awk -F: '{printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

# Checks
check-env:
ifndef ENV
	$(error ENV is not defined)
endif

check-type:
ifndef TYPE
	$(error TYPE is not defined)
endif

check-group:
ifndef GROUP
	$(error GROUP is not defined)
endif

check-group-optional:
ifdef GROUP
export _GROUP = ${GROUP}
else
export _GROUP = all
endif

check-host:
ifndef HOST
	$(error HOST is not defined)
endif

check-module:
ifdef MODULE
export _MODULE = ${MODULE}
else
	$(error MODULE is not defined)
endif

check-args:
ifdef ARGS
export _ARGS = -a "${ARGS}"
else
export _ARGS =
endif

check-ansible-args:
ifdef ANSIBLE_ARGS
export _ANSIBLE_ARGS = "${ANSIBLE_ARGS}"
else
export _ANSIBLE_ARGS =
endif

check-playbook:
ifndef PLAYBOOK
	$(error PLAYBOOK is not defined)
else
export _PLAYBOOK = plays/${PLAYBOOK}.yml
endif

check-refquota:
ifndef REFQUOTA
	$(error REFQUOTA is not defined)
endif

check-target:
ifndef TARGET
	$(error TARGET is not defined)
endif

check-user:
ifndef USER
	$(error USERHASH is not defined)
endif

check-userhash:
ifndef USERHASH
	$(error USERHASH is not defined. Try user/findhash to determine it)
endif

# Terraform tasks
HELP: Runs any first steps when this repository is first cloned
terraform/setup:
	@echo "There are no steps to run at this time"

HELP: Runs "terraform init" for $ENV
terraform/init: check-env
	@cd ${TF_PATH}/${ENV} ; \
	terraform init

HELP: Runs "terraform plan" for $ENV
terraform/plan: terraform/init
	@cd ${TF_PATH}/${ENV} ; \
	terraform plan

HELP: Runs "terraform apply" for $ENV
terraform/apply: terraform/plan
	@cd ${TF_PATH}/${ENV} ; \
	terraform apply

HELP: Runs "terraform apply -auto-approve" for $ENV
terraform/auto-apply: terraform/plan
	@cd ${TF_PATH}/${ENV} ; \
	terraform apply -auto-approve

HELP: Runs "terraform destroy" for $ENV
terraform/destroy: check-env
	@cd ${TF_PATH}/${ENV} ; \
	terraform destroy

HELP: Runs "terraform destroy -auto-approve" for $ENV
terraform/auto-destroy: check-env
	@cd ${TF_PATH}/${ENV} ; \
	terraform destroy -auto-approve

HELP: Runs "terraform show" for $ENV
terraform/show: check-env
	@cd ${TF_PATH}/${ENV} ; \
	terraform show

HELP: Lists available targets in $ENV
terraform/list-targets: check-env
	@cd ${TF_PATH}/${ENV} ; \
	terraform show | grep :$$ | tr -d : | sort

HELP: Runs "terraform taint" on a $TARGET in $ENV
terraform/taint: check-env check-target
	@cd ${TF_PATH}/${ENV} ; \
	terraform taint ${TARGET}

HELP: Rebuilds an instance and volumes in $ENV
terraform/hub/rebuild: check-env
	@make terraform/taint ENV=${ENV} TARGET=openstack_compute_instance_v2.hub
	@make terraform/taint ENV=${ENV} TARGET=openstack_blockstorage_volume_v2.zfs.0
	@make terraform/taint ENV=${ENV} TARGET=openstack_blockstorage_volume_v2.zfs.1
	@make terraform/auto-apply ENV=${ENV}

HELP: List the different types of environments
terraform/list-environments:
	@grep ^## ${TF_PATH}/templates/*.tf | sed -e 's/#//g' | sed -e "s!${TF_PATH}/templates/!!g" | sed -e 's/\.tf//g' | sort | awk -F: '{printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

HELP: Create a new $TYPE of environment called $ENV
terraform/new: check-env check-type
	@cd ${TF_PATH} ; \
	if [[ ! -d ${ENV} ]]; then \
		mkdir ${ENV} ; \
		cp templates/${TYPE}.tf ${ENV}/main.tf ; \
		sed -i -e 's/ENV/${ENV}/g' ${ENV}/main.tf ; \
	fi
	@if [[ ! -d ${ANSIBLE_PATH}/group_vars/${ENV} ]]; then \
		mkdir ${ANSIBLE_PATH}/group_vars/${ENV} ; \
		cp ${ANSIBLE_PATH}/local_vars.yml.example ${ANSIBLE_PATH}/group_vars/${ENV}/local_vars.yml ; \
	fi
	@echo ""
	@echo "Make sure to edit ${ANSIBLE_PATH}/group_vars/${ENV}/local_vars.yml."
	@echo ""

# Ansible tasks
HELP: Runs any first steps when this repository is first cloned
ansible/setup:
	@cd ${ANSIBLE_PATH} ; \
	echo "Setting up Ansible Inventory" ; \
	[[ -e "inventory" ]] || ln -s ../bin/${UNAME}/ansible-terraform-inventory inventory ; \
	echo "" ; \
	echo "Remember to update group_vars/<env>/local_vars.yml to fit your environment." ; \
	echo "" ; \
	echo "Installing external Ansible roles" ; \
	/bin/bash scripts/role_update.sh

HELP: Lists plays
ansible/list-playbooks:
	@cd ${ANSIBLE_PATH} ; \
	grep -H ^## plays/*.yml | grep -v Environment | sed -e 's/\(plays\/\)\(.*\)\(.yml\)/\2/' | sort | awk 'BEGIN {FS = ":## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

HELP: Lists playbooks to deploy environments
ansible/list-environments:
	@cd ${ANSIBLE_PATH} ; \
	grep -H ^'## Environment:' plays/*.yml | sed -e 's/Environment: //g' | sed -e 's/\(plays\/\)\(.*\)\(.yml\)/\2/' | sort | awk 'BEGIN {FS = ":## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

HELP: Lists the tasks in a $PLAYBOOK in $ENV
ansible/list-tasks: check-playbook
	@cd ${ANSIBLE_PATH} ; \
	${PLAYBOOK_CMD} --list-tasks ${_PLAYBOOK}

HELP: Lists all hosts in $ENV
ansible/hosts: check-env
	@cd ${ANSIBLE_PATH} ; \
	${ANSIBLE_CMD} all --list-hosts

HELP: Lists the hosts in $GROUP in $ENV
ansible/hosts/group: check-env check-group-optional
	@cd ${ANSIBLE_PATH} ; \
	${ANSIBLE_CMD} ${_GROUP} --list-hosts

HELP: Lists the hosts in $PLAYBOOK in $ENV
ansible/hosts/playbook: check-env check-playbook
	@cd ${ANSIBLE_PATH} ; \
	${PLAYBOOK_CMD} ${_PLAYBOOK} --list-hosts

HELP: Runs $PLAYBOOK on $GROUP in check-mode in $ENV
ansible/playbook/check: check-env check-playbook check-group-optional
	@cd ${ANSIBLE_PATH} ; \
	${PLAYBOOK_CMD} --check --diff --limit ${_GROUP} ${_PLAYBOOK}

HELP: Runs $PLAYBOOK on $GROUP for reals in $ENV
ansible/playbook: check-env check-playbook check-group-optional
	@cd ${ANSIBLE_PATH} ; \
	${PLAYBOOK_CMD} --limit ${_GROUP} ${_PLAYBOOK}

HELP: Returns the ipv4 address of $HOST in $ENV
ansible/get-ipv4: check-env check-host
	@cd ${ANSIBLE_PATH} ;\
	${ANSIBLE_CMD} ${HOST} -m setup -a "filter=ansible_default_ipv4" | grep \"address | sed -e 's/[\", ]//g' | cut -d: -f2

HELP: Returns the ssh user of $HOST in $ENV
ansible/get-ssh-user: check-env check-host
	@cd ${ANSIBLE_PATH} ; \
	${ANSIBLE_CMD} ${HOST} -m debug -a "msg={{ ansible_user }}" | grep msg | sed -e 's/[\", ]//g' | cut -d: -f2

HELP: Returns a variable of $HOST in $ENV
ansible/get-var: check-env check-host
	@cd ${ANSIBLE_PATH} ; \
	${ANSIBLE_CMD} ${HOST} -m debug -a "msg={{ ${VAR} }}" | grep msg | sed -e 's/[\", ]//g' | cut -d: -f2

HELP: Pings the hosts in $GROUP in $ENV
ansible/ping: check-env check-group-optional
	@cd ${ANSIBLE_PATH} ; \
	${ANSIBLE_CMD} ${_GROUP} -m ping

HELP: Executes $MODULE on $GROUP with $ARGS in $ENV
ansible/exec: check-env check-group-optional check-module check-args check-ansible-args
	@cd ${ANSIBLE_PATH} ; \
	$(ANSIBLE_EXEC_CMD) $(_ANSIBLE_ARGS) ${_GROUP} -m ${_MODULE} ${_ARGS}

# Quota tasks
HELP: Gets a quota for $USERHASH on hub $HOST in $ENV
quota/get: check-env check-userhash check-host
	@cd ${ANSIBLE_PATH} ; \
	${PLAYBOOK_CMD} --limit hub plays/quota_tasks.yml --limit ${HOST} --extra-vars user=${USERHASH}

HELP: Sets a quota to $REFQUOTA for $USERHASH on hub $HOST in $ENV
quota/set: check-env check-userhash check-refquota check-host
	@cd ${ANSIBLE_PATH} ; \
	${PLAYBOOK_CMD} --limit hub plays/quota_tasks.yml --limit ${HOST} --extra-vars set_quota=1 --extra-vars user=${USERHASH} --extra-vars refquota=${REFQUOTA}

# ZFS Delete user directory task
HELP: Deletes the ZFS directory for $USERHASH on hub $HOST in $ENV
zfsdir/delete: check-env check-userhash check-host
	@cd ${ANSIBLE_PATH} ; \
	${PLAYBOOK_CMD} --limit hub plays/zfsdir_destroy.yml --limit ${HOST} --extra-vars user=${USERHASH}


HELP: Finds a hash ($USERHASH) for $USER in $ENV
user/findhash: check-env check-user
	@cd ${ANSIBLE_PATH} ; \
	${PLAYBOOK_CMD} plays/find_hash.yml --extra-vars user=${USER}

HELP: Ban $USERHASH from $ENV
user/banuser: check-env check-userhash
	@cd ${ANSIBLE_PATH} ; \
	${PLAYBOOK_CMD} plays/ban_user.yml --extra-vars user=${USERHASH}

# Backup tasks
HELP: Performs a backup of sensitive data
backup:
	@cd ${ANSIBLE_PATH} ; \
	${PLAYBOOK_CMD} --limit localhost plays/backup.yml

# Packer tasks
HELP: Builds the CentOS image for Callysto
packer/build/centos:
	@cd $(PACKER_PATH) ; \
	$(PACKER_CMD) build -var region=Calgary -var flavor=m1.small -var image_name="CentOS 7" -var network_id=b0b12e8f-a695-480e-9dc2-3dc8ac2d55fd centos.json

HELP: Builds the Ubuntu 18.04 image for callysto
packer/build/ubuntu1804:
	@cd $(PACKER_PATH) ; \
	$(PACKER_CMD) build -var region=Calgary -var flavor=m1.small -var image_name="Ubuntu 18.04" -var network_id=b0b12e8f-a695-480e-9dc2-3dc8ac2d55fd ubuntu1804.json

HELP: Builds the Ubuntu 16.04 image for callysto
packer/build/ubuntu1604:
	@cd $(PACKER_PATH) ; \
	$(PACKER_CMD) build -var region=Calgary -var flavor=m1.small -var image_name="Ubuntu 16.04" -var network_id=b0b12e8f-a695-480e-9dc2-3dc8ac2d55fd ubuntu1604.json

# Let's Encrypt tasks
letsencrypt/generate: check-env
	@cd letsencrypt/${ENV} ; \
	unset OS_USERNAME ; \
	unset OS_PASSWORD ; \
	if [[ ${ENV} =~ 'dev' ]]; then \
	  echo "*.${DEV_CALLYSTO_DOMAINNAME} > ${DEV_CALLYSTO_SSL_DIR_NAME}" > domains.txt ; \
	  ${DEHYDRATED_PATH} -c --accept-terms -f 'config' -k './hook.sh' ; \
	else \
	  echo "*.${PROD_CALLYSTO_DOMAINNAME} > ${PROD_CALLYSTO_SSL_DIR_NAME}" > domains.txt ; \
	  ${DEHYDRATED_PATH} -c --accept-terms -f 'config' -k './hook.sh' ; \
	fi

# SSH tasks
HELP: SSH to a given $HOST in $ENV
ssh/shell: check-env check-host
	@_host=$(shell make ansible/get-ipv4 ENV=${ENV} HOST=${HOST}) ; \
	_user=$(shell make ansible/get-ssh-user ENV=${ENV} HOST=${HOST}) ; \
	${SSH_CMD} $$_user@$$_host

# Tutor tasks
HELP: Install and configure Tutor
tutor/install:
	@pip3.6 install --user tutor-openedx
	cd ~/work ; \
	git clone https://github.com/callysto/tutor-callysto ; \
	pip3.6 install --user ./tutor-callysto

HELP: Upgrade Tutor
tutor/upgrade:
	@pip3.6 install --user --upgrade tutor-openedx
	cd ~/work/tutor-callysto ; \
	git pull ; \
	pip3.6 install --user ./tutor-callysto

HELP: Upgrade a Tutor environment
tutor/upgrade/environment: check-env
	cd ${TUTOR_PATH} ; \
	mv ${ENV}.orig/.git ${ENV}/ ; \
	mv ${ENV}.orig/env/build/openedx/requirements/* ${ENV}/env/build/openedx/requirements/ ; \
	mv ${ENV}.orig/env/build/openedx/themes/* ${ENV}/env/build/openedx/themes ; \

HELP: Pull down the base Tutor openedx image
tutor/image/pull/upstream: check-env
	TUTOR_ROOT="${TUTOR_PATH}/${ENV}" tutor config save --unset DOCKER_IMAGE_OPENEDX
	TUTOR_ROOT="${TUTOR_PATH}/${ENV}" tutor images pull openedx
	TUTOR_ROOT="${TUTOR_PATH}/${ENV}" tutor config save --set DOCKER_IMAGE_OPENEDX=callysto/openedx:${ENV}

HELP: Build an edx image for $ENV
tutor/image/build: check-env
	TUTOR_ROOT="${TUTOR_PATH}/${ENV}" tutor plugins enable tutor_callysto
	TUTOR_ROOT="${TUTOR_PATH}/${ENV}" tutor config save --set DOCKER_IMAGE_OPENEDX=callysto/openedx:${ENV}
	TUTOR_ROOT="${TUTOR_PATH}/${ENV}" tutor images build openedx
	TUTOR_ROOT="${TUTOR_PATH}/${ENV}" tutor images push openedx

HELP: Render the custom Tutor theme for $ENV
tutor/theme/render: check-env
	TUTOR_ROOT="${TUTOR_PATH}/${ENV}" tutor config render --extra-config ../tutor-indigo/config.yml ../tutor-indigo/theme ${TUTOR_PATH}/${ENV}/env/build/openedx/themes/indigo
