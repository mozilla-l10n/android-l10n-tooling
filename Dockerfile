FROM python:3.7-slim-stretch

WORKDIR /workdir/
RUN apt-get update
RUN apt-get upgrade -y
RUN apt-get install -y git

RUN pip3 install -U pip wheel setuptools
COPY . /src/android-l10n-tooling
RUN pip3 install /src/android-l10n-tooling
RUN rm -rf /src

RUN groupadd --gid 10001 app && useradd -g app --uid 10001 --shell /usr/sbin/nologin app
RUN chown app:app /workdir
USER app
