bash: build
	docker-compose run -w /code --rm local bash

build:
	docker-compose build local
