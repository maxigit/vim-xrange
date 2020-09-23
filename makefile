.PHONY: test
test:
		vim --not-a-term --noplugin -Nu mini.vimrc -c 'Vader! test/current.vader' > /dev/null
all:
		vim --not-a-term --noplugin -Nu mini.vimrc -c 'Vader! test/*' > /dev/null
v:
		vim --noplugin -Nu mini.vimrc -c 'Vader test/*'
c:
		vim --noplugin -Nu mini.vimrc -c 'Vader test/default.vader'
