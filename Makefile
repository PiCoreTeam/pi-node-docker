__PHONY__: build

build:
	docker build --platform linux/amd64 -t pinetwork/pi-node-docker:organization_mainnet-v1.4-p19.6 -f Dockerfile .
