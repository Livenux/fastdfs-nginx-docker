FROM debian as build
WORKDIR /src
ARG FASTDFS_VERSION=6.06 
ARG LIBFASTCOMMON=1.0.43
ARG NGINX=1.19.2
ARG NGINX_FASTDFS=1.22

RUN sed -i 's/deb.debian.org/mirrors.cloud.tencent.com/g' /etc/apt/sources.list && \
    sed -i 's/security.debian.org/mirrors.cloud.tencent.com/g' /etc/apt/sources.list && \
    apt-get update && apt-get install -y curl build-essential make gcc libpcre3 \ 
            libpcre3-dev libpcre++-dev zlib1g-dev libbz2-dev libxslt1-dev libxml2-dev libgd-dev \ 
            libgeoip-dev libgoogle-perftools-dev libperl-dev libssl-dev libcurl4-openssl-dev libatomic-ops-dev wget && \
    wget -c https://github.com/happyfish100/fastdfs/archive/V${FASTDFS_VERSION}.tar.gz  -O - | tar -xz && \
    wget -c https://github.com/happyfish100/libfastcommon/archive/V${LIBFASTCOMMON}.tar.gz  -O - | tar -xz && \
    wget -c http://nginx.org/download/nginx-${NGINX}.tar.gz -O - | tar -xz && \
    wget -c https://github.com/happyfish100/fastdfs-nginx-module/archive/V${NGINX_FASTDFS}.tar.gz -O - | tar -xz && \
    cd libfastcommon-${LIBFASTCOMMON} && sh make.sh && sh  make.sh install && \
    cd ../fastdfs-${FASTDFS_VERSION} && sh make.sh && sh make.sh install && \
    cd ../nginx-${NGINX} && ./configure --add-module=/src/fastdfs-nginx-module-${NGINX_FASTDFS}/src/  \
                                        --with-http_stub_status_module --with-threads \
					--prefix=/etc/nginx \ 
                                        --sbin-path=/usr/sbin/nginx \ 
                                        --modules-path=/usr/lib/nginx/modules \ 
                                        --conf-path=/etc/nginx/nginx.conf \
                                        --error-log-path=/var/log/nginx/error.log \
                                        --pid-path=/var/run/nginx.pid \
                                        --lock-path=/var/run/nginx.lock && \
    make -j 4 


FROM debian

ENV  TZ='Asia/Shanghai'

COPY --from=build /src /src

ARG FASTDFS_VERSION=6.06 
ARG LIBFASTCOMMON=1.0.43
ARG NGINX=1.19.2

ENV TRACKER_SERVER='tracker_server = tracker0:22122\ntracker_server = tracker1:22122' \
    HTTP_DOMAIN='web'
    
WORKDIR /home/fdfs

RUN set -x \
    echo $TZ > /etc/timezone && \
    sed -i 's/deb.debian.org/mirrors.cloud.tencent.com/g' /etc/apt/sources.list && \
    sed -i 's/security.debian.org/mirrors.cloud.tencent.com/g' /etc/apt/sources.list && \
    apt-get update && apt-get install -y tzdata make  curl libssl1.1 libtiff5 libwebp6 \
            libx11-6 libx11-data libxau6 libxcb1 libxdmcp6 libxml2 \
            libxpm4 libxslt1.1 lsb-base  sensible-utils ucf  libpng16-16 \
            fontconfig-config fonts-dejavu-core geoip-database libbsd0 libexpat1 \ 
            libfontconfig1 libfreetype6 libgd3 libgeoip1 libicu63 libjbig0 libjpeg62-turbo && \
    rm /etc/localtime && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
    dpkg-reconfigure -f noninteractive tzdata  && \
    useradd -d /home/fdfs -s /bin/bash fdfs && \
    cd /src/libfastcommon-${LIBFASTCOMMON} && sh make.sh install && \
    cd /src/fastdfs-${FASTDFS_VERSION} && sh make.sh install && \
    cd /src/nginx-${NGINX} && make install && \
    mkdir -p /var/fdfs/store0 && \
    chown fdfs /etc/fdfs -R && chown fdfs /var/fdfs -R && \
    rm -rf /var/lib/apt/lists/* /src /etc/fdfs/*.simple && \
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

EXPOSE  80   
COPY conf /etc/fdfs    
COPY nginx.conf /etc/nginx/nginx.conf
ADD startup.sh /home/fdfs/

HEALTHCHECK --interval=60s --timeout=5s --retries=3 \
    CMD curl http://localhost/status.html  || exit 1

ENTRYPOINT ["bash", "/home/fdfs/startup.sh"] 


