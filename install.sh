#!/bin/bash
SOURCE_DIR=/usr/src
LUA_VERSION=5.3.5

install_luaoauth_var=false
rhel_based=false
debian_based=false
lua_installed=false
lua_dep_dir=/usr/local/share/lua/5.3/

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

download_rhel_lua() {
    printf "\r[+] Downloading Lua\n"
    curl -sLO https://www.lua.org/ftp/lua-$LUA_VERSION.tar.gz
    tar xf lua-$LUA_VERSION.tar.gz && rm lua-$LUA_VERSION.tar.gz
}

install_yum_deps() {
    printf "\r[+] Installing yum dependencies\n"
    yum -y install gcc openssl-devel readline-devel systemd-devel unzip >/dev/null 2>&1
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
    curl -sLO https://github.com/haproxytech/haproxy-lua-oauth/archive/master.zip
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
    luaoauth)
        install_luaoauth_var=true
        ;;
    *)
        echo "Usage: install.sh luaoauth"
esac

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
