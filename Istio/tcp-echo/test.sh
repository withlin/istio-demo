for i in {1..10}; do \
docker run  -it --rm busybox sh -c "(date; sleep 1) | nc 172.18.17.86 30620"; \
done