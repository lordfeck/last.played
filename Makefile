INSTALLER := $(shell command -v cpanm 2>/dev/null || echo cpan)
PERL_DEPS = LWP Plack JSON Starman

.PHONY: check_root
check_root:
	@if [ "$$(id -u)" -ne 0 ]; then \
		echo "Error: This operation requires root privileges. Please run as sudo."; \
		exit 1; \
	fi

.PHONY: init
init:
	@echo "Using installer: $(INSTALLER)"
	$(INSTALLER) $(PERL_DEPS)

.PHONY: run
run:
	plackup --port 5010 last.played.psgi

.PHONY: install
install: check_root
	cp -v last.played.psgi /usr/local/bin/
	cp -v last.played.service /etc/systemd/system/
	touch /var/log/last.played.log && chown www-data /var/log/last.played.log
	systemctl daemon-reload
	systemctl enable last.played.service
