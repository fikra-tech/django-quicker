
# default target
.DEFAULT_GOAL				:= run/server

# Variables commands
UV_RUN				:= uv run
DJANGO_RUN				:= $(UV_RUN) -m core.manage
PRE_COMMIT_CMD				:= $(UV_RUN) pre-commit
DOCKER_COMPOSE				:= docker compose
CARGO_INSTALL				:= cargo install


# Variables paths
DOCS_PATH				:= docs
PROJECT_SETTINGS_TEMPLATE_PATH		:= core/project/settings/templates/settings.dev.py
DOCKER_COMPOSE_DEV_PATH			:= docker-compose.dev.yaml


# Commands
.PHONY: sync
sync:
	uv sync --dev

.PHONY: install-pre-commit
install-pre-commit:
	$(PRE_COMMIT_CMD) uninstall && $(PRE_COMMIT_CMD) install

.PHONY: lint
lint:
	$(PRE_COMMIT_CMD) run --all-files


.PHONY: run/server
run/server:
	$(DJANGO_RUN) runserver


.PHONY: migrate
migrate:
	$(DJANGO_RUN) migrate

.PHONY: migrations
migrations:
	$(DJANGO_RUN) makemigrations

.PHONY: superuser
superuser:
	$(DJANGO_RUN) createsuperuser


.PHONY: app
app:
	$(eval name=$(filter-out $@,$(MAKECMDGOALS)))
	$(DJANGO_RUN) startapp $(name)
	mv $(name) core/
%:
	@:


.PHONY: local-settings
local-settings:
	if [ ! -f "local/settings.dev.py" ]; then mkdir local && cp $(PROJECT_SETTINGS_TEMPLATE_PATH) local/settings.dev.py; fi


.PHONY: update
update: install migrate install-pre-commit;

.PHONY: up-dependencies-only
up-dependencies-only:
	test -f .env || touch .env
	$(DOCKER_COMPOSE)  -f $(DOCKER_COMPOSE_DEV_PATH) up --force-recreate db


.PHONY: collectstatic
collectstatic:
	$(DJANGO_RUN) collectstatic

.PHONY: shell
shell:
	$(DJANGO_RUN) shell

.PHONY: api-version
api-version:
	$(DJANGO_RUN) shell -c "from django.conf import settings; print(settings.API_VERSION)"

.PHONY: image/build
image/build:
	@API_VERSION=$$($(DJANGO_RUN) shell -c "from django.conf import settings; print(settings.API_VERSION)") && \
	docker build -t hotmix:$$API_VERSION -t hotmix:latest .

.PHONY: docker/dev/build
docker/dev/build:
	$(DOCKER_COMPOSE) -f docker-compose.dev.yaml build

.PHONY: docker/dev/up
docker/dev/up:
	$(DOCKER_COMPOSE) -f docker-compose.dev.yaml up 

.PHONY: build-up
build-up:build up;

.PHONY: docker/down
docker/down:
	$(DOCKER_COMPOSE) down

.PHONY: install/cargo
install/cargo:
	curl --proto '=https' --tlsv1.2 https://sh.rustup.rs -sSf | sh

.PHONY: install/mdbook
install/mdbook:
	$(CARGO_INSTALL) mdbook


.PHONY: docs/build
docs/build:
	cd $(DOCS_PATH) && mdbook build

.PHONY: docs/serve
docs/serve:
	cd $(DOCS_PATH) && mdbook serve --open

.PHONY:migrations/clean
migrations/clean:
	find . -path "*/migrations/*.py" -not -name "__init__.py" -delete
	find . -path "*/migrations/*.pyc" -delete
	rm -rf db.sqlite3

.PHONY: zero
zero: migrations/clean migrations migrate superuser

.PHONY: deploy
deploy:
	$(DOCKER_COMPOSE) --env-file .env.prod up --build -d

# Provide quick help for common Makefile targets.
.PHONY: help
help:
	@echo "run 'make' to run the the django server"
	@echo ""
	@echo "or 'make <target>' where <target> is one of the following:"
	@echo ""
	@echo "  sync				Install the project dependencies"
	@echo "  install-pre-commit			Install pre-commit hooks"
	@echo "  lint					Run pre-commit hooks"
	@echo ""
	@echo "  run/server				Run the django server"
	@echo "  migrate				Apply migrations"
	@echo "  migrations				Create migrations"
	@echo "  migrattions/clean			Delete all migrations files"
	@echo "  superuser				Create superuser"
	@echo "  app <name>				Create a new app"
	@echo "  shell					Run the django shell"
	@echo ""
	@echo "  local-settings			Create local settings file"
	@echo "  update				Install dependencies, apply migrations and install pre-commit hooks"
	@echo "  up-dependencies-only			Up only the dependencies"
	@echo "  collectstatic				Collect static files"
	@echo "  zero					Delete all migrations files, apply migrations and create superuser"
	@echo ""
	@echo "  docker/build				Build the docker images"
	@echo "  docker/up				Up the docker containers"
	@echo "  build-up				Build and up the docker containers"
	@echo "  docker/down				Down the docker containers"
	@echo ""
	@echo "  install/cargo				Install cargo"
	@echo "  install/mdbook			Install mdbook"
	@echo "  docs/build				Build the documentation"
	@echo "  docs/serve				Serve the documentation"
	@echo ""
	@echo "For more information, see the README.md file."
