__PHONY__: build build-testing

build:
	docker build --platform linux/amd64 -t pinetwork/pi-node-docker:p19.1t2 -f Dockerfile .

build-testing:
	docker build --platform linux/amd64 -t pinetwork/pi-node-docker:testing -f Dockerfile.testing
