
FROM    openjdk:8-jre
MAINTAINER  Martijn Koster "mak-docker@greenhills.co.uk"

# Override the solr download location with e.g.:
#   docker build -t mine --build-arg SOLR_DOWNLOAD_SERVER=http://www-eu.apache.org/dist/lucene/solr .
ARG SOLR_DOWNLOAD_SERVER

RUN apt-get update && \
  apt-get -y install lsof procps wget gpg && \
  rm -rf /var/lib/apt/lists/*

ENV SOLR_USER="solr" \
    SOLR_UID="8983" \
    SOLR_GROUP="solr" \
    SOLR_GID="8983" \
    SOLR_VERSION="6.6.2" \
    SOLR_URL="${SOLR_DOWNLOAD_SERVER:-https://archive.apache.org/dist/lucene/solr}/6.6.2/solr-6.6.2.tgz" \
    SOLR_SHA256="a41594888a30394df8819c36ceee727dd2ed0a7cd18b41230648f1ef1a8b0cd2" \
    SOLR_KEYS="2085660D9C1FCCACC4A479A3BF160FF14992A24C" \
    PATH="/opt/solr/bin:/opt/docker-solr/scripts:$PATH" \
	SOLR_Path="/opt/solr/server/solr"

RUN groupadd -r --gid $SOLR_GID $SOLR_GROUP && \
  useradd -r --uid $SOLR_UID --gid $SOLR_GID $SOLR_USER

RUN set -e; for key in $SOLR_KEYS; do \
    found=''; \
    for server in \
      ha.pool.sks-keyservers.net \
      hkp://keyserver.ubuntu.com:80 \
      hkp://p80.pool.sks-keyservers.net:80 \
      pgp.mit.edu \
    ; do \
      echo "  trying $server for $key"; \
      gpg --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$key" && found=yes && break; \
    done; \
    test -z "$found" && echo >&2 "error: failed to fetch $key from several disparate servers -- network issues?" && exit 1; \
  done; \
  exit 0

RUN mkdir -p /opt/solr && \
  echo "downloading $SOLR_URL" && \
  wget -nv $SOLR_URL -O /opt/solr.tgz && \
  echo "downloading $SOLR_URL.asc" && \
  wget -nv $SOLR_URL.asc -O /opt/solr.tgz.asc && \
  echo "$SOLR_SHA256 */opt/solr.tgz" | sha256sum -c - && \
  (>&2 ls -l /opt/solr.tgz /opt/solr.tgz.asc) && \
  gpg --batch --verify /opt/solr.tgz.asc /opt/solr.tgz && \
  tar -C /opt/solr --extract --file /opt/solr.tgz --strip-components=1 && \
  rm /opt/solr.tgz* && \
  rm -Rf /opt/solr/docs/ && \
  mkdir -p /opt/solr/server/solr/lib /opt/solr/server/solr/mycores /opt/solr/server/logs /docker-entrypoint-initdb.d /opt/docker-solr && \
  sed -i -e 's/"\$(whoami)" == "root"/$(id -u) == 0/' /opt/solr/bin/solr && \
  sed -i -e 's/lsof -PniTCP:/lsof -t -PniTCP:/' /opt/solr/bin/solr && \
  sed -i -e 's/#SOLR_PORT=8983/SOLR_PORT=8983/' /opt/solr/bin/solr.in.sh && \
  sed -i -e '/-Dsolr.clustering.enabled=true/ a SOLR_OPTS="$SOLR_OPTS -Dsun.net.inetaddr.ttl=60 -Dsun.net.inetaddr.negative.ttl=60"' /opt/solr/bin/solr.in.sh && \
  chown -R $SOLR_USER:$SOLR_GROUP /opt/solr

COPY scripts /opt/docker-solr/scripts
RUN chown -R $SOLR_USER:$SOLR_GROUP /opt/docker-solr

# Adding sitecore_master_index core
RUN cp -af sitecore_master_index $SOLR_PATH/sitecore_master_index
#COPY schema.xml $SOLR_PATH/sitecore_master_index/conf/
RUN echo name=sitecore_master_index > $SOLR_PATH/sitecore_master_index/core.properties

# Adding sitecore_web_index core
RUN cp -af $SOLR_PATH/configsets/basic_configs $SOLR_PATH/sitecore_web_index
#COPY schema.xml $SOLR_PATH/sitecore_web_index/conf/
RUN echo name=sitecore_web_index > $SOLR_PATH/sitecore_web_index/core.properties

# Adding sitecore_core_index core
RUN cp -af sitecore_core_index $SOLR_PATH/sitecore_core_index
#COPY schema.xml $SOLR_PATH/sitecore_core_index/conf/
RUN echo name=sitecore_core_index > $SOLR_PATH/sitecore_core_index/core.properties

# Adding sitecore_fxm_master_index core
RUN cp -af sitecore_fxm_master_index $SOLR_PATH/sitecore_fxm_master_index
#COPY schema.xml $SOLR_PATH/sitecore_fxm_master_index/conf/
RUN echo name=sitecore_fxm_master_index > $SOLR_PATH/sitecore_fxm_master_index/core.properties

# Adding sitecore_fxm_web_index core
RUN cp -af sitecore_fxm_web_index $SOLR_PATH/sitecore_fxm_web_index
#COPY schema.xml $SOLR_PATH/sitecore_fxm_master_index/conf/
RUN echo name=sitecore_fxm_web_index > $SOLR_PATH/sitecore_fxm_web_index/core.properties

# Adding sitecore_list_index core
RUN cp -af sitecore_list_index $SOLR_PATH/sitecore_list_index
#COPY schema.xml $SOLR_PATH/sitecore_list_index/conf/
RUN echo name=sitecore_list_index > $SOLR_PATH/sitecore_list_index/core.properties

# Adding sitecore_marketing_asset_index_master core
RUN cp -af sitecore_list_index $SOLR_PATH/sitecore_marketing_asset_index_master
#COPY schema.xml $SOLR_PATH/sitecore_marketing_asset_index_master/conf/
RUN echo name=sitecore_marketing_asset_index_master > $SOLR_PATH/sitecore_marketing_asset_index_master/core.properties

# Adding sitecore_marketing_asset_index_web core
RUN cp -af sitecore_marketing_asset_index_web $SOLR_PATH/sitecore_marketing_asset_index_web
#COPY schema.xml $SOLR_PATH/sitecore_marketing_asset_index_web/conf/
RUN echo name=sitecore_marketing_asset_index_web > $SOLR_PATH/sitecore_marketing_asset_index_web/core.properties

# Adding sitecore_marketingdefinitions_web core
RUN cp -af sitecore_marketingdefinitions_web $SOLR_PATH/sitecore_marketingdefinitions_web
#COPY schema.xml $SOLR_PATH/sitecore_marketingdefinitions_web/conf/
RUN echo name=sitecore_marketingdefinitions_web > $SOLR_PATH/sitecore_marketingdefinitions_web/core.properties

# Adding sitecore_master_index_sec core
RUN cp -af sitecore_master_index_sec $SOLR_PATH/sitecore_master_index_sec
#COPY schema.xml $SOLR_PATH/sitecore_fxm_master_index/conf/
RUN echo name=sitecore_master_index_sec > $SOLR_PATH/sitecore_master_index_sec/core.properties

# Adding sitecore_suggested_test_index core
RUN cp -af sitecore_suggested_test_index $SOLR_PATH/sitecore_suggested_test_index
#COPY schema.xml $SOLR_PATH/sitecore_fxm_master_index/conf/
RUN echo name=sitecore_suggested_test_index > $SOLR_PATH/sitecore_suggested_test_index/core.properties

# Adding sitecore_testing_index core
RUN cp -af sitecore_testing_index $SOLR_PATH/sitecore_testing_index
#COPY schema.xml $SOLR_PATH/sitecore_testing_index/conf/
RUN echo name=sitecore_testing_index > $SOLR_PATH/sitecore_testing_index/core.properties

# Adding sitecore_web_index_sec core
RUN cp -af sitecore_web_index_sec $SOLR_PATH/sitecore_web_index_sec
#COPY schema.xml $SOLR_PATH/sitecore_fxm_master_index/conf/
RUN echo name=sitecore_web_index_sec > $SOLR_PATH/sitecore_web_index_sec/core.properties

# Adding social_messages_master core
RUN cp -af social_messages_master $SOLR_PATH/social_messages_master
#COPY schema.xml $SOLR_PATH/social_messages_master/conf/
RUN echo name=social_messages_master > $SOLR_PATH/social_messages_master/core.properties

# Adding social_messages_web core
RUN cp -af social_messages_web $SOLR_PATH/social_messages_web
#COPY schema.xml $SOLR_PATH/sitecore_fxm_master_index/conf/
RUN echo name=social_messages_web > $SOLR_PATH/social_messages_web/core.properties



EXPOSE 8983
WORKDIR /opt/solr
USER $SOLR_USER

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["solr-foreground"]
