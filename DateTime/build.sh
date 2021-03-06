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

build_MakefilePL Attribute-Handlers 0.88
build_BuildPL Params-Validate 0.95

build_MakefilePL Class-Singleton 1.4
build_MakefilePL DateTime-TimeZone 1.19

build_MakefilePL List-MoreUtils 0.22
build_MakefilePL DateTime-Locale 0.45

build_BuildPL DateTime 0.55

build_MakefilePL Number-Compare 0.01
build_MakefilePL Text-Glob 0.08
build_MakefilePL File-Find-Rule 0.32

build_MakefilePL Test-Pod 1.44
build_MakefilePL Devel-Symdump 2.08
build_MakefilePL Pod-Coverage 0.20
build_MakefilePL Test-Pod-Coverage 1.08

build_MakefilePL Module-CoreList 2.34
build_BuildPL Test-Distribution 2.00

build_MakefilePL Task-Weaken 1.03
build_MakefilePL Class-Factory-Util 1.7
build_MakefilePL DateTime-Format-Strptime 1.2000
build_MakefilePL DateTime-Format-Builder 0.80
build_MakefilePL DateTime-Format-ISO8601 0.07

build_MakefilePL DateTime-Format-HTTP 0.40
