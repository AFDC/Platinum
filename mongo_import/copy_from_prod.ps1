scp root@159.203.99.230:/root/mongo_backup/platypus_dump.tar.gz .

tar -xzvf platypus_dump.tar.gz

docker cp dump/Platypus platinum-mongodb-1:/var/mongo_backup

docker exec platinum-mongodb-1 mongorestore --drop -d Platypus /var/mongo_backup

rm dump -Recurse


