oasis:
	oasis setup
	ocaml setup.ml -configure
oasis-test:
	oasis setup
	ocaml setup.ml -configure --enable-tests
all:
# https://stackoverflow.com/questions/16552834/how-to-use-thread-compiler-flag-with-ocamlbuild
	ocaml setup.ml -build -tag thread
install:
	ocaml setup.ml -uninstall
	ocaml setup.ml -install
uninstall:
	ocamlfind remove oqam