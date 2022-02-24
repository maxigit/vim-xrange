.PHONY: test
test:
		vim --not-a-term --noplugin -Nu mini.vimrc -c 'Vader! test/full.vader' > /dev/null
all:
		vim --not-a-term --noplugin -Nu mini.vimrc -c 'Vader! test/*' > /dev/null
v:
		vim --noplugin -Nu mini.vimrc -c 'Vader test/*'
c:
		vim --noplugin -Nu mini.vimrc -c 'Vader test/default.vader'

always:
.PHONY: always 
%.vader: always
		vim --noplugin -Nu mini.vimrc -c 'Vader! $@'
