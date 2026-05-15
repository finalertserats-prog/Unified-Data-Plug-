.PHONY: doctor install start stop restart bootstrap smoke-test logs status clean

doctor:
	./udp doctor

install:
	bash install.sh

start:
	./udp start

stop:
	./udp stop

restart:
	./udp restart

bootstrap:
	./udp bootstrap

smoke-test:
	./udp smoke-test

logs:
	./udp logs

status:
	./udp status

clean:
	./udp clean
