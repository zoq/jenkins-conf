#!/bin/bash

arma_version=$1
boost_version=$2
llvm_version=$3

cat > Dockerfile <<EOF

# Using debian:stretch image as base-image.
FROM debian:stretch

# Steps to reduce image size.
RUN apt-get update  && apt-get install -y aptitude && apt-get purge -y \
    \$(aptitude search '~i!~M!~prequired!~pimportant!~R~prequired! \
    ~R~R~prequired!~R~pimportant!~R~R~pimportant!busybox!grub!initramfs-tools' \
    | awk '{print $2}') && apt-get purge -y aptitude && \
    apt-get autoremove -y && apt-get clean && rm -rf /usr/share/man/?? && \
    rm -rf /usr/share/man/??_*

# Installing dependencies required to run mlpack.
RUN apt-get update  && apt-get install -y --no-install-recommends wget \
    cmake binutils-dev make txt2man git build-essential python \
    doxygen unzip liblapack-dev libblas-dev libarpack2 libsuperlu-dev && \
    apt-get clean && rm -rf /usr/share/man/?? && rm -rf /usr/share/man/??_* \
    && rm -rf /var/lib/apt/lists/* && rm -rf /usr/share/locale/* && \
    rm -rf /var/cache/debconf/*-old && rm -rf /usr/share/doc/*


# Installing clang from source.
WORKDIR /
RUN wget http://masterblaster.mlpack.org:5005/$llvm_version.tar.xz && \
    tar xvf $llvm_version.tar.xz && \
    rm -f $llvm_version.tar.xz && \
    cd $llvm_version && \
    mkdir build && \
    cd build && \
    cmake -DCMAKE_INSTALL_PREFIX=/usr ../ && \
    make && \
    make install && \
    apt-get purge -y gcc && \
    cd .. && \
    rm -rf $llvm_version

# Installing armadillo via source-code.
WORKDIR /
RUN wget --no-check-certificate \
      "http://masterblaster.mlpack.org:5005/$arma_version.tar.gz" && \
    tar xvzf $arma_version.tar.gz && \
    rm -f $arma_version.tar.gz && \
    cd $arma_version && \
    cmake -DINSTALL_LIB_DIR=/usr/lib/ . && \
    make && \
    make install && \
    cd .. && \
    rm -rf $arma_version


# Installing boost from source.
WORKDIR /
RUN wget \
      http://masterblaster.mlpack.org:5005/$boost_version.tar.gz && \
    tar xvzf $boost_version.tar.gz && \
    rm -f $boost_version.tar.gz && \
    cd $boost_version && \
    ./bootstrap.sh --with-toolset=clang --prefix=/usr/ \
        --with-libraries=math,program_options,serialization,test && \
    ./bjam install && \
    rm -f $boost_version/
EOF

cat >> Dockerfile << 'EOF'
# Creating a non-root user.
RUN adduser --system --disabled-password --disabled-login \
   --shell /bin/sh mlpack

# Hardening the containers by unsetting all SUID tags.
RUN for i in `find / -perm 6000 -type f`; do chmod a-s $i; done

# Changing work directory and user to mlpack.
WORKDIR /home/mlpack
USER mlpack
EOF
