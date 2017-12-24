FROM centos:6

LABEL org.label-schema.vcs-url="https://github.com/giovtorres/docker-centos6-slurm" \
      org.label-schema.docker.cmd="docker run -it -h ernie giovtorres/docker-centos6-slurm:latest" \
      org.label-schema.name="docker-centos6-slurm" \
      org.label-schema.description="Slurm All-in-one Docker container on CentOS 6" \
      maintainer="Giovanni Torres"

ARG SLURM_VERSION=17.11.1-2
ARG SLURM_DOWNLOAD_MD5=ef196cce63f8f6872ba2225e35b339d8
ARG SLURM_DOWNLOAD_URL=https://download.schedmd.com/slurm/slurm-"$SLURM_VERSION".tar.bz2

RUN yum makecache fast \
    && yum -y install epel-release \
    && yum -y install \
        wget \
        bzip2 \
        perl \
        gcc \
        gcc-c++\
        vim-enhanced \
        git \
        make \
        munge \
        munge-devel \
        python-devel \
        python-pip \
        mysql-server \
        mysql-devel \
        psmisc \
        bash-completion \
    && yum clean all \
    && rm -rf /var/cache/yum

RUN pip install --upgrade Cython nose supervisor setuptools

RUN groupadd -r slurm && useradd -r -g slurm slurm

RUN set -x \
    && wget -O slurm.tar.bz2 "$SLURM_DOWNLOAD_URL" \
    && echo "$SLURM_DOWNLOAD_MD5  slurm.tar.bz2" | md5sum -c - \
    && mkdir /usr/local/src/slurm \
    && tar jxf slurm.tar.bz2 -C /usr/local/src/slurm --strip-components=1 \
    && rm slurm.tar.bz2 \
    && cd /usr/local/src/slurm \
    && ./configure --enable-debug --enable-front-end --prefix=/usr \
       --sysconfdir=/etc/slurm --with-mysql_config=/usr/bin \
       --libdir=/usr/lib64 \
    && make install \
    && install -D -m644 etc/cgroup.conf.example /etc/slurm/cgroup.conf.example \
    && install -D -m644 etc/slurm.conf.example /etc/slurm/slurm.conf.example \
    && install -D -m644 etc/slurm.epilog.clean /etc/slurm/slurm.epilog.clean \
    && install -D -m644 etc/slurmdbd.conf.example /etc/slurm/slurmdbd.conf.example \
    && install -D -m644 contribs/slurm_completion_help/slurm_completion.sh /etc/profile.d/slurm_completion.sh \
    && cd \
    && rm -rf /usr/local/src/slurm \
    && mkdir -m 0755 /var/run/munge \
    && mkdir /var/log/supervisor \
    && chown munge:munge /var/run/munge \
    && mkdir /etc/sysconfig/slurm \
        /var/spool/slurmd \
        /var/run/slurmd \
        /var/lib/slurmd \
        /var/log/slurm \
    && /usr/sbin/create-munge-key

COPY slurm.conf /etc/slurm/slurm.conf
COPY slurmdbd.conf /etc/slurm/slurmdbd.conf
COPY supervisord.conf /etc/

VOLUME ["/var/lib/mysql", "/var/lib/slurmd", "/var/spool/slurmd", "/var/log/slurm"]

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/bin/bash"]
