__PHONY__: build build-deps build-deps-core build-deps-horizon build-deps-rpc

TAG?=mainnet-relay-v1.0-p23.0.1
CORE_REPO?=https://github.com/stellar/stellar-core.git
CORE_REF?=v23.0.1
CORE_CONFIGURE_FLAGS?=--disable-tests
HORIZON_REF?=horizon-v23.0.0
RPC_REPO?=https://github.com/stellar/stellar-rpc.git
RPC_REF?=v23.0.4

build-deps: build-deps-core build-deps-horizon build-deps-rpc

build-deps-core:
	docker build --platform linux/amd64 -t stellar-core:$(CORE_REF) -f Dockerfile.core . \
	  --build-arg REF="$(CORE_REF)" \
	  --build-arg CORE_REPO="$(CORE_REPO)" \
	  --build-arg CONFIGURE_FLAGS="$(CORE_CONFIGURE_FLAGS)"

build-deps-horizon:
	docker build --platform linux/amd64 -t stellar-horizon:$(HORIZON_REF) -f Dockerfile.horizon --target builder . --build-arg REF="$(HORIZON_REF)"

build-deps-rpc:
	docker build --platform linux/amd64 -t stellar-rpc:$(RPC_REF) -f Dockerfile.rpc . \
	  --build-arg REF="$(RPC_REF)" \
	  --build-arg RPC_REPO="$(RPC_REPO)"

build:
	$(MAKE) build-deps
	docker build --platform linux/amd64 -t pinetwork/pi-node-docker:$(TAG) -f Dockerfile . \
	  --build-arg STELLAR_CORE_IMAGE_REF=stellar-core:$(CORE_REF) \
	  --build-arg HORIZON_IMAGE_REF=stellar-horizon:$(HORIZON_REF) \
	  --build-arg STELLAR_RPC_IMAGE_REF=stellar-rpc:$(RPC_REF)
