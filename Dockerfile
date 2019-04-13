FROM nimlang/nim

WORKDIR /app
RUN mkdir /app/config

COPY server.nim /app
RUN nim c -d:release -d:ssl server.nim

EXPOSE 5010
ENTRYPOINT ["./server"]
