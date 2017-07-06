FROM alpine:latest

#Install open JDK 8
RUN apk add --no-cache alpine-sdk openjdk8
ENV JAVA8_HOME /usr/lib/jvm/default-jvm
ENV JAVA_HOME $JAVA8_HOME

ENV PATH=$PATH:$JAVA_HOME/jre/bin:$JAVA_HOME/bin

ENV LANG=C.UTF-8

# Install wget, unzip
RUN apk add --no-cache --virtual=.sdk-update-dependencies wget unzip

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

#Install ant

ARG ANT_VERSION=1.10.1
ENV ANT_HOME /lib/ant
ENV ANT_ROOT =$ANT_HOME/bin

ENV PATH $PATH:$ANT_HOME:$ANT_ROOT

WORKDIR $ANT_HOME
RUN mkdir temp \
    && cd temp \
    && wget http://apache.mirror.cdnetworks.com/ant/binaries/apache-ant-${ANT_VERSION}-bin.tar.gz \
    && tar -zxvf apache-ant-${ANT_VERSION}-bin.tar.gz \
    && mv apache-ant-${ANT_VERSION} ${ANT_HOME} \
    && rm apache-ant-${ANT_VERSION}-bin.tar.gz \
    && rm -rf ant-${ANT_VERSION} \
    && rm -rf ${ANT_HOME}/manual \
    && cd $ANT_HOME \
    && rm -rf temp


#install gradle
ARG GRADLE_VERSION=4.0

ENV GRADLE_HOME /lib/gradle
ENV PATH $PATH:$GRADLE_HOME/bin

WORKDIR $GRADLE_HOME
RUN set -x \
  && apk add --no-cache wget \
  && wget https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip \
  && unzip gradle-${GRADLE_VERSION}-bin.zip \
  && rm gradle-${GRADLE_VERSION}-bin.zip

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
    # && cd ${ANDROID_HOME}/tools \
    # && echo y | ./android update sdk --all --no-ui --force --filter tools,platform-tools,${ANDROID_BUILD_TOOLS},${ANDROID_SDK},${ANDROID_EXTRA_SDK}

#Install python 2.7

ENV PATH /usr/local/bin:$PATH

ENV GPG_KEY C01E1CAD5EA2C4F0B8E3571504C367C218ADD4FF
ENV PYTHON_VERSION 2.7.13

RUN set -ex \
	&& apk add --no-cache --virtual .fetch-deps \
		gnupg \
		openssl \
		tar \
		xz \
	\
	&& wget -O python.tar.xz "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz" \
	&& wget -O python.tar.xz.asc "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz.asc" \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$GPG_KEY" \
	&& gpg --batch --verify python.tar.xz.asc python.tar.xz \
	&& rm -rf "$GNUPGHOME" python.tar.xz.asc \
	&& mkdir -p /usr/src/python \
	&& tar -xJC /usr/src/python --strip-components=1 -f python.tar.xz \
	&& rm python.tar.xz \
	\
	&& apk add --no-cache --virtual .build-deps  \
		bzip2-dev \
		coreutils \
		dpkg-dev dpkg \
		gcc \
		gdbm-dev \
		libc-dev \
		linux-headers \
		make \
		ncurses-dev \
		openssl \
		openssl-dev \
		pax-utils \
		readline-dev \
		sqlite-dev \
		tcl-dev \
		tk \
		tk-dev \
		zlib-dev \
# add build deps before removing fetch deps in case there's overlap
	&& apk del .fetch-deps \
	\
	&& cd /usr/src/python \
	&& gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
	&& ./configure \
		--build="$gnuArch" \
		--enable-shared \
		--enable-unicode=ucs4 \
	&& make -j "$(nproc)" \
	&& make install \
	\
	&& runDeps="$( \
		scanelf --needed --nobanner --recursive /usr/local \
			| awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
			| sort -u \
			| xargs -r apk info --installed \
			| sort -u \
	)" \
	&& apk add --virtual .python-rundeps $runDeps \
	&& apk del .build-deps \
	\
	&& find /usr/local -depth \
		\( \
			\( -type d -a -name test -o -name tests \) \
			-o \
			\( -type f -a -name '*.pyc' -o -name '*.pyo' \) \
		\) -exec rm -rf '{}' + \
	&& rm -rf /usr/src/python

# if this is called "PIP_VERSION", pip explodes with "ValueError: invalid truth value '<VERSION>'"
ENV PYTHON_PIP_VERSION 9.0.1

RUN set -ex; \
	\
	apk add --no-cache --virtual .fetch-deps openssl; \
	\
	wget -O get-pip.py 'https://bootstrap.pypa.io/get-pip.py'; \
	\
	apk del .fetch-deps; \
	\
	python get-pip.py \
		--disable-pip-version-check \
		--no-cache-dir \
		"pip==$PYTHON_PIP_VERSION" \
	; \
	pip --version; \
	\
	find /usr/local -depth \
		\( \
			\( -type d -a -name test -o -name tests \) \
			-o \
			\( -type f -a -name '*.pyc' -o -name '*.pyo' \) \
		\) -exec rm -rf '{}' +; \
	rm -f get-pip.py

# Install cocos2d-x
ARG COCOS2D_X_VERSION=3.15.1
ARG COCOS2D_X_VERSION_LINK=375

ENV PATH $PATH:/opt/cocos2d-x-$COCOS2D_X_VERSION/tools/cocos2d-console/bin

WORKDIR "/opt" 
RUN wget -O cocos2d-x-$COCOS2D_X_VERSION.zip http://cocos2d-x.org/filedown/start/$COCOS2D_X_VERSION_LINK && \
    unzip cocos2d-x-$COCOS2D_X_VERSION.zip && \
    rm cocos2d-x-$COCOS2D_X_VERSION.zip && \
    cd cocos2d-x-$COCOS2D_X_VERSION && \
    python setup.py

#Clean up
RUN apk update \
    && apk del .sdk-update-dependencies
