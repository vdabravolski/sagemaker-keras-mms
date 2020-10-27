FROM ubuntu:18.04

LABEL maintainer="vadimd@amazon.com"
# Set a docker label to advertise multi-model support on the container
LABEL com.amazonaws.sagemaker.capabilities.multi-models=false
# Set a docker label to enable container to use SAGEMAKER_BIND_TO_PORT environment variable if present
LABEL com.amazonaws.sagemaker.capabilities.accept-bind-to-port=true

ARG PYTHON=python3
ARG PIP=pip3
ARG TF_VERSION=2.1.0

# See http://bugs.python.org/issue19846
ENV LANG=C.UTF-8
# Python won’t try to write .pyc or .pyo files on the import of source modules
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Install necessary dependencies for MMS and SageMaker Inference Toolkit
RUN apt-get update && \
    apt-get -y install --no-install-recommends \
    build-essential \
    ca-certificates \
    openjdk-8-jdk-headless \
    python3-dev \
    curl \
    vim \
    && rm -rf /var/lib/apt/lists/* \
    && curl -O https://bootstrap.pypa.io/get-pip.py \
    && python3 get-pip.py

RUN apt-get update &&  \
    apt-get install -y libgl1-mesa-dev libglib2.0-0

# Install MXNet, MMS, and SageMaker Inference Toolkit to set up MMS
RUN ${PIP} --no-cache-dir install mxnet \
    multi-model-server \
    sagemaker-inference \
    retrying \
    opencv-python

########## Install Tensorflow

RUN ${PIP} --no-cache-dir install --upgrade pip setuptools

# cython, falcon, gunicorn, grpc
RUN ${PIP} install --no-cache-dir \
    awscli \
    cython==0.29.14 \
    falcon==2.0.0 \
    gunicorn==20.0.4 \
    gevent==1.4.0 \
    requests==2.22.0 \
    grpcio==1.27.1 \
    protobuf==3.11.1 \
    tensorflow==${TF_VERSION}

# Some TF tools expect a "python" binary
RUN ln -s $(which ${PYTHON}) /usr/local/bin/python

RUN curl https://tensorflow-aws.s3-us-west-2.amazonaws.com/MKL-Libraries/libiomp5.so -o /usr/local/lib/libiomp5.so
RUN curl https://tensorflow-aws.s3-us-west-2.amazonaws.com/MKL-Libraries/libmklml_intel.so -o /usr/local/lib/libmklml_intel.so

# Expose ports
# gRPC and REST
EXPOSE 8500 8501

######### End of TF install
RUN pwd
RUN ls

# Copy entrypoint script to the image
COPY serving_src/dockerd_entrypoint.py /usr/local/bin/dockerd-entrypoint.py
RUN chmod +x /usr/local/bin/dockerd-entrypoint.py

RUN mkdir -p /home/model-server/

# Copy the default custom service file to handle incoming data and inference requests
COPY serving_src/model_handler.py /opt/ml/model/model_handler.py
ADD serving_src/models /opt/ml/model/models

# Define an entrypoint script for the docker image
ENTRYPOINT ["python", "/usr/local/bin/dockerd-entrypoint.py"]

# Define command to be passed to the entrypoint
CMD ["serve"]



