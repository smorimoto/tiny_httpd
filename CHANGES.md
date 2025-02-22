
## 0.11

- breaking: remove deprecated path handlers based on scanf
- breaking: more getter/setters for request/response, change signatures,
  make request/response private aliases

- fix: release semaphore in case of exception in accept

- feat: add a notion of Middleware
- feat: add `?middlewares` param to `create`
- feat: add `?get_time_s` param to `create`
- feat: close connection if response's headers contains connection
- feat: store `start_time` in request
- feat: implement connection timeout using socket options
  Default is `max_keep_alive = -1.0` which preserves the original behaviour.
- feat: in server-sent-events, add a `close()` function

- refactor(zip): compression is now a middleware
- perf: pass `buf_size` in many places, set default `buf_size` to 16kb
- example: update `echo` to provide a /stats/ endpoint using a middleware

## 0.10

- feat: allow socket activation by passing a raw unix socket to `create`
- fix: `Unix.accept` may raise an exception
  (typicall Unix.EINTR, even with sigpipe blocked ?),
  prevent the server from stopping

## 0.9

- support handlers that stream server-sent events to client

## 0.8

- bump to ocaml 4.04
- Validate header key's character set (#15)
- perf: simpler parsing of headers

- fix: workaround for css/js in `http_of_dir` (#16)
- fix(urlencode): encode non ascii chars

## 0.7

- feat: add `rest_of_path_urlencoded` and rename `rest` to `rest_of_path`
- feat: `http_of_dir`: redirect to index.html if present
- fix: `http_of_dir`: do not url-encode '/' in paths
- feat: add `Route.rest` to match the rest of the path
- feat: printing routes

## 0.6

- feat: add `Route.t` construct, deprecate scanf, add more structured path
- feat: use chunked encoding for large string responses, in addition to streams
- refactor(echo): simplify code, use gzip aggressively
- accept http1.0

- fix: do not output a `content-length` for a chunked response
- fix: set `transfer-encoding` header when returning a chunked stream
- fix(zip): handle case where camlzip consumes 0 bytes
- feat(zip): also compress string responses if they're big
- add more debug msg

## 0.5

- new `tiny_httpd_camlzip` library for handling `deflate` compression
- feat: expose `Headers.empty`
- fix: use the non-query path for routing
- feat(util): add some query related utils

## 0.4

- easy accessor to the query parameters in path
- fix: header field names are case insensitive
- doc: add note on jemalloc in the readme
- log error when closing client socket

## 0.3

- feat(http_of_dir): use `file` to guess mime type of file
- feat: allow handlers to take streams
- feat(bin): disable uploading by default
- feat: add `Tiny_httpd_util.parse_query` for query decoding
- feat(bin): set charset to utf8
- feat: autodetect ipv6 address
- feat: support ipv6 address

- fix: missing crlf between chunks
- fix: read_all must return rather than blocking when done
- fix: proper amortized O(1) push in Buf.push
- fix: `%X` for percent_encode; use `percent_decode` in `parse_query`

## 0.2

- feat(bin): count number of hidden files
- feat(bin): use `details` for hiding hidden files by default
- fix: improved percent encoding of paths
- feat: add percent encoding/decoding
- feat(bin): better human-size display
- feat: in http_of_dir, sort entries and display their size
- fix(http_of_dir): handle bad symlinks
- improve docs and opam, tidy up for 0.1
