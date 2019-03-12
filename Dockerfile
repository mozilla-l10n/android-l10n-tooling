FROM python:3.7-slim-stretch AS builder

RUN echo "deb http://ftp.debian.org/debian stretch-backports main" > /etc/apt/sources.list.d/backports.list
RUN apt-get update
RUN apt-get upgrade -y
RUN apt-get -t stretch-backports install -y libgit2-27 libgit2-dev
# pygit2 needs to write binaries after install time
RUN apt-get install -y gcc
RUN pip3 install -U pip
RUN pip3 install pygit2==0.27.3
RUN pip3 install compare-locales==5.1.0
RUN find /usr/local/lib/python3.7/site-packages/ -name \*.so
# create pygit2 runtime binaries
RUN python3 -c 'import pygit2'
RUN find /usr/local/lib/python3.7/site-packages/ -name \*.so
COPY . /src/android-l10n-tooling
RUN pip3 install /src/android-l10n-tooling

FROM python:3.7-slim-stretch
WORKDIR /workdir/
RUN echo "deb http://ftp.debian.org/debian stretch-backports main" > /etc/apt/sources.list.d/backports.list
RUN apt-get update
RUN apt-get upgrade -y
RUN apt-get -t stretch-backports install -y libgit2-27
RUN apt-get install -y git

COPY --from=builder /usr/local/lib/python3.7/site-packages/ /usr/local/lib/python3.7/site-packages/
COPY --from=builder /usr/local/bin/compare-locales /usr/local/bin/compare-locales

RUN groupadd --gid 10001 app && useradd -g app --uid 10001 --shell /usr/sbin/nologin app
RUN chown app:app /workdir
USER app
