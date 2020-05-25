#
# GitLab CI: Android v0.3
#
# https://hub.docker.com/r/jangrewe/gitlab-ci-android/
# https://git.faked.org/jan/gitlab-ci-android
#

FROM ubuntu:18.04
MAINTAINER Jan Grewe <jan@faked.org>

ENV VERSION_TOOLS "6200805"

ENV ANDROID_HOME "/sdk"
ENV PATH "$PATH:${ANDROID_HOME}/tools"
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get -qq update \
 && apt-get install -qqy --no-install-recommends \
      bzip2 \
      curl \
      git-core \
      html2text \
      openjdk-8-jdk \
      libc6-i386 \
      lib32stdc++6 \
      lib32gcc1 \
      lib32ncurses5 \
      lib32z1 \
      unzip \
      locales \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
RUN locale-gen en_US.UTF-8
ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'

RUN rm -f /etc/ssl/certs/java/cacerts; \
    /var/lib/dpkg/info/ca-certificates-java.postinst configure

RUN curl -s https://dl.google.com/android/repository/commandlinetools-linux-${VERSION_TOOLS}_latest.zip > /tools.zip \
 && mkdir -p ${ANDROID_HOME}/cmdline-tools \
 && unzip /tools.zip -d ${ANDROID_HOME}/cmdline-tools \
 && rm -v /tools.zip

RUN mkdir -p $ANDROID_HOME/licenses/ \
 && echo "8933bad161af4178b1185d1a37fbf41ea5269c55\nd56f5187479451eabf01fb78af6dfcb131a6481e\n24333f8a63b6825ea9c5514f83c2829b004d1fee" > $ANDROID_HOME/licenses/android-sdk-license \
 && echo "84831b9409646a918e30573bab4c9c91346d8abd\n504667f4c0de7af1a06de9f4b1727b84351f2910" > $ANDROID_HOME/licenses/android-sdk-preview-license \
 && yes | ${ANDROID_HOME}/cmdline-tools/tools/bin/sdkmanager --sdk_root=${ANDROID_HOME} --licenses >/dev/null

ADD packages.txt /sdk
RUN mkdir -p /root/.android \
 && touch /root/.android/repositories.cfg \
 && ${ANDROID_HOME}/cmdline-tools/tools/bin/sdkmanager --sdk_root=${ANDROID_HOME} --update

RUN while read -r package; do PACKAGES="${PACKAGES}${package} "; done < /sdk/packages.txt \
 && ${ANDROID_HOME}/cmdline-tools/tools/bin/sdkmanager --sdk_root=${ANDROID_HOME} ${PACKAGES}
 sdkmanager "emulator" "platform-tools" && \
    ln -s ${ANDROID_SDK_ROOT}/emulator/emulator /usr/local/bin && \
    ln -s ${ANDROID_SDK_ROOT}/platform-tools/adb /usr/local/bin && \
    rm commandlinetools-linux.zip && \
    echo "5 4 * * * /usr/bin/find /tmp/android* -mtime +3 -exec rm -rf {} \;" > ${ANDROID_SDK_ROOT}/cleanup.cron && \
    # get supercronic
    wget https://github.com/aptible/supercronic/releases/download/${SUPERCRONIC_VERSION}/supercronic-linux-amd64 -O /usr/local/bin/supercronic && \
    echo "${SUPERCRONIC_SHA1SUM}  /usr/local/bin/supercronic" | sha1sum -c - && \
    chmod +x /usr/local/bin/supercronic && \
    # cleanup and get runtime dependencies
    apt-get remove -y unzip wget && apt-get auto-remove -y && \
    apt-get install -y libfontconfig libglu1 libnss3-dev libxcomposite1 libxcursor1 libpulse0 libasound2 socat && \
    rm -rf /var/lib/apt/lists/* && \
    # create unprivileged user
    addgroup --gid 1000 android && \
    useradd -u 1000 -g android -ms /bin/sh android && \
    chown -R android:android ${ANDROID_SDK_ROOT}

ARG ANDROID_DEVICE="Nexus One"
ARG ANDROID_VERSION=29

USER android

RUN sdkmanager "platforms;android-${ANDROID_VERSION}" "system-images;android-${ANDROID_VERSION};google_apis;x86" && \
    rm ${ANDROID_SDK_ROOT}/emulator/qemu/linux-x86_64/qemu-system-aarch64* && \
    rm ${ANDROID_SDK_ROOT}/emulator/qemu/linux-x86_64/qemu-system-armel* && \
    rm ${ANDROID_SDK_ROOT}/emulator/qemu/linux-x86_64/qemu-system-i386* && \
    avdmanager create avd --name 'Emulator' --package "system-images;android-${ANDROID_VERSION};google_apis;x86" --device "${ANDROID_DEVICE}"


COPY ./docker-entrypoint.sh /usr/bin/

EXPOSE 5555

HEALTHCHECK CMD \[ $(adb shell getprop sys.boot_completed) \] || exit 1
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["emulator", "@Emulator", "-use-system-libs", "-read-only", "-no-boot-anim", "-no-window", "-no-audio", "-no-snapstorage", "-verbose"]
