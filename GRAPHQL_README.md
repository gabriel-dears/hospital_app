# GraphQL API (appointment_history_service)

This document describes the GraphQL schema and usage for the appointment_history_service, generated from:
- appointment_history_service/src/main/resources/graphql/schema.graphqls

The service exposes historical snapshots of appointments and supports filtering, pagination, and time scope (past, future, all).

Notes
- Authentication: Most GraphQL operations require a valid JWT (Authorization: Bearer <token>). GraphiQL/Voyager UIs may be publicly accessible, but queries still require JWT unless configured otherwise.
- Patient scoping: If the JWT role is PATIENT, queries are automatically scoped to that patient (the backend reads user_id from the token).


## Scalars
- UUID
- OffsetDateTime
- Date


## Pagination Types
- PageInfo
  - pageNumber: Int!
  - pageSize: Int!
  - totalPages: Int!
  - totalElements: Int!
  - isFirst: Boolean!
  - isLast: Boolean!

- AppointmentHistoryConnection
  - pageInfo: PageInfo!
  - content: [AppointmentHistoryResponse!]!


## Domain Types
- AppointmentHistoryResponse
  - id: UUID!
  - appointmentId: UUID!
  - patientId: UUID!
  - patientEmail: String!
  - patientName: String!
  - doctorId: UUID!
  - doctorName: String!
  - status: String!
  - dateTime: OffsetDateTime!
  - notes: String!
  - version: Int!


## Queries
- pastAppointmentHistoryByAppointmentId(
  - id: UUID!,
  - lastVersionOnly: Boolean = true,
  - page: Int = 0,
  - size: Int = 10
  ): AppointmentHistoryConnection!

- futureAppointmentHistoryByAppointmentId(
  - id: UUID!,
  - lastVersionOnly: Boolean = true,
  - page: Int = 0,
  - size: Int = 10
  ): AppointmentHistoryConnection!

- allAppointmentHistoryByAppointmentId(
  - id: UUID!,
  - lastVersionOnly: Boolean = true,
  - page: Int = 0,
  - size: Int = 10
  ): AppointmentHistoryConnection!

- pastAppointmentHistories(
  - lastVersionOnly: Boolean = true,
  - page: Int = 0,
  - size: Int = 10,
  - patientName: String,
  - doctorName: String,
  - status: String,
  - startDate: Date!,
  - endDate: Date!,
  - patientEmail: String
  ): AppointmentHistoryConnection!

- futureAppointmentHistories(
  - lastVersionOnly: Boolean = true,
  - page: Int = 0,
  - size: Int = 10,
  - patientName: String,
  - doctorName: String,
  - status: String,
  - startDate: Date!,
  - endDate: Date!,
  - patientEmail: String
  ): AppointmentHistoryConnection!

- allAppointmentHistories(
  - lastVersionOnly: Boolean = true,
  - page: Int = 0,
  - size: Int = 10,
  - patientName: String,
  - doctorName: String,
  - status: String,
  - startDate: Date!,
  - endDate: Date!,
  - patientEmail: String
  ): AppointmentHistoryConnection!


## Example Queries
1) By appointmentId (all, latest version only)

query {
  allAppointmentHistoryByAppointmentId(
    id: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
    lastVersionOnly: true,
    page: 0,
    size: 10
  ) {
    pageInfo { pageNumber pageSize totalPages totalElements isFirst isLast }
    content {
      id
      appointmentId
      patientId
      patientEmail
      patientName
      doctorId
      doctorName
      status
      dateTime
      notes
      version
    }
  }
}

2) Filtered list (past)

query {
  pastAppointmentHistories(
    lastVersionOnly: true,
    page: 0,
    size: 10,
    patientName: "Alice",
    doctorName: "Dr. Bob",
    status: "SCHEDULED",
    startDate: "2025-01-01",
    endDate: "2025-12-31",
    patientEmail: "alice@example.com"
  ) {
    pageInfo { pageNumber pageSize totalPages totalElements isFirst isLast }
    content { id appointmentId patientName doctorName status dateTime version }
  }
}


## Performing a request (curl)

- Replace <JWT> with a valid token from user_service /login.

curl -X POST \
   http://localhost:8000/history/graphql \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer <JWT>' \
  -d '{
    "query": "query { allAppointmentHistoryByAppointmentId(id: \"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee\", lastVersionOnly: true, page: 0, size: 10) { pageInfo { pageNumber } content { id status version } } }"
  }'


## Notes
- lastVersionOnly: true returns only the last known version per appointment at the selected time scope; set to false to see the full change history.
- Date vs OffsetDateTime: filters use Date (yyyy-MM-dd), while stored values are OffsetDateTime for precise timestamps.
- Patient role: If your token has role PATIENT, results get auto-scoped to your user_id.
