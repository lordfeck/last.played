INSTALLER := $(shell command -v cpanm 2>/dev/null || echo cpan)
PERL_DEPS = LWP Plack

.PHONY: init
init:
	@echo "Using installer: $(INSTALLER)"
	$(INSTALLER) $(PERL_DEPS)

.PHONY: run
run:
	plackup --port 5000 last.played.psgi       

