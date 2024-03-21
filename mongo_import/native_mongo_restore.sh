#!/bin/bash
tar -xzf platypus_dump.tar.gz
mongorestore --drop
rm -rf dump
