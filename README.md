# Library API

A simple rails API for library to manage books, readers and loans, with email reminders
before and on the due date. 

Built with Ruby on Rails 8.1 (Ruby 3.4), PostgreSQL 17, Sidekiq and Redis.

## Quick start

```sh
docker compose up -d
```

Run this from the repository root. 

It starts PostgreSQL, Redis, the API on <http://localhost:3000> and a Sidekiq worker. 

On first start the seed data is inserted: 5 books, 8 copies (books and their copies are divided into 2 models) and
3 users-readers.

```sh
curl localhost:3000/api/book_copies
```

## Requirements 

| Requirement | Endpoint |
|---|---|
| 1. Add a new book | `POST /api/book_copies` |
| 2. Delete a book | `DELETE /api/book_copies/:id` |
| 3. List all books with availability | `GET /api/book_copies` |
| 4. Book details with full borrowing history | `GET /api/book_copies/:id` |
| 5. Update status: borrowed / available | `PATCH /api/book_copies/:id`, or `POST /api/book_copies/:id/loans` and `PUT /api/loans/:id/return` |
| Reminders 3 days before and on the due date | Daily Sidekiq job, see [Email reminders](#email-reminders) |

Extra endpoints: `GET /api/loans` (add `?open=true` for current loans only),
and `GET /api/readers` and `POST /api/readers`.

## API

All endpoints accept and return JSON.

### Books

```sh
# Add a copy of a new or existing title (the title is reused if title + author match)
curl -X POST localhost:3000/api/book_copies -H 'Content-Type: application/json' \
  -d '{"title": "Solaris", "author": "Stanisław Lem"}'

# Add another copy of a known title
curl -X POST localhost:3000/api/book_copies -H 'Content-Type: application/json' \
  -d '{"book_id": 1}'
```

`serial_number` is optional. If you leave it out, the next free six-digit number is
assigned. You can also pass one, for example the number printed on a barcode sticker.

```json
{
  "id": 1,
  "serial_number": 100000,
  "book_id": 1,
  "title": "Lalka",
  "author": "Bolesław Prus",
  "status": "borrowed",
  "current_loan": {
    "id": 1,
    "borrowed_at": "2026-11-23T12:00:00.000+01:00",
    "due_on": "2026-12-23",
    "returned_at": null,
    "reader": { "id": 1, "card_number": 123456, "full_name": "Jan Kowalski", "email": "jan.kowalski@example.pl" }
  }
}
```

`GET /api/book_copies/:id` returns the same fields plus `loans`, the full borrowing
history with the newest loan first.

### Borrowing and returning

```sh
# Borrow (identify the reader by card_number or reader_id). The loan is due in 30 days.
curl -X PATCH localhost:3000/api/book_copies/1 -H 'Content-Type: application/json' \
  -d '{"status": "borrowed", "card_number": 123456}'

# Return
curl -X PATCH localhost:3000/api/book_copies/1 -H 'Content-Type: application/json' \
  -d '{"status": "available"}'
```

The same actions are also available as loan endpoints:
`POST /api/book_copies/:id/loans` with `{"card_number": ...}`, and `PUT /api/loans/:id/return`.

### Readers

```sh
curl -X POST localhost:3000/api/readers -H 'Content-Type: application/json' \
  -d '{"full_name": "Maria Wiśniewska", "email": "maria@example.pl"}'
```

A unique six-digit `card_number` is issued automatically unless you pass one. Emails
are normalized (trimmed and lowercased) and must be unique.

### Errors

| Status | When |
|---|---|
| 400 | A required parameter is missing, e.g. `status` or the reader |
| 404 | The record doesn't exist, including archived copies |
| 409 | The copy is already borrowed or already available, or a borrowed copy is being deleted |
| 422 | Validation failed, e.g. duplicate serial or email, or an invalid email. The body is `{"errors": {"field": ["message"]}}` |

## Email reminders

Every loan lasts 30 days. Sidekiq runs `LoanRemindersJob` every day at 08:00
Europe/Warsaw (`config/schedule.yml`, via sidekiq-cron). The job sends:

- **3 days before the due date:** `LoanMailer#due_soon`
- **On the due date:** `LoanMailer#due_today`

No real email is sent. Each email is:

- **logged** as `[EMAIL] to=... subject=...` with its text body. See `docker compose logs sidekiq`.
- **saved** as HTML by [letter_opener](https://github.com/ryanb/letter_opener) in
  `api/tmp/letter_opener/`, which you can open in a browser.

To trigger reminders without waiting until 08:00:

```sh
docker compose exec api bin/rails runner '
  BookCopy.first.borrow!(Reader.first, at: 27.days.ago)  # due in 3 days
  LoanRemindersJob.perform_later'
docker compose logs sidekiq | grep -A3 EMAIL
```

## Tests and linting

```sh
docker compose exec -e RAILS_ENV=test api bin/rails db:create   # once, on a fresh clone
docker compose exec api bundle exec rspec
docker compose exec api bin/rubocop
```

- **Request specs:** every API endpoint, including error cases.
- **Job specs:** the reminder job.
- **Mailer specs:** both reminder emails.

## Design decisions

- **A book vs. a copy.** The task describes a "book" with a serial number, title and
  author. A library usually owns several copies of the same title, so the schema splits
  this into `books` (title, author) and `book_copies` (serial number). The API's
  "book" is a copy: that's what has a serial number and gets borrowed.
- **Loans are the history.** Borrowing creates a `loans` row (`borrowed_at`, `due_on`,
  `returned_at`, reader), and returning sets `returned_at`. A copy's status is derived
  from whether it has an open loan, so status and history can't disagree. A partial
  unique index guarantees at most one open loan per copy, even when two requests borrow
  the same copy at once; the second gets 409.
- **Status endpoint and loan endpoints.** `PATCH /book_copies/:id` with `status` follows
  the requirement's wording ("update the book status"). The loan endpoints are the
  resource-oriented equivalent. Both call the same model methods (`BookCopy#borrow!`,
  `Loan#return!`).
- **Serial numbers from a database sequence.** A PostgreSQL sequence
  (`START 100000 MAXVALUE 999999`) is the column default, so numbers are unique and
  safe under concurrent requests without application code. A CHECK constraint and a
  unique index enforce the six-digit range and uniqueness.
- **`structure.sql` instead of `schema.rb`.** `schema.rb` can't represent the custom
  sequence: it would be loaded as a plain `serial` starting at 1, which breaks the
  six-digit check on a fresh database. `structure.sql` keeps the sequence exactly,
  along with the CHECK constraints and partial indexes.
- **Delete archives copies with history.** Deleting a copy that was never borrowed
  removes it. A copy with loans gets `archived_at` instead and disappears from the API,
  so borrowing history (and readers' records) is kept. A borrowed copy can't be deleted.
- **Reminders are idempotent.** `three_day_reminder_sent_at` and
  `due_day_reminder_sent_at` record what was sent, so a re-run never sends a duplicate.
  The 3-day reminder looks at loans due in the next 1–3 days, so a missed daily run
  still sends it later.
- **Time zone.** The app runs in Europe/Warsaw, so due dates and "due today" follow the
  library's local calendar, not UTC.
- **Serialization.** [Alba](https://github.com/okuramasafumi/alba) resources in
  `app/resources/`.

## Limitations and ideas for improvement

- **No authentication or authorization**, as allowed by the task.
- **Development setup only.** Docker Compose runs Rails in development mode, with code
  mounted from the host. A production setup would need its own image, configuration
  and real email delivery (SMTP or a provider).
- **No pagination or filtering** on lists.
- **Readers can only be listed and created.** Updating, deleting and per-reader loan
  history are not implemented.
- **Card numbers are random.** If two readers are created at the same moment with the
  same random number, the second request gets 409 and has to be retried. A database
  sequence, as used for serial numbers, would remove this.
- **Serial numbers run out at 999 999**, about 900k copies. After that, the sequence
  raises an error.
- **No overdue handling.** After the due date there are no further reminders, fines or
  loan extensions.
- **No API documentation file.** An OpenAPI spec (e.g. via rswag from the request
  specs) would make the API easier to explore.
