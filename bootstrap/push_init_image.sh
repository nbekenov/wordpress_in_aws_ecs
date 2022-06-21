#!/usr/bin/env bash

aws ecr get-login-password --region us-east-1 --profile=xxxxxxxx | docker login --username AWS --password-stdin xxxxxxxx.dkr.ecr.us-east-1.amazonaws.com
docker build -t amazonlinux:latest .
docker tag amazonlinux:latest xxxxxxxx.dkr.ecr.us-east-1.amazonaws.com/xxxxxxxx:amazonlinux
docker push xxxxxxxx.dkr.ecr.us-east-1.amazonaws.com/xxxxxxxx:amazonlinux