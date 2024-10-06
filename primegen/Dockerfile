FROM bash

WORKDIR /job

COPY primegen.sh ./

RUN chmod +x ./primegen.sh

# ENTRYPOINT ["sleep", "3600"] # uncomment for debug container code

ENTRYPOINT ["bash", "./primegen.sh"]