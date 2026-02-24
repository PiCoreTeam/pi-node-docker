__PHONY__: build

build:
	docker build --platform linux/amd64 -t pinetwork/pi-node-docker:community-v1.0-p20.2 -f Dockerfile .
