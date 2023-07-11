FROM bash

WORKDIR /job

COPY primegen.sh ./

RUN apk update && apk add curl jq

RUN chmod +x ./primegen.sh

# ENTRYPOINT ["sleep", "3600"]

ENTRYPOINT ["bash", "./primegen.sh"]

CMD ["42"]