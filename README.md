# hospital_app

Monorepo for a microservices-based hospital application. It includes:
- user_service: identity, authentication (issues JWT), and user data. Exposes REST and gRPC (mTLS).
- appointment_service: creates/updates appointments, validates users via gRPC, publishes events to RabbitMQ.
- appointment_history_service: consumes appointment events and serves GraphQL queries for history.
- notification_service: consumes appointment events and sends HTML emails.
- common: shared DTOs/utilities (messaging, error responses, pagination).
- jwt_security_common: shared JWT resource server config and public key support.
- proto_repo: shared protobuf definitions and generated gRPC classes.
- kong: declarative config for Kong API Gateway (optional for local usage).
- rabbitmq: RabbitMQ configuration and TLS materials.


## Prerequisites
- Docker and Docker Compose
- JDK 21 and Maven (if you want to run locally without Docker)


## Environment configuration (.env.example)
- In the repository root, there is a .env.example with all environment variables used by docker-compose.yml and services.
- Copy it to .env and adjust values as needed, especially:
  - NOTIFICATION_SERVICE_MAIL_USER and NOTIFICATION_SERVICE_MAIL_PASS (SMTP credentials)
  - Leave the default internal hostnames (e.g., user-service-db, appointment-service-db) when running via Docker Compose

Example:
  cp .env.example .env
  # then edit .env

This file drives:
- Database URLs, users, passwords for each service
- gRPC TLS configuration for user_service and the appointment_service client
- RabbitMQ TLS keystore/truststore locations and passwords
- Kong exposed ports

Refer to .env.example for the authoritative list and inline comments.


## Certificates and keys (IMPORTANT)
This project uses TLS/mTLS in two places:
- JWT signing/verification (user_service signs, other services verify)
- gRPC mTLS between appointment_service (client) and user_service (server)
- RabbitMQ TLS (keystore/truststore for AMQP over TLS)

Scripts are provided to generate required keys/certificates. Run them before building/running the stack for the first time.

Steps:

- FIRST OF ALL, go to the scripts folder and run the scripts from there:

```bash
    cd scripts/
```

1) Generate JWT key pair
- Location: run: ./JWT_keys_generator.sh
- What it does: creates user_service/src/main/resources/private.key and jwt_security_common/src/main/resources/public.key
- How to run:
    cd scripts
    bash JWT_keys_generator.sh

2) Generate service/RabbitMQ TLS materials
- Location: run: ./RabbitMQ_certs.sh
- Output locations commonly used by the stack:
  - user_service/src/main/resources/tls/ (user_service.crt, user_service_pkcs8.key, ca.crt)
  - appointment_service/src/main/resources/tls/ (appointment_service.crt, appointment_service_pkcs8.key, ca.crt)
  - rabbitmq/certs and rabbitmq/truststore/keystore files referenced by .env

3) Generate mTLS materials
- Location: run: ./mTLS_gRPC_certs_and_keys_generator.sh

Notes:
- If TLS files already exist in the repository (checked into version control) you may skip regeneration.
- Ensure filenames match the ones referenced in .env(.example) and application.yml files.

After generating keys/certs, rebuild the project so resources are packaged into JARs used by Docker images.


## Build (monorepo)
- To build everything locally (installs shared modules to your ~/.m2):
  mvn -q -DskipTests package

This compiles:
- proto_repo (generated sources and JAR)
- common and jwt_security_common
- All services


## Running with Docker Compose
1) Prepare .env (copy from .env.example) and generate certificates (see above).
2) From repository root, bring up the stack. Common options:
- Full stack (gateway + services + DBs + RabbitMQ):
  docker compose up -d
- Bring up only core services and dependencies:
  docker compose up -d user-service user-service-db appointment-service appointment-service-db appointment-history-service appointment-history-service-db notification-service notification-service-db rabbitmq

Exposed ports (host -> container):
- Kong: 8000->8000 (HTTP), 8443->8443 (HTTPS), 8001->8001 (Admin HTTP), 8444->8444 (Admin HTTPS)
- user_service: 8081->8080 (REST), 9090->9090 (gRPC), 5005->5005 (debug)
- appointment_service: 8082->8080 (REST), 5006->5005 (debug)
- notification_service: 8083->8080 (no public API), 5009->5005 (debug)
- appointment_history_service: 8084->8080 (GraphQL), 5008->5005 (debug)
- RabbitMQ (TLS): 5671->5671 (AMQP over TLS), 15671->15671 (mgmt over TLS)
- Postgres DBs: 5437 (user), 5435 (appointment), 5436 (history), 5438 (notification)

Helpful commands:
- View logs for a service:
  docker logs -f hospital-app-user-service
- Stop everything:
  docker compose down
- Rebuild a service image after code changes:
  docker compose build user-service

Note: The services mount a Maven cache volume (m2-repo) to speed up repeated builds in Docker.


## Test collection (Insomnia)
Folder: test_collection/insomnia
- Contains an Insomnia collection you can import to exercise the APIs.
- Typical usage:
  1) Import the collection into Insomnia (File -> Import -> From File/Folder)
  2) Adjust environment variables inside Insomnia as needed (base URLs, tokens)
  3) Use the following flows:
     - Authenticate on user_service (POST /login) to obtain a JWT
     - Use the JWT to access protected endpoints (/user/**, appointment_service endpoints, GraphQL queries)


## Service/module quick links
- User Service: user_service/README.md
- Appointment Service: appointment_service/README.md
- Appointment History Service: appointment_history_service/README.md
- Notification Service: notification_service/README.md
- Common: common/README.md
- JWT Security Common: jwt_security_common/README.md
- Proto repo: proto_repo/README.md


## API entry points
- user_service Swagger UI: http://localhost:8000/users/swagger-ui/index.html
- appointment_service Swagger UI: http://localhost:8000/appointments/swagger-ui/index.html
- appointment_history_service GraphQL: see [GRAPHQL_README.md](./GRAPHQL_README.md)
- user_service (base path with gateway): http://localhost:8000/users
- appointment_service (base path with gateway): http://localhost:8000/appointments
- appointment_history_service (base path with gateway): http://localhost:8000/history

## Security overview
- JWT: user_service issues RS256 tokens using private.key. Other services validate tokens using the public.key shipped in jwt_security_common.
- Roles are mapped from the claim "role" to ROLE_<ROLE> in Spring Security.
- gRPC: appointment_service connects to user_service with mTLS; certificates are loaded from service classpaths.
- RabbitMQ: all services use AMQP over TLS; keystore/truststore and passwords are defined in .env.


## Troubleshooting
- 401/403 on APIs: confirm Authorization: Bearer <JWT> and role requirements in each service README.
- gRPC TLS failures: ensure service certs and CA match, regenerate via scripts/tls if needed.
- RabbitMQ TLS errors: verify keystore/truststore files and passwords match .env and application.yml; check rabbitmq/conf/rabbitmq.conf.
- DB connection issues: ensure the corresponding *-db container is healthy (docker ps, docker logs) and ports are not occupied locally.
- Missing keys: re-run scripts/JWT_keys_generator.sh and scripts/tls/*, then rebuild (mvn package) and rebuild Docker images.


## Development notes
- Hexagonal architecture is used in each service: adapters in infra/adapter (in/out), ports in application layer, domain models isolated.
- Shared utilities live in common and jwt_security_common; keep contracts in proto_repo for gRPC.


## License
This repository is part of an educational/portfolio project. See root-level LICENSE if available.
