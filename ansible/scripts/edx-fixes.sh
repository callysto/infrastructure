#!/bin/bash

cd ~/work/callysto-infra/ansible/roles/edx/configuration/playbooks/roles

for i in $(grep -lR "celery_worker is defined"); do
  echo $i
  sed -i -e 's/celery_worker is defined/celery_worker/g' $i
done

for i in $(grep -lR "celery_worker is not defined"); do
  echo $i
  sed -i -e 's/celery_worker is not defined/not celery_worker/g' $i
done

for i in $(grep -lR "\- common$" * | grep meta); do
  echo $i
  sed -i -e 's/- common$/- common_vars/g' $i
done
