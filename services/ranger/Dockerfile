# Apache Ranger admin built from upstream source.
# First-time build ~10 minutes (clones apache/ranger, runs Maven build).
# Provides the policy-admin plane only. StarRocks enforcement is roadmap v0.4.

FROM maven:3.9-eclipse-temurin-17 AS build

ARG RANGER_VERSION=release-ranger-2.4.0
ARG RANGER_REPO=https://github.com/apache/ranger.git

WORKDIR /src
RUN git clone --depth 1 --branch ${RANGER_VERSION} ${RANGER_REPO} ranger
WORKDIR /src/ranger
RUN mvn -q -DskipTests -pl security-admin -am package

FROM eclipse-temurin:17-jre

ENV RANGER_HOME=/opt/ranger-admin
RUN mkdir -p ${RANGER_HOME}

COPY --from=build /src/ranger/security-admin/target/ranger-*-admin.tar.gz /tmp/ranger-admin.tar.gz
RUN tar -xzf /tmp/ranger-admin.tar.gz -C ${RANGER_HOME} --strip-components=1 \
    && rm /tmp/ranger-admin.tar.gz

COPY install.sh ${RANGER_HOME}/install.sh
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh ${RANGER_HOME}/install.sh

EXPOSE 6080
ENTRYPOINT ["/entrypoint.sh"]
