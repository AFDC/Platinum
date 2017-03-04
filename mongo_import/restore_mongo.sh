#!/bin/bash
cd /var/import
tar -xzf platypus_dump.tar.gz
mongorestore --drop -d Platypus dump/Platypus
rm -rf dump
