#!/bin/bash

cd /aind

_gapps_rel="$(curl -s -L https://api.opengapps.org/list | sed -r 's/.*-x86_64-7.1-pico-([0-9]+).zip".*/\1/')"
_gapps_src="https://downloads.sourceforge.net/project/opengapps/x86_64/$_gapps_rel/open_gapps-x86_64-7.1-pico-$_gapps_rel.zip"

_gapps_list=(
    'gsfcore-all'
    'gsflogin-all'
    'gmscore-x86_64'
    'vending-x86_64'
)

HOUDINI_Y='https://github.com/redchenjs/aur-packages/raw/master/anbox-image/houdini_y.sfs'
HOUDINI_Z='https://github.com/redchenjs/aur-packages/raw/master/anbox-image/houdini_z.sfs'
SUPER_SU='http://supersuroot.org/downloads/SuperSU-v2.82-201705271822.zip'
XPOSED_TOOLS='https://github.com/youling257/XposedTools/files/1931996/xposed-x86_64.zip'
XPOSED_INSTALLER='https://forum.xda-developers.com/attachment.php?attachmentid=4393082&d=1516301692'

curl --retry 10 -L -o houdini_y.sfs "$HOUDINI_Y"
curl --retry 10 -L -o houdini_z.sfs "$HOUDINI_Z"
curl --retry 10 -L -o super_su.zip "$SUPER_SU"
curl --retry 10 -L -o xposed_tools.zip "$XPOSED_TOOLS"
curl --retry 10 -L -o XposedInstaller.apk "$XPOSED_INSTALLER"
curl --retry 10 -L -o gapps.zip "$_gapps_src"

unzip ./super_su.zip -d ./su
unzip ./xposed_tools.zip
unzip ./gapps.zip

mkdir -p ./squashfs-root/system/app/XposedInstaller
chmod 755 ./squashfs-root/system/app/XposedInstaller
# unpack anbox image
mkdir -p squashfs-root
rm -rf ./squashfs-root/*
unsquashfs -f -d ./squashfs-root android.img

# load houdini_y
mkdir -p houdini_y
rm -rf ./houdini_y/*
unsquashfs -f -d ./houdini_y ./houdini_y.sfs

mkdir -p ./squashfs-root/system/lib/arm
cp -r ./houdini_y/* ./squashfs-root/system/lib/arm
mv ./squashfs-root/system/lib/arm/libhoudini.so ./squashfs-root/system/lib/libhoudini.so

# load houdini_z
mkdir -p houdini_z
rm -rf ./houdini_z/*
unsquashfs -f -d ./houdini_z ./houdini_z.sfs

mkdir -p ./squashfs-root/system/lib64/arm64
cp -r ./houdini_z/* ./squashfs-root/system/lib64/arm64
mv ./squashfs-root/system/lib64/arm64/libhoudini.so ./squashfs-root/system/lib64/libhoudini.so

# add houdini parser
mkdir -p ./squashfs-root/system/etc/binfmt_misc
echo ':arm_exe:M::\x7f\x45\x4c\x46\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x28::/system/lib/arm/houdini:P' >> ./squashfs-root/system/etc/binfmt_misc/arm_exe
echo ':arm_dyn:M::\x7f\x45\x4c\x46\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x03\x00\x28::/system/lib/arm/houdini:P' >> ./squashfs-root/system/etc/binfmt_misc/arm_dyn
echo ':arm64_exe:M::\x7f\x45\x4c\x46\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7::/system/lib64/arm64/houdini64:P' >> ./squashfs-root/system/etc/binfmt_misc/arm64_exe
echo ':arm64_dyn:M::\x7f\x45\x4c\x46\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x03\x00\xb7::/system/lib64/arm64/houdini64:P' >> ./squashfs-root/system/etc/binfmt_misc/arm64_dyn

# add features
sed -i '/<\/permissions>/d' ./squashfs-root/system/etc/permissions/anbox.xml
sed -i '/<unavailable-feature name=\"android.hardware.wifi\" \/>/d' ./squashfs-root/system/etc/permissions/anbox.xml
sed -i '/<unavailable-feature name=\"android.hardware.bluetooth\" \/>/d' ./squashfs-root/system/etc/permissions/anbox.xml

echo '    <feature name="android.hardware.touchscreen" />
<feature name="android.hardware.audio.output" />
<feature name="android.hardware.camera" />
<feature name="android.hardware.camera.any" />
<feature name="android.hardware.location" />
<feature name="android.hardware.location.gps" />
<feature name="android.hardware.location.network" />
<feature name="android.hardware.microphone" />
<feature name="android.hardware.screen.portrait" />
<feature name="android.hardware.screen.landscape" />
<feature name="android.hardware.wifi" />
<feature name="android.hardware.bluetooth" />' >> ./squashfs-root/system/etc/permissions/anbox.xml
echo '</permissions>' >> ./squashfs-root/system/etc/permissions/anbox.xml

# set processors
sed -i '/^ro.product.cpu.abilist=x86_64,x86/ s/$/,arm64-v8a,armeabi-v7a,armeabi/' ./squashfs-root/system/build.prop
sed -i '/^ro.product.cpu.abilist32=x86/ s/$/,armeabi-v7a,armeabi/' ./squashfs-root/system/build.prop
sed -i '/^ro.product.cpu.abilist64=x86_64/ s/$/,arm64-v8a/' ./squashfs-root/system/build.prop

# enable nativebridge
echo 'persist.sys.nativebridge=1' >> ./squashfs-root/system/build.prop
sed -i 's/ro.dalvik.vm.native.bridge=0/ro.dalvik.vm.native.bridge=libhoudini.so/' ./squashfs-root/default.prop

# enable opengles
echo 'ro.opengles.version=131072' >> ./squashfs-root/system/build.prop

# install supersu
mkdir -p ./squashfs-root/system/app/SuperSU
mkdir -p ./squashfs-root/system/bin/.ext/

cp ./su/common/Superuser.apk ./squashfs-root/system/app/SuperSU/SuperSU.apk
cp ./su/common/install-recovery.sh ./squashfs-root/system/etc/install-recovery.sh
cp ./su/common/install-recovery.sh ./squashfs-root/system/bin/install-recovery.sh
cp ./su/x64/su ./squashfs-root/system/xbin/su
cp ./su/x64/su ./squashfs-root/system/bin/.ext/.su
cp ./su/x64/su ./squashfs-root/system/xbin/daemonsu
cp ./su/x64/supolicy ./squashfs-root/system/xbin/supolicy
cp ./su/x64/libsupol.so ./squashfs-root/system/lib64/libsupol.so
cp ./squashfs-root/system/bin/app_process64 ./squashfs-root/system/bin/app_process_init
cp ./squashfs-root/system/bin/app_process64 ./squashfs-root/system/bin/app_process64_original
cp ./squashfs-root/system/xbin/daemonsu ./squashfs-root/system/bin/app_process
cp ./squashfs-root/system/xbin/daemonsu ./squashfs-root/system/bin/app_process64

chmod +x ./squashfs-root/system/app/SuperSU/SuperSU.apk
chmod +x ./squashfs-root/system/etc/install-recovery.sh
chmod +x ./squashfs-root/system/bin/install-recovery.sh
chmod +x ./squashfs-root/system/xbin/su
chmod +x ./squashfs-root/system/bin/.ext/.su
chmod +x ./squashfs-root/system/xbin/daemonsu
chmod +x ./squashfs-root/system/xbin/supolicy
chmod +x ./squashfs-root/system/lib64/libsupol.so
chmod +x ./squashfs-root/system/bin/app_process_init
chmod +x ./squashfs-root/system/bin/app_process64_original
chmod +x ./squashfs-root/system/bin/app_process
chmod +x ./squashfs-root/system/bin/app_process64

# install media codecs
cp media_codec*.xml ./squashfs-root/system/etc/

# install gapps
for i in ${_gapps_list[*]}; do
    mkdir -p $i
    rm -rf ./$i/*
    tar --lzip -xvf ./Core/$i.tar.lz
    cp -r ./$i/nodpi/priv-app/* ./squashfs-root/system/priv-app/
done

# install xposed
install -Dm 644 ./xposed.prop ./squashfs-root/system/xposed.prop
install -Dm 644 ./framework/XposedBridge.jar ./squashfs-root/system/framework/XposedBridge.jar
install -Dm 755 ./bin/app_process32_xposed ./squashfs-root/system/bin/app_process32
install -Dm 755 ./bin/dex2oat ./squashfs-root/system/bin/dex2oat
install -Dm 755 ./bin/oatdump ./squashfs-root/system/bin/oatdump
install -Dm 755 ./bin/patchoat ./squashfs-root/system/bin/patchoat
install -Dm 644 ./lib/libart.so ./squashfs-root/system/lib/libart.so
install -Dm 644 ./lib/libart-compiler.so ./squashfs-root/system/lib/libart-compiler.so
install -Dm 644 ./lib/libsigchain.so ./squashfs-root/system/lib/libsigchain.so
install -Dm 644 ./lib/libxposed_art.so ./squashfs-root/system/lib/libxposed_art.so
install -Dm 755 ./bin/app_process64_xposed ./squashfs-root/system/bin/app_process64
install -Dm 644 ./lib64/libart.so ./squashfs-root/system/lib64/libart.so
install -Dm 644 ./lib64/libart-compiler.so ./squashfs-root/system/lib64/libart-compiler.so
install -Dm 644 ./lib64/libart-disassembler.so ./squashfs-root/system/lib64/libart-disassembler.so
install -Dm 644 ./lib64/libsigchain.so ./squashfs-root/system/lib64/libsigchain.so
install -Dm 644 ./lib64/libxposed_art.so ./squashfs-root/system/lib64/libxposed_art.so

install -Dm 644 ./XposedInstaller.apk ./squashfs-root/system/app/XposedInstaller/XposedInstaller.apk

# repack image
rm android.img
mksquashfs ./squashfs-root /aind/android.img -noappend -b 131072 -comp xz -Xbcj x86
