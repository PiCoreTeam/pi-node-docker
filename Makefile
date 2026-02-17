__PHONY__: build

build:
	docker build --platform linux/amd64 -t pinetwork/pi-node-docker:mainnet_relay-v1.1-p19.6 -f Dockerfile .
