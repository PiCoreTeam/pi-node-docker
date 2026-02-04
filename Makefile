__PHONY__: build

build:
	docker build --platform linux/amd64 -t pinetwork/pi-node-docker:organization_mainnet-v1.0-p19.9 -f Dockerfile .
