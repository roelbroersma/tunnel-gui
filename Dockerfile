FROM python:3.9.12-bullseye
RUN curl -sSL https://install.python-poetry.org | python -
ENV PATH /root/.local/bin:$PATH

RUN mkdir project
COPY pyproject.toml project/
COPY poetry.lock project/
WORKDIR ./project

RUN poetry config virtualenvs.in-project true
RUN poetry install --no-root

COPY . .
RUN echo "defaultpassword" > web_password.txt

EXPOSE 5000
