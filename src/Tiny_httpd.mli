
(** {1 Tiny Http Server}

    This library implements a very simple, basic HTTP/1.1 server using blocking
    IOs and threads. Basic routing based on {!Scanf} is provided for convenience,
    so that several handlers can be registered.

    It is possible to use a thread pool, see {!create}'s argument [new_thread].
*)

type stream = {
  is_fill_buf: unit -> (bytes * int * int);
  (** See the current slice of the internal buffer as [bytes, i, len],
      where the slice is [bytes[i] .. [bytes[i+len-1]]].
      Can block to refill the buffer if there is currently no content.
      If [len=0] then there is no more data. *)
  is_consume: int -> unit;
  (** Consume n bytes from the buffer. This should only be called with [n <= len]
      after a call to [is_fill_buf] that returns a slice of length [len]. *)
  is_close: unit -> unit;
  (** Close the stream. *)
}
(** A buffered stream, with a view into the current buffer (or refill if empty),
    and a function to consume [n] bytes.
    See {!Buf_} for more details. *)

(** {2 Tiny buffer implementation}

    These buffers are used to avoid allocating too many byte arrays when
    processing streams and parsing requests.
*)
module Buf_ : sig
  type t
  val size : t -> int
  val clear : t -> unit
  val create : ?size:int -> unit -> t
  val contents : t -> string
end

(** {2 Generic stream of data}

  Streams are used to represent a series of bytes that can arrive progressively.
    For example, an uploaded file will be sent as a series of chunks. *)
module Stream_ : sig
  type t = stream

  val close : t -> unit

  val of_chan : in_channel -> t
  (** Make a buffered stream from the given channel. *)

  val of_chan_close_noerr : in_channel -> t
  (** Same as {!of_chan} but the [close] method will never fail. *)

  val of_bytes : ?i:int -> ?len:int -> bytes -> t
  (** A stream that just returns the slice of bytes starting from [i]
      and of length [len]. *)

  val with_file : string -> (t -> 'a) -> 'a
  (** Open a file with given name, and obtain an input stream
      on its content. When the function returns, the stream (and file) are closed. *)

  val read_line : ?buf:Buf_.t -> t -> string
  (** Read a line from the stream.
      @param buf a buffer to (re)use. Its content will be cleared. *)

  val read_all : ?buf:Buf_.t -> t -> string
  (** Read the whole stream into a string.
      @param buf a buffer to (re)use. Its content will be cleared. *)
end

module Meth : sig
  type t = [
    | `GET
    | `PUT
    | `POST
    | `HEAD
    | `DELETE
  ]
  (** A HTTP method.
      For now we only handle a subset of these.

      See https://tools.ietf.org/html/rfc7231#section-4 *)

  val pp : Format.formatter -> t -> unit
  val to_string : t -> string
end

module Headers : sig
  type t = (string * string) list
  (** The header files of a request or response.

      Neither the key nor the value can contain ['\r'] or ['\n'].
      See https://tools.ietf.org/html/rfc7230#section-3.2 *)

  val get : ?f:(string->string) -> string -> t -> string option
  (** [get k headers] looks for the header field with key [k].
      @param f if provided, will transform the value before it is returned. *)

  val set : string -> string -> t -> t
  (** [set k v headers] sets the key [k] to value [v].
      It erases any previous entry for [k] *)

  val remove : string -> t -> t
  (** Remove the key from the headers, if present. *)

  val contains : string -> t -> bool
  (** Is there a header with the given key? *)

  val pp : Format.formatter -> t -> unit
  (** Pretty print the headers. *)
end

(** {2 HTTP request}

    A request sent by a client. *)
module Request : sig
  type 'body t = {
    meth: Meth.t;
    headers: Headers.t;
    path: string;
    body: 'body;
  }
(** A request with method, path, headers, and a body.

    The body is polymorphic because the request goes through
    several transformations. First it has no body, as only the request
    and headers are read; then it has a stream body; then the body might be
    entirely read as a string via {!read_body_full}. *)

  val pp : Format.formatter -> string t -> unit
  (** Pretty print the request and its body *)

  val pp_ : Format.formatter -> _ t -> unit
  (** Pretty print the request without its body *)

  val headers : _ t -> Headers.t

  val get_header : ?f:(string->string) -> _ t -> string -> string option

  val get_header_int : _ t -> string -> int option

  val set_header : 'a t -> string -> string -> 'a t

  val meth : _ t -> Meth.t

  val path : _ t -> string

  val body : 'b t -> 'b

  val read_body_full : stream t -> string t
  (** Read the whole body into a string. Potentially blocking. *)
end

(** {2 Response code} *)
module Response_code : sig
  type t = int
  (** A standard HTTP code.

      https://tools.ietf.org/html/rfc7231#section-6 *)

  val ok : t
  (** The code [200] *)

  val not_found : t
  (** The code [404] *)

  val descr : t -> string
  (** A description of some of the error codes.
      NOTE: this is not complete (yet). *)
end

(** {2 Response}

    A response sent back to a client. *)
module Response : sig
  type body = [`String of string | `Stream of stream]
  (** Body of a response, either as a simple string,
      or a stream of bytes. *)

  type t = {
    code: Response_code.t; (** HTTP response code. See {!Response_code}. *)
    headers: Headers.t; (** Headers of the reply. Some will be set by [Tiny_httpd] automatically. *)
    body: body; (** Body of the response. Can be empty. *)
  }
  (** A response. *)

  val make_raw :
    ?headers:Headers.t ->
    code:Response_code.t ->
    string ->
    t
  (** Make a response from its raw components, with a string body.
      Use [""] to not send a body at all. *)

  val make_raw_stream :
    ?headers:Headers.t ->
    code:Response_code.t ->
    stream ->
    t
  (** Same as {!make_raw} but with a stream body. The body will be sent with
      the chunked transfer-encoding. *)

  val make :
    ?headers:Headers.t ->
    (body, Response_code.t * string) result -> t
  (** [make r] turns a result into a response.

      - [make (Ok body)] replies with [200] and the body.
      - [make (Error (code,msg))] replies with the given error code
        and message as body.
  *)

  val make_string :
    ?headers:Headers.t ->
    (string, Response_code.t * string) result -> t
  (** Same as {!make} but with a string body. *)

  val make_stream :
    ?headers:Headers.t ->
    (stream, Response_code.t * string) result -> t
  (** Same as {!make} but with a stream body. *)

  val fail : ?headers:Headers.t -> code:int ->
    ('a, unit, string, t) format4 -> 'a
  (** Make the current request fail with the given code and message.
      Example: [fail ~code:404 "oh noes, %s not found" "waldo"].
  *)

  val fail_raise : code:int -> ('a, unit, string, 'b) format4 -> 'a
  (** Similar to {!fail} but raises an exception that exits the current handler.
      This should not be used outside of a (path) handler.
      Example: [fail_raise ~code:404 "oh noes, %s not found" "waldo"; never_executed()]
  *)

  val pp : Format.formatter -> t -> unit
  (** Pretty print the response. *)
end

type t
(** A HTTP server. See {!create} for more details. *)

val create :
  ?masksigpipe:bool ->
  ?new_thread:((unit -> unit) -> unit) ->
  ?addr:string ->
  ?port:int ->
  unit ->
  t
(** Create a new webserver.

    The server will not do anything until {!run} is called on it.
    Before starting the server, one can use {!add_path_handler} and
    {!set_top_handler} to specify how to handle incoming requests.

    @param masksigpipe if true, block the signal {!Sys.sigpipe} which otherwise
    tends to kill client threads when they try to write on broken sockets. Default: [true].

    @param new_thread a function used to spawn a new thread to handle a
    new client connection. By default it is {!Thread.create} but one
    could use a thread pool instead.

    @param addr the address (IPv4) to listen on. Default ["127.0.0.1"].
    @param port to listen on. Default [8080].
    *)

val addr : t -> string
(** Address on which the server listen. *)

val port : t -> int
(** Port on which the server listen. *)

val add_decode_request_cb :
  t ->
  (unit Request.t -> (unit Request.t * (stream -> stream)) option) -> unit
(** Add a callback for every request.
    The callback can provide a stream transformer and a new request (with
    modified headers, typically).
    A possible use is to handle decompression by looking for a [Transfer-Encoding]
    header and returning a stream transformer that decompresses on the fly.
*)

val add_encode_response_cb:
  t -> (string Request.t -> Response.t -> Response.t option) -> unit
(** Add a callback for every request/response pair.
    Similarly to {!add_encode_response_cb} the callback can return a new
    response, for example to compress it.
    The callback is given the fully parsed query as well as the current
    response.
*)

val set_top_handler : t -> (string Request.t -> Response.t) -> unit
(** Setup a handler called by default.

    This handler is called with any request not accepted by any handler
    installed via {!add_path_handler}.
    If no top handler is installed, unhandled paths will return a [404] not found. *)

val add_path_handler :
  ?accept:(unit Request.t -> (unit, Response_code.t * string) result) ->
  ?meth:Meth.t ->
  t ->
  ('a, Scanf.Scanning.in_channel,
   'b, 'c -> string Request.t -> Response.t, 'a -> 'd, 'd) format6 ->
  'c -> unit
(** [add_path_handler server "/some/path/%s@/%d/" f]
    calls [f request "foo" 42 ()] when a request with path "some/path/foo/42/"
    is received.

    This uses {!Scanf}'s splitting, which has some gotchas (in particular,
    ["%s"] is eager, so it's generally necessary to delimit its
    scope with a ["@/"] delimiter. The "@" before a character indicates it's
    a separator.

    Note that the handlers are called in the reverse order of their addition,
    so the last registered handler can override previously registered ones.

    @param meth if provided, only accept requests with the given method.
    Typically one could react to [`GET] or [`PUT].
    @param accept should return [Ok()] if the given request (before its body
    is read) should be accepted, [Error (code,message)] if it's to be rejected (e.g. because
    its content is too big, or for some permission error).
    See the {!http_of_dir} program for an example of how to use [accept] to
    filter uploads that are too large before the upload even starts.
*)

val stop : t -> unit
(** Ask the server to stop. This might not have an immediate effect
    as {!run} might currently be waiting on IO. *)

val run : t -> (unit, exn) result
(** Run the main loop of the server, listening on a socket
    described at the server's creation time, using [new_thread] to
    start a thread for each new client. 

    This returns [Ok ()] if the server exits gracefully, or [Error e] if
    it exits with an error. *)

(**/**)

val _debug : ((('a, out_channel, unit, unit, unit, unit) format6 -> 'a) -> unit) -> unit
val _enable_debug: bool -> unit

(**/**)

