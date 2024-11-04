#!/bin/bash

###
# Инициализируем сервер конфигурации
###

echo "configSrv initiate"
docker compose exec -T configSrv mongosh --port 27017 --quiet <<EOF
rs.initiate({
  _id: "config_server",
  configsvr: true,
  members: [{ _id: 0, host: "configSrv:27017" }]
})
EOF

###
# Инициализируем шарды
###
echo "shard1 initiate"
docker compose exec -T mongodb-shard1-1 mongosh --port 27018 --quiet <<EOF
rs.initiate({
  _id: "shard1",
  members: [{ _id: 0, host: "shard1-1:27018" }, { _id: 1, host: "shard1-2:27018" }, { _id: 2, host: "shard1-3:27018" } ]
})
EOF

echo "shard2 initiate"
docker compose exec -T mongodb-shard2-1 mongosh --port 27019 --quiet <<EOF
rs.initiate({
  _id: "shard2",
  members: [{ _id: 0, host: "shard2-1:27019" }, { _id: 1, host: "shard2-2:27019" }, { _id: 2, host: "shard2-3:27019" }]
})
EOF

###
# Инициализируем роутер, шардируем коллекцию somedb и наполняем ее данными
###

echo "waiting for container initialization..."
sleep 10

echo "mongos_router add shards"
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
sh.addShard("shard1/shard1-1:27018")
sh.addShard("shard2/shard2-1:27019")

print("mongos_router enable sharding")
use somedb
sh.enableSharding("somedb")
db.createCollection("helloDoc")
db.helloDoc.createIndex({ _id: "hashed" })
sh.shardCollection("somedb.helloDoc", { _id: "hashed" })

print("mongos_router generate data")
use somedb
for(var i = 0; i < 1000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i})
EOF

