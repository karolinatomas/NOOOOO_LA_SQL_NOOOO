#!/bin/bash

mongosh <<EOF
use admin;
db.createUser({user: "admin", pwd: "heslo_123", roles:[{role: "root", db: "admin"}]});
exit;
EOF


