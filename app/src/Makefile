all: pre-install deploy_dynamodb_table test

lint:
	pylint --disable=R,C,W src/handlers/*.py

test:
	python -m pytest -s -vvv tests/unit/ --junitxml=reports/unit.xml

pre-install:
	pip3 install -r requirements.txt


start-local:
	docker-compose up --build --force-recreate --no-deps  -d

stop-local:
	docker-compose down