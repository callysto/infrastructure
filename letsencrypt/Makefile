TOP := $(shell pwd)
DH_PATH := $(TOP)/../vendor/dehydrated

export PATH := $(DH_PATH):$(PATH)

check-env:
ifndef env
	$(error env is not defined)
endif

generate: check-env
	cd $(env) ; \
	unset OS_USERNAME ; \
	unset OS_PASSWORD ; \
	dehydrated -c --accept-terms -f 'config' -k './hook.sh'
