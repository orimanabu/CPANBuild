#!/bin/sh

#PREFIX=/home/www/opt

#export PATH=$PATH:$PREFIX/bin
#export PERL5LIB=$PERL5LIB:$PREFIX/lib/perl5:$PREFIX/lib/perl5/site_perl

filesdir=../files

function print_prompt {
	local prompt=$1; shift
	if [ -z $prompt ]; then
		return
	fi
	if [ $prompt == "prompt" ]; then
		echo "> continue?"
		read line
	fi
}

function build_MakefilePL {
	local package=$1; shift
	local version=$1; shift
	local prompt=$1; shift
	echo "==> $package-$version"
	if [ ! -f $filesdir/$package-$version.tar.gz ]; then
		echo "$filesdir/$package-$version.tar.gz not found"
		exit 1
	fi

	echo "===> extracting..."
	tar zxf $filesdir/$package-$version.tar.gz
	cd $package-$version

	echo "===> perl Makefile.PL"
#	perl Makefile.PL PREFIX=$PREFIX 2>&1 | tee log.Makefile
	perl Makefile.PL 2>&1 | tee log.Makefile
	print_prompt $prompt

	echo "===> make"
	make 2>&1 | tee log.make
	print_prompt $prompt

	echo "===> make install"
	sudo make install 2>&1 | tee log.install
	print_prompt $prompt

	cd ..
}

function build_BuildPL {
	local package=$1; shift
	local version=$1; shift
	local prompt=$1; shift
	echo "==> $package-$version"
	if [ ! -f $filesdir/$package-$version.tar.gz ]; then
		echo "$filesdir/$package-$version.tar.gz not found"
		exit 1
	fi

	echo "===> extracting..."
	tar zxf $filesdir/$package-$version.tar.gz
	cd $package-$version

	echo "===> perl Build.PL"
#	perl Build.PL PREFIX=/home/www/opt 2>&1 | tee log.Makefile
	perl Build.PL 2>&1 | tee log.Makefile
	print_prompt $prompt

	echo "===> make"
	./Build 2>&1 | tee log.make
	print_prompt $prompt

	echo "===> make install"
	sudo ./Build install 2>&1 | tee log.install
	print_prompt $prompt

	cd ..
}

build_MakefilePL File-Path 2.08
build_MakefilePL File-Temp 0.22
build_MakefilePL IPC-Run3 0.044
build_MakefilePL Probe-Perl 0.01
build_MakefilePL Test-Script 1.07
build_MakefilePL File-Which 1.09
build_MakefilePL File-HomeDir 0.97
build_MakefilePL CPAN-Mini 1.111001
