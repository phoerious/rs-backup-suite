##
# Copyright (C) 2013-2014 by Janek Bevendorff
# Website: http://www.refining-linux.org/
# 
# Makefile for installing the scripts to their locations in the system.
##

OS=$(shell lsb_release -si)

.PHONY: server-install client-install server-uninstall client-uninstall

all: server client

server:
	true

client:
	true

install: server-install client-install

server-install: $(wildcard server/bkp/etc/*) $(wildcard server/etc/*/*) $(wildcard server/usr/*/*)
	mkdir -p /etc/rs-skel
	mkdir -p /etc/rs-backup
	mkdir -p /bkp/{bin,dev,etc,lib,usr}
	mkdir -p /bkp/usr/{bin,lib,share}
	
ifeq ($(OS),Ubuntu)
	mkdir -p /bkp/usr/share/perl
else
	mkdir -p /bkp/usr/share/perl5
endif
	
	ln -snf /bkp /bkp/bkp
	
	@for i in $+; do \
		cp -av $$i $${i/server/}; \
		chown root:root $$i; \
	done;

client-install: $(wildcard client/etc/*/*) $(wildcard client/usr/bin/*)
	mkdir -p /etc/rs-backup

	@for i in $+; do \
		cp -av $$i $${i/client/}; \
		chown root:root $$i; \
	done;

uninstall: server-uninstall client-uninstall

server-uninstall:  $(wildcard server/etc/*/*) server/etc/rs-skel server/etc/rs-backup $(wildcard server/usr/*/*)
	rm -Rf $(addprefix /,$(subst server/,,$+))
	@echo -e "\e[1mINFO: /bkp not removed to preserve your data. Delete it manually if you don't need it anymore.\e[0m"

client-uninstall: client/etc/rs-backup client/usr/bin/*
	rm -Rf $(addprefix /,$(subst client/,,$+))
