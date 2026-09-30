SOURCES=optionfactory/docker-heist optionfactory/pinch
GPG_KEY=9FE6CDC2B377ECF54D7E974580C79C8962B033BB
BASE_URL=https://optionfactory.github.io/linux-packages
SITE=target/site

build:
	@./build.sh target $(GPG_KEY) $(BASE_URL) $(SOURCES)

publish: build
	@git -C $(SITE) init -q -b gh-pages
	@git -C $(SITE) add -A
	@git -C $(SITE) commit -q -m "publish"
	@git -C $(SITE) push -q -f "$$(git remote get-url origin)" gh-pages
	@echo "published $(BASE_URL)"

clean:
	-@rm -rf target

deps:
	@sudo apt install -y gh apt-utils createrepo-c rpm gnupg
	@command -v nfpm >/dev/null || { \
		tmp=$$(mktemp -d); \
		gh release download --repo goreleaser/nfpm --dir $$tmp --pattern '*_amd64.deb' --pattern checksums.txt \
		&& (cd $$tmp && sha256sum --quiet --ignore-missing -c checksums.txt) \
		&& sudo apt install -y $$tmp/nfpm_*_amd64.deb; \
		s=$$?; rm -rf $$tmp; exit $$s; }

.PHONY: build publish clean deps
