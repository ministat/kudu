#!/bin/bash
basedir=`dirname $0`
. $basedir/env.sh

$basedir/kudu cluster ksck $MASTERS
