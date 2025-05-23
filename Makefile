__PHONY__: build build-testing

build:
	docker build --platform linux/amd64 -t pinetwork/pi-node-docker:organization_testnet2-v1.1-p19.6 -f Dockerfile .

build-testing:
	docker build --platform linux/amd64 -t pinetwork/pi-node-docker:testing -f Dockerfile.testing
