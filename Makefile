__PHONY__: build build-deps build-deps-core build-deps-horizon

TAG?=organization-mainnet-v1.0-p23.0.1
CORE_REPO?=https://github.com/stellar/stellar-core.git
CORE_REF?=v23.0.1
CORE_CONFIGURE_FLAGS?=--disable-tests
HORIZON_REF?=horizon-v23.0.0

build-deps: build-deps-core build-deps-horizon

build-deps-core:
	docker build --platform linux/amd64 -t stellar-core:$(CORE_REF) -f Dockerfile.core . \
	  --build-arg REF="$(CORE_REF)" \
	  --build-arg CORE_REPO="$(CORE_REPO)" \
	  --build-arg CONFIGURE_FLAGS="$(CORE_CONFIGURE_FLAGS)"

build-deps-horizon:
	docker build --platform linux/amd64 -t stellar-horizon:$(HORIZON_REF) -f Dockerfile.horizon --target builder . --build-arg REF="$(HORIZON_REF)"

build:
	$(MAKE) build-deps
	docker build --platform linux/amd64 -t pinetwork/pi-node-docker:$(TAG) -f Dockerfile . \
	  --build-arg STELLAR_CORE_IMAGE_REF=stellar-core:$(CORE_REF) \
	  --build-arg HORIZON_IMAGE_REF=stellar-horizon:$(HORIZON_REF)
