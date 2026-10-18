### Library Management System

A Spring Boot REST API for managing books, authors, patrons and lendings, backed by MySQL. It is packaged as a container, deployed to Kubernetes with Helm, delivered through an approval-gated GitOps pipeline (GitHub Actions + Argo CD), and observed with Prometheus, Grafana, Loki and Jaeger.

#### Deployment and Operations:

- [docs/RUN.md](docs/RUN.md): prerequisites, Docker Compose, the full kind + Argo CD platform, access, releases, rollback, known limitations
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): components, request flow, commit-to-pod pipeline, release control, SLOs, failure boundaries, security
- [docs/EVIDENCE.md](docs/EVIDENCE.md): recorded runs of the pipeline, user journey, metrics/logs/traces, fault and recovery, rollback and drift demos, security checks

Baseline before the DevOps work: tag `baseline` = commit `05fd425`.

#### Quick start:

```bash
bash deploy/bootstrap-local.sh
```

```bash
kubectl -n argocd get application library
```

When it shows `Synced  Healthy`, the API answers on http://library.localhost/author. See [docs/RUN.md](docs/RUN.md) for details.

#### Models:

1. **Book:**
   - **Fields:**
      - Book ID (Auto Increment)
      - Title
      - Author
      - Genre
      - Publication Date
      - ISBN
   - **Relationships:**
      - Many-to-one with Author (each book has one author).
      - Genre is a fixed list (enum).

2. **Author:**
   - **Fields:**
      - ID (Auto Increment)
      - Name
      - Date of Birth

3. **Genre:** (enum) `FICTION`, `MYSTERY`, `THRILLER`, `SCIENCEFICTION`, `HISTORICALFICTION`

4. **Patron:**
   - **Fields:**
      - Patron ID (Auto Increment)
      - Name
      - Email
      - Registration Date

5. **Lending:**
   - **Fields:**
      - Lending ID (Auto Increment)
      - Book
      - Patron
      - Date Borrowed
      - Due Date
      - Date Returned
      - Lending Status (`BORROWED`, `RETURNED`)

#### Requests:

1. **Book Management:**
   - GET:
      - By Title: `/book/title/{title}`
      - By Author: `/book/author/{author}`
      - By Genre: `/book/genre/{genre}`
      - All: `/book`
   - POST: `/book`
   - PUT: `/book/{id}`
   - DELETE: `/book/{id}`

2. **Author Management:**
   - GET:
      - All: `/author`
   - POST: `/author`
   - PUT: `/author/{id}`
   - DELETE: `/author/{id}`

3. **Patron Management:**
   - GET:
      - By Id: `/patron/{id}`
      - All: `/patron`
   - POST: `/patron`
   - PUT: `/patron/{id}`
   - DELETE: `/patron/{id}`

4. **Lending Management:**
   - GET:
      - By Id: `/lending/{id}`
      - By Patron ID: `/lending/patron/{patronId}`
      - By Book Title: `/lending/book/{bookTitle}`
      - By Lending Date: `/lending/lendingDate/{date}`
      - By Due Date: `/lending/dueDate/{dueDate}`
      - By Status: `/lending/status/{status}`
      - All: `/lending`
   - POST: `/lending`
   - PUT: `/lending/{lendingId}`
   - DELETE: `/lending/{lendingId}`

#### Functionalities:

1. **Book Management:**
   - CRUD operations for Books.
   - Search books by title, author, or genre.

2. **Patron Management:**
   - CRUD operations for Patrons.
   - List all lendings of a specific patron.

3. **Lending Management:**
   - Check-out and check-in of books.
   - Find lendings by book, patron, date, due date or status.

#### Project Details:

- **RESTful API:** Spring Boot 3.5 on Java 21.
- **Database:** MySQL 8.4. The schema is versioned with Flyway (`src/main/resources/db/migration`); Hibernate only validates it.
- **ORM:** Hibernate (Spring Data JPA).
- **Logging:** one structured JSON line per API request (method, path, status, duration, trace ID).
- **Health and metrics:** Spring Boot Actuator health probes, `/actuator/info` with the git commit, and Prometheus metrics on a separate management port.
