FROM docker.io/archlinux/archlinux

RUN pacman -Syu --noconfirm \
    git \
    python

RUN mkdir /opt/mkosi && \
    git clone https://github.com/systemd/mkosi.git --revision=d6ddc66acb05d3d761d3f600c6b029319db9ae95 /opt/mkosi && \
    ln -s /opt/mkosi/bin/mkosi /usr/bin/mkosi