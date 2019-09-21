
REGISTRY:=npodewitz
IMAGE_NAME:=lum
CONTAINER_NAME:=${IMAGE_NAME}
DOCKER_ADD_RUN_ARGS:=-p 80:80 -p 443:443
DOCKER_RUN_ARGS:=--name ${CONTAINER_NAME} --hostname ${CONTAINER_NAME} ${DOCKER_ADD_RUN_ARGS} --env-file startup.env
VERSION:=
DOCKERFILE:=Dockerfile


.PHONY: build build-nc build-debug run debug debug-exec stop up up-debug clean

build:
	docker build -f ${DOCKERFILE} -t ${IMAGE_NAME} .

build-nc:
	docker build --no-cache -f ${DOCKERFILE} -t ${IMAGE_NAME} .

build-debug:
	docker build --target BUILD -f ${DOCKERFILE} -t ${IMAGE_NAME} .

run:
	docker run ${DOCKER_RUN_ARGS} ${IMAGE_NAME}

debug:
	docker run -it ${DOCKER_RUN_ARGS} --entrypoint /bin/bash ${IMAGE_NAME}

debug-exec:
	docker exec -it ${CONTAINER_NAME} /bin/bash

stop:
	-docker stop ${CONTAINER_NAME}

up: clean build run

up-debug: clean build-debug run

clean: stop
	-docker rm -v ${CONTAINER_NAME}
