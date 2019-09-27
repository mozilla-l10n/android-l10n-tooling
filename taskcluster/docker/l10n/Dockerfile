# %ARG DOCKER_IMAGE_PARENT
FROM $DOCKER_IMAGE_PARENT
MAINTAINER Tom Prince <mozilla@hocat.ca>

VOLUME /builds/worker/checkouts

# %include setup.py
# %include setup.cfg
# %include src
ADD topsrcdir /setup/
RUN pip3 install /setup
RUN rm -rf /setup

