__PHONY__: build

build:
	docker build --platform linux/amd64 -t pinetwork/pi-node-docker:mainnet_relay-v1.0-p19.9 -f Dockerfile .
