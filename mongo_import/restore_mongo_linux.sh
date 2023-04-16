#!/bin/bash
tar -xzf platypus_dump.tar.gz
docker cp dump/Platypus platinum-mongodb-1:/var/mongo_backup/
MSYS_NO_PATHCONV=1 docker exec platinum-mongodb-1 mongorestore --drop -d Platypus /var/mongo_backup/
rm -rf dump
