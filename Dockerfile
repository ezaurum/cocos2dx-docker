FROM ubuntu:16.04 as builder

ENV LANG=C.UTF-8

#Install oracle java
RUN echo debconf shared/accepted-oracle-license-v1-1 select true | debconf-set-selections
RUN echo debconf shared/accepted-oracle-license-v1-1 seen true | debconf-set-selections

RUN apt-get update && \
    apt-get install -y --no-install-recommends software-properties-common && \
    add-apt-repository ppa:webupd8team/java && \
    apt-get update && \
    apt-get install -y --no-install-recommends oracle-java8-installer

#Install utils and deps
RUN apt-get install -y unzip sudo python cmake wget gradle ant \
                       apt-utils libx11-dev libxmu-dev libglu1-mesa-dev \
                       libgl2ps-dev libxi-dev gcc-4.9 g++-4.9 \
                       libzip-dev libpng12-dev libcurl4-gnutls-dev \
                       libfontconfig1-dev libsqlite3-dev libglew-dev \
                       libssl-dev libgtk-3-dev
                       
# Set args
ARG NDK_TOOLS_VERSION='r14b'
ARG SDK_TOOLS_VERSION='r25.2.3'
ARG ANDROID_BUILD_TOOLS='build-tools-24.0.0'
ARG ANDROID_SDK='android-24'

ARG SDK_TOOLS_FILE_NAME=tools_$SDK_TOOLS_VERSION-linux.zip
ARG SDK_TOOLS_FILE_URL=https://dl.google.com/android/repository/$SDK_TOOLS_FILE_NAME 

ARG NDK_TOOLS_FILE_NAME=android-ndk-$NDK_TOOLS_VERSION-linux-x86_64.zip
ARG NDK_TOOLS_FILE_URL=https://dl.google.com/android/repository/$NDK_TOOLS_FILE_NAME

ARG ANDROID_EXTRA_SDK='extra-android-support,extra-android-m2repository,extra-google-google_play_services,extra-google-m2repository,extra-google-analytics_sdk_v2'

# install android sdk
ENV ANDROID_HOME /lib/android-sdk
ENV ANDROID_SDK_ROOT $ANDROID_HOME

ENV PATH $PATH:$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools:$ANDROID_HOME/build-tools/$ANDROID_BUILD_TOOLS_VERSION

WORKDIR $ANDROID_HOME
RUN wget --no-cookies --no-check-certificate ${SDK_TOOLS_FILE_URL} \
    && unzip ${SDK_TOOLS_FILE_NAME} \
    && rm -f ${SDK_TOOLS_FILE_NAME} \
    && cd ${ANDROID_HOME}/tools \
    && echo y | ./android update sdk --all --no-ui --force --filter tools,platform-tools,${ANDROID_BUILD_TOOLS},${ANDROID_SDK},${ANDROID_EXTRA_SDK}

#install android ndk

ENV NDK_HOME /lib/android-ndk
ENV NDK_ROOT $NDK_HOME

ENV PATH $PATH:$NDK_HOME

WORKDIR $NDK_HOME
RUN mkdir -p $NDK_HOME \
    && cd $NDK_HOME \
    && wget --no-cookies --no-check-certificate ${NDK_TOOLS_FILE_URL} \
    && unzip ${NDK_TOOLS_FILE_NAME} \
    && rm -f ${NDK_TOOLS_FILE_NAME} \
    && cd ${ANDROID_HOME}/tools \
    && echo y | ./android update sdk --all --no-ui --force --filter tools,platform-tools,${ANDROID_BUILD_TOOLS},${ANDROID_SDK},${ANDROID_EXTRA_SDK}


# Install cocos2d-x

WORKDIR /opt

ARG COCOS2D_X_VERSION_LINK=375 
ARG COCOS2D_X_VERSION=3.15.1

RUN wget -O cocos2d-x.zip http://cocos2d-x.org/filedown/start/$COCOS2D_X_VERSION_LINK && \
    unzip cocos2d-x.zip && \ 
    mv cocos2d-x-$COCOS2D_X_VERSION cocos2d-x && \
    rm cocos2d-x.zip

WORKDIR /opt/cocos2d-x
RUN ./build/install-deps-linux.sh

# Set ant
ENV ANT_HOME /usr/share/ant
ENV ANT_ROOT $ANT_HOME/bin

# Setup cocos
RUN python setup.py

ENV PATH $PATH:/opt/cocos2d-x/tools/cocos2d-console/bin

#Build by docker

WORKDIR "/usr/app/src"
COPY . .
RUN echo y | cocos deploy -p web -m release

#Make runner image
 
FROM alpine:latest
WORKDIR "/app/src"
COPY --from=builder /usr/app/src/publish/html5 .  

