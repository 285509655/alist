FROM centos:centos8

ENV BRANCH 2.2
ENV RSTUDIO 1.4.1103

# Enable EPEL
RUN \
  yum upgrade -y && \
  yum install -y dnf-plugins-core epel-release && \
  yum config-manager --set-enabled powertools epel-testing 

# Install.
RUN \
  useradd -ms /bin/bash builder && \
  yum update -y && \
  yum upgrade -y && \
  yum install -y rpm-build make wget tar httpd-devel libapreq2-devel R-devel libcurl-devel protobuf-devel openssl-devel libxml2-devel libicu-devel cairo-devel createrepo && \
  yum clean all

USER builder

RUN \
  mkdir -p ~/rpmbuild/SOURCES && \
  mkdir -p ~/rpmbuild/SPECS

RUN \
  cd ~ && \
  wget --quiet https://github.com/jeffreyhorner/rapache/archive/v1.2.9.tar.gz -O rapache-1.2.9.tar.gz && \
  tar xzvf rapache-1.2.9.tar.gz rapache-1.2.9/rpm/rapache.spec --strip-components 2 && \
  mv -f rapache-1.2.9.tar.gz ~/rpmbuild/SOURCES/ && \
  mv -f rapache.spec ~/rpmbuild/SPECS/ && \
  rpmbuild -ba ~/rpmbuild/SPECS/rapache.spec

RUN \
  cd ~ && \
  wget --quiet https://github.com/opencpu/opencpu-server/archive/master.tar.gz -O opencpu-server-master.tar.gz  && \
  tar xzvf opencpu-server-master.tar.gz opencpu-server-master/rpm/opencpu.spec --strip-components 2 && \
  mv -f opencpu-server-master.tar.gz ~/rpmbuild/SOURCES/ && \
  mv -f opencpu.spec ~/rpmbuild/SPECS/ && \
  rpmbuild -ba ~/rpmbuild/SPECS/opencpu.spec --define "branch master"

RUN \
  createrepo ~/rpmbuild/RPMS/x86_64/

USER root

RUN \
  cp -Rf /home/builder/rpmbuild/RPMS ~/ && \
  cp -Rf /home/builder/rpmbuild/SRPMS ~/ && \
  userdel -r builder

RUN \
  yum install -y MTA mod_ssl /usr/sbin/semanage && \
  /usr/libexec/httpd-ssl-gencerts && \
  cd ~/RPMS/x86_64/ && \
  rpm -i rapache-*.rpm && \
  rpm -i opencpu-lib-*.rpm && \
  rpm -i opencpu-server-*.rpm

RUN \
  wget --quiet https://download2.rstudio.org/server/centos8/x86_64/rstudio-server-rhel-${RSTUDIO}-x86_64.rpm && \
  yum install -y --nogpgcheck rstudio-server-rhel-${RSTUDIO}-x86_64.rpm && \
  rm rstudio-server-rhel-${RSTUDIO}-x86_64.rpm && \
  echo "server-app-armor-enabled=0" >> /etc/rstudio/rserver.conf

RUN \
  yum remove -y httpd-devel libapreq2-devel && \
  yum clean all

# Apache ports
EXPOSE 80
EXPOSE 443
EXPOSE 8004

# Define default command.
CMD /usr/lib/rstudio-server/bin/rserver && apachectl -DFOREGROUND
