FROM nimlang/nim

WORKDIR /app
RUN mkdir /app/config

COPY server.nim /app
RUN nim c -d:release server.nim

EXPOSE 5010
ENTRYPOINT ["./server"]
