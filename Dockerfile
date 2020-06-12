FROM ubuntu:18.04

ENV DEBIAN_FRONTEND=noninteractive \
    WINEARCH=win64 \
    WINEDEBUG=fixme-all

## BEGIN WINE INSTALLATION ##
# Install dependencies needed for installation and using PPAs and Locales
RUN apt-get -q update && \
    apt-get --no-install-recommends --no-install-suggests -y install \
        apt-utils apt-transport-https ca-certificates \
        software-properties-common gnupg \
        lib32stdc++6 lib32gcc1 \
        sed wget xvfb locales cabextract \
        && \
    localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 && \
    export LANG=en_US.UTF-8 && \
    apt-get clean autoclean && apt-get -y autoremove && rm -rf /var/lib/{apt,dpkg,cache,log}/

RUN (cd /usr/bin; \
        wget "https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks") && \
    chmod a+x /usr/bin/winetricks && \
    (cd /usr/share/bash-completion/completions; \
        wget "https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks.bash-completion")

RUN dpkg --add-architecture i386 && \
    wget -nc https://dl.winehq.org/wine-builds/winehq.key && \
    apt-key add winehq.key && rm winehq.key && \
    add-apt-repository https://dl.winehq.org/wine-builds/ubuntu/ && \
    add-apt-repository ppa:cybermax-dexter/sdl2-backport && \
    apt-get -q update && \
    apt-get --no-install-recommends --no-install-suggests -y install \
        winehq-devel wine-devel wine-devel-i386 wine-devel-amd64 \
        && \
    rm -rf /root/.wine && \
    env WINEDLLOVERRIDES="mscoree,mshtml=" wineboot --init && \
    xvfb-run winetricks --unattended vcrun2013 vcrun2017 && \
    wineboot --init && \
    winetricks --unattended dotnet472 corefonts dxvk && \
    apt-get clean autoclean && apt-get autoremove -y && rm -rf /var/lib/{apt,dpkg,cache,log}/

## BEGIN STEAM INSTALLATION ##
RUN echo steam steam/question select "I AGREE" | debconf-set-selections && \
    apt-get -q update && \
    apt-get -y install \
        steamcmd:i386 \
        winbind \
        && \
    ln -s /usr/games/steamcmd /usr/bin/steamcmd && \
    apt-get clean autoclean && apt-get autoremove -y && rm -rf /var/lib/{apt,dpkg,cache,log}/

## BEGIN USERSPACE SETUP ##
# The following part was gladly adapted and extended
# from https://github.com/bregell/docker_space_engineers_server/blob/38c7d3d8f2b6bdbfcfb45f84b3b2df1c128eb99f/Dockerfile
# Licenced under MIT by Johan Bregell
# Part of this is also inspired by Pterodactyl docker images.

COPY entrypoint.sh /entrypoint.sh
RUN chmod 755 /entrypoint.sh

RUN useradd -m -d /home/container -s /bin/bash container
USER container
ENV HOME /home/container

ENV SE_WORKING_DIR="${HOME}/.wine/drive_c/SpaceEngineersDedicatedServer" \
    SE_CONFIG_DIR="${HOME}/.wine/drive_c/users/container/AppData/Roaming/SpaceEngineersDedicated" \
    SERVER_NAME=DockerDedicated \
    SERVER_PORT=27016 \
    SERVER_API_PORT=8080 \
    STEAM_PORT=8766 \
    WORLD_NAME=DockerWorld

COPY resources/SpaceEngineers-Dedicated.cfg /etc/default/SpaceEngineers-Dedicated.cfg

RUN mkdir -p "${SE_WORKING_DIR}" && \
    mkdir -p "${SE_CONFIG_DIR}"

#VOLUME ${SE_WORKING_DIR}
WORKDIR ${SE_WORKING_DIR}

CMD ["/bin/bash", "/entrypoint.sh"]
EXPOSE ${STEAM_PORT}/udp ${SERVER_PORT}/udp ${SERVER_API_PORT}/tcp
