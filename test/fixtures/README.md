# API response fixtures

Captured live X GraphQL JSON for parser characterization tests. Prefer real
responses over hand-written stubs.

## Present

| Path | Source | Used by |
|---|---|---|
| `UserByScreenName/ok.json` | Guest `UserByScreenName` for `@X` | `UserWithExtra.fromNonLegacyJson` |
| `TweetDetail/tweet_result.json` | Tweet node from guest `UserTweets` | `TweetWithCard.fromGraphqlJson` |
| `UserTweets/add_entries.json` | Slim `TimelineAddEntries` from guest `UserTweets` | `Twitter.createTweetChains` |

Guest `TweetDetail` returned 404; tweet shapes were taken from `UserTweets`
instead. No auth tokens are stored in these files.

## Rules

- Redact auth tokens and personal secrets before committing.
- When a parser change breaks a fixture test, treat it as a compatibility
  signal: either X changed shape, or the parser regressed.
- Optional next captures: authenticated `TweetDetail`, `SearchTimeline`,
  `HomeTimeline`, plus unavailable/tombstone shapes.
