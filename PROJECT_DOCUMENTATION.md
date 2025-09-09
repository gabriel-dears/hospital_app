# 3. Project Documentation

This document presents a comprehensive and formal overview of the Hospital App microservices system. It consolidates the system architecture, interfaces, operational concerns, and detailed instructions for setup and execution. It is intended for architects, developers, and operators who require an authoritative reference to understand, deploy, and maintain the system.

References to supplementary material within this repository are provided throughout, including the root-level README.md (implementation and operations quick-start) and module-specific READMEs. The official repository is hosted at: https://github.com/gabriel-dears/hospital_app.


## 3.1 Executive Summary
The Hospital App is a microservices-based system designed to manage hospital operations related to users and appointments. It comprises distinct services responsible for identity and authentication, appointment creation and updates, notification delivery via email, and appointment history retrieval via GraphQL. Services communicate through REST, gRPC (with mutual TLS), and asynchronous messaging (RabbitMQ over TLS). Security is enforced using JWT-based resource servers and role-based access control.


## 3.2 System Overview
- System name: hospital_app
- Programming language and platform: Java 21, Spring Boot 3.5
- Deployment: Docker Compose for local and development environments
- Inter-service communication:
  - REST (HTTP) with OpenAPI documentation (Swagger UI)
  - gRPC with mutual TLS (mTLS) for service-to-service validation
  - Asynchronous messaging via RabbitMQ (TLS-enabled)
- Security: OAuth2 resource servers with JWT validation using a shared public key; role claims mapped to Spring authorities

Primary modules/services:
- user_service: Identity management, authentication (JWT issuance), user CRUD; exposes REST and gRPC server.
- appointment_service: Appointment creation/update; validates user identities via gRPC; publishes appointment events to RabbitMQ.
- appointment_history_service: GraphQL queries for the historical timeline of appointments; consumes appointment events.
- notification_service: Consumes appointment events and sends emails using template-based HTML content and retry semantics.
- common: Shared utilities, DTOs, error-handling helpers, and messaging configuration.
- jwt_security_common: Shared JWT resource server configuration and key utilities.
- proto_repo: Protobuf definitions and generated gRPC artifacts for inter-service contracts.

For a practical quick start, see the root README.md.


## 3.3 Architecture
### 3.3.1 Architectural Style
- Microservices with hexagonal (ports and adapters) internal organization for each service.
- Clear separation of inbound adapters (e.g., REST controllers, GraphQL resolvers, message listeners) and outbound adapters (e.g., repositories, gRPC clients, mail senders, message producers).

### 3.3.2 Components and Responsibilities
- user_service
  - REST API for user CRUD (/user), authentication (/login), and existence checks (/doctor/{id}/exists, /patient/{id}/exists).
  - gRPC server (UserService) providing GetUser and existence checks for doctor/patient IDs.
  - Security: JWT resource server for REST; TLS/mTLS for gRPC (configurable client authentication).
  - Persistence: PostgreSQL.

- appointment_service
  - REST API for creating and updating appointments.
  - Outbound gRPC client to user_service to validate doctor/patient identities and to fetch user information.
  - Publishes AppointmentMessage events to RabbitMQ fanout exchange (appointment.exchange).
  - Persistence: PostgreSQL.

- appointment_history_service
  - GraphQL API for querying appointment histories (past, future, all) with filtering and pagination.
  - Consumes AppointmentMessage events; persists historical snapshots.
  - Security: JWT resource server; patient scoping when the role is PATIENT.
  - Persistence: PostgreSQL.

- notification_service
  - Message-driven; consumes AppointmentMessage events to send HTML emails to patients.
  - Templates rendered with Thymeleaf; resilience via retry (Resilience4j).
  - Scheduled cleanup job removes obsolete records daily.
  - Persistence: PostgreSQL.

- common
  - DTOs (AppointmentMessage), error response factories, pagination models, and a Jackson-based RabbitMQ JSON converter bean.

- jwt_security_common
  - Shared configuration and utilities for JWT validation. Exposes a reusable OAuth2ResourceServer customizer and a JwtDecoder wired to classpath:public.key.

- proto_repo
  - Protobuf contracts and generated Java classes for the UserService gRPC API.

### 3.3.3 Cross-Cutting Concerns
- Authentication and Authorization
  - JWT tokens (RS256) are issued by user_service (private key) and validated across services via jwt_security_common (public key).
  - Role claim mapping: claim "role" -> ROLE_<ROLE> (e.g., ADMIN, DOCTOR, NURSE, PATIENT).

- Transport Security
  - gRPC client/server communication uses TLS/mTLS.
  - RabbitMQ connections are established over TLS using keystores/truststores.

- Observability and Operations (development/devops context)
  - Docker Compose managed services with health checks for databases and RabbitMQ.
  - Logs accessible via docker logs and Spring Boot console output.

### 3.3.4 Messaging Topology
- Exchange: appointment.exchange (fanout)
- Producers: appointment_service (publishes AppointmentMessage)
- Consumers: notification_service (notification.queue), appointment_history_service (history.queue)
- Serialization: JSON via Jackson2JsonMessageConverter (from common module)


## 3.4 Interfaces and API Endpoints
This section summarizes primary interaction points. For full, up-to-date endpoint details, consult service-specific Swagger UIs and the GraphQL documentation.

- API Gateway (optional local usage): Kong proxy exposed at http://localhost:8000 (as configured in docker-compose.yaml and kong/kong.yml).

- user_service (REST)
  - Swagger UI (via gateway): http://localhost:8000/users/swagger-ui/index.html
  - Direct (service port): http://localhost:8081/swagger-ui/index.html
  - Notable endpoints:
    - POST /login – authenticate and obtain JWT
    - /user – CRUD operations (ADMIN only)
    - GET /doctor/{id}/exists, GET /patient/{id}/exists – identity checks (authenticated)

- appointment_service (REST)
  - Swagger UI (via gateway): http://localhost:8000/appointments/swagger-ui/index.html
  - Direct (service port): http://localhost:8082/swagger-ui/index.html
  - Notable endpoints:
    - POST /appointment – create appointment (roles: NURSE, DOCTOR, ADMIN)
    - PUT /appointment/{id} – update appointment (roles: NURSE, DOCTOR, ADMIN)

- appointment_history_service (GraphQL)
  - GraphQL endpoint: http://localhost:8084/graphql
  - GraphiQL UI: http://localhost:8084/graphiql
  - Voyager: http://localhost:8084/voyager
  - For a detailed schema and samples, refer to GRAPHQL_README.md in the repository root.

- notification_service
  - Message-driven; no public HTTP API. Operationally observed via logs and database state.

For comprehensive API details, including request/response payloads and examples, consult:
- Root README.md, section “API entry points”
- user_service/README.md and appointment_service/README.md (REST)
- GRAPHQL_README.md and appointment_history_service/README.md (GraphQL)


## 3.5 Setup and Execution
This section provides a formal, stepwise procedure for preparing cryptographic materials, configuring the environment, building the system, and starting the services. For quick commands, see the root README.md.

### 3.5.1 Prerequisites
- Docker and Docker Compose
- JDK 21 and Apache Maven (if running services outside containers)

### 3.5.2 Environment Configuration
- Copy .env.example at the repository root to .env and adjust values for your environment. Key variables include:
  - Database connection strings, users, and passwords
  - JWT/gRPC certificates and paths
  - RabbitMQ TLS keystore/truststore paths and passwords
  - SMTP credentials for notification_service
- See .env.example for the authoritative list and commentary.

### 3.5.3 Cryptographic Materials (Certificates and Keys)
1) JWT key pair generation (required):
   - Navigate to scripts/ and run JWT_keys_generator.sh
   - Result: private.key for user_service; public.key for jwt_security_common
2) TLS materials for services and RabbitMQ (required for gRPC mTLS and AMQP over TLS):
   - Navigate to scripts/tls and execute the helper scripts sequentially (follow any numeric ordering in filenames)
   - Expected outputs:
     - user_service/src/main/resources/tls/: user_service.crt, user_service_pkcs8.key, ca.crt
     - appointment_service/src/main/resources/tls/: appointment_service.crt, appointment_service_pkcs8.key, ca.crt
     - rabbitmq/certs and related keystores/truststores referenced by .env
3) Rebuild after generation to ensure resources are packaged into service artifacts (especially when building Docker images).

### 3.5.4 Build (Monorepo)
- From the repository root, build all modules and services:
  - mvn -q -DskipTests package
- This step compiles and installs shared modules (proto_repo, common, jwt_security_common) into the local Maven repository for subsequent service builds and container image creation.

### 3.5.5 Execution (Docker Compose)
- Start the complete stack:
  - docker compose up -d
- Or selectively start components (example):
  - docker compose up -d user-service user-service-db appointment-service appointment-service-db appointment-history-service appointment-history-service-db notification-service notification-service-db rabbitmq

Exposed ports (host → container) include:
- user_service: 8081 → 8080 (REST), 9090 → 9090 (gRPC), 5005 → 5005 (debug)
- appointment_service: 8082 → 8080 (REST), 5006 → 5005 (debug)
- appointment_history_service: 8084 → 8080 (GraphQL), 5008 → 5005 (debug)
- notification_service: 8083 → 8080 (no public API), 5009 → 5005 (debug)
- RabbitMQ (TLS): 5671 → 5671 (AMQP), 15671 → 15671 (Management)
- Postgres: 5437 (user), 5435 (appointment), 5436 (history), 5438 (notification)
- Kong proxy (optional): 8000 (HTTP), 8443 (HTTPS), 8001 (Admin HTTP), 8444 (Admin HTTPS)

### 3.5.6 Post-Startup Verification
- Verify service health by accessing Swagger UIs and GraphiQL:
  - http://localhost:8081/swagger-ui/index.html (user_service)
  - http://localhost:8082/swagger-ui/index.html (appointment_service)
  - http://localhost:8084/graphiql and /graphql (appointment_history_service)
- Issue a token via user_service POST /login and use it to access protected endpoints.
- Observe RabbitMQ management UI (TLS): https://localhost:15671
- Tail service logs as needed, e.g., docker logs -f hospital-app-appointment-service


## 3.6 Security Model
- JWT (RS256): Tokens issued by user_service include claims such as sub, role, and user_id. Public key verification is performed by all resource servers via jwt_security_common.
- Role-Based Access Control: Spring Security enforces roles mapped from the "role" claim (e.g., ROLE_ADMIN, ROLE_DOCTOR, ROLE_NURSE, ROLE_PATIENT). Each service declares endpoint-specific access rules.
- Transport Security: gRPC endpoints use mTLS; RabbitMQ uses TLS with client certificates and trust anchors. Configuration is externalized via environment variables and Docker Compose.


## 3.7 Data and Persistence
- PostgreSQL databases per service ensure isolation of persistence and independent schema evolution.
- Schema management: Spring Data JPA with hibernate.ddl-auto governed by service-specific environment variables (default: update).
- Historical records: appointment_history_service maintains versioned snapshots keyed by appointment identifiers and timestamps.


## 3.8 Operations and Maintenance
- Logs and Diagnostics: Access via docker logs and service console output. Investigate connectivity, TLS, and authentication issues using logs and the RabbitMQ management UI.
- Credentials Management: Store SMTP and other sensitive values in the .env file (or secrets management in production). For Gmail SMTP usage, prefer application-specific passwords.
- Certificate Rotation: Re-run scripts in scripts/ and scripts/tls as appropriate, and rebuild images to include updated materials.


## 3.9 Troubleshooting (Selected Scenarios)
- 401/403 responses: Verify Authorization: Bearer <JWT>, role claims, and that the public/private key pair matches (regenerate if unsure).
- gRPC mTLS failures: Ensure certificate files are present under service classpaths, CA chains match, and client-auth settings are correct.
- RabbitMQ TLS errors: Confirm keystore/truststore paths and passwords correspond to packaged resources and .env; validate rabbitmq/conf/rabbitmq.conf settings.
- Database connectivity: Ensure the corresponding *-db container is healthy, credentials are correct, and ports are not occupied.
- Email delivery issues: Confirm SMTP credentials, provider settings (STARTTLS), and observe retry logs for failures.


## 3.10 Document References
- Root operations and quick-start: README.md (repository root)
- GraphQL schema and usage: GRAPHQL_README.md (repository root)
- Module/service details:
  - user_service/README.md
  - appointment_service/README.md
  - appointment_history_service/README.md
  - notification_service/README.md
  - common/README.md
  - jwt_security_common/README.md
  - proto_repo/README.md
- Official repository: https://github.com/gabriel-dears/hospital_app

This document is intentionally formal and structured to facilitate conversion to PDF for distribution and review. It should be read alongside the referenced READMEs to obtain the most granular and up-to-date operational details.