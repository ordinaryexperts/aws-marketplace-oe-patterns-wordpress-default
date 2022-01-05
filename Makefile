bash: build
	docker-compose run -w /var/www/app --service-ports --rm wordpress bash

build:
	docker-compose build wordpress

up: build
	docker-compose up
