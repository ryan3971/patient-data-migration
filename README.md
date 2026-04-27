# Patient Data Migration

A Rails 8 web application for importing patient demographic records from CSV files into a PostgreSQL database. Clinicians upload a CSV, the application validates it, deduplicates records by health number, and displays a summary of what was created, skipped, or failed.

## Tech Stack

- **Ruby** 3.1.2
- **Rails** 8.1.3
- **PostgreSQL**
- **Hotwire** (Turbo + Stimulus) for page navigation
- **Propshaft** for assets
- **Solid Cache / Queue / Cable** (Rails 8 built-ins)

## Prerequisites

- Ruby 3.1.2 (use `rbenv` or `asdf`)
- PostgreSQL running locally
- Bundler

## Setup

```bash
# Install dependencies
bundle install

# Create and migrate the database
rails db:create db:migrate

# Start the server
rails server
```

The app is available at `http://localhost:3000`.

## Usage

1. Open the app in your browser.
2. Select a CSV file and click **Upload and Import**.
3. The results page shows how many patients were created, skipped, or failed, along with a detail table for any failed rows.

### Expected CSV Format

The CSV must include the following headers (case-sensitive, exact spacing):

| Header | Required | Notes |
|---|---|---|
| `health identifier` | Yes | Digits only |
| `health identifier province` | Yes | |
| `first name` | No | |
| `last name` | No | |
| `middle name` | No | |
| `phone` | No | |
| `email` | No | |
| `address 1` | No | |
| `address 2` | No | |
| `address province` | No | |
| `address city` | No | |
| `address postal code` | No | |
| `date of birth` | No | Parsed with `Date.parse` |
| `sex` | No | |

Rows with a missing or non-numeric health identifier are recorded as failures and do not halt the import.

## Design Decisions

### Row-by-row vs Bulk Insert

Row-by-row processing was chosen over bulk insert for the following reasons:

| Concern | Row-by-row | Bulk insert |
|---|---|---|
| Memory | One row in memory at a time | Entire CSV buffered |
| Bad rows | Skipped individually; rest continue | One bad row can abort the batch |
| Duplicate detection | `find_or_create_by` per row | Must pre-filter existing records |
| Complexity | Straightforward loop | More moving parts |

### Idempotency

Three options were considered when an identical file is re-uploaded:

- **A)** Overwrite everything
- **B)** Fill blanks only
- **C) Skip existing entirely** ← chosen

Option C was chosen because A and B require assumptions about update intent that would need explicit validation. It also keeps the import relationship clean: an `Import` record only points to patients it created. Allowing updates would complicate that relationship.

### Transaction Scope

Each row is wrapped in its own transaction. A save error on one row records a failure and moves on; it does not roll back the entire import. For a file with millions of rows, aborting the whole operation on one bad row is a poor use of time and resources.

### Table Count

A clinic table was considered but deemed out of scope. Header validation happens at import time against one fixed expected set. Different clinic formats would be addressed once clinics are properly modelled.

### Patient Address Columns

Address fields are kept on the `patients` table rather than split into a separate table. A separate table only makes sense when a patient may have multiple addresses. A strict one-to-one relationship is overhead for a join with no benefit.

### File Upload

MIME type checking is sufficient for a trusted internal tool. For a public-facing endpoint, content sniffing would be added. In a larger setup, the upload would go directly to S3 via a pre-signed URL — keeping large files off the app server — and the import job would be placed on an async queue. Virus scanning would also apply in that context.

### `pending` Status

The `Import` status begins at `running` in the current implementation. The `pending` state is reserved for a future async flow where uploaded files are queued before processing begins.

## Assumptions

- CSV headers are validated against one fixed expected set. Different clinic formats are a future problem, addressed when clinics are properly modelled.
- Health identifiers are expected to be numeric. Non-numeric values (e.g. `"unknow"`) are treated as invalid and recorded as failures rather than inserted.

## Scalability

The row-by-row approach keeps memory usage flat regardless of file size — only one row is in memory at a time. For files with millions of rows this avoids out-of-memory failures and means a bad row near the end of the file does not waste the work already done.

## Future Work

The `import_failures` table stores the row number, identity fields, and failure reason for every rejected row. A natural next feature would be reprocessing failed rows after the source data is corrected, without requiring a full re-upload.

## Architecture

### Models

**`Import`** — tracks a single file upload and its outcome.

| Column | Type | Notes |
|---|---|---|
| `filename` | string | Original filename |
| `status` | integer | `pending`, `running`, `complete`, `failed` |
| `total_rows` | integer | Row count from the CSV |
| `created_count` | integer | Patients created |
| `skipped_count` | integer | Rows skipped (patient already exists) |
| `failed_count` | integer | Rows that could not be processed |
| `error_message` | text | Set when status is `failed` |
| `started_at` / `completed_at` | datetime | |

**`Patient`** — a single patient record. Unique on `(health_number, health_number_province)`. Linked to the import that created it.

**`ImportFailure`** — one row per failed CSV row, recording the row number, the identity fields (if present), and the reason for failure. This table was added after discovering that a row had silently failed to be created with no way to identify which one — manual scanning does not scale to large files. The `health_number` column stores the raw string value that was present (e.g. `"unknow"`), even when it is invalid, so the failure is auditable.

### Service

`PatientImportService` is the single entry point for import processing:

1. Creates an `Import` record and sets it to `running`.
2. Parses the CSV with Ruby's standard library, normalising headers via `HEADER_MAP`.
3. Validates that all required headers are present (aborts the whole import if not).
4. Iterates rows: validates identity fields, checks for an existing patient, creates or skips, and records failures row-by-row.
5. Wraps patient creation in a database transaction per row so a save error only fails that row.
6. Sets the `Import` status to `complete` or `failed` when done and always returns the `Import` record.

### Controllers

**`ImportsController`**

| Action | Route | Description |
|---|---|---|
| `index` | `GET /` | Upload form |
| `create` | `POST /imports` | Validates the upload and delegates to `PatientImportService`, then redirects to `show` |
| `show` | `GET /imports/:id` | Displays the import result |

## Running Tests

```bash
rails test
```

Test files are located in `test/models/`. The test suite uses Minitest with parallel workers.

## Database

The application uses four PostgreSQL databases in production (via Rails 8 Solid adapters): the primary app database plus separate databases for the cache, job queue, and Action Cable. In development, only the primary database is used.

```bash
# Reset the database
rails db:drop db:create db:migrate
```
