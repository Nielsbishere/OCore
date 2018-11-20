#!/bin/bash

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
abi=all
lvl=24
dev=linux-x86_64

# Params and flags
declFlag release release
declFlag exclude_ext_formats exexfo
declFlag help helpMe
declFlag strip_debug_info strip
declFlag disable_parallel noparallel
declFlag run run
declFlag cmake cmake
declParam abi abi
declParam lvl lvl
declParam dev dev

if [ "$dev" == "windows-x86_64" ]
then
	gen=MinGW\ Makefiles
	makeCmd=mingw32-make
	android_ndk=${ANDROID_NDK}
	android_ndk="${android_ndk//\\//}"
else
	makeCmd=make
	android_ndk=${ANDROID_NDK}
fi

# Help

if [ $helpMe ]
then
	echo Android requires the following dependencies to be installed:
	echo - Java
	echo - Android SDK
	echo - Android NDK set up as environment variable ANDROID_NDK
	echo - MinGW Makefiles 64-bit
	echo - Apache Ant
	echo - Vulkan SDK
	echo
	echo "Command line args:"
	echo "-cmake Reloads or initializes the CMake data"
	echo "-run Runs the build"
	echo "-abi=all Android ABI (all if not specified)"
	echo "-lvl=24 Android API level (24 or higher)"
	echo "-dev=linux-x86_64 Dev environment (linux-x86_64 by default)"
	echo "-release Release environment (debug by default)"
	echo "-exclude_ext_formats Exclude external formats (only allow baked formats to be packaged; including pngs)"
	echo "-strip_debug_info Strips debug info (shaders)"
	echo "-disable_parallel To disable parallel compilation (for travis build)"
	exit
fi

# build abi
build(){

	echo "Making Android build ($dev $lvl $1)"
	
	mkdir -p builds
	mkdir -p builds/Android
	mkdir -p builds/Android/$1
	cd builds/Android/$1
	
	if ! [ "$gen" == "" ] ; then
		cmake "../../../" -G "$gen" -DCMAKE_TOOLCHAIN_FILE="${ANDROID_NDK}/build/cmake/android.toolchain.cmake" -DANDROID_NATIVE_API_LEVEL=android-$lvl -DCMAKE_MAKE_PROGRAM="${ANDROID_NDK}/prebuilt/$dev/bin/make" -DANDROID_ABI="$1" -DAndroid=ON -DANDROID_STL=c++_shared
	else
		cmake "../../../" -DCMAKE_TOOLCHAIN_FILE="${ANDROID_NDK}/build/cmake/android.toolchain.cmake" -DANDROID_NATIVE_API_LEVEL=android-$lvl -DCMAKE_MAKE_PROGRAM="${ANDROID_NDK}/prebuilt/$dev/bin/make" -DANDROID_ABI="$1" -DAndroid=ON -DANDROID_STL=c++_shared
	fi


	cd ../../../

}


if ! [ $noparallel ] ; then
	params="-j"
fi

if [ "$abi" == "all" ]
then

	# Make all builds

	if [ $cmake ] ; then

		build arm64-v8a
		build x86_64
		build armeabi-v7a
		build x86

	fi

	# Build all targets

	cd builds/Android/arm64-v8a
	eval "$makeCmd" $params

	cd ../x86_64
	eval "$makeCmd" $params

	cd ../armeabi-v7a
	eval "$makeCmd" $params

	cd ../x86
	eval "$makeCmd" $params

	cd ../

	# Make apk dirs

	rm -rf build
	mkdir -p build
	mkdir -p build/libs
	mkdir -p build/libs/arm64-v8a
	mkdir -p build/libs/x86_64
	mkdir -p build/libs/armeabi-v7a
	mkdir -p build/libs/x86

	# Dependencies

	if ! [ $release ]
	then
		cp -r $android_ndk/sources/third_party/vulkan/src/build-android/jniLibs/* build/libs
		rm -rf build/libs/mips
		rm -rf build/libs/mips64
	fi

	cp -r $android_ndk/sources/cxx-stl/llvm-libc++/libs/* build/libs

	# Prepare assets, src and AndroidManifest, build.xml

	cp -r arm64-v8a/bin/build/* build

else

	# Make build

	if [ $cmake ] ; then
		build $abi
	fi
	
	# Build all targets

	cd builds/Android/$abi
	eval "$makeCmd" $params
	cd ../

	# Make apk dirs

	rm -rf build
	mkdir -p build
	mkdir -p build/libs
	mkdir -p build/libs/$abi

	# Dependencies

	if ! [ $release ]
	then
		cp -r $android_ndk/sources/third_party/vulkan/src/build-android/jniLibs/$abi/* build/libs/$abi
	fi

	cp -r $android_ndk/sources/cxx-stl/llvm-libc++/libs/$abi/* build/libs/$abi

	# Prepare src and AndroidManifest, build.xml

	cp -r $abi/bin/build/* build

fi

# Prepare assets and src

mkdir -p build/src
cp -r ../../app_android/src/* build/src
cp -r ../../app_android/res/* build/res

mkdir -p build/assets
mkdir -p build/assets/res

# Run baker

if [ "$dev" == "windows-x86_64" ] ; then

	cd ../../app
	
	if [ $strip ] ; then
		"../oibaker.exe" -strip_debug_info
	else
		"../oibaker.exe"
	fi

	cd ../builds/Android

fi

# Copy results

cp -r ../../app/res/* build/assets/res

# Filter out some extensions

if [ $exexfo ]
then
	cd build/assets/res
	find . -type f -name '*.oiBM' -exec rm -f {} +	>> build_android.sh
	find . -type f -name '*.fbx' -exec rm -f {} +
	find . -type f -name '*.obj' -exec rm -f {} +
	find . -type f -name '*.glsl' -exec rm -f {} +	>> build_android.sh
	find . -type f -name '*.hlsl' -exec rm -f {} +	>> build_android.sh
	find . -type f -name '*.vert' -exec rm -f {} +	>> build_android.sh
	find . -type f -name '*.frag' -exec rm -f {} +	>> build_android.sh
	find . -type f -name '*.geom' -exec rm -f {} +	>> build_android.sh
	find . -type f -name '*.comp' -exec rm -f {} +	>> build_android.sh
	cd ../../../
fi

if [ "$abi" == "all" ]
then

	# Copy build results

	cp arm64-v8a/lib/libapp_android.so build/libs/arm64-v8a/libapp_android.so
	cp x86_64/lib/libapp_android.so build/libs/x86_64/libapp_android.so
	cp armeabi-v7a/lib/libapp_android.so build/libs/armeabi-v7a/libapp_android.so
	cp x86/lib/libapp_android.so build/libs/x86/libapp_android.so

else

	# Copy build results

	cp $abi/lib/libapp_android.so build/libs/$abi/libapp_android.so

fi

cd build

if [ $release ]
then
	ant release
	# jarsigner -verbose -keystore ~/my-release-key.keystore bin/app_android-unsigned.apk myalias
	zipalign -v -f 4 bin/app_android-unsigned.apk bin/app_android.apk
else
	ant debug
fi

# run script

if [ $run ] ; then

	cd bin
	
	if [ $release ]
	then
		adb install -r app_android.apk
	else
		adb install -r app_android-debug.apk
	fi
	
	adb shell am start -n net.osomi.Osomi_Core/android.app.NativeActivity
	adb logcat -c
	adb logcat -s "oi_Log"

fi

cd ../../../../