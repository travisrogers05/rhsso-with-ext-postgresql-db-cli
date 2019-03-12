#!/usr/bin/env bash
set -x
echo "Running $PWD/install.sh"
injected_dir=$1
cp -rf ${injected_dir} $JBOSS_HOME/extensions

