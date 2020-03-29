FROM ubuntu:18.04

ARG KUBECTL_VERSION=1.16.8
ENV CONFIGMAP_FIELD=file-sd-config.json CONFIGMAP_NAMESPACE=prometheus CONFIGMAP_NAME=prometheus

RUN apt-get update && apt-get install -y jq unzip curl \
      && curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
      && unzip awscliv2.zip && ./aws/install && rm awscliv2.zip && rm -rf aws \
      && curl "https://storage.googleapis.com/kubernetes-release/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" -o "kubectl" \
      && chmod +x kubectl && mv kubectl /usr/bin

COPY discovery.sh /opt/discovery.sh

CMD /opt/discovery.sh
