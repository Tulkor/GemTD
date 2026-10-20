# TD-Hub-Relay als fertiges Image (ohne RUN-Schritte, baut deshalb auch für ARM ohne Emulation).
#   docker build -t tdhub-relay tools/relay      oder fertig: tools/relay/image_bauen.sh
ARG BASE=python:3.12-alpine
FROM ${BASE}
COPY relay.py /relay/relay.py
USER 65534:65534
EXPOSE 24565/tcp
ENTRYPOINT ["python", "-u", "-I", "/relay/relay.py"]
CMD ["--port=24565"]
