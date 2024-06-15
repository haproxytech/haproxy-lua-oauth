#!/bin/sh
SOURCE_DIR=/usr/src
LUA_VERSION=5.4.4
CWD=$(pwd)

install_luaoauth_var="false"
rhel_based="false"
debian_based="false"
alpine_based="false"
lua_installed="false"
lua_dep_dir=/usr/local/share/lua/5.4/

if [ -f /etc/redhat-release ]; then
    echo "Red Hat based system detected"
    rhel_based="true"
elif [ -f /etc/debian_version ]; then
    echo "Debian based system detected"
    debian_based="true"
elif [ -f /etc/alpine-release ]; then
    echo "Alpine based system detected"
    alpine_based="true"
fi

if [ ! -e $SOURCE_DIR ]; then
    mkdir -p $SOURCE_DIR;
fi;

cd $SOURCE_DIR

display_working() {
    pid=$1
    spin='-\|/'
    i=0
    while kill -0 "$pid" 2>/dev/null
    do
        i=$(( (i+1) %4 ))
        printf "\r${spin:$i:1}"
        sleep .1
    done
}

# ----------------------------
# Functions not currently used
# ----------------------------

download_rhel_lua() {
    printf "\r[+] Downloading Lua\n"
    cd $SOURCE_DIR
    curl -sLO https://www.lua.org/ftp/lua-$LUA_VERSION.tar.gz
    tar xf lua-$LUA_VERSION.tar.gz && rm lua-$LUA_VERSION.tar.gz
}

install_yum_deps() {
    printf "\r[+] Installing yum dependencies\n"
    yum -y install dnf gcc openssl-devel readline-devel systemd-devel unzip >/dev/null 2>&1
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
    apt-get install -y software-properties-common unzip build-essential libssl-dev lua5.4 liblua5.4-dev >/dev/null 2>&1
}

install_alpine_lua() {
    printf "\r[+] Installing Lua\n"
    apk add --no-cache lua5.4 lua5.4-dev openssl-dev gcc libc-dev git make automake libtool curl unzip >/dev/null 2>&1
    #?? build-base libc-dev liblua5.4-dev unzip
}    

# ----------------------------
# ----------------------------

install_luaoauth_deps_alpine() {
    printf "\r[+] Installing haproxy-lua-oauth dependencies\n"

    if [ ! -e $lua_dep_dir ]; then
        mkdir -p $lua_dep_dir;
    fi;    

    apt-get update >/dev/null 2>&1
    apk add --no-cache lua5.4 lua5.4-dev openssl-dev gcc libc-dev git make automake libtool curl unzip >/dev/null 2>&1

    cd $SOURCE_DIR

    curl -sLO https://github.com/rxi/json.lua/archive/refs/heads/master.zip
    unzip -qo master.zip && rm master.zip
    mv json.lua-master/json.lua $lua_dep_dir 

    curl -sLO https://github.com/lunarmodules/luasocket/archive/refs/heads/master.zip
    unzip -qo master.zip && rm master.zip
    cd luasocket-master/
    make clean all install-both LUAINC=/usr/include/lua5.4/ >/dev/null
    cd ..

    curl -sLO https://github.com/wahern/luaossl/archive/refs/heads/master.zip
    unzip -qo master.zip && rm master.zip
    cd luaossl-master/
    make install >/dev/null
    cd ..
}

install_luaoauth_deps_debian() {
    printf "\r[+] Installing haproxy-lua-oauth dependencies\n"

    if [ ! -e $lua_dep_dir ]; then
        mkdir -p $lua_dep_dir;
    fi;

    apt-get update >/dev/null 2>&1
    apt-get install -y build-essential liblua5.4-dev libssl-dev unzip >/dev/null 2>&1

    cd $SOURCE_DIR

    curl -sLO https://github.com/rxi/json.lua/archive/refs/heads/master.zip
    unzip -qo master.zip && rm master.zip
    cp json.lua-master/json.lua $lua_dep_dir 

    curl -sLO https://github.com/lunarmodules/luasocket/archive/refs/heads/master.zip
    unzip -qo master.zip && rm master.zip
    cd luasocket-master/
    make clean all install-both LUAINC=/usr/include/lua5.4/ >/dev/null
    cd ..

    curl -sLO https://github.com/wahern/luaossl/archive/refs/heads/master.zip
    unzip -qo master.zip && rm master.zip
    cd luaossl-master/
    make install >/dev/null
    cd ..
}

install_luaoauth_deps_rhel() {
    printf "\r[+] Installing haproxy-lua-oauth dependencies\n"

    if [ ! -e $lua_dep_dir ]; then
        mkdir -p $lua_dep_dir;
    fi;

    yum -y install dnf
    dnf -y install dnf-plugins-core
    dnf config-manager --set-enabled powertools
    dnf update >/dev/null 2>&1
    dnf install -y gcc openssl-devel lua-devel make readline-devel systemd-devel unzip >/dev/null 2>&1

    cd $SOURCE_DIR

    curl -sLO https://github.com/rxi/json.lua/archive/refs/heads/master.zip
    unzip -qo master.zip && rm master.zip
    mv json.lua-master/json.lua $lua_dep_dir 

    curl -sLO https://github.com/lunarmodules/luasocket/archive/refs/heads/master.zip
    unzip -qo master.zip && rm master.zip
    cd luasocket-master/
    make clean all install-both LUAINC=/usr/include/ >/dev/null
    cd ..

    curl -sLO https://github.com/wahern/luaossl/archive/rel-20181207.zip
    unzip -qo rel-20181207.zip && rm rel-20181207.zip
    cd luaossl-rel-20181207/
    make install >/dev/null
    cd ..
}

install_luaoauth() {
    printf "\r[+] Installing haproxy-lua-oauth\n"
    if [ ! -e $lua_dep_dir ]; then
        mkdir -p $lua_dep_dir;
    fi;

    cp "$CWD"/lib/*.lua $lua_dep_dir
}

case $1 in
    luaoauth)
        install_luaoauth_var="true"
        ;;
    *)
        echo "Usage: install.sh luaoauth"
        exit 1
        ;;
esac

echo "$rhel_based" 

if $install_luaoauth_var; then
    if $rhel_based; then
        echo "RHEL based system detected"
        download_and_install_luaoauth="install_luaoauth_deps_rhel install_luaoauth"
    elif $debian_based; then
        echo "Debian based system detected"
        download_and_install_luaoauth="install_luaoauth_deps_debian install_luaoauth"
    elif $alpine_based; then
        echo "Alpine based system detected"
        download_and_install_luaoauth="install_luaoauth_deps_alpine install_luaoauth"
    fi

    for func in $download_and_install_luaoauth; do
        "$func" &
        display_working "$!"
    done
fi

