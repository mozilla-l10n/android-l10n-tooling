ARG DOCKER_IMAGE_PARENT
FROM $DOCKER_IMAGE_PARENT
MAINTAINER Tom Prince <mozilla@hocat.ca>

VOLUME /builds/worker/checkouts

# %include setup.py
# %include setup.cfg
# %include src
ADD topsrcdir /setup/
RUN pip3 install /setup
RUN rm -rf /setup

ADD git-credential-taskcluster /usr/local/bin/
ADD gitconfig /etc/gitconfig
RUN chmod a+x /usr/local/bin/git-credential-taskcluster
RUN pip install taskcluster==19.0.0
RUN pip install git-pull-request==4.3.0
RUN apt-get update && apt-get install --yes vim
