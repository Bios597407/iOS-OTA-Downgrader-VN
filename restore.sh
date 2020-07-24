#!/bin/bash
trap 'Clean; exit' INT TERM EXIT

function Clean {
    rm -rf iP*/ tmp/ $(ls *_${ProductType}_${OSVer}-*.shsh2 2>/dev/null) $(ls *_${ProductType}_${OSVer}-*.shsh 2>/dev/null) $(ls *.im4p 2>/dev/null) $(ls *.bbfw 2>/dev/null) BuildManifest.plist
}

function Error {
    echo "[Lỗi] $1"
    [[ ! -z $2 ]] && echo "* $2"
    exit
}

function Log {
    echo "[Log] $1"
}

function Main {
    clear
    echo "******* iOS-OTA-Downgrader *******"
    echo "   Mã hạ cấp bởi LukeZGD   	      "
    echo "   Việt hóa bởi NDang Mods        "
    echo
    if [[ $OSTYPE == "linux-gnu" ]]; then
        platform='linux'
    elif [[ $OSTYPE == "darwin"* ]]; then
        platform='macos'
    else
        error "Hệ điều hành không hỗ trợ" "Chỉ hỗ trợ cho Linux và MacOS"
    fi
    cd resources/tools
    ln -sf futurerestore249_macos futurerestore152_macos
    cd ../..
    
    [[ ! $(ping -c1 google.com 2>/dev/null) ]] && Error "Xin vui lòng kiểm tra kết nối Internet trước khi tiếp tục"
    [[ $(uname -m) != 'x86_64' ]] && Error "Chỉ hỗ trợ hệ điều hành x86_64. Sử dụng hệ điều hành 64-bit và thử lại"
    Clean
    mkdir tmp

    DFUDevice=$(lsusb | grep -c '1227')
    RecoveryDevice=$(lsusb | grep -c '1281')
    if [[ $1 == InstallDependencies ]] || [ ! $(which bspatch) ] || [ ! $(which ideviceinfo) ] ||
       [ ! $(which lsusb) ] || [ ! $(which ssh) ] || [ ! $(which python3) ]; then
        InstallDependencies
    elif [ $DFUDevice == 1 ] || [ $RecoveryDevice == 1 ]; then
        GetProductType
        UniqueChipID=$(sudo LD_LIBRARY_PATH=/usr/local/lib irecovery -q | grep 'ECID' | cut -c 7-)
        ProductVer='Unknown'
    else
        HWModel=$(ideviceinfo -s | grep 'HardwareModel' | cut -c 16- | tr '[:upper:]' '[:lower:]' | sed 's/.\{2\}$//')
        ProductType=$(ideviceinfo -s | grep 'ProductType' | cut -c 14-)
        [ ! $ProductType ] && ProductType=$(ideviceinfo | grep 'ProductType' | cut -c 14-)
        [ ! $ProductType ] && ProductType='NA'
        ProductVer=$(ideviceinfo -s | grep 'ProductVer' | cut -c 17-)
        VersionDetect=$(echo $ProductVer | cut -c 1)
        UniqueChipID=$(ideviceinfo -s | grep 'UniqueChipID' | cut -c 15-)
        UniqueDeviceID=$(ideviceinfo -s | grep 'UniqueDeviceID' | cut -c 17-)
    fi
    BasebandDetect
    
    chmod +x resources/tools/*
    SaveExternal firmware
    SaveExternal ipwndfu
    
    if [ $DFUDevice == 1 ]; then
        Log "Đã thấy thiết bị trong chế độ DFU"
        if [[ $A7Device != 1 ]]; then
            read -p "[Nhập] Có phải thiết bị của bạn đang ở trong chế độ kDFU không? (y/N) " DFUManual
            if [[ $DFUManual == y ]] || [[ $DFUManual == Y ]]; then
                Log "Đang hạ cấp thiết bị $ProductType trong chế độ kDFU..."
                Mode='Downgrade'
                SelectVersion
            else
                Error "Vui lòng để thiết bị của bạn ở chế độ bình thường (và đã jailbreak cho 32-bit) trước khi tiếp tục" "Chế độ Recovery hoặc DFU cũng được áp dụng cho thiết bị A7"
            fi
        fi
    elif [ $RecoveryDevice == 1 ] && [[ $A7Device != 1 ]]; then
        Error "Không phải thiết bị A7 được phát hiện trong chế độ Recovery. Vui lòng để thiết bị ở chế độ bình thường và đã jailbreak trước khi tiếp tục"
    elif [ $ProductType == 'NA' ]; then
        Error "Vui lòng để thiết bị của bạn ở chế độ bình thường (và đã jailbreak cho 32-bit) trước khi tiếp tục" "Chế độ Recovery hoặc DFU cũng được áp dụng cho thiết bị A7"
    fi
    
    echo "* HardwareModel: ${HWModel}ap"
    echo "* ProductType: $ProductType"
    echo "* ProductVersion: $ProductVer"
    echo "* UniqueChipID (ECID): $UniqueChipID"
    echo
    if [[ $1 ]]; then
        Mode="$1"
    else
        Selection=("Hạ cấp thiết bị")
        [[ $A7Device != 1 ]] && Selection+=("Lưu OTA Blobs" "Chỉ để thiết bị của bạn ở trong chế độ kDFU")
        Selection+=("Cài đặt lại các gói cần thiết" "(Các phím còn lại để thoát)")
        echo "*** Mục lục chính ***"
        echo "[Nhập] Chọn một cài đặt:"
        select opt in "${Selection[@]}"; do
            case $opt in
                "Hạ cấp thiết bị" ) Mode='Downgrade'; break;;
                "Lưu OTA Blobs" ) Mode='SaveOTABlobs'; break;;
                "Chỉ để thiết bị trong chế độ kDFU" ) Mode='kDFU'; break;;
                "Cài đặt lại các gói cần thiết" ) InstallDependencies; exit;;
                * ) exit;;
            esac
        done
    fi
    SelectVersion
}

function SelectVersion {
    if [[ $ProductType == iPad4* ]] || [[ $ProductType == iPhone6* ]]; then
        OSVer='10.3.3'
        BuildVer='14G60'
        Action
    fi
    Selection=("iOS 8.4.1")
    if [ $ProductType == iPad2,1 ] || [ $ProductType == iPad2,2 ] ||
       [ $ProductType == iPad2,3 ] || [ $ProductType == iPhone4,1 ]; then
        Selection+=("iOS 6.1.3")
    fi
    [[ $Mode == 'Downgrade' ]] && Selection+=("Other")
    echo "[Nhập] Chọn phiên bản iOS bạn muốn hạ cấp:"
    select opt in "${Selection[@]}"; do
        case $opt in
            "iOS 8.4.1" ) OSVer='8.4.1'; BuildVer='12H321'; break;;
            "iOS 6.1.3" ) OSVer='6.1.3'; BuildVer='10B329'; break;;
            "Other" ) OSVer='Other'; break;;
            *) exit;;
        esac
    done
    Action
}

function Action {    
    Log "Cài đặt: $Mode"
    if [[ $OSVer == 'Other' ]]; then
        echo "* Di chuyển/sao chép iPSW và SHSH và thư mục where nơi mà chứa file đang chạy"
        read -p "[Nhập] Địa chỉ tới iPSW (kéo thả iPSW tới cửa sổ terminal): " IPSW
        IPSW="$(basename $IPSW .ipsw)"
        read -p "[Nhập] Địa chỉ tới SHSH (kéo thả SHSH tới cửa sổ terminal): " SHSH
    elif [[ $A7Device == 1 ]] && [[ $pwnDFUDevice != 1 ]]; then
        if [[ $DFUDevice == 1 ]]; then
            CheckM8
        else
            Recovery
        fi
    fi
    
    if [ $ProductType == iPod5,1 ]; then
        iBSS="iBSS.${HWModel}ap.RELEASE"
        iBSSBuildVer='10B329'
    elif [ $ProductType == iPad3,1 ]; then
        iBSS="iBSS.${HWModel}ap.RELEASE"
        iBSSBuildVer='11D257'
    elif [ $ProductType == iPhone6,1 ] || [ $ProductType == iPhone6,2 ]; then
        iBSS="iBSS.iphone6.RELEASE"
        iBEC="iBEC.iphone6.RELEASE"
    elif [ $ProductType == iPad4,1 ] || [ $ProductType == iPad4,2 ] || [ $ProductType == iPad4,3 ]; then
        iBSS="iBSS.ipad4.RELEASE"
        iBEC="iBEC.ipad4.RELEASE"
    elif [ $ProductType == iPad4,4 ] || [ $ProductType == iPad4,5 ]; then
        iBSS="iBSS.ipad4b.RELEASE"
        iBEC="iBEC.ipad4b.RELEASE"
    else
        iBSS="iBSS.$HWModel.RELEASE"
        iBSSBuildVer='12H321'
    fi
    IV=$(cat $Firmware/$iBSSBuildVer/iv 2>/dev/null)
    Key=$(cat $Firmware/$iBSSBuildVer/key 2>/dev/null)
    
    if [[ $Mode == 'Downgrade' ]]; then
        Downgrade
    elif [[ $Mode == 'SaveOTABlobs' ]]; then
        SaveOTABlobs
    elif [[ $Mode == 'kDFU' ]]; then
        kDFU
    fi
    exit
}

function SaveOTABlobs {
    Log "Đang lưu $OSVer blobs với tsschecker..."
    BuildManifest="resources/manifests/BuildManifest_${ProductType}_${OSVer}.plist"
    if [ $A7Device == 1 ]; then
        APNonce=$(sudo LD_LIBRARY_PATH=/usr/local/lib irecovery -q | grep 'NONC' | cut -c 7-)
        echo "* APNonce: $APNonce"
    fi
    if [ $A7Device == 1 ]; then
        LD_LIBRARY_PATH=/usr/local/lib resources/tools/tsschecker_$platform -d $ProductType -B ${HWModel}ap -i $OSVer -e $UniqueChipID -m $BuildManifest --apnonce $APNonce -o -s
    else
        LD_LIBRARY_PATH=/usr/local/lib resources/tools/tsschecker_$platform -d $ProductType -i $OSVer -e $UniqueChipID -m $BuildManifest -o -s
        SHSH=$(ls *_${ProductType}_${OSVer}-*.shsh2)
    fi
    [ ! $SHSH ] && SHSH=$(ls *_${ProductType}_${HWModel}ap_${OSVer}-*.shsh)
    [ ! $SHSH ] && Error "Lưu $OSVer blobs thất bại. Vui lòng chạy lại tệp" "Cũng có thể $OSVer cho $ProductType không còn được mở"
    mkdir -p saved/shsh 2>/dev/null
    cp "$SHSH" saved/shsh
    Log "Lưu thành công $OSVer blobs"
}

function kDFU {
    if [ ! -e saved/$ProductType/$iBSS.dfu ]; then
        Log "Đang tải iBSS..."
        resources/tools/pzb_$platform -g Firmware/dfu/${iBSS}.dfu -o $iBSS.dfu $(cat $Firmware/$iBSSBuildVer/url)
        mkdir -p saved/$ProductType 2>/dev/null
        mv $iBSS.dfu saved/$ProductType
    fi
    Log "Đang giải nén iBSS..."
    Log "IV = $IV"
    Log "Key = $Key"
    resources/tools/xpwntool_$platform saved/$ProductType/$iBSS.dfu tmp/iBSS.dec -k $Key -iv $IV
    Log "Đang nén iBSS..."
    bspatch tmp/iBSS.dec tmp/pwnediBSS resources/patches/$iBSS.patch
    
    # Regular kloader only works on iOS 6 to 9, so other versions are provided for iOS 5 and 10
    if [[ $VersionDetect == 1 ]]; then
        kloader='kloader_hgsp'
    elif [[ $VersionDetect == 5 ]]; then
        kloader='kloader5'
    else
        kloader='kloader'
    fi

    if [[ $VersionDetect == 1 ]]; then
        # ifuse+MTerminal is used instead of SSH for devices on iOS 10
        [ ! $(which ifuse) ] && Error "Một trong các gói cần thiết (ifuse) không thể tìm thấy. Xin vui lòng cài đặt lại các gói cần thiết" "Cho hệ thống MacOS, cài đặt osxfuse và ifuse với brew"
        WifiAddr=$(ideviceinfo -s | grep 'WiFiAddress' | cut -c 14-)
        WifiAddrDecr=$(echo $(printf "%x\n" $(expr $(printf "%d\n" 0x$(echo "${WifiAddr}" | tr -d ':')) - 1)) | sed 's/\(..\)/\1:/g;s/:$//')
        echo '#!/bin/bash' > tmp/pwn.sh
        echo "nvram wifiaddr=$WifiAddrDecr
        chmod 755 kloader_hgsp
        ./kloader_hgsp pwnediBSS" >> tmp/pwn.sh
        Log "Đang giải nén thiết bị với ifuse..."
        mkdir mount
        ifuse mount
        Log "Đang sao chép các tệp tới thiết bị..."
        cp "tmp/pwn.sh" "resources/tools/$kloader" "tmp/pwnediBSS" "mount/"
        Log "Ngừng giải nén thiết bị... (Nhập mật khẩu của PC/Mac khi cần yêu cầu)"
        sudo umount mount
        echo
        echo "* Mở MTerminal và chạy lệnh dưới đây:"
        echo
        echo '$ su'
        echo "(Nhập mật khẩu gốc của thiết bị iOS của bạn, mặc định là 'alpine')"
        echo "# cd Media"
        echo "# chmod +x pwn.sh"
        echo "# ./pwn.sh"
    else
        # SSH kloader and pwnediBSS
        echo "* Hãy chắc chắn SSH đã cài đặt và đang hoạt động trên thiết bị của bạn!"
        echo "* Xin vui lòng nhập địa chỉ IP Wi-Fi của thiết bị cho kết nối SSH"
        read -p "[Nhập] Địa chỉ IP: " IPAddress
        Log "Đang kết nối tới thiết bị thông qua SSH... (Nhập mật khẩu gốc của thiết bị iOS của bạn, mặc định là 'alpine')"
        Log "Đang sao chép tệp tới thiết bị..."
        scp resources/tools/$kloader tmp/pwnediBSS root@$IPAddress:/
        [ $? == 1 ] && Error "Không thể kết nối với thiết bị thông qua SSH" "Xin vui lòng kiểm tra tệp ~ / .ssh / know_hosts của bạn và thử lại"
        Log "Entering kDFU mode..."
        ssh root@$IPAddress "chmod 755 /$kloader && /$kloader /pwnediBSS" &
    fi
    echo
    echo "* Nhấn nút home / power một lần khi màn hình tối đen trên thiết bị"
    
    Log "Đang tìm thiết bị trong chế độ DFU..."
    while [[ $DFUDevice != 1 ]]; do
        DFUDevice=$(lsusb | grep -c '1227')
        sleep 2
    done
    Log "Đã tìm thấy thiết bị trong chế độ DFU"
}

function Recovery {
    RecoveryDevice=$(lsusb | grep -c '1281')
    if [[ $RecoveryDevice != 1 ]]; then
        Log "Đang truy cập vào chế độ Recovery..."
        ideviceenterrecovery $UniqueDeviceID >/dev/null
        while [[ $RecoveryDevice != 1 ]]; do
            RecoveryDevice=$(lsusb | grep -c '1281')
            sleep 2
        done
    fi
    Log "Đã phát hiện thiết bị chip A7 trong chế độ Recovery. Hãy sẵn sàng để vào chế độ DFU"
    read -p "[Nhập] Chọn Y để tiếp tục, N để thoát chế độ Recovery (Y/n) " RecoveryDFU
    if [[ $RecoveryDFU == n ]] || [[ $RecoveryDFU == N ]]; then
        Log "Đang thoát chế độ Recovery"
        sudo LD_LIBRARY_PATH=/usr/local/lib irecovery -n
        exit
    fi
    echo "* Giữ nút POWER và HOME trong 10 giây."
    for i in {10..01}; do
        echo -n "$i "
        sleep 1
    done
    echo -e "\n* Nhả POWER và giữ nút HOME trong 10 giây"
    for i in {10..01}; do
        echo -n "$i "
        DFUDevice=$(lsusb | grep -c '1227')
        sleep 1
        if [[ $DFUDevice == 1 ]]; then
            echo -e "\n[Log] Đã tiềm thấy thiết bị trong chế độ DFU"
            CheckM8
        fi
    done
    echo -e "\n[Lỗi] Tìm thiết bị trong chế độ DFU thất bại. Xin vui lòng chạy lại tệp lần nữa"
    exit
}

function CheckM8 {
    DFUManual=0
    Log "Đang vào chế độ pwnDFU với ipwndfu..."
    cd resources/ipwndfu
    sudo python2 ipwndfu -p
    pwnDFUDevice=$(sudo lsusb -v -d 05ac:1227 2>/dev/null | grep -c 'checkm8')
    if [ $pwnDFUDevice == 1 ]; then
        Log "Đã phát hiện thiết bị của bạn trong chế độ pwnDFU. Đang chạy rmsigchks.py..."
        sudo python2 rmsigchks.py
        cd ../..
        Log "Đang hạ cấp thiết bị $ProductType trong chế độ pwnDFU..."
        Mode='Downgrade'
        SelectVersion
    else
        Error "Vào chế độ pwnDFU thất bại. Xin vui lòng chạy lại tệp này lần nữa"
    fi    
}

function Downgrade {    
    if [[ $OSVer != 'Other' ]]; then
        if [[ $ProductType == iPad4* ]]; then
            IPSW="iPad_64bit"
        elif [[ $ProductType == iPhone6* ]]; then
            IPSW="iPhone_64bit"
        else
            IPSW="${ProductType}"
            SaveOTABlobs
        fi
        IPSW="${IPSW}_${OSVer}_${BuildVer}_Restore"
        IPSWCustom="${ProductType}_${OSVer}_${BuildVer}_Custom"
        if [ ! -e $IPSW.ipsw ]; then
            Log "iOS $OSVer iPSW không thể tìm thấy. Đang tải iPSW..."
            curl -L $(cat $Firmware/$BuildVer/url) -o tmp/$IPSW.ipsw
            mv tmp/$IPSW.ipsw .
        fi
        if [ ! -e $IPSWCustom.ipsw ]; then
            Log "Đang xác minh iPSW..."
            IPSWSHA1=$(cat $Firmware/$BuildVer/sha1sum)
            IPSWSHA1L=$(sha1sum $IPSW.ipsw | awk '{print $1}')
            [[ $IPSWSHA1L != $IPSWSHA1 ]] && Error "Xác minh iPSW thất bại. Xóa/thay thế iPSW và chạy lại tệp này lần nữa"
        else
            IPSW=$IPSWCustom
        fi
        if [ ! $DFUManual ]; then
            Log "Đang giải nén iBSS từ iPSW..."
            mkdir -p saved/$ProductType 2>/dev/null
            unzip -o -j $IPSW.ipsw Firmware/dfu/$iBSS.dfu -d saved/$ProductType
        fi
    fi
    
    [ ! $DFUManual ] && kDFU
    
    Log "Đang giải nén iPSW..."
    unzip -q $IPSW.ipsw -d $IPSW/
    
    if [ $A7Device == 1 ]; then
        if [ ! -e $IPSWCustom.ipsw ]; then
            Log "Chuản bị iPSW tùy chỉnh..."
            cp $IPSW/Firmware/all_flash/$SEP .
            bspatch $IPSW/Firmware/dfu/$iBSS.im4p $iBSS.im4p resources/patches/$iBSS.patch
            bspatch $IPSW/Firmware/dfu/$iBEC.im4p $iBEC.im4p resources/patches/$iBEC.patch
            cp -f $iBSS.im4p $iBEC.im4p $IPSW/Firmware/dfu
            cd $IPSW
            zip ../$IPSWCustom.ipsw -r0 *
            cd ..
            mv $IPSW $IPSWCustom
            IPSW=$IPSWCustom
        else
            cp $IPSW/Firmware/dfu/$iBSS.im4p .
            cp $IPSW/Firmware/dfu/$iBEC.im4p .
            cp $IPSW/Firmware/all_flash/$SEP .
        fi
        Log "Đang vào chế độ PWNREC..."
        sudo LD_LIBRARY_PATH=/usr/local/lib irecovery -f $iBSS.im4p
        sudo LD_LIBRARY_PATH=/usr/local/lib irecovery -f $iBEC.im4p
        sleep 5
        RecoveryDevice=$(lsusb | grep -c '1281')
        if [[ $RecoveryDevice != 1 ]]; then
            echo -e "\n[Lỗi] Không thể gửi iBSS/iBEC. Vui lòng thử lại"
            exit
        fi
        SaveOTABlobs
    fi
    
    Log "Chuẩn bị cho... (Nhập mật khẩu của PC/Mac khi cần yêu cầu)"
    cd resources
    sudo bash -c "python3 -m http.server 80 &"
    cd ..
    
    if [ $Baseband == 0 ]; then
        Log "Thiết bị $ProductType không có baseband"
        Log "Tiếp tục tới futurerestore..."
        if [ $A7Device == 1 ]; then
            sudo LD_LIBRARY_PATH=/usr/local/lib resources/tools/futurerestore249_$platform -t $SHSH -s $SEP -m $BuildManifest --no-baseband $IPSW.ipsw
        else
            sudo LD_PRELOAD=libcurl.so.3 resources/tools/futurerestore152_$platform -t $SHSH --no-baseband --use-pwndfu $IPSW.ipsw
        fi
    else
        if [ $A7Device == 1 ]; then
            cp $IPSW/Firmware/$Baseband .
        elif [ ! saved/$ProductType/*.bbfw ]; then
            Log "Đang tải xuống baseband..."
            resources/tools/pzb_$platform -g Firmware/$Baseband -o $Baseband $BasebandURL
            resources/tools/pzb_$platform -g BuildManifest.plist -o BuildManifest.plist $BasebandURL
            mkdir -p saved/$ProductType 2>/dev/null
            cp $Baseband BuildManifest.plist saved/$ProductType
        else
            cp saved/$ProductType/*.bbfw saved/$ProductType/BuildManifest.plist .
        fi
        BasebandSHA1L=$(sha1sum $Baseband | awk '{print $1}')
        if [ ! *.bbfw ] || [[ $BasebandSHA1L != $BasebandSHA1 ]]; then
            rm -f saved/$ProductType/*.bbfw saved/$ProductType/BuildManifest.plist
            echo "[Lỗi] Tải/xác minh baseband thất bại"
            echo "* Thiết bị của bạn vẫn ở chế độ kDFU và bạn có thể chạy lại tệp này"
            echo "* Bạn cũng có thể tiếp tục và Futurerestore có thể cố gắng tải lại baseband"
            echo "* Tiếp tục tới Futurerestore sau 10 giây (Nhấn Ctrl + C để hủy)"
            sleep 10
            Log "Tiếp tục tới futurerestore..."
            if [ $A7Device == 1 ]; then
                sudo LD_LIBRARY_PATH=/usr/local/lib resources/tools/futurerestore249_$platform -t $SHSH -s $SEP -m $BuildManifest --latest-baseband $IPSW.ipsw
            else
                sudo LD_PRELOAD=libcurl.so.3 resources/tools/futurerestore152_$platform -t $SHSH --latest-baseband --use-pwndfu $IPSW.ipsw
            fi
        elif [ $A7Device == 1 ]; then
            Log "Tiếp tục tới futurerestore..."
            sudo LD_LIBRARY_PATH=/usr/local/lib resources/tools/futurerestore249_$platform -t $SHSH -s $SEP -m $BuildManifest -b $Baseband -p $BuildManifest $IPSW.ipsw
        else
            Log "Tiếp tục tới futurerestore..."
            sudo LD_PRELOAD=libcurl.so.3 resources/tools/futurerestore152_$platform -t $SHSH -b $Baseband -p BuildManifest.plist --use-pwndfu $IPSW.ipsw
        fi
    fi
        
    echo
    Log "Đã hạ cấp thành công!"    
    Log "Dừng máy chủ cục bộ ... (Nhập mật khẩu gốc của PC/Mac khi cần thiết)"
    ps aux | awk '/python3/ {print "sudo kill -9 "$2" 2>/dev/null"}' | bash
    Log "Mã hạ cấp đã xong!"
}

function InstallDependencies {
    echo "Cài đặt các gói cần thiết"
    . /etc/os-release 2>/dev/null
    cd tmp
    
    Log "Đang cài đặt các gói cần thiết..."
    if [[ $(which pacman) ]]; then
        # Arch Linux
        sudo pacman -Sy --noconfirm --needed bsdiff curl libcurl-compat libpng12 libimobiledevice libzip openssh openssl-1.0 python2 python unzip usbmuxd usbutils
        Compile libimobiledevice ifuse
        sudo ln -sf /usr/lib/libzip.so.5 /usr/lib/libzip.so.4
        
    elif [[ $VERSION_ID == "20.04" ]]; then
        # Ubuntu Focal
        sudo apt update
        sudo apt -y install autoconf automake binutils bsdiff build-essential checkinstall curl git ifuse libimobiledevice-utils libplist3 libreadline-dev libtool-bin libusb-1.0-0-dev libusbmuxd6 libzip5 python2 usbmuxd
        curl -L http://archive.ubuntu.com/ubuntu/pool/universe/c/curl3/libcurl3_7.58.0-2ubuntu2_amd64.deb -o libcurl3.deb
        ar x libcurl3.deb data.tar.xz
        tar xf data.tar.xz
        sudo cp usr/lib/x86_64-linux-gnu/libcurl.so.4.* /usr/lib/libcurl.so.3
        curl -L http://ppa.launchpad.net/linuxuprising/libpng12/ubuntu/pool/main/libp/libpng/libpng12-0_1.2.54-1ubuntu1.1+1~ppa0~focal_amd64.deb -o libpng12.deb
        curl -L http://archive.ubuntu.com/ubuntu/pool/main/o/openssl1.0/libssl1.0.0_1.0.2n-1ubuntu5.3_amd64.deb -o libssl1.0.0.deb
        curl -L http://archive.ubuntu.com/ubuntu/pool/universe/libz/libzip/libzip4_1.1.2-1.1_amd64.deb -o libzip4.deb
        sudo dpkg -i libpng12.deb libssl1.0.0.deb libzip4.deb
        sudo ln -sf /usr/lib/x86_64-linux-gnu/libimobiledevice.so.6 /usr/local/lib/libimobiledevice-1.0.so.6
        sudo ln -sf /usr/lib/x86_64-linux-gnu/libplist.so.3 /usr/local/lib/libplist-2.0.so.3
        sudo ln -sf /usr/lib/x86_64-linux-gnu/libusbmuxd.so.6 /usr/local/lib/libusbmuxd-2.0.so.6
        
    elif [[ $(which dnf) ]]; then
        sudo dnf install -y automake bsdiff ifuse libimobiledevice-utils libpng12 libtool libusb-devel libzip make python2 readline-devel
        curl -L http://ftp.pbone.net/mirror/ftp.scientificlinux.org/linux/scientific/6.1/x86_64/os/Packages/openssl-1.0.0-10.el6.x86_64.rpm -o openssl-1.0.0.rpm
        rpm2cpio openssl-1.0.0.rpm | cpio -idmv
        sudo cp usr/lib64/libcrypto.so.1.0.0 usr/lib64/libssl.so.1.0.0 /usr/lib64
        sudo ln -sf /usr/lib64/libimobiledevice.so.6 /usr/local/lib/libimobiledevice-1.0.so.6
        sudo ln -sf /usr/lib64/libplist.so.3 /usr/local/lib/libplist-2.0.so.3
        sudo ln -sf /usr/lib64/libusbmuxd.so.6 /usr/local/lib/libusbmuxd-2.0.so.6
        sudo ln -sf /usr/lib64/libzip.so.5 /usr/lib64/libzip.so.4
        
    elif [[ $OSTYPE == "darwin"* ]]; then
        # macOS
        if [[ ! $(which brew) ]]; then
            Log "Homebrew không thể tìm thấy/chưa cài đặt, đang cài đặt Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
        fi
        brew uninstall --ignore-dependencies usbmuxd
        brew uninstall --ignore-dependencies libimobiledevice
        brew install --HEAD usbmuxd
        brew install --HEAD libimobiledevice
        brew install libzip lsusb python3
        brew install make automake autoconf libtool pkg-config gcc
        brew cask install osxfuse
        brew install ifuse
        
    else
        Error "Hệ điều hành không hỗ trợ/không biết bởi mã lệnh này"
    fi
    
    Compile libimobiledevice libirecovery
    [[ $platform == linux ]] && sudo cp ../resources/lib/* /usr/local/lib
    
    Log "Cài đặt mã lệnh thành công! Xin vui lòng chạy lại chương trình"
    exit
}

function Compile {
    git clone https://github.com/$1/$2.git
    cd $2
    ./autogen.sh
    sudo make install
    cd ..
    sudo rm -rf $2
}

function SaveExternal {
    if [[ ! $(ls resources/$1 2>/dev/null) ]]; then
        if [[ $1 == 'ipwndfu' ]]; then
            ExternalURL="https://github.com/LukeZGD/ipwndfu/archive/master.zip"
            ExternalFile="ipwndfu-master"
        else
            ExternalURL="https://github.com/LukeZGD/iOS-OTA-Downgrader/archive/$1.zip"
            ExternalFile="iOS-OTA-Downgrader-$1"
        fi
        Log "Đang tải xuống $1..."
        curl -Ls $ExternalURL -o tmp/$ExternalFile.zip
        unzip -q tmp/$ExternalFile.zip -d tmp
        mkdir resources/$1
        mv tmp/$ExternalFile/* resources/$1
    fi
}

function GetProductType {
    ProductType=$(sudo LD_LIBRARY_PATH=/usr/local/lib resources/tools/igetnonce_$platform)
    [ ! $ProductType ] && read -p "[Nhập] Nhập loại thiết bị (eg. iPad2,1): " ProductType
}

function BasebandDetect {
    Firmware=resources/firmware/$ProductType
    BasebandURL=$(cat $Firmware/13G37/url 2>/dev/null) # iOS 9.3.6
    if [ $ProductType == iPad2,2 ]; then
        BasebandURL=$(cat $Firmware/13G36/url) # iOS 9.3.5
        Baseband=ICE3_04.12.09_BOOT_02.13.Release.bbfw
        BasebandSHA1=e6f54acc5d5652d39a0ef9af5589681df39e0aca
    elif [ $ProductType == iPad2,3 ]; then
        Baseband=Phoenix-3.6.03.Release.bbfw
        BasebandSHA1=8d4efb2214344ea8e7c9305392068ab0a7168ba4
    elif [ $ProductType == iPad2,6 ] || [ $ProductType == iPad2,7 ]; then
        Baseband=Mav5-11.80.00.Release.bbfw
        BasebandSHA1=aa52cf75b82fc686f94772e216008345b6a2a750
    elif [ $ProductType == iPad3,2 ] || [ $ProductType == iPad3,3 ]; then
        Baseband=Mav4-6.7.00.Release.bbfw
        BasebandSHA1=a5d6978ecead8d9c056250ad4622db4d6c71d15e
    elif [ $ProductType == iPhone4,1 ]; then
        Baseband=Trek-6.7.00.Release.bbfw
        BasebandSHA1=22a35425a3cdf8fa1458b5116cfb199448eecf49
    elif [ $ProductType == iPad3,5 ] || [ $ProductType == iPad3,6 ] ||
         [ $ProductType == iPhone5,1 ] || [ $ProductType == iPhone5,2 ]; then
        BasebandURL=$(cat $Firmware/14G61/url) # iOS 10.3.4
        Baseband=Mav5-11.80.00.Release.bbfw
        BasebandSHA1=8951cf09f16029c5c0533e951eb4c06609d0ba7f
    elif [ $ProductType == iPad4,2 ] || [ $ProductType == iPad4,3 ] || [ $ProductType == iPad4,5 ] ||
         [ $ProductType == iPhone6,1 ] || [ $ProductType == iPhone6,2 ]; then
        BasebandURL=$(cat $Firmware/14G60/url)
        Baseband=Mav7Mav8-7.60.00.Release.bbfw
        BasebandSHA1=f397724367f6bed459cf8f3d523553c13e8ae12c
        A7Device=1
    else # For Wi-Fi only devices
        Baseband=0
        if [ $ProductType == iPad4,1 ] || [ $ProductType == iPad4,4 ]; then
            A7Device=1
        fi
    fi
    [ $ProductType == iPhone6,1 ] && HWModel=n51
    [ $ProductType == iPhone6,2 ] && HWModel=n53
    [ $ProductType == iPad4,1 ] && HWModel=j71
    [ $ProductType == iPad4,2 ] && HWModel=j72
    [ $ProductType == iPad4,3 ] && HWModel=j73
    [ $ProductType == iPad4,4 ] && HWModel=j85
    [ $ProductType == iPad4,5 ] && HWModel=j86
    SEP=sep-firmware.$HWModel.RELEASE.im4p
}

Main $1
