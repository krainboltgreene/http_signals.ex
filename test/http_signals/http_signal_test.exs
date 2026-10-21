defmodule HTTPSignals.HTTPSignalTest do
  use HTTPSignals.DataCase, async: true
  use Machete

  describe "casting remote_ip" do
    test "when given a map" do
      {:ok, http_signal} =
        HTTPSignals.create_http_signal(%{
          service: "edge",
          context_id: Ecto.UUID.generate(),
          source: :them,
          stacktrace: HTTPSignals.current_stacktrace(),
          request: %{
            method: :get,
            scheme: :https,
            remote_ip: {127, 0, 0, 0},
            port: 80,
            path: "/",
            headers: [
              ["host", "dashboard.tryedge.io"]
            ]
          }
        })

      assert http_signal
             ~> struct_like(HTTPSignals.HTTPSignal,
               request:
                 struct_like(HTTPSignals.HTTPSignal.Request,
                   remote_ip: %{address: [127, 0, 0, 0], netmask: 32}
                 )
             )
    end
  end

  describe "with a list of arrays as headers" do
    test "correctly casts headers" do
      {:ok, %{id: id}} =
        HTTPSignals.create_http_signal(%{
          service: "edge",
          context_id: Ecto.UUID.generate(),
          source: :them,
          stacktrace: HTTPSignals.current_stacktrace(),
          request: %{
            method: :post,
            scheme: "https",
            remote_ip: {127, 0, 0, 0},
            port: 8080,
            path: "/webhooks/edge",
            headers: [
              ["content-type", "text/json"],
              ["accept", "text/xml"],
              ["host", "dashboard.tryedge.io"]
            ]
          }
        })

      http_signal = HTTPSignals.get_http_signal(id)

      assert match?(
               %HTTPSignals.HTTPSignal{
                 request: %{
                   headers: [
                     ["content-type", "text/json"],
                     ["accept", "text/xml"],
                     ["host", "dashboard.tryedge.io"]
                   ]
                 }
               },
               http_signal
             )
    end
  end

  describe "with a list of tuples as headers" do
    test "correctly casts headers" do
      {:ok, %{id: id}} =
        HTTPSignals.create_http_signal(%{
          service: "edge",
          context_id: Ecto.UUID.generate(),
          source: :them,
          stacktrace: HTTPSignals.current_stacktrace(),
          request: %{
            method: :post,
            scheme: :https,
            remote_ip: {127, 0, 0, 0},
            port: 8080,
            path: "/webhooks/edge",
            headers: [
              {"content-type", "text/json"},
              {"host", "dashboard.tryedge.io"},
              {"accept", "text/xml"}
            ]
          }
        })

      http_signal = HTTPSignals.get_http_signal(id)

      assert match?(
               %HTTPSignals.HTTPSignal{
                 request: %{
                   headers: [
                     ["content-type", "text/json"],
                     ["host", "dashboard.tryedge.io"],
                     ["accept", "text/xml"]
                   ]
                 }
               },
               http_signal
             )
    end
  end

  describe "with a map as headers" do
    test "correctly casts headers" do
      {:ok, %{id: id}} =
        HTTPSignals.create_http_signal(%{
          service: "edge",
          context_id: Ecto.UUID.generate(),
          source: :them,
          stacktrace: HTTPSignals.current_stacktrace(),
          request: %{
            method: :post,
            scheme: "https",
            remote_ip: {127, 0, 0, 0},
            port: 8080,
            path: "/webhooks/edge",
            headers: %{
              "content-type" => "text/json",
              "accept" => "text/xml",
              "host" => "dashboard.tryedge.io"
            }
          }
        })

      http_signal = HTTPSignals.get_http_signal(id)

      assert match?(
               %HTTPSignals.HTTPSignal{
                 request: %{
                   headers: [
                     ["accept", "text/xml"],
                     ["content-type", "text/json"],
                     ["host", "dashboard.tryedge.io"]
                   ]
                 }
               },
               http_signal
             )
    end
  end

  describe "recording inbound request" do
    test "requires a stacktrace when creating a http signal" do
      assert {:error, changeset} =
               HTTPSignals.create_http_signal(%{
                 service: "edge",
                 context_id: Ecto.UUID.generate(),
                 source: :us,
                 request: %{
                   method: :post,
                   scheme: :https,
                   host: "example.com",
                   port: 7400,
                   path: "/foo/bar/baz",
                   query: %{},
                   headers: [
                     ["content-type", "text/json"],
                     ["accept", "text/xml"]
                   ]
                 }
               })

      assert {"can't be blank", _metadata} = changeset.errors[:stacktrace]
    end

    test "stores a nxdomain error" do
      {:ok, http_signal} =
        HTTPSignals.create_http_signal(%{
          service: "edge",
          context_id: Ecto.UUID.generate(),
          source: :us,
          stacktrace: HTTPSignals.current_stacktrace(),
          request: %{
            method: :post,
            scheme: :https,
            host: "example.com",
            port: 7400,
            path: "/foo/bar/baz",
            query: %{"a" => 1, "b" => %{"z" => 1}, "c" => 3},
            headers: [
              ["content-type", "text/json"],
              ["accept", "text/xml"]
            ],
            body: "{\"a\": 1}"
          }
        })

      {:ok, http_signal} =
        HTTPSignals.TestRepo.update(
          HTTPSignals.HTTPSignal.with_rejection_changeset(
            http_signal,
            %Req.TransportError{reason: :nxdomain}
          )
        )

      http_signal = HTTPSignals.get_http_signal(http_signal.id)

      assert http_signal
             ~> struct_like(HTTPSignals.HTTPSignal,
               rejection:
                 struct_like(HTTPSignals.HTTPSignal.Rejection,
                   type: "Elixir.Req.TransportError",
                   details: %{"reason" => "nxdomain"}
                 )
             )
    end

    test "correctly stores when done in one go" do
      stacktrace = HTTPSignals.current_stacktrace()

      {:ok, http_signal} =
        HTTPSignals.create_http_signal(%{
          service: "edge",
          context_id: Ecto.UUID.generate(),
          source: :us,
          stacktrace: stacktrace,
          request: %{
            method: :post,
            scheme: :https,
            host: "example.com",
            port: 7400,
            path: "/foo/bar/baz",
            query: %{"a" => 1, "b" => %{"z" => 1}, "c" => 3},
            headers: [
              ["content-type", "text/json"],
              ["accept", "text/xml"]
            ],
            body: "{\"a\": 1}",
            data: %{"a" => 1}
          },
          response: %{
            status: 200,
            headers: [
              ["content-type", "text/json"],
              ["accept", "text/xml"]
            ],
            body: "{\"a\": 1}",
            data: %{"a" => 1},
            sent_at: DateTime.utc_now()
          }
        })

      http_signal = HTTPSignals.get_http_signal(http_signal.id)

      assert http_signal
             ~> struct_like(HTTPSignals.HTTPSignal,
               service: "edge",
               context_id: string(),
               source: :us,
               stacktrace: stacktrace,
               request:
                 struct_like(HTTPSignals.HTTPSignal.Request,
                   method: :post,
                   scheme: :https,
                   host: "example.com",
                   port: 7400,
                   path: "/foo/bar/baz",
                   query: %{"a" => 1, "b" => %{"z" => 1}, "c" => 3},
                   headers: [
                     ["content-type", "text/json"],
                     ["accept", "text/xml"]
                   ],
                   body: "{\"a\": 1}",
                   data: %{"a" => 1}
                 ),
               response:
                 struct_like(HTTPSignals.HTTPSignal.Response,
                   status: 200,
                   headers: [
                     ["content-type", "text/json"],
                     ["accept", "text/xml"]
                   ],
                   body: "{\"a\": 1}",
                   data: %{"a" => 1},
                   sent_at: datetime()
                 )
             )
    end

    test "correctly stores when done piecemeal" do
      {:ok, http_signal} =
        HTTPSignals.create_http_signal(%{
          service: "edge",
          context_id: Ecto.UUID.generate(),
          source: :us,
          stacktrace: HTTPSignals.current_stacktrace(),
          request: %{
            method: :post,
            scheme: :https,
            host: "example.com",
            port: 7400,
            path: "/foo/bar/baz",
            query: %{"a" => 1, "b" => %{"z" => 1}, "c" => 3},
            headers: [
              ["content-type", "text/json"],
              ["accept", "text/xml"]
            ],
            data: %{"a" => 1}
          }
        })

      http_signal = HTTPSignals.get_http_signal(http_signal.id)

      assert http_signal
             ~> struct_like(HTTPSignals.HTTPSignal,
               service: "edge",
               context_id: string(),
               source: :us,
               request:
                 struct_like(HTTPSignals.HTTPSignal.Request,
                   method: :post,
                   scheme: :https,
                   host: "example.com",
                   port: 7400,
                   path: "/foo/bar/baz",
                   query: %{"a" => 1, "b" => %{"z" => 1}, "c" => 3},
                   headers: [
                     ["content-type", "text/json"],
                     ["accept", "text/xml"]
                   ],
                   data: %{"a" => 1}
                 ),
               response: nil
             )

      {:ok, http_signal} =
        HTTPSignals.TestRepo.update(
          HTTPSignals.HTTPSignal.postprocess_request_changeset(
            http_signal,
            %{request: %{body: "{\"a\": 1}"}}
          )
        )

      http_signal = HTTPSignals.get_http_signal(http_signal.id)

      assert http_signal
             ~> struct_like(HTTPSignals.HTTPSignal,
               service: "edge",
               context_id: string(),
               source: :us,
               request:
                 struct_like(HTTPSignals.HTTPSignal.Request,
                   method: :post,
                   scheme: :https,
                   host: "example.com",
                   port: 7400,
                   path: "/foo/bar/baz",
                   query: %{"a" => 1, "b" => %{"z" => 1}, "c" => 3},
                   headers: [
                     ["content-type", "text/json"],
                     ["accept", "text/xml"]
                   ],
                   body: "{\"a\": 1}",
                   data: %{"a" => 1}
                 ),
               response: nil
             )

      {:ok, http_signal} =
        HTTPSignals.TestRepo.update(
          HTTPSignals.HTTPSignal.with_response_changeset(
            http_signal,
            %{
              response: %{
                status: 200,
                headers: [
                  ["content-type", "text/json"],
                  ["accept", "text/xml"]
                ],
                body: "{\"a\": 1}",
                sent_at: DateTime.utc_now()
              }
            }
          )
        )

      http_signal = HTTPSignals.get_http_signal(http_signal.id)

      assert http_signal
             ~> struct_like(HTTPSignals.HTTPSignal,
               service: "edge",
               context_id: string(),
               source: :us,
               request:
                 struct_like(HTTPSignals.HTTPSignal.Request,
                   method: :post,
                   scheme: :https,
                   host: "example.com",
                   port: 7400,
                   path: "/foo/bar/baz",
                   query: %{"a" => 1, "b" => %{"z" => 1}, "c" => 3},
                   headers: [
                     ["content-type", "text/json"],
                     ["accept", "text/xml"]
                   ],
                   body: "{\"a\": 1}",
                   data: %{"a" => 1}
                 ),
               response:
                 struct_like(HTTPSignals.HTTPSignal.Response,
                   status: 200,
                   headers: [
                     ["content-type", "text/json"],
                     ["accept", "text/xml"]
                   ],
                   body: "{\"a\": 1}",
                   data: nil
                 )
             )

      {:ok, http_signal} =
        HTTPSignals.TestRepo.update(
          HTTPSignals.HTTPSignal.postprocess_response_changeset(
            http_signal,
            %{response: %{data: %{"a" => 1}}}
          )
        )

      http_signal = HTTPSignals.get_http_signal(http_signal.id)

      assert http_signal
             ~> struct_like(HTTPSignals.HTTPSignal,
               service: "edge",
               context_id: string(),
               source: :us,
               request:
                 struct_like(HTTPSignals.HTTPSignal.Request,
                   method: :post,
                   scheme: :https,
                   host: "example.com",
                   port: 7400,
                   path: "/foo/bar/baz",
                   query: %{"a" => 1, "b" => %{"z" => 1}, "c" => 3},
                   headers: [
                     ["content-type", "text/json"],
                     ["accept", "text/xml"]
                   ],
                   body: "{\"a\": 1}",
                   data: %{"a" => 1}
                 ),
               response:
                 struct_like(HTTPSignals.HTTPSignal.Response,
                   status: 200,
                   headers: [
                     ["content-type", "text/json"],
                     ["accept", "text/xml"]
                   ],
                   body: "{\"a\": 1}",
                   data: %{"a" => 1}
                 )
             )
    end
  end
end
