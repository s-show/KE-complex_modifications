all:
	scripts/update-json.sh
	scripts/erb2html.rb < src/index.html.erb > docs/index.html
	scripts/apply-lint.sh

rebuild:
	touch src/json/*
	$(MAKE) all
