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

**`ImportFailure`** — one row per failed CSV row, recording the row number, the identity fields (if present), and the reason for failure.

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
