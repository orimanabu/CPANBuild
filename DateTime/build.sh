#!/bin/sh

PREFIX=/home/www/opt

export PATH=$PATH:$PREFIX/bin
export PERL5LIB=$PERL5LIB:$PREFIX/lib/perl5:$PREFIX/lib/perl5/site_perl

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
	if [ ! -f $package-$version.tar.gz ]; then
		echo "$package-$version.tar.gz not found"
		exit 1
	fi

	echo "===> extracting..."
	tar zxf $package-$version.tar.gz
	cd $package-$version

	echo "===> perl Makefile.PL"
	perl Makefile.PL PREFIX=$PREFIX 2>&1 | tee log.Makefile
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
	if [ ! -f $package-$version.tar.gz ]; then
		echo "$package-$version.tar.gz not found"
		exit 1
	fi

	echo "===> extracting..."
	tar zxf $package-$version.tar.gz
	cd $package-$version

	echo "===> perl Build.PL"
	perl Build.PL PREFIX=/home/www/opt 2>&1 | tee log.Makefile
	print_prompt $prompt

	echo "===> make"
	./Build 2>&1 | tee log.make
	print_prompt $prompt

	echo "===> make install"
	sudo ./Build install 2>&1 | tee log.install
	print_prompt $prompt

	cd ..
}

build_MakefilePL YAML-Tiny 1.41
build_MakefilePL Test-Harness 3.21

build_MakefilePL Algorithm-Diff 1.1902
build_MakefilePL Text-Diff 1.37
build_MakefilePL Compress-Raw-Zlib 2.027
build_MakefilePL Compress-Raw-Bzip2 2.027
build_MakefilePL IO-Compress 2.027
build_MakefilePL IO-Zlib 1.10
build_MakefilePL Package-Constants 0.02
build_MakefilePL Archive-Tar 1.60

build_MakefilePL Digest-SHA 5.48
build_MakefilePL ExtUtils-Install 1.54
build_MakefilePL ExtUtils-Command 1.16
build_MakefilePL ExtUtils-Manifest 1.58
build_MakefilePL ExtUtils-MakeMaker 6.56
build_MakefilePL Module-Signature 0.64

build_MakefilePL Pod-Escapes 1.04
build_MakefilePL Pod-Simple 3.14
build_MakefilePL podlators 2.3.1
build_MakefilePL Regexp-Common 2010010201
build_MakefilePL Pod-Readme 0.10

build_MakefilePL Sub-Install 0.925
build_MakefilePL Params-Util 1.01
build_MakefilePL Data-OptList 0.106
build_MakefilePL Sub-Exporter 0.982
build_MakefilePL Text-Template 1.45
build_MakefilePL Test-Simple 0.94

build_MakefilePL ExtUtils-CBuilder 0.2703
build_MakefilePL ExtUtils-ParseXS 2.2205

build_MakefilePL Module-Build 0.3607

build_BuildPL Algorithm-C3 0.08
build_MakefilePL Class-C3 0.22
build_MakefilePL MRO-Compat 0.11
build_MakefilePL Data-Section 0.100770
build_MakefilePL Software-License 0.101410

build_MakefilePL Module-Build 0.3607

build_MakefilePL Sub-Uplevel 0.22
build_MakefilePL Test-Exception 0.29

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
