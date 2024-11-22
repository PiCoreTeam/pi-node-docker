__PHONY__: build build-testing

build:
	docker build --platform linux/amd64 -t pinetwork/pi-node-docker:protocol18t1 -f Dockerfile .

build-testing:
	docker build --platform linux/amd64 -t stellar/quickstart:testing -f Dockerfile.testing
