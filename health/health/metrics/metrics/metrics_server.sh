#!/usr/bin/env bash

PORT=9105

while true; do
  {
    echo -e "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n"
    /metrics/node_metrics.sh
  } | nc -l -p $PORT -q 1
done
