SHELL = /bin/bash

build:
	docker build -t testcontainer .

run:
	docker build -t testcontainer .
	docker run -p 5000:5000 -it testcontainer /bin/bash

freeze:
	source ./.venv/bin/activate && pip list --format=freeze > requirements.txt

start:
	source ./.venv/bin/activate && python app.py
