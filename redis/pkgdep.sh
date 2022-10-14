sudo apt-get -y install build-essential ant-optional openjdk-8-jdk python cmake \
                valgrind ntp ccache git-completion git-core git-svn git-doc \
                git-email python-httplib2 python-setuptools python-dev apt-show-versions

sudo apt-get -y install ant
sudo apt-get -y purge openjdk-11-jre-headless:amd64
sudo apt-get -y install redis-server
sudo apt-get -y autoremove
