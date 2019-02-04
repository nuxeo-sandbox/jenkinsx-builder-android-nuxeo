FROM jenkinsxio/builder-base:0.1.211

# Locale settings
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8

# Gradle
# ARG GRADLE_VERSION=4.6
# ARG GRADLE_DOWNLOAD_SHA_256=98bd5fd2b30e070517e03c51cbb32beee3e2ee1a84003a5a5d748996d4b1b915
# ENV GRADLE_HOME /opt/gradle

# RUN set -o errexit -o nounset \
# 	&& echo "Downloading Gradle" \
# 	&& wget -O gradle.zip "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip" \
# 	&& echo "Checking download hash" \
# 	&& echo "${GRADLE_DOWNLOAD_SHA_256} gradle.zip" | sha256sum -c - \
# 	&& echo "Installing Gradle" \
# 	&& unzip gradle.zip && mkdir -p /opt && mv "gradle-${GRADLE_VERSION}" "${GRADLE_HOME}/" \
# 	&& rm gradle.zip

# ENV PATH ${GRADLE_HOME}/bin:${PATH}

# # Add a symlink in $USER_HOME/.gradle to the gradle.properties file mounted as a secret in a read-only volume
# RUN mkdir -p /root/.gradle \
#   && ln -s /home/jenkins/.gradle/gradle.properties /root/.gradle/gradle.properties

# # Run the Gradle Daemon on container execution for subsequent builds to be faster
# CMD ["gradle"]

# # Android SDK
# ARG ANDROID_VERSION=4333796
# ARG ANDROID_DOWNLOAD_SHA_256=92ffee5a1d98d856634e8b71132e8a95d96c83a63fde1099be3d86df3106def9
# ENV ANDROID_HOME /opt/android-sdk-linux
# ENV PATH ${ANDROID_HOME}/tools:${ANDROID_HOME}/tools/bin:${ANDROID_HOME}/platform-tools:${PATH}

# RUN echo "Downloading Android SDK" \
#   && wget -O sdk-tools-linux.zip https://dl.google.com/android/repository/sdk-tools-linux-${ANDROID_VERSION}.zip \
#   && echo "Checking download hash" \
# 	&& echo "${ANDROID_DOWNLOAD_SHA_256} sdk-tools-linux.zip" | sha256sum -c - \
#   && echo "Installing Android SDK" \
#   && unzip sdk-tools-linux.zip -d android-sdk-linux && mv android-sdk-linux "${ANDROID_HOME}/" \
#   && rm sdk-tools-linux.zip
# RUN yes | sdkmanager --licenses
# RUN sdkmanager "platform-tools"
# RUN yes | sdkmanager \
#     "build-tools;23.0.1" \
#     "build-tools;25.0.0" \
#     "build-tools;25.0.1" \
#     "build-tools;25.0.2" \
#     "build-tools;25.0.3" \
#     "build-tools;26.0.1" \
#     "build-tools;26.0.3" \
#     "platforms;android-23" \
#     "platforms;android-25" \
#     "platforms;android-26" \
#     "platforms;android-26" \
#     "extras;android;m2repository" \
#     "extras;google;m2repository"

# # Node.js
# RUN curl -f --silent --location https://rpm.nodesource.com/setup_11.x | bash - \
#   && yum install -y nodejs gcc-c++ make

# # Yarn
# ARG YARN_VERSION=1.13.0
# RUN curl -f -L -o /tmp/yarn.tgz https://github.com/yarnpkg/yarn/releases/download/v${YARN_VERSION}/yarn-v${YARN_VERSION}.tar.gz \
# 	&& tar xf /tmp/yarn.tgz \
# 	&& mv yarn-v${YARN_VERSION} /opt/yarn \
# 	&& ln -s /opt/yarn/bin/yarn /usr/local/bin/yarn

# Ruby
# Inspired from https://github.com/drecom/docker-centos-ruby/blob/master/Dockerfile
ARG RUBY_VERSION=2.6.1
ARG RUBY_PATH=/usr/local
RUN yum -y install \
        epel-release \
        make \
        gcc \
        git \
        openssl-devel \
        zlib-devel \
        mysql-devel \
        redis \
        sqlite-devel
RUN git clone git://github.com/rbenv/ruby-build.git $RUBY_PATH/plugins/ruby-build \
  &&  $RUBY_PATH/plugins/ruby-build/install.sh
RUN ruby-build $RUBY_VERSION $RUBY_PATH/

ENV PATH $RUBY_PATH/bin:$PATH

RUN gem install bundler -N

# # RDoc
# RUN gem install rdoc

# # Fastlane
# RUN gem install fastlane -NV
# ENV FASTLANE_DISABLE_COLORS 1
