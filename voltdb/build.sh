#!/bin/bash

source voltdb-globals.sh

install_pkg() {
    sudo apt-get -y install build-essential ant-optional openjdk-8-jdk python cmake \
        valgrind ntp ccache git-completion git-core git-svn git-doc \
        git-email python-httplib2 python-setuptools python-dev apt-show-versions

    sudo apt-get -y install ant
    sudo apt purge -y openjdk-11-jre-headless:amd64
    sudo apt autoremove -y
}

prepare() {
    local vdb_src_dir="~/git/voltdb"

    install_pkg

    if [[ -e $vdb_src_dir ]]; then
        cp -r $vdb_src_dir $VDB_TOP_DIR
    else
        cd $VDB_TOP_DIR
        git clone https://github.com/VoltDB/voltdb.git
    fi

    [[ ! -d $VDB_SRC_DIR ]] && echo "VoltDB source code [$VDB_SRC_DIR] not found ..." && exit
    cd $VDB_SRC_DIR
    git checkout voltdb-10.0
}

compile() {
    cd $VDB_SRC_DIR
    ant -Djmemcheck=NO_MEMCHECK
    echo ""
    echo "===> VoltDB compilation done! [$VOLTDBTOPDIR]"
    echo ""
}

verify_ssh_passless() {
    local ret=$(ssh -o PasswordAuthentication=no $VDB_CLIENT /bin/true)
    if [[ $ret ]]; then
        ssh-copy-id ~/.ssh/id_rsa.pub $VDB_CLIENT
    fi
    ret=$(ssh -o PasswordAuthentication=no $VDB_CLIENT /bin/true)
    if [[ $ret ]]; then
        echo "===> Password-less ssh to [$VDB_CLIENT] failed ... please do it manually"
        exit
    fi
}

main() {
    prepare
    compile
}

main
verify_ssh_passless
