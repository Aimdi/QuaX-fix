# API response fixtures

Drop captured live X GraphQL / REST JSON here, one folder per endpoint or
operation name, for example:

```
test/fixtures/UserByScreenName/ok.json
test/fixtures/TweetDetail/ok.json
test/fixtures/SearchTimeline/ok.json
```

Rules:

- Redact auth tokens and personal secrets before committing.
- Prefer real responses over hand-written stubs — these characterize parser
  behavior against what X actually returns.
- When a parser change breaks a fixture test, treat it as a compatibility
  signal: either X changed shape, or the parser regressed.
