SHELL = /bin/bash

build:
	docker build -t testcontainer .

run:
	docker build -t testcontainer .
	docker run -p 5000:5000 -it testcontainer /bin/bash

freeze:
	source ./.venv/bin/activate && pip list --format=freeze > requirements.txt

start:
	flask --app app run --host=0.0.0.0 
