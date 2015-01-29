# Zy

Zy is an application level protocol, defining a structure for requests and replies to a service. It draws from concepts of REST over HTTP. It encodes its structure as JSON, and is intended to be transported over ØMQ (ZeroMQ).

An example request from a client looks like:

```
{
  "zy_version": "0.0",
  "resource": "events",
  "action": "update",
  "params": {
    "name": "2004 summer olympics"
  },
  "body": {
    "location": "Athens, Greece"
  }
}
```

These are the fields present:

- zy_version: the version of the zy protocol in use
- resource: the name of the resource. this is analagous to the request path or URI in HTTP.
- action: the action to be performed. this is analagous to the request method in HTTP.
- params: parameters of the request. in this case specifying the identity of the resource in question.
- body: the main message which the server will act on. may not always be specified.

A reply to this might look like:

```
{
  "zy_version": "0.0",
  "status": ["success", "update"],
  "body": {
    "name": "2004 summer olympics",
    "location": "Athens, Greece",
    "year": "2004"
  }
}
```

- zy_version: again, the zy protocol version in use
- status: an array of strings, each being a short word to identify aspects of the status, in decreasing order of specificity. this is conceptually similar to an HTTP status code, but is human-readable and allows for more precision.
- body: the main message of the response to be conveyed back to the requester. may not always be specified - in this case, for example, it may have been omitted on the assumption that the client knows the identified resource and does not need a representation of it in the reply after the update.

