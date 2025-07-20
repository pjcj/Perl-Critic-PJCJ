.PHONY: show-deps install-deps reinstall-deps test format lint clean build \
        install cover cover-html cover-compilation cover-nvim

show-deps:
	@dzil listdeps --develop

install-deps:
	dzil listdeps --develop --missing | cpm install -g -

reinstall-deps:
	dzil listdeps --develop | cpm install -g --reinstall --no-prebuilt -

test:
	yath test -j20 --qvf --no-color -T --term-width=$(tput cols)

format:
	@mkdir -p tmp/perltidy
	@git ls-files '*.pl' '*.pm' '*.t' | while read file; do \
		if perltidy -b -bext=tdybak "$$file" >/dev/null 2>&1; then \
			if [[ -f "$$file.tdybak" ]]; then \
				if ! diff -q "$$file" "$$file.tdybak" >/dev/null 2>&1; then \
					echo "Formatted $$file"; \
				fi; \
				mv "$$file.tdybak" tmp/perltidy/; \
			fi; \
		fi; \
	done

lint:
	pre-commit run --all-files

clean:
	dzil clean

build: clean
	dzil build

install: build
	dzil install

cover: build
	cover --delete
	HARNESS_PERL_SWITCHES=-MDevel::Cover=+ignore,^t/ make test

cover-html: cover
	cover --report=html_basic --launch

cover-compilation: cover
	cover --report=compilation

cover-nvim: cover
	cover --report=nvim

cover-all: cover
	cover --report=nvim
	cover --report=compilation
