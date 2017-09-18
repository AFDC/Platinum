#!/bin/bash
cd /var/import
tar -xzf platypus_dump.tar.gz
mongorestore --host $MONGODB_PORT_27017_TCP_ADDR --drop -d Platypus dump/Platypus
rm -rf dump
