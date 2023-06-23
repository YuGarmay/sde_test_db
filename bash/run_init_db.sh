#!/bin/bash
# Скачиваем Docker образ PostgreSQL
$ docker pull postgres
# Запускаем контейнер PostgreSQL
$ docker run --name psql_container -e POSTGRES_USER=test_sde -e POSTGRES_PASSWORD=@sde_password012 -e POSTGRES_DB=demo -v /$(pwd)/sql/init_db:/psql_container/data/ -p 5432:5432 -d postgres
sleep 5
# Запускаем скрипт для заполнения БД
$ docker cp C:/Users/YuGarmay/IdeaProjects/sde_test_db/sql/init_db/demo.sql psql_container:/var/lib/postgresql/data/
docker exec psql_container psql -U test_sde -d demo -f //var/lib/postgresql/data/demo.sql