#!/bin/bash

readonly INSTALL_PATH="/root/.scripts"
readonly USER_NAME="$(logname)"
readonly USER_HOME=$(sudo -u $USER_NAME sh -c 'echo $HOME')

rm /etc/apt/apt.conf.d/99fix-opera
rm /usr/share/libalpm/hooks/fix-opera.hook
rm /etc/dnf/plugins/post-transaction-actions.d/fix-opera.action
sed -i '/alias fix-opera/d' $USER_HOME/.bashrc
rm -rf $INSTALL_PATH
