#!/usr/bin/env bash
echo "Executing actions.cli"
$JBOSS_HOME/bin/jboss-cli.sh --file=$JBOSS_HOME/extensions/actions.cli
