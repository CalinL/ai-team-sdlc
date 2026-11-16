# Notes API — PRD

- REQ-1 Create a note: `POST /notes` with `{ "text": "..." }` returns 201 and the note with an id.
- REQ-2 List and get: `GET /notes` returns every note; `GET /notes/:id` returns one or 404.
- REQ-3 Delete: `DELETE /notes/:id` returns 204, or 404 when it doesn't exist.
