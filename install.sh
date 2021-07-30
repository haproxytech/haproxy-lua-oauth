#!/bin/bash
SOURCE_DIR=/usr/src
DEST_BASE_DIR=""
SYSTEMD_NAME=haproxy.service
HAPROXY_VERSION=1.9.1
LUA_VERSION=5.3.5

install_haproxy_var=false
install_luaoauth_var=false
rhel_based=false
debian_based=false
lua_installed=false
lua_dep_dir=$DEST_BASE_DIR/usr/local/share/lua/5.3/

if [ -f /etc/redhat-release ]; then
    rhel_based=true
elif [ -f /etc/debian_version ]; then
    debian_based=true
fi

cd $SOURCE_DIR

display_working() {
    pid=$1
    spin='-\|/'
    i=0
    while kill -0 $pid 2>/dev/null
    do
        i=$(( (i+1) %4 ))
        printf "\r${spin:$i:1}"
        sleep .1
    done
}

download_haproxy_rhel() {
    printf "\r[+] Downloading HAProxy\n"
    curl -sLO https://www.haproxy.org/download/1.9/src/haproxy-$HAPROXY_VERSION.tar.gz
    tar xf haproxy-$HAPROXY_VERSION.tar.gz && rm haproxy-$HAPROXY_VERSION.tar.gz
}

download_rhel_lua() {
    printf "\r[+] Downloading Lua\n"
    curl -sLO https://www.lua.org/ftp/lua-$LUA_VERSION.tar.gz
    tar xf lua-$LUA_VERSION.tar.gz && rm lua-$LUA_VERSION.tar.gz
}

install_yum_deps() {
    printf "\r[+] Installing yum dependencies\n"
    yum -y install gcc openssl-devel readline-devel systemd-devel unzip >/dev/null 2>&1
}

build_haproxy() {
    printf "\r[+] Building HAProxy\n"
    cd $SOURCE_DIR/haproxy-$HAPROXY_VERSION
    make TARGET=linux2628 USE_LINUX_SPLICE=1 USE_CPU_AFFINITY=1 USE_REGPARM=1 USE_SYSTEMD=1 USE_PCRE= USE_PCRE_JIT=1 USE_NS=1 USE_OPENSSL=1 USE_LUA=1 LUA_INC=/usr/src/lua-$LUA_VERSION/src/ LUA_LIB=/usr/src/lua-$LUA_VERSION/src/ >/dev/null
   
    if [ ! -f haproxy ]; then
        printf "\rThere was an error within the HAProxy build\n";
        printf "\rmake TARGET=linux2628 USE_LINUX_SPLICE=1 USE_CPU_AFFINITY=1 USE_REGPARM=1 USE_SYSTEMD=1 USE_PCRE= USE_PCRE_JIT=1 USE_NS=1 USE_OPENSSL=1 USE_LUA=1 LUA_INC=/usr/src/lua-$LUA_VERSION/src/ LUA_LIB=/usr/src/lua-$LUA_VERSION/src/\n"
        make TARGET=linux2628 USE_LINUX_SPLICE=1 USE_CPU_AFFINITY=1 USE_REGPARM=1 USE_SYSTEMD=1 USE_PCRE= USE_PCRE_JIT=1 USE_NS=1 USE_OPENSSL=1 USE_LUA=1 LUA_INC=/usr/src/lua-$LUA_VERSION/src/ LUA_LIB=/usr/src/lua-$LUA_VERSION/src/  
    fi
}

install_rhel_haproxy() {
    printf "\r[+] Installing HAProxy\n"
    /bin/cp $SOURCE_DIR/haproxy-$HAPROXY_VERSION/haproxy $DEST_BASE_DIR/usr/sbin/
    mkdir -p $DEST_BASE_DIR/etc/haproxy/pem
}

install_deb_haproxy() {
    printf "\r[+] Installing HAProxy\n"
    haproxy_deb_version=$(echo $HAPROXY_VERSION |cut -d'.' -f1-2)
    add-apt-repository ppa:vbernat/haproxy-$haproxy_deb_version >/dev/null 2>&1 
    apt-get update >/dev/null
    apt-get install -y haproxy >/dev/null
}

install_haproxy_systemd() {
    cd $SOURCE_DIR/haproxy-$HAPROXY_VERSION/contrib/systemd
    make clean >/dev/null
    make PREFIX=$DEST_BASE_DIR/usr >/dev/null
    /bin/cp haproxy.service /usr/lib/systemd/system/$SYSTEMD_NAME
    systemctl daemon-reload
} 

build_lua() {
    printf "\r[+] Building Lua\n"
    cd $SOURCE_DIR/lua-$LUA_VERSION
    make linux test >/dev/null
}

install_rhel_lua() {
    printf "\r[+] Installing Lua\n"
    cd $SOURCE_DIR/lua-$LUA_VERSION
    make install >/dev/null
}

install_deb_lua() {
    printf "\r[+] Installing Lua\n"
    apt-get update >/dev/null 2>&1
    apt-get install -y software-properties-common unzip build-essential libssl-dev lua5.3 liblua5.3-dev >/dev/null 2>&1
}

download_luaoauth() {
    printf "\r[+] Downloading haproxy-lua-oauth\n"
    cd $SOURCE_DIR
    curl -sLO https://github.com/greyscaleai521/gs-haproxy-lua-oauth/archive/master.zip
    unzip -qo master.zip && rm master.zip
}

download_luaoauth_deps() {
    printf "\r[+] Downloading haproxy-lua-oauth dependencies\n"
    cd $SOURCE_DIR
    apt-get install -y unzip >/dev/null 2>&1

    curl -sLO https://github.com/diegonehab/luasocket/archive/master.zip
    unzip -qo master.zip && mv luasocket-master luasocket && rm master.zip

    curl -sLO https://github.com/rxi/json.lua/archive/master.zip
    unzip -qo master.zip && mv json.lua-master json && rm master.zip

    curl -sLO https://github.com/wahern/luaossl/archive/rel-20181207.zip
    unzip -qo rel-20181207.zip && mv luaossl-rel-20181207 luaossl && rm rel-20181207.zip
}

install_luaoauth() {
    printf "\r[+] Installing haproxy-lua-oauth\n"
    if [ ! -e $lua_dep_dir ]; then
        mkdir -p $lua_dep_dir;
    fi;
    mv $SOURCE_DIR/haproxy-lua-oauth-master/lib/*.lua $lua_dep_dir
}

install_luaoauth_deps() {
    printf "\r[+] Installing haproxy-lua-oauth dependencies\n"
    cd $SOURCE_DIR
    cd luasocket/
    make clean all install-both LUAINC=/usr/include/lua5.3/ >/dev/null
    cd ..
    cd luaossl/
    make install >/dev/null
    cd ..
    mv json/json.lua $lua_dep_dir 
}

case $1 in
    haproxy)
        install_haproxy_var=true
        ;;
    luaoauth)
        install_luaoauth_var=true
        ;;
    all)
        install_haproxy_var=true
        install_luaoauth_var=true
        ;;
    *)
    print_help
esac

if $install_haproxy_var; then
    # Install HAProxy
    if $rhel_based; then
        download_and_install_haproxylua=(download_haproxy_rhel download_rhel_lua install_yum_deps build_lua install_rhel_lua build_haproxy install_rhel_haproxy install_haproxy_systemd)
        for func in ${download_and_install_haproxylua[*]}; do
            $func &
            display_working $!
        done
    elif $debian_based; then
        download_and_install_haproxylua=(install_deb_haproxy install_deb_lua)
        for func in ${download_and_install_haproxylua[*]}; do
            $func &
            display_working $!
        done
    fi
    lua_installed=true
fi

if $install_luaoauth_var; then
    # Install Lua JWT
    if ! $lua_installed; then
        if $rhel_based; then
            download_and_install_lua=(install_yum_deps download_rhel_lua build_lua install_rhel_lua)
        elif $debian_based; then
            download_and_install_lua=(install_deb_lua)
        fi
        for func in ${download_and_install_lua[*]}; do
            $func &
            display_working $!
        done
    fi 
    download_and_install_luaoauth=(download_luaoauth_deps install_luaoauth_deps download_luaoauth install_luaoauth)
    for func in ${download_and_install_luaoauth[*]}; do
        $func &
        display_working $!
    done
fi
