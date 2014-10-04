#!/bin/sh
##
# Copyright (C) 2014 Janek Bevendorff
# Install script for installing server and client script files
# 
# The MIT License (MIT)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
##

if [[ "$1" != "all" ]] && [[ "$1" != "client" ]] && [[ "$1" != "server" ]]; then
	./server/usr/bin/rs-version
	echo "Usage: $(basename $0) [all|server|client]"
	exit
fi

if [ $UID -ne 0 ]; then
	echo "ERROR: This script must be run as root."
	exit 1
fi

DISTRIBUTION="$(./server/usr/bin/rs-detect-distribution)"
COMPONENT="$1"
MODE="install"
if [[ "$(basename $0)" == "uninstall.sh" ]]; then
	MODE="uninstall"
fi

# Command aliases
CP="cp -vr --preserve=mode,timestamps,links,xattr"
RM="rm -Rvf"
MKDIR="mkdir -pv"

if [[ $MODE == "install" ]]; then
	if [[ $COMPONENT == "all" ]] || [[ $COMPONENT == "server" ]]; then
		echo "Installing Server component..."

		$CP ./server/usr/bin/*     /usr/bin/
		$CP ./server/usr/sbin/*    /usr/sbin/
		$CP ./server/etc/rs-skel   /etc/
		
		# Do not overwrite existing config
		if [ ! -e /etc/rs-backup/server-config ]; then
			$CP ./server/etc/rs-backup /etc/
			# Correct command paths in rsnapshot config for Synology DSM
			if [[ "$DISTRIBUTION" == "Synology" ]]; then
				sed -i "s#/usr/bin/\(cp\|rm\|rsync\)\$#/opt/bin/\1#" /etc/rs-backup/rsnapshot.global.conf
			fi
		fi

		echo
		echo "Installing cron scripts..."
		if [ -d /etc/cron.daily ]; then
			$CP ./server/etc/cron.daily/* /etc/cron.daily/
			$CP ./server/etc/cron.weekly/* /etc/cron.weekly/
			$CP ./server/etc/cron.monthly/* /etc/cron.monthly/
		elif [ -e /etc/crontab ]; then
			if ! grep -q "/usr/sbin/rs-rotate-cron" /etc/crontab; then
				if [[ "$DISTRIBUTION" == "Synology" ]]; then
					cat ./server/etc/crontab_synology >> /etc/crontab
				else
					cat ./server/etc/crontab >> /etc/crontab
				fi
			fi
		else
			echo "ERROR: Could not install cron scripts, please add rotation jobs manually." >&2
		fi

		echo "Installing backup directory..."
		BKP_DIR="$(grep -o '^BACKUP_ROOT=".*"$' /etc/rs-backup/server-config | sed 's#BACKUP_ROOT=\"\(.*\)\"$#\1#')"
		if [[ "$DISTRIBUTION" == "Synology" ]] && [[ "$BKP_DIR" == "/bkp" ]]; then
			if readlink -q /var/services/homes > /dev/null; then
				BKP_DIR="/var/services/homes"
			elif [ -d /volume1/homes ]; then
				# Try hard
				BKP_DIR="/volume1/homes"
			fi
		fi
		echo "Backup directory path will be '$BKP_DIR'."
		echo -n "Do you want to use this directory? [Y/n] "
		read answer

		if [[ "" != "$answer" ]] && [[ "Y" != "$answer" ]] && [[ "y" != "$answer" ]]; then
			echo -n "Please enter a new location: "
			read BKP_DIR
		fi

		# Correct backup folder path in server config
		sed -i "s#^BACKUP_ROOT=\".*\"\$#BACKUP_ROOT=\"$BKP_DIR\"#" /etc/rs-backup/server-config

		echo "Creating backup directory structure at '$BKP_DIR'..."

		$MKDIR "$BKP_DIR"/bin
		$MKDIR "$BKP_DIR"/dev
		$MKDIR "$BKP_DIR"/etc
		$MKDIR "$BKP_DIR"/lib
		$MKDIR "$BKP_DIR"/usr/bin
		$MKDIR "$BKP_DIR"/usr/lib
		$MKDIR "$BKP_DIR"/usr/share

		if [[ "$DISTRIBUTION" == "Synology" ]]; then
			$MKDIR "$BKP_DIR"/opt/bin
		fi

		if [[ "$DISTRIBUTION" == "Ubuntu" ]]; then
			$MKDIR "$BKP_DIR"/usr/share/perl
		else
			$MKDIR "$BKP_DIR"/usr/share/perl5
		fi

		$CP ./server/bkp/etc/* "$BKP_DIR"/etc/

		# Create symlink for chroot
		dir="$(dirname ${BKP_DIR}${BKP_DIR})"
		if [ ! -d "$dir" ]; then
			$MKDIR "$dir"
		fi
		rel_dir="."
		orig_dir="$(pwd)"
		cd "$dir"
		while [[ "$(realpath .)" != "$(realpath $BKP_DIR)" ]]; do
			if [[ "." == "$rel_dir" ]]; then
				rel_dir=".."
			else
				rel_dir="../$rel_dir"
			fi
			cd ..
		done
		ln -snf "$rel_dir" "${BKP_DIR}${BKP_DIR}"
		cd "$orig_dir"

		echo "Done."
	
	elif [[ $COMPONENT == "all" ]] || [[ $COMPONENT == "client" ]]; then
		echo "Installing client component..."

		$CP ./client/usr/bin/* /usr/bin/

		# Do not overwrite existing config
		if [ ! -e /etc/rs-backup/client-config ]; then
			$CP ./client/etc/rs-backup /etc/
		fi

		echo "Done."
	fi
elif [[ "$MODE" == "uninstall" ]]; then
	echo "This will uninstall rs-backup suite from this computer."
	echo "Selected components for removal: $COMPONENT"
	echo "NOTE: This will NOT remove your backup data, just the program!"
	echo
	echo -n "Do you want to continue? [y/N] "
	read answer

	if [[ "$answer" != "Y" ]] && [[ "$answer" != "y" ]]; then
		echo "Okay, no hard feelings. Exiting."
		exit
	fi

	if [[ $COMPONENT == "all" ]] || [[ $COMPONENT == "server" ]]; then
		echo "Uninstalling server component..."

		for i in ./server/usr/bin/*; do
			$RM /usr/bin/"$(basename $i)"
		done

		for i in ./server/usr/sbin/*; do
			$RM /usr/sbin/"$(basename $i)"
		done

		echo "Done."

	elif [[ $COMPONENT == "all" ]] || [[ $COMPONENT == "client" ]]; then
		echo "Uninstalling client component..."

		for i in ./client/usr/bin/*; do
			$RM /usr/bin/"$(basename $i)"
		done

		echo "Done."
	fi

	echo -n "Do you want to remove your config files, too? [y/N] "
	read answer
	if [[ "$answer" == "Y" ]] || [[ "$answer" == "y" ]]; then
		echo "Removing config files..."
		$RM /etc/rs-backup
		echo "Done."
	fi

	echo
	echo "INFO: Your backup folder was not removed to preserve your data."
	echo "      If you don't need it anymore, just delete it."
else
	# Program should never end here
	echo "Nothing to do." >&2
	exit 1
fi
