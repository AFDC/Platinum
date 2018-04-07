#!/bin/bash
tar -xzf platypus_dump.tar.gz
docker cp dump/Platypus platinum_mongodb_1:/var/mongo_backup/
MSYS_NO_PATHCONV=1 docker exec platinum_mongodb_1 mongorestore --drop -d Platypus /var/mongo_backup/Platypus
rm -rf dump
