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
#RUN echo '{"staticOrDhcp": "static", "ipAddress": "1.2.3.4", "subnetMask": "2.3.4.5", "dnsAddress": "123.211.1.4", "gateway": "9.9.9.9"}' > ip_config.json
RUN echo '{"staticOrDhcp": "dhcp", "ipAddress": "", "subnetMask": "", "dnsAddress": "", "gateway": ""}' > ip_config.json

RUN echo "hello from logfile!" > testik.txt

EXPOSE 5000
