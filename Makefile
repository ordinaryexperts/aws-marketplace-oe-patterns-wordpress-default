bash: build
	docker-compose run -w /app --rm wordpress bash

build:
	docker-compose build wordpress

up: build
	docker-compose up
