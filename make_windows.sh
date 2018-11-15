#!/bin/bash

# simple pause
pause() {
	read -p "Press enter to continue..."
	exit
}

# declFlag flagName flagVar
declFlag() {

	for var in ${BASH_ARGV[*]}
	do
		if [ "$var" == "-$1" ]
		then
			eval $2=true
			return
		fi
	done

}

# declParam paramName paramVar
declParam() {

	for var in ${BASH_ARGV[*]}
	do
		if [[ "$var" = "-$1="* ]]
		then
			eval $2="${var/-$1=/}"
			return
		fi
	done

}

# Default params

env=all

declFlag release release
declFlag exclude_ext_formats exexfo
declFlag help helpMe
declFlag no_console noConsole
declFlag strip_debug_info strip
declParam env env

if [ $helpMe ]
then
	echo Windows requires the following dependencies to be installed:
	echo - Visual Studio
	echo - Vulkan SDK
	echo
	echo "Command line args:"
	echo "-env=all Platform (x86, x64)"
	echo "-release Release environment (debug by default)"
	echo "-exclude_ext_formats Exclude external formats (only allow baked formats to be packaged; including pngs)"
	echo "-no_console Hides console (program can still redirect console calls)"
	echo "-strip_debug_info Strips debug info (shaders)"
	pause
fi

# reload "dir" "generator"
reload(){
	
	mkdir -p "$1"
	cd "$1"

	if [ $noConsole ] ; then
		cmake ../../../ -G "$2" -Dno_console=ON
	else
		cmake ../../../ -G "$2"
	fi

	cd ../

}

mkdir -p builds/Windows
cd builds/Windows

if [ "$env" == "all" ] || [ "$env" == "x64" ] ; then
	reload "x86_64" "Visual Studio 15 2017 Win64"
fi

if [ "$env" == "all" ] || [ "$env" == "x86" ] ; then
	reload "x86" "Visual Studio 15 2017"
fi

# Multi core compiling & minimal verbosity

if [ $release ] ; then
	btype="Release"
else
	btype="Debug"
fi

# Build

if [ "$env" == "all" ] || [ "$env" == "x64" ] ; then
	cmd.exe /c "MSBuild.exe \"x86_64/oic.sln\" /m /v:m /p:Configuration=$btype /p:Platform=\"x64\""
fi

if [ "$env" == "all" ] || [ "$env" == "x86" ] ; then
	cmd.exe /c "MSBuild.exe \"x86/oic.sln\" /m /v:m /p:Configuration=$btype /p:Platform=\"Win32\""
fi

rm -rf build/*
mkdir -p build

# Copy results

if [ "$env" == "all" ] || [ "$env" == "x64" ] ; then
	cp "x86_64/bin/$btype/Osomi Core.exe" "build/Osomi Core.exe"
fi

if [ "$env" == "all" ] || [ "$env" == "x86" ] ; then
	cp "x86/bin/$btype/Osomi Core.exe" "build/Osomi Core x86.exe"
fi

# Prepare resources

mkdir -p build/res
cp -r ../../app/res/* build/res

cd build

if [ $strip ] ; then
	"../../../oibaker.exe" -strip_debug_info
else
	"../../../oibaker.exe"
fi

cd res

# Get rid of fbx, obj, oiBM and glsl/hlsl/vert/frag/geom/comp files

if [ $exexfo ]
then

	find . -type f -name '*.oiBM' -exec rm -f {} +
	find . -type f -name '*.fbx' -exec rm -f {} +
	find . -type f -name '*.obj' -exec rm -f {} +
	find . -type f -name '*.glsl' -exec rm -f {} +
	find . -type f -name '*.hlsl' -exec rm -f {} +
	find . -type f -name '*.vert' -exec rm -f {} +
	find . -type f -name '*.frag' -exec rm -f {} +
	find . -type f -name '*.geom' -exec rm -f {} +
	find . -type f -name '*.comp' -exec rm -f {} +

fi

cd ../../../../