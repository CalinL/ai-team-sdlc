# Architecture overview

One process, `node:http`, in-memory `Map` store behind a small module. JSON in and out; errors as
`{ "error": "<message>" }` with a 4xx/5xx status. No runtime dependencies.
