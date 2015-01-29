# Zy

Zy is an application level protocol, defining a structure for requests and replies to a service. It draws from concepts of REST over HTTP.

It encodes its structure as JSON, and is intended to be transported over ØMQ (ZeroMQ).

A request from a client consists of a message with two frames, and an example looks like:

```
zy 0.0 json
```

```json
{
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

The first frame is called the protocol frame and sets up the basics, telling the server that the client is speaking the zy protocol, version 0.0. It indicates that the following message is formatted as JSON (JSON is currently the only supported format).

The next frame is the JSON-formatted request. It includes these fields:

- resource: the name of the resource. this is analagous to the request path or URI in HTTP.
- action: the action to be performed. this is analagous to the request method in HTTP.
- params: parameters of the request. in this case specifying the identity of the resource in question.
- body: the main message which the server will act on. may not always be specified.

A reply to this also consists of two frames and might look like:

```
zy 0.0 json
```

```json
{
  "status": ["success", "update"],
  "body": {
    "name": "2004 summer olympics",
    "location": "Athens, Greece",
    "year": "2004"
  }
}
```

The protocol frame is the same. The reply frame has these fields:

- status: an array of strings, each being a short word to identify aspects of the status, in decreasing order of specificity. this is conceptually similar to an HTTP status code, but is human-readable and allows for more precision.
- body: the main message of the response to be conveyed back to the requester. may not always be specified - in this case, for example, it may have been omitted on the assumption that the client knows the identified resource and does not need a representation of it in the reply after the update.
