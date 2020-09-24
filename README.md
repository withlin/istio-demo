## Istio 介绍

## VirtaulService(虚拟服务)

> 虚拟服务在增强 Istio 流量管理的灵活性和有效性方面，发挥着至关重要的作用，通过对客户端请求的目标地址与真实响应请求的目标工作负载进行解耦来实现。虚拟服务同时提供了丰富的方式，为发送至这些工作负载的流量指定不同的路由规则。

使用虚拟服务，您可以为一个或多个主机名指定流量行为。在虚拟服务中使用路由规则，告诉 Envoy 如何发送虚拟服务的流量到适当的目标。路由目标地址可以是同一服务的不同版本，也可以是完全不同的服务。

```text

[devops_root@ali-tekton-CI-devops-dev-01 istio-1.7.1]$ kd vs
Name:         bookinfo
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  networking.istio.io/v1beta1
Kind:         VirtualService
Metadata:
  Creation Timestamp:  2020-09-15T08:32:36Z
  Generation:          1
  Managed Fields:
    API Version:  networking.istio.io/v1alpha3
    Fields Type:  FieldsV1
    fieldsV1:
      f:metadata:
        f:annotations:
          .:
          f:kubectl.kubernetes.io/last-applied-configuration:
      f:spec:
        .:
        f:gateways:
        f:hosts:
        f:http:
    Manager:         kubectl-client-side-apply
    Operation:       Update
    Time:            2020-09-15T08:32:36Z
  Resource Version:  295670
  Self Link:         /apis/networking.istio.io/v1beta1/namespaces/default/virtualservices/bookinfo
  UID:               15705622-2450-441d-a164-96cc2a1a61b2
Spec:
  Gateways:
    bookinfo-gateway
  Hosts:
    *
  Http:
    Match:
      Uri:
        Exact:  /productpage
      Uri:
        Prefix:  /static
      Uri:
        Exact:  /login
      Uri:
        Exact:  /logout
      Uri:
        Prefix:  /api/v1/products
    Route:
      Destination:
        Host:  productpage
        Port:
          Number:  9080
Events:            <none>
```

## GateWay(网关)

使用网关为网格来管理入站和出站流量,可以让您指定进入或离开网格的流量。网关配置被用于运行在网格边界的独立 Envoy 代理,而不是网络工作负载 sidecar 代理。

### Gateway 示例

```text

apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: ext-host-gwy
spec:
  selector:
    app: my-gateway-controller
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    hosts:
    - ext-host.example.com
    tls:
      mode: SIMPLE
      serverCertificate: /tmp/tls.crt
      privateKey: /tmp/tls.key

```

这个网关配置让 HTTPS 流量从 ext-host.example.com 通过 443 端口流入网格，但没有为请求指定任何路由规则。为想要工作的网关指定路由，您必须把网关绑定到虚拟服务上。正如下面的示例所示，使用虚拟服务的 gateways 字段进行设置

```Virtual Service
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: virtual-svc
spec:
  hosts:
  - ext-host.example.com
  gateways:
    - ext-host-gwy

```

### ServiceEntry(服务入口)

使用服务入口来添加一个入口到 Istio 内部维护的服务注册中心，添加服务入口后，添加服务之后，Envoy 代理可以向服务发送流量，就好像他是网格内部服务一样。功能：

- 为外部目标 redirect 和转发请求，例如 web 端的 api 调用，或者流向老系统的服务
- 为外部目标定义`重试`,`超时`和`故障注入`策略
- 添加一个虚拟机的服务来扩展你的服务网格

### 事例

```text
apiVersion: networking.istio.io/v1alpha3
kind: ServiceEntry
metadata:
  name: svc-entry
spec:
  hosts:
  - ext-svc.example.com
  ports:
  - number: 443
    name: https
    protocol: HTTPS
  location: MESH_EXTERNAL
  resolution: DNS
```

您可以配置虚拟服务和目标规则，以更细粒度的方式控制到服务入口的流量，这与网格中的任何其他服务配置流量的方式相同。例如，下面的目标规则配置流量路由以使用双向 TLS 来保护到 ext-svc.example.com 外部服务的连接，我们使用服务入口配置了该外部服务：

```text

apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: ext-res-dr
spec:
  host: ext-svc.example.com
  trafficPolicy:
    tls:
      mode: MUTUAL
      clientCertificate: /etc/certs/myclientcert.pem
      privateKey: /etc/certs/client_private_key.pem
      caCertificates: /etc/certs/rootcacerts.pem

```

## Sidecar

默认情况下，Istio 让每个 Envoy 代理都可以访问来自和它关联的工作负载的所有端口的请求，然后转发到对应的工作负载。您可以使用 sidecar 配置去做下面的事情：

- 微调 Envoy 代理接收代理和协议集
- 限制 Envoy 可以访问的服务集合

```text

apiVersion: networking.istio.io/v1alpha3
kind: Sidecar
metadata:
  name: default
  namespace: bookinfo
spec:
  egress:
  - hosts:
    - "./*"
    - "istio-system/*"


```

## 超时

```text

apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: ratings
spec:
  hosts:
  - ratings
  http:
  - route:
    - destination:
        host: ratings
        subset: v1
    timeout: 10s

```

## 重试

```text

apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: ratings
spec:
  hosts:
  - ratings
  http:
  - route:
    - destination:
        host: ratings
        subset: v1
    retries:
      attempts: 3
      perTryTimeout: 2s


```

### 熔断器

```text
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: reviews
spec:
  host: reviews
  subsets:
  - name: v1
    labels:
      version: v1
    trafficPolicy:
      connectionPool:
        tcp:
          maxConnections: 100

```

### 网关 Ingress 和 Eggress

## 安全(Citadel)

### TLS

## 策略

### 限速

### 请求头和路由控制

### Denials 和黑白名单

通过 Istio 您可以根据 Mixer 中可用的任意属性来控制对服务的访问。 这种简单形式的访问控制是基于 Mixer 选择器的条件拒绝请求功能实现的。

## 可观察性

### 指标度量

### 日志收集

### 分布式链路跟踪(zipkip/skywalking/jaeger)

## 网络可视化

compass 的 service mesh 功能

- 服务拓扑 ✔︎
- 服务列表 ✔︎
- 灰度发布 ✔︎
- 流量监控 ✔︎
- 路由管理 ✔︎
- 流量策略 ✔︎
- 服务网关 ✔︎
- 安全策略 ✺
- 调用链跟踪 ✔︎
- 资源列表 ✔︎

Galley：Galley 代表其他的 Istio 控制平面组件，用来验证用户编写的 Istio API 配置

Citadel：Citadel 通过内置身份和凭证管理赋能强大的服务间和最终用户身份验证。可用于升级服务网格中未加密的流量，并为运维人员提供基于服务标识而不是网络控制的强制执行策略的能力。

策略执行模块（Mixer）：负责在服务网格上执行访问控制和使用策略，并从智能代理（Envoy）和其他服务收集遥测数据。依据智能代理（Envoy）提供的属性执行策略。

Istio 管理器（Pilot）：负责收集和验证配置，并将其传播到各种 Istio 组件。它从策略执行模块（Mixer）和智能代理（Envoy）中抽取环境特定的实现细节，为他们提供用户服务的抽象表示，独立于底层平台。此外，流量管理规则（即通用 4 层规则和 7 层 HTTP/gRPC 路由规则）可以在运行时通过 Pilot 进行编程。

Pilot 相关的 CRD

- Virtualservice：用于定义路由规则，如根据来源或 Header 制定规则，或在不同服务版本之间分拆流量。
- DestinationRule：定义目的服务的配置策略以及可路由子集。策略包括断路器、负载均衡以及 TLS 等。
- ServiceEntry：可以使用 ServiceEntry 向 Istio 中加入附加的服务条目，以使网格内可以向 istio 服务网格之外的服务发出请求。
- Gateway：为网格配置网关，以允许一个服务可以被网格外部访问。
- EnvoyFilter：可以为 Envoy 配置过滤器。由于 Envoy 已经支持 Lua 过滤器，因此可以通过 EnvoyFilter 启用 Lua 过滤器，动态改变 Envoy 的过滤链行为。我之前一直在考虑如何才能动态扩展 Envoy 的能力，EnvoyFilter 提供了很灵活的扩展性。
- Sidecar：缺省情况下，Pilot 将会把和 Envoy Sidecar 所在 namespace 的所有 services 的相关配置，包括 inbound 和 outbound listenter, cluster, route 等，都下发给 Enovy。使用 Sidecar 可以对 Pilot 向 Envoy Sidcar 下发的配置进行更细粒度的调整，例如只向其下发该 Sidecar 所在服务需要访问的那些外部服务的相关 outbound 配置。

## 数据平面

在数据面有两个进程 Pilot-agent 和 envoy，这两个进程被放在一个 docker 容器 gcr.io/istio-release/proxyv2 中。

```text
{
  "node": {
    "id": "sidecar~10.16.0.104~productpage-v1-65576bb7bf-djw4c.default~default.svc.cluster.local",
    "cluster": "productpage.default",
    "locality": {
    },
    "metadata": {"APP_CONTAINERS":"productpage","CLUSTER_ID":"Kubernetes","EXCHANGE_KEYS":"NAME,NAMESPACE,INSTANCE_IPS,LABELS,OWNER,PLATFORM_METADATA,WORKLOAD_NAME,MESH_ID,SERVICE_ACCOUNT,CLUSTER_ID","INSTANCE_IPS":"10.16.0.104","INTERCEPTION_MODE":"REDIRECT","ISTIO_PROXY_SHA":"istio-proxy:262253d9d066f8ef7ed82fd175c28b8f95acbec0","ISTIO_VERSION":"1.7.1","LABELS":{"app":"productpage","istio.io/rev":"default","pod-template-hash":"65576bb7bf","security.istio.io/tlsMode":"istio","service.istio.io/canonical-name":"productpage","service.istio.io/canonical-revision":"v1","version":"v1"},"MESH_ID":"cluster.local","NAME":"productpage-v1-65576bb7bf-djw4c","NAMESPACE":"default","OWNER":"kubernetes://apis/apps/v1/namespaces/default/deployments/productpage-v1","POD_PORTS":"[{\"containerPort\":9080,\"protocol\":\"TCP\"}]","PROXY_CONFIG":{"binaryPath":"/usr/local/bin/envoy","concurrency":2,"configPath":"./etc/istio/proxy","controlPlaneAuthPolicy":"MUTUAL_TLS","discoveryAddress":"istiod.istio-system.svc:15012","drainDuration":"45s","envoyAccessLogService":{},"envoyMetricsService":{},"parentShutdownDuration":"60s","proxyAdminPort":15000,"proxyMetadata":{"DNS_AGENT":""},"serviceCluster":"productpage.default","statNameLength":189,"statusPort":15020,"terminationDrainDuration":"5s","tracing":{"zipkin":{"address":"zipkin.istio-system:9411"}}},"SDS":"true","SERVICE_ACCOUNT":"bookinfo-productpage","WORKLOAD_NAME":"productpage-v1"}
  },
  "layered_runtime": {
      "layers": [
          {
              "name": "deprecation",
              "static_layer": {
                  "envoy.deprecated_features:envoy.config.listener.v3.Listener.hidden_envoy_deprecated_use_original_dst": true
              }
          },
          {
              "name": "admin",
              "admin_layer": {}
          }
      ]
  },
  "stats_config": {
    "use_all_default_tags": false,
    "stats_tags": [
      {
        "tag_name": "cluster_name",
        "regex": "^cluster\\.((.+?(\\..+?\\.svc\\.cluster\\.local)?)\\.)"
      },
      {
        "tag_name": "tcp_prefix",
        "regex": "^tcp\\.((.*?)\\.)\\w+?$"
      },
      {
        "regex": "(response_code=\\.=(.+?);\\.;)|_rq(_(\\.d{3}))$",
        "tag_name": "response_code"
      },
      {
        "tag_name": "response_code_class",
        "regex": "_rq(_(\\dxx))$"
      },
      {
        "tag_name": "http_conn_manager_listener_prefix",
        "regex": "^listener(?=\\.).*?\\.http\\.(((?:[_.[:digit:]]*|[_\\[\\]aAbBcCdDeEfF[:digit:]]*))\\.)"
      },
      {
        "tag_name": "http_conn_manager_prefix",
        "regex": "^http\\.(((?:[_.[:digit:]]*|[_\\[\\]aAbBcCdDeEfF[:digit:]]*))\\.)"
      },
      {
        "tag_name": "listener_address",
        "regex": "^listener\\.(((?:[_.[:digit:]]*|[_\\[\\]aAbBcCdDeEfF[:digit:]]*))\\.)"
      },
      {
        "tag_name": "mongo_prefix",
        "regex": "^mongo\\.(.+?)\\.(collection|cmd|cx_|op_|delays_|decoding_)(.*?)$"
      },
      {
        "regex": "(reporter=\\.=(.*?);\\.;)",
        "tag_name": "reporter"
      },
      {
        "regex": "(source_namespace=\\.=(.*?);\\.;)",
        "tag_name": "source_namespace"
      },
      {
        "regex": "(source_workload=\\.=(.*?);\\.;)",
        "tag_name": "source_workload"
      },
      {
        "regex": "(source_workload_namespace=\\.=(.*?);\\.;)",
        "tag_name": "source_workload_namespace"
      },
      {
        "regex": "(source_principal=\\.=(.*?);\\.;)",
        "tag_name": "source_principal"
      },
      {
        "regex": "(source_app=\\.=(.*?);\\.;)",
        "tag_name": "source_app"
      },
      {
        "regex": "(source_version=\\.=(.*?);\\.;)",
        "tag_name": "source_version"
      },
      {
        "regex": "(source_cluster=\\.=(.*?);\\.;)",
        "tag_name": "source_cluster"
      },
      {
        "regex": "(destination_namespace=\\.=(.*?);\\.;)",
        "tag_name": "destination_namespace"
      },
      {
        "regex": "(destination_workload=\\.=(.*?);\\.;)",
        "tag_name": "destination_workload"
      },
      {
        "regex": "(destination_workload_namespace=\\.=(.*?);\\.;)",
        "tag_name": "destination_workload_namespace"
      },
      {
        "regex": "(destination_principal=\\.=(.*?);\\.;)",
        "tag_name": "destination_principal"
      },
      {
        "regex": "(destination_app=\\.=(.*?);\\.;)",
        "tag_name": "destination_app"
      },
      {
        "regex": "(destination_version=\\.=(.*?);\\.;)",
        "tag_name": "destination_version"
      },
      {
        "regex": "(destination_service=\\.=(.*?);\\.;)",
        "tag_name": "destination_service"
      },
      {
        "regex": "(destination_service_name=\\.=(.*?);\\.;)",
        "tag_name": "destination_service_name"
      },
      {
        "regex": "(destination_service_namespace=\\.=(.*?);\\.;)",
        "tag_name": "destination_service_namespace"
      },
      {
        "regex": "(destination_port=\\.=(.*?);\\.;)",
        "tag_name": "destination_port"
      },
      {
        "regex": "(destination_cluster=\\.=(.*?);\\.;)",
        "tag_name": "destination_cluster"
      },
      {
        "regex": "(request_protocol=\\.=(.*?);\\.;)",
        "tag_name": "request_protocol"
      },
      {
        "regex": "(request_operation=\\.=(.*?);\\.;)",
        "tag_name": "request_operation"
      },
      {
        "regex": "(request_host=\\.=(.*?);\\.;)",
        "tag_name": "request_host"
      },
      {
        "regex": "(response_flags=\\.=(.*?);\\.;)",
        "tag_name": "response_flags"
      },
      {
        "regex": "(grpc_response_status=\\.=(.*?);\\.;)",
        "tag_name": "grpc_response_status"
      },
      {
        "regex": "(connection_security_policy=\\.=(.*?);\\.;)",
        "tag_name": "connection_security_policy"
      },
      {
        "regex": "(permissive_response_code=\\.=(.*?);\\.;)",
        "tag_name": "permissive_response_code"
      },
      {
        "regex": "(permissive_response_policyid=\\.=(.*?);\\.;)",
        "tag_name": "permissive_response_policyid"
      },
      {
        "regex": "(source_canonical_service=\\.=(.*?);\\.;)",
        "tag_name": "source_canonical_service"
      },
      {
        "regex": "(destination_canonical_service=\\.=(.*?);\\.;)",
        "tag_name": "destination_canonical_service"
      },
      {
        "regex": "(source_canonical_revision=\\.=(.*?);\\.;)",
        "tag_name": "source_canonical_revision"
      },
      {
        "regex": "(destination_canonical_revision=\\.=(.*?);\\.;)",
        "tag_name": "destination_canonical_revision"
      },
      {
        "regex": "(cache\\.(.+?)\\.)",
        "tag_name": "cache"
      },
      {
        "regex": "(component\\.(.+?)\\.)",
        "tag_name": "component"
      },
      {
        "regex": "(tag\\.(.+?);\\.)",
        "tag_name": "tag"
      },
      {
        "regex": "(wasm_filter\\.(.+?)\\.)",
        "tag_name": "wasm_filter"
      }
    ],
    "stats_matcher": {
      "inclusion_list": {
        "patterns": [
          {
          "prefix": "reporter="
          },
          {
          "prefix": "cluster_manager"
          },
          {
          "prefix": "listener_manager"
          },
          {
          "prefix": "http_mixer_filter"
          },
          {
          "prefix": "tcp_mixer_filter"
          },
          {
          "prefix": "server"
          },
          {
          "prefix": "cluster.xds-grpc"
          },
          {
          "prefix": "wasm"
          },
          {
          "prefix": "component"
          }
        ]
      }
    }
  },
  "admin": {
    "access_log_path": "/dev/null",
    "profile_path": "/var/lib/istio/data/envoy.prof",
    "address": {
      "socket_address": {
        "address": "127.0.0.1",
        "port_value": 15000
      }
    }
  },
  "dynamic_resources": {
    "lds_config": {
      "ads": {},
      "resource_api_version": "V3"
    },
    "cds_config": {
      "ads": {},
      "resource_api_version": "V3"
    },
    "ads_config": {
      "api_type": "GRPC",
      "transport_api_version": "V3",
      "grpc_services": [
        {
          "envoy_grpc": {
            "cluster_name": "xds-grpc"
          }
        }
      ]
    }
  },
  "static_resources": {
    "clusters": [
      {
        "name": "prometheus_stats",
        "type": "STATIC",
        "connect_timeout": "0.250s",
        "lb_policy": "ROUND_ROBIN",
        "load_assignment": {
          "cluster_name": "prometheus_stats",
          "endpoints": [{
            "lb_endpoints": [{
              "endpoint": {
                "address":{
                  "socket_address": {
                    "protocol": "TCP",
                    "address": "127.0.0.1",
                    "port_value": 15000
                  }
                }
              }
            }]
          }]
        }
      },
      {
        "name": "agent",
        "type": "STATIC",
        "connect_timeout": "0.250s",
        "lb_policy": "ROUND_ROBIN",
        "load_assignment": {
          "cluster_name": "prometheus_stats",
          "endpoints": [{
            "lb_endpoints": [{
              "endpoint": {
                "address":{
                  "socket_address": {
                    "protocol": "TCP",
                    "address": "127.0.0.1",
                    "port_value": 15020
                  }
                }
              }
            }]
          }]
        }
      },
      {
        "name": "sds-grpc",
        "type": "STATIC",
        "http2_protocol_options": {},
        "connect_timeout": "1s",
        "lb_policy": "ROUND_ROBIN",
        "load_assignment": {
          "cluster_name": "sds-grpc",
          "endpoints": [{
            "lb_endpoints": [{
              "endpoint": {
                "address":{
                  "pipe": {
                    "path": "./etc/istio/proxy/SDS"
                  }
                }
              }
            }]
          }]
        }
      },
      {
        "name": "xds-grpc",
        "type": "STRICT_DNS",
        "respect_dns_ttl": true,
        "dns_lookup_family": "V4_ONLY",
        "connect_timeout": "1s",
        "lb_policy": "ROUND_ROBIN",
        "transport_socket": {
          "name": "envoy.transport_sockets.tls",
          "typed_config": {
            "@type": "type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.UpstreamTlsContext",
            "sni": "istiod.istio-system.svc",
            "common_tls_context": {
              "alpn_protocols": [
                "h2"
              ],
              "tls_certificate_sds_secret_configs": [
                {
                  "name": "default",
                  "sds_config": {
                    "resource_api_version": "V3",
                    "initial_fetch_timeout": "0s",
                    "api_config_source": {
                      "api_type": "GRPC",
                      "transport_api_version": "V3",
                      "grpc_services": [
                        {
                          "envoy_grpc": { "cluster_name": "sds-grpc" }
                        }
                      ]
                    }
                  }
                }
              ],
              "validation_context": {
                "trusted_ca": {
                  "filename": "./var/run/secrets/istio/root-cert.pem"
                },
                "match_subject_alt_names": [{"exact":"istiod.istio-system.svc"}]
              }
            }
          }
        },
        "load_assignment": {
          "cluster_name": "xds-grpc",
          "endpoints": [{
            "lb_endpoints": [{
              "endpoint": {
                "address":{
                  "socket_address": {"address": "istiod.istio-system.svc", "port_value": 15012}
                }
              }
            }]
          }]
        },
        "circuit_breakers": {
          "thresholds": [
            {
              "priority": "DEFAULT",
              "max_connections": 100000,
              "max_pending_requests": 100000,
              "max_requests": 100000
            },
            {
              "priority": "HIGH",
              "max_connections": 100000,
              "max_pending_requests": 100000,
              "max_requests": 100000
            }
          ]
        },
        "upstream_connection_options": {
          "tcp_keepalive": {
            "keepalive_time": 300
          }
        },
        "max_requests_per_connection": 1,
        "http2_protocol_options": { }
      }

      ,
      {
        "name": "zipkin",
        "type": "STRICT_DNS",
        "respect_dns_ttl": true,
        "dns_lookup_family": "V4_ONLY",
        "connect_timeout": "1s",
        "lb_policy": "ROUND_ROBIN",
        "load_assignment": {
          "cluster_name": "zipkin",
          "endpoints": [{
            "lb_endpoints": [{
              "endpoint": {
                "address":{
                  "socket_address": {"address": "zipkin.istio-system", "port_value": 9411}
                }
              }
            }]
          }]
        }
      }


    ],
    "listeners":[
      {
        "address": {
          "socket_address": {
            "protocol": "TCP",
            "address": "0.0.0.0",
            "port_value": 15090
          }
        },
        "filter_chains": [
          {
            "filters": [
              {
                "name": "envoy.http_connection_manager",
                "typed_config": {
                  "@type": "type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager",
                  "codec_type": "AUTO",
                  "stat_prefix": "stats",
                  "route_config": {
                    "virtual_hosts": [
                      {
                        "name": "backend",
                        "domains": [
                          "*"
                        ],
                        "routes": [
                          {
                            "match": {
                              "prefix": "/stats/prometheus"
                            },
                            "route": {
                              "cluster": "prometheus_stats"
                            }
                          }
                        ]
                      }
                    ]
                  },
                  "http_filters": [{
                    "name": "envoy.router",
                    "typed_config": {
                      "@type": "type.googleapis.com/envoy.extensions.filters.http.router.v3.Router"
                    }
                  }]
                }
              }
            ]
          }
        ]
      },
      {
        "address": {
          "socket_address": {
            "protocol": "TCP",
            "address": "0.0.0.0",
            "port_value": 15021
          }
        },
        "filter_chains": [
          {
            "filters": [
              {
                "name": "envoy.http_connection_manager",
                "typed_config": {
                  "@type": "type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager",
                  "codec_type": "AUTO",
                  "stat_prefix": "agent",
                  "route_config": {
                    "virtual_hosts": [
                      {
                        "name": "backend",
                        "domains": [
                          "*"
                        ],
                        "routes": [
                          {
                            "match": {
                              "prefix": "/healthz/ready"
                            },
                            "route": {
                              "cluster": "agent"
                            }
                          }
                        ]
                      }
                    ]
                  },
                  "http_filters": [{
                    "name": "envoy.router",
                    "typed_config": {
                      "@type": "type.googleapis.com/envoy.extensions.filters.http.router.v3.Router"
                    }
                  }]
                }
              }
            ]
          }
        ]
      }
    ]
  }
  ,
  "tracing": {
    "http": {
      "name": "envoy.zipkin",
      "typed_config": {
        "@type": "type.googleapis.com/envoy.config.trace.v3.ZipkinConfig",
        "collector_cluster": "zipkin",
        "collector_endpoint": "/api/v2/spans",
        "collector_endpoint_version": "HTTP_JSON",
        "trace_id_128bit": true,
        "shared_span_context": false
      }
    }
  }


}
```

## 部署模型

### 单一集群

一个集群和一个单一的 istio 网络模型

### 多集群

单个服务欧网格配置成为多集群

- 故障隔离和转移:当 cluster-1 下线业务将转移至 cluster-2
- 位置感知路由和故障转移: 支持不同级别的可用信
- 多种控制平面模型
- 团队或项目隔离:每个团队仅运行自己的集群

## 性能

1000 个服务和 2000 个 sidecar，全网格内 QPS 为 70000，Isito 的结果:

- 通过大力的 QPS 有 1000 时,Envoy 使用了 0.5vCPU 和 50MB 内存
- 网格总的 QPS 为 1000 时，istio-telemetry 服务使用了 0.6vCPU
- Pilot 使用了 1vCPU 和 1.5G 内存
- 90%的情况 Envoy 代理只增加了 6.3ms 的延迟

## Pod 和 Service

k8s 集群中的 Pod 和 Service 必须满足以下要求:

- 命名的服务端口: Service 的端口必须命名，端口名键值对必须按以下格式: name:<protocol>[-<suffix>]
- Service 关联:每个 Pod 必须至少属于一个 Kubernetes Service，不管这个 Pod 是否对外暴露端口。
- 带有 app 和 version 标签(label)的 Deployment：
  - app 标签:每个部署配置应该有一个不同的 app 标签并且该标签的值具有一定的意义。app label 用于在分布式链路追踪添加上下文信息。
  - verion 标签:这个标签用于在特定的方式部署应用中表示版本

## 流量管理

- 协议选择：Istio 默认支持代理所有 TCP 流量，但为了提供附加的能力，比如路由和丰富的指标，使用什么协议必须被确定。协议可以被自动检测或者明确的声明确定。
- 地域负载均衡:地理位置通常代表数据中心。Istio 使用该信息来优化负载均衡池，用以控制请求发送到的地理位置。 默认开启。

## 可观测性

- Envoy 的统计信息只覆盖了特定 Envoy 实例的流量。参考可观测性 了解关于服务级别的 Istio 遥测方面的内容。这些由 Envoy 代理产生的统计数据记录能够提供更多关于 pod 实例的具体信息:

```text
[devops_root@ali-tekton-CI-devops-dev-01 ~]$ k exec productpage-v1-65576bb7bf-djw4c  -c istio-proxy -- pilot-agent request GET stats
cluster_manager.cds.version_text: "2020-09-18T09:42:08Z/26"
listener_manager.lds.version_text: "2020-09-18T09:42:08Z/26"
cluster.xds-grpc.assignment_stale: 0
cluster.xds-grpc.assignment_timeout_received: 0
cluster.xds-grpc.bind_errors: 0
cluster.xds-grpc.circuit_breakers.default.cx_open: 0
cluster.xds-grpc.circuit_breakers.default.cx_pool_open: 0
cluster.xds-grpc.circuit_breakers.default.rq_open: 0
cluster.xds-grpc.circuit_breakers.default.rq_pending_open: 0
cluster.xds-grpc.circuit_breakers.default.rq_retry_open: 0
cluster.xds-grpc.circuit_breakers.high.cx_open: 0
cluster.xds-grpc.circuit_breakers.high.cx_pool_open: 0
cluster.xds-grpc.circuit_breakers.high.rq_open: 0
cluster.xds-grpc.circuit_breakers.high.rq_pending_open: 0
cluster.xds-grpc.circuit_breakers.high.rq_retry_open: 0
cluster.xds-grpc.client_ssl_socket_factory.downstream_context_secrets_not_ready: 0
cluster.xds-grpc.client_ssl_socket_factory.ssl_context_update_by_sds: 12
cluster.xds-grpc.client_ssl_socket_factory.upstream_context_secrets_not_ready: 0
cluster.xds-grpc.default.total_match_count: 19946
cluster.xds-grpc.http2.dropped_headers_with_underscores: 0
cluster.xds-grpc.http2.header_overflow: 0
cluster.xds-grpc.http2.headers_cb_no_stream: 0
cluster.xds-grpc.http2.inbound_empty_frames_flood: 0
cluster.xds-grpc.http2.inbound_priority_frames_flood: 0
cluster.xds-grpc.http2.inbound_window_update_frames_flood: 0
cluster.xds-grpc.http2.outbound_control_flood: 0
cluster.xds-grpc.http2.outbound_flood: 0
cluster.xds-grpc.http2.pending_send_bytes: 0
cluster.xds-grpc.http2.requests_rejected_with_underscores_in_headers: 0
cluster.xds-grpc.http2.rx_messaging_error: 0
cluster.xds-grpc.http2.rx_reset: 0
cluster.xds-grpc.http2.streams_active: 1
cluster.xds-grpc.http2.too_many_header_frames: 0
cluster.xds-grpc.http2.trailers: 0
cluster.xds-grpc.http2.tx_flush_timeout: 0
cluster.xds-grpc.http2.tx_reset: 0
cluster.xds-grpc.internal.upstream_rq_200: 285
cluster.xds-grpc.internal.upstream_rq_2xx: 285
cluster.xds-grpc.internal.upstream_rq_503: 3
cluster.xds-grpc.internal.upstream_rq_5xx: 3
cluster.xds-grpc.internal.upstream_rq_completed: 288
cluster.xds-grpc.lb_healthy_panic: 3
cluster.xds-grpc.lb_local_cluster_not_ok: 0
cluster.xds-grpc.lb_recalculate_zone_structures: 0
cluster.xds-grpc.lb_subsets_active: 0
cluster.xds-grpc.lb_subsets_created: 0
cluster.xds-grpc.lb_subsets_fallback: 0
cluster.xds-grpc.lb_subsets_fallback_panic: 0
cluster.xds-grpc.lb_subsets_removed: 0
cluster.xds-grpc.lb_subsets_selected: 0
cluster.xds-grpc.lb_zone_cluster_too_small: 0
cluster.xds-grpc.lb_zone_no_capacity_left: 0
cluster.xds-grpc.lb_zone_number_differs: 0
cluster.xds-grpc.lb_zone_routing_all_directly: 0
cluster.xds-grpc.lb_zone_routing_cross_zone: 0
cluster.xds-grpc.lb_zone_routing_sampled: 0
cluster.xds-grpc.max_host_weight: 1
cluster.xds-grpc.membership_change: 1
cluster.xds-grpc.membership_degraded: 0
cluster.xds-grpc.membership_excluded: 0
cluster.xds-grpc.membership_healthy: 1
cluster.xds-grpc.membership_total: 1
cluster.xds-grpc.original_dst_host_invalid: 0
cluster.xds-grpc.retry_or_shadow_abandoned: 0
cluster.xds-grpc.ssl.ciphers.ECDHE-RSA-AES128-GCM-SHA256: 285
cluster.xds-grpc.ssl.connection_error: 0
cluster.xds-grpc.ssl.curves.X25519: 285
cluster.xds-grpc.ssl.fail_verify_cert_hash: 0
cluster.xds-grpc.ssl.fail_verify_error: 0
cluster.xds-grpc.ssl.fail_verify_no_cert: 0
cluster.xds-grpc.ssl.fail_verify_san: 0
cluster.xds-grpc.ssl.handshake: 285
cluster.xds-grpc.ssl.no_certificate: 0
cluster.xds-grpc.ssl.session_reused: 216
cluster.xds-grpc.ssl.sigalgs.rsa_pss_rsae_sha256: 285
cluster.xds-grpc.ssl.versions.TLSv1.2: 285
cluster.xds-grpc.update_attempt: 19946
cluster.xds-grpc.update_empty: 0
cluster.xds-grpc.update_failure: 0
cluster.xds-grpc.update_no_rebuild: 19945
cluster.xds-grpc.update_success: 19946
cluster.xds-grpc.upstream_cx_active: 1
cluster.xds-grpc.upstream_cx_close_notify: 284
cluster.xds-grpc.upstream_cx_connect_attempts_exceeded: 0
cluster.xds-grpc.upstream_cx_connect_fail: 0
cluster.xds-grpc.upstream_cx_connect_timeout: 0
cluster.xds-grpc.upstream_cx_destroy: 284
cluster.xds-grpc.upstream_cx_destroy_local: 0
cluster.xds-grpc.upstream_cx_destroy_local_with_active_rq: 0
cluster.xds-grpc.upstream_cx_destroy_remote: 284
cluster.xds-grpc.upstream_cx_destroy_remote_with_active_rq: 284
cluster.xds-grpc.upstream_cx_destroy_with_active_rq: 284
cluster.xds-grpc.upstream_cx_http1_total: 0
cluster.xds-grpc.upstream_cx_http2_total: 285
cluster.xds-grpc.upstream_cx_idle_timeout: 0
cluster.xds-grpc.upstream_cx_max_requests: 285
cluster.xds-grpc.upstream_cx_none_healthy: 3
cluster.xds-grpc.upstream_cx_overflow: 0
cluster.xds-grpc.upstream_cx_pool_overflow: 0
cluster.xds-grpc.upstream_cx_protocol_error: 0
cluster.xds-grpc.upstream_cx_rx_bytes_buffered: 17
cluster.xds-grpc.upstream_cx_rx_bytes_total: 49678276
cluster.xds-grpc.upstream_cx_total: 285
cluster.xds-grpc.upstream_cx_tx_bytes_buffered: 0
cluster.xds-grpc.upstream_cx_tx_bytes_total: 29267888
cluster.xds-grpc.upstream_flow_control_backed_up_total: 0
cluster.xds-grpc.upstream_flow_control_drained_total: 0
cluster.xds-grpc.upstream_flow_control_paused_reading_total: 0
cluster.xds-grpc.upstream_flow_control_resumed_reading_total: 0
cluster.xds-grpc.upstream_internal_redirect_failed_total: 0
cluster.xds-grpc.upstream_internal_redirect_succeeded_total: 0
cluster.xds-grpc.upstream_rq_200: 285
cluster.xds-grpc.upstream_rq_2xx: 285
cluster.xds-grpc.upstream_rq_503: 3
cluster.xds-grpc.upstream_rq_5xx: 3
cluster.xds-grpc.upstream_rq_active: 1
cluster.xds-grpc.upstream_rq_cancelled: 0
cluster.xds-grpc.upstream_rq_completed: 288
cluster.xds-grpc.upstream_rq_maintenance_mode: 0
cluster.xds-grpc.upstream_rq_max_duration_reached: 0
cluster.xds-grpc.upstream_rq_pending_active: 0
cluster.xds-grpc.upstream_rq_pending_failure_eject: 284
cluster.xds-grpc.upstream_rq_pending_overflow: 0
cluster.xds-grpc.upstream_rq_pending_total: 285
cluster.xds-grpc.upstream_rq_per_try_timeout: 0
cluster.xds-grpc.upstream_rq_retry: 0
cluster.xds-grpc.upstream_rq_retry_limit_exceeded: 0
cluster.xds-grpc.upstream_rq_retry_overflow: 0
cluster.xds-grpc.upstream_rq_retry_success: 0
cluster.xds-grpc.upstream_rq_rx_reset: 0
cluster.xds-grpc.upstream_rq_timeout: 0
cluster.xds-grpc.upstream_rq_total: 285
cluster.xds-grpc.upstream_rq_tx_reset: 0
cluster.xds-grpc.version: 0
cluster_manager.active_clusters: 45
cluster_manager.cds.init_fetch_timeout: 0
cluster_manager.cds.update_attempt: 585
cluster_manager.cds.update_failure: 284
cluster_manager.cds.update_rejected: 0
cluster_manager.cds.update_success: 300
cluster_manager.cds.update_time: 1600671023819
cluster_manager.cds.version: 11549674845441926298
cluster_manager.cluster_added: 45
cluster_manager.cluster_modified: 7
cluster_manager.cluster_removed: 0
cluster_manager.cluster_updated: 3
cluster_manager.cluster_updated_via_merge: 0
cluster_manager.update_merge_cancelled: 0
cluster_manager.update_out_of_merge_window: 0
cluster_manager.warming_clusters: 0
component.proxy.tag.1.7.1;._istio_build: 1
listener_manager.lds.init_fetch_timeout: 0
listener_manager.lds.update_attempt: 585
listener_manager.lds.update_failure: 284
listener_manager.lds.update_rejected: 0
listener_manager.lds.update_success: 300
listener_manager.lds.update_time: 1600671023827
listener_manager.lds.version: 11549674845441926298
listener_manager.listener_added: 32
listener_manager.listener_create_failure: 0
listener_manager.listener_create_success: 64
listener_manager.listener_in_place_updated: 0
listener_manager.listener_modified: 0
listener_manager.listener_removed: 0
listener_manager.listener_stopped: 0
listener_manager.total_filter_chains_draining: 0
listener_manager.total_listeners_active: 32
listener_manager.total_listeners_draining: 0
listener_manager.total_listeners_warming: 0
listener_manager.workers_started: 1
reporter=.=destination;.;source_workload=.=istio-ingressgateway;.;source_workload_namespace=.=istio-system;.;source_principal=.=spiffe://cluster.local/ns/istio-system/sa/istio-ingressgateway-service-account;.;source_app=.=istio-ingressgateway;.;source_version=.=unknown;.;source_canonical_service=.=istio-ingressgateway;.;source_canonical_revision=.=latest;.;destination_workload=.=productpage-v1;.;destination_workload_namespace=.=default;.;destination_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-productpage;.;destination_app=.=productpage;.;destination_version=.=v1;.;destination_service=.=productpage.default.svc.cluster.local;.;destination_service_name=.=productpage;.;destination_service_namespace=.=default;.;destination_canonical_service=.=productpage;.;destination_canonical_revision=.=v1;.;request_protocol=.=http;.;response_code=.=0;.;grpc_response_status=.=;.;response_flags=.=DC;.;connection_security_policy=.=mutual_tls;.;_istio_requests_total: 1
reporter=.=destination;.;source_workload=.=istio-ingressgateway;.;source_workload_namespace=.=istio-system;.;source_principal=.=spiffe://cluster.local/ns/istio-system/sa/istio-ingressgateway-service-account;.;source_app=.=istio-ingressgateway;.;source_version=.=unknown;.;source_canonical_service=.=istio-ingressgateway;.;source_canonical_revision=.=latest;.;destination_workload=.=productpage-v1;.;destination_workload_namespace=.=default;.;destination_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-productpage;.;destination_app=.=productpage;.;destination_version=.=v1;.;destination_service=.=productpage.default.svc.cluster.local;.;destination_service_name=.=productpage;.;destination_service_namespace=.=default;.;destination_canonical_service=.=productpage;.;destination_canonical_revision=.=v1;.;request_protocol=.=http;.;response_code=.=200;.;grpc_response_status=.=;.;response_flags=.=-;.;connection_security_policy=.=mutual_tls;.;_istio_requests_total: 86
reporter=.=destination;.;source_workload=.=ratings-v1;.;source_workload_namespace=.=default;.;source_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-ratings;.;source_app=.=ratings;.;source_version=.=v1;.;source_canonical_service=.=ratings;.;source_canonical_revision=.=v1;.;destination_workload=.=productpage-v1;.;destination_workload_namespace=.=default;.;destination_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-productpage;.;destination_app=.=productpage;.;destination_version=.=v1;.;destination_service=.=productpage.default.svc.cluster.local;.;destination_service_name=.=productpage;.;destination_service_namespace=.=default;.;destination_canonical_service=.=productpage;.;destination_canonical_revision=.=v1;.;request_protocol=.=http;.;response_code=.=200;.;grpc_response_status=.=;.;response_flags=.=-;.;connection_security_policy=.=mutual_tls;.;_istio_requests_total: 1
reporter=.=source;.;source_workload=.=productpage-v1;.;source_workload_namespace=.=default;.;source_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-productpage;.;source_app=.=productpage;.;source_version=.=v1;.;source_canonical_service=.=productpage;.;source_canonical_revision=.=v1;.;destination_workload=.=details-v1;.;destination_workload_namespace=.=default;.;destination_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-details;.;destination_app=.=details;.;destination_version=.=v1;.;destination_service=.=details.default.svc.cluster.local;.;destination_service_name=.=details;.;destination_service_namespace=.=default;.;destination_canonical_service=.=details;.;destination_canonical_revision=.=v1;.;request_protocol=.=http;.;response_code=.=200;.;grpc_response_status=.=;.;response_flags=.=-;.;connection_security_policy=.=unknown;.;_istio_requests_total: 77
reporter=.=source;.;source_workload=.=productpage-v1;.;source_workload_namespace=.=default;.;source_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-productpage;.;source_app=.=productpage;.;source_version=.=v1;.;source_canonical_service=.=productpage;.;source_canonical_revision=.=v1;.;destination_workload=.=reviews-v1;.;destination_workload_namespace=.=default;.;destination_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-reviews;.;destination_app=.=reviews;.;destination_version=.=v1;.;destination_service=.=reviews.default.svc.cluster.local;.;destination_service_name=.=reviews;.;destination_service_namespace=.=default;.;destination_canonical_service=.=reviews;.;destination_canonical_revision=.=v1;.;request_protocol=.=http;.;response_code=.=200;.;grpc_response_status=.=;.;response_flags=.=-;.;connection_security_policy=.=unknown;.;_istio_requests_total: 26
reporter=.=source;.;source_workload=.=productpage-v1;.;source_workload_namespace=.=default;.;source_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-productpage;.;source_app=.=productpage;.;source_version=.=v1;.;source_canonical_service=.=productpage;.;source_canonical_revision=.=v1;.;destination_workload=.=reviews-v2;.;destination_workload_namespace=.=default;.;destination_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-reviews;.;destination_app=.=reviews;.;destination_version=.=v2;.;destination_service=.=reviews.default.svc.cluster.local;.;destination_service_name=.=reviews;.;destination_service_namespace=.=default;.;destination_canonical_service=.=reviews;.;destination_canonical_revision=.=v2;.;request_protocol=.=http;.;response_code=.=200;.;grpc_response_status=.=;.;response_flags=.=-;.;connection_security_policy=.=unknown;.;_istio_requests_total: 26
reporter=.=source;.;source_workload=.=productpage-v1;.;source_workload_namespace=.=default;.;source_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-productpage;.;source_app=.=productpage;.;source_version=.=v1;.;source_canonical_service=.=productpage;.;source_canonical_revision=.=v1;.;destination_workload=.=reviews-v3;.;destination_workload_namespace=.=default;.;destination_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-reviews;.;destination_app=.=reviews;.;destination_version=.=v3;.;destination_service=.=reviews.default.svc.cluster.local;.;destination_service_name=.=reviews;.;destination_service_namespace=.=default;.;destination_canonical_service=.=reviews;.;destination_canonical_revision=.=v3;.;request_protocol=.=http;.;response_code=.=200;.;grpc_response_status=.=;.;response_flags=.=-;.;connection_security_policy=.=unknown;.;_istio_requests_total: 25
server.concurrency: 2
server.days_until_first_cert_expiring: 0
server.debug_assertion_failures: 0
server.dynamic_unknown_fields: 0
server.envoy_bug_failures: 0
server.hot_restart_epoch: 0
server.hot_restart_generation: 1
server.live: 1
server.main_thread.watchdog_mega_miss: 0
server.main_thread.watchdog_miss: 0
server.memory_allocated: 13913728
server.memory_heap_size: 20971520
server.memory_physical_size: 23592960
server.parent_connections: 0
server.state: 0
server.static_unknown_fields: 0
server.stats_recent_lookups: 148952
server.total_connections: 1
server.uptime: 513410
server.version: 2499155
server.watchdog_mega_miss: 0
server.watchdog_miss: 0
server.worker_0.watchdog_mega_miss: 0
server.worker_0.watchdog_miss: 0
server.worker_1.watchdog_mega_miss: 0
server.worker_1.watchdog_miss: 0
wasm.envoy.wasm.runtime.null.active: 20
wasm.envoy.wasm.runtime.null.created: 25
wasm_filter.stats_filter.cache.hit.metric_cache_count: 100
wasm_filter.stats_filter.cache.miss.metric_cache_count: 11
wasm_vm.null.active: 20
wasm_vm.null.cloned: 0
wasm_vm.null.created: 25
cluster.xds-grpc.upstream_cx_connect_ms: P0(nan,1.0) P25(nan,1.0378989361702127) P50(nan,1.0757978723404256) P75(nan,2.0953703703703703) P90(nan,5.010869565217392) P95(nan,5.072826086956522) P99(nan,7.038333333333332) P99.5(nan,7.0858333333333325) P99.9(nan,9.071499999999997) P100(nan,9.1)
cluster.xds-grpc.upstream_cx_length_ms: P0(nan,1600000.0) P25(nan,1708860.759493671) P50(nan,1798734.17721519) P75(nan,1900000.0) P90(nan,1960000.0) P95(nan,1980000.0) P99(nan,1996000.0) P99.5(nan,1998000.0) P99.9(nan,1999600.0) P100(nan,2000000.0)
reporter=.=destination;.;source_workload=.=istio-ingressgateway;.;source_workload_namespace=.=istio-system;.;source_principal=.=spiffe://cluster.local/ns/istio-system/sa/istio-ingressgateway-service-account;.;source_app=.=istio-ingressgateway;.;source_version=.=unknown;.;source_canonical_service=.=istio-ingressgateway;.;source_canonical_revision=.=latest;.;destination_workload=.=productpage-v1;.;destination_workload_namespace=.=default;.;destination_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-productpage;.;destination_app=.=productpage;.;destination_version=.=v1;.;destination_service=.=productpage.default.svc.cluster.local;.;destination_service_name=.=productpage;.;destination_service_namespace=.=default;.;destination_canonical_service=.=productpage;.;destination_canonical_revision=.=v1;.;request_protocol=.=http;.;response_code=.=0;.;grpc_response_status=.=;.;response_flags=.=DC;.;connection_security_policy=.=mutual_tls;.;_istio_request_bytes: P0(nan,1100.0) P25(nan,1125.0) P50(nan,1150.0) P75(nan,1175.0) P90(nan,1190.0) P95(nan,1195.0) P99(nan,1199.0) P99.5(nan,1199.5) P99.9(nan,1199.9) P100(nan,1200.0)
reporter=.=destination;.;source_workload=.=istio-ingressgateway;.;source_workload_namespace=.=istio-system;.;source_principal=.=spiffe://cluster.local/ns/istio-system/sa/istio-ingressgateway-service-account;.;source_app=.=istio-ingressgateway;.;source_version=.=unknown;.;source_canonical_service=.=istio-ingressgateway;.;source_canonical_revision=.=latest;.;destination_workload=.=productpage-v1;.;destination_workload_namespace=.=default;.;destination_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-productpage;.;destination_app=.=productpage;.;destination_version=.=v1;.;destination_service=.=productpage.default.svc.cluster.local;.;destination_service_name=.=productpage;.;destination_service_namespace=.=default;.;destination_canonical_service=.=productpage;.;destination_canonical_revision=.=v1;.;request_protocol=.=http;.;response_code=.=0;.;grpc_response_status=.=;.;response_flags=.=DC;.;connection_security_policy=.=mutual_tls;.;_istio_request_duration_milliseconds: P0(nan,0.0) P25(nan,0.0) P50(nan,0.0) P75(nan,0.0) P90(nan,0.0) P95(nan,0.0) P99(nan,0.0) P99.5(nan,0.0) P99.9(nan,0.0) P100(nan,0.0)
reporter=.=destination;.;source_workload=.=istio-ingressgateway;.;source_workload_namespace=.=istio-system;.;source_principal=.=spiffe://cluster.local/ns/istio-system/sa/istio-ingressgateway-service-account;.;source_app=.=istio-ingressgateway;.;source_version=.=unknown;.;source_canonical_service=.=istio-ingressgateway;.;source_canonical_revision=.=latest;.;destination_workload=.=productpage-v1;.;destination_workload_namespace=.=default;.;destination_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-productpage;.;destination_app=.=productpage;.;destination_version=.=v1;.;destination_service=.=productpage.default.svc.cluster.local;.;destination_service_name=.=productpage;.;destination_service_namespace=.=default;.;destination_canonical_service=.=productpage;.;destination_canonical_revision=.=v1;.;request_protocol=.=http;.;response_code=.=0;.;grpc_response_status=.=;.;response_flags=.=DC;.;connection_security_policy=.=mutual_tls;.;_istio_response_bytes: P0(nan,0.0) P25(nan,0.0) P50(nan,0.0) P75(nan,0.0) P90(nan,0.0) P95(nan,0.0) P99(nan,0.0) P99.5(nan,0.0) P99.9(nan,0.0) P100(nan,0.0)
reporter=.=destination;.;source_workload=.=istio-ingressgateway;.;source_workload_namespace=.=istio-system;.;source_principal=.=spiffe://cluster.local/ns/istio-system/sa/istio-ingressgateway-service-account;.;source_app=.=istio-ingressgateway;.;source_version=.=unknown;.;source_canonical_service=.=istio-ingressgateway;.;source_canonical_revision=.=latest;.;destination_workload=.=productpage-v1;.;destination_workload_namespace=.=default;.;destination_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-productpage;.;destination_app=.=productpage;.;destination_version=.=v1;.;destination_service=.=productpage.default.svc.cluster.local;.;destination_service_name=.=productpage;.;destination_service_namespace=.=default;.;destination_canonical_service=.=productpage;.;destination_canonical_revision=.=v1;.;request_protocol=.=http;.;response_code=.=200;.;grpc_response_status=.=;.;response_flags=.=-;.;connection_security_policy=.=mutual_tls;.;_istio_request_bytes: P0(nan,610.0) P25(nan,1110.4166666666667) P50(nan,1140.2777777777778) P75(nan,1170.138888888889) P90(nan,1188.0555555555557) P95(nan,1194.0277777777778) P99(nan,1198.8055555555557) P99.5(nan,1199.4027777777778) P99.9(nan,1199.8805555555555) P100(nan,1200.0)
reporter=.=destination;.;source_workload=.=istio-ingressgateway;.;source_workload_namespace=.=istio-system;.;source_principal=.=spiffe://cluster.local/ns/istio-system/sa/istio-ingressgateway-service-account;.;source_app=.=istio-ingressgateway;.;source_version=.=unknown;.;source_canonical_service=.=istio-ingressgateway;.;source_canonical_revision=.=latest;.;destination_workload=.=productpage-v1;.;destination_workload_namespace=.=default;.;destination_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-productpage;.;destination_app=.=productpage;.;destination_version=.=v1;.;destination_service=.=productpage.default.svc.cluster.local;.;destination_service_name=.=productpage;.;destination_service_namespace=.=default;.;destination_canonical_service=.=productpage;.;destination_canonical_revision=.=v1;.;request_protocol=.=http;.;response_code=.=200;.;grpc_response_status=.=;.;response_flags=.=-;.;connection_security_policy=.=mutual_tls;.;_istio_request_duration_milliseconds: P0(nan,1.0) P25(nan,13.85) P50(nan,26.125) P75(nan,30.75) P90(nan,38.7) P95(nan,59.7) P99(nan,791.4) P99.5(nan,795.6999999999999) P99.9(nan,799.14) P100(nan,800.0)
reporter=.=destination;.;source_workload=.=istio-ingressgateway;.;source_workload_namespace=.=istio-system;.;source_principal=.=spiffe://cluster.local/ns/istio-system/sa/istio-ingressgateway-service-account;.;source_app=.=istio-ingressgateway;.;source_version=.=unknown;.;source_canonical_service=.=istio-ingressgateway;.;source_canonical_revision=.=latest;.;destination_workload=.=productpage-v1;.;destination_workload_namespace=.=default;.;destination_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-productpage;.;destination_app=.=productpage;.;destination_version=.=v1;.;destination_service=.=productpage.default.svc.cluster.local;.;destination_service_name=.=productpage;.;destination_service_namespace=.=default;.;destination_canonical_service=.=productpage;.;destination_canonical_revision=.=v1;.;request_protocol=.=http;.;response_code=.=200;.;grpc_response_status=.=;.;response_flags=.=-;.;connection_security_policy=.=mutual_tls;.;_istio_response_bytes: P0(nan,5200.0) P25(nan,5282.692307692308) P50(nan,6234.0) P75(nan,6277.0) P90(nan,19700.000000000004) P95(nan,38850.0) P99(nan,125700.0) P99.5(nan,127849.99999999997) P99.9(nan,129570.0) P100(nan,130000.0)
reporter=.=destination;.;source_workload=.=ratings-v1;.;source_workload_namespace=.=default;.;source_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-ratings;.;source_app=.=ratings;.;source_version=.=v1;.;source_canonical_service=.=ratings;.;source_canonical_revision=.=v1;.;destination_workload=.=productpage-v1;.;destination_workload_namespace=.=default;.;destination_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-productpage;.;destination_app=.=productpage;.;destination_version=.=v1;.;destination_service=.=productpage.default.svc.cluster.local;.;destination_service_name=.=productpage;.;destination_service_namespace=.=default;.;destination_canonical_service=.=productpage;.;destination_canonical_revision=.=v1;.;request_protocol=.=http;.;response_code=.=200;.;grpc_response_status=.=;.;response_flags=.=-;.;connection_security_policy=.=mutual_tls;.;_istio_request_bytes: P0(nan,530.0) P25(nan,532.5) P50(nan,535.0) P75(nan,537.5) P90(nan,539.0) P95(nan,539.5) P99(nan,539.9) P99.5(nan,539.95) P99.9(nan,539.99) P100(nan,540.0)
reporter=.=destination;.;source_workload=.=ratings-v1;.;source_workload_namespace=.=default;.;source_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-ratings;.;source_app=.=ratings;.;source_version=.=v1;.;source_canonical_service=.=ratings;.;source_canonical_revision=.=v1;.;destination_workload=.=productpage-v1;.;destination_workload_namespace=.=default;.;destination_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-productpage;.;destination_app=.=productpage;.;destination_version=.=v1;.;destination_service=.=productpage.default.svc.cluster.local;.;destination_service_name=.=productpage;.;destination_service_namespace=.=default;.;destination_canonical_service=.=productpage;.;destination_canonical_revision=.=v1;.;request_protocol=.=http;.;response_code=.=200;.;grpc_response_status=.=;.;response_flags=.=-;.;connection_security_policy=.=mutual_tls;.;_istio_request_duration_milliseconds: P0(nan,919.9999999999999) P25(nan,922.4999999999999) P50(nan,924.9999999999999) P75(nan,927.4999999999999) P90(nan,928.9999999999999) P95(nan,929.4999999999999) P99(nan,929.8999999999999) P99.5(nan,929.9499999999999) P99.9(nan,929.9899999999999) P100(nan,929.9999999999999)
reporter=.=destination;.;source_workload=.=ratings-v1;.;source_workload_namespace=.=default;.;source_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-ratings;.;source_app=.=ratings;.;source_version=.=v1;.;source_canonical_service=.=ratings;.;source_canonical_revision=.=v1;.;destination_workload=.=productpage-v1;.;destination_workload_namespace=.=default;.;destination_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-productpage;.;destination_app=.=productpage;.;destination_version=.=v1;.;destination_service=.=productpage.default.svc.cluster.local;.;destination_service_name=.=productpage;.;destination_service_namespace=.=default;.;destination_canonical_service=.=productpage;.;destination_canonical_revision=.=v1;.;request_protocol=.=http;.;response_code=.=200;.;grpc_response_status=.=;.;response_flags=.=-;.;connection_security_policy=.=mutual_tls;.;_istio_response_bytes: P0(nan,6200.0) P25(nan,6225.0) P50(nan,6250.0) P75(nan,6275.0) P90(nan,6290.0) P95(nan,6295.0) P99(nan,6299.0) P99.5(nan,6299.5) P99.9(nan,6299.9) P100(nan,6300.0)
reporter=.=source;.;source_workload=.=productpage-v1;.;source_workload_namespace=.=default;.;source_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-productpage;.;source_app=.=productpage;.;source_version=.=v1;.;source_canonical_service=.=productpage;.;source_canonical_revision=.=v1;.;destination_workload=.=details-v1;.;destination_workload_namespace=.=default;.;destination_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-details;.;destination_app=.=details;.;destination_version=.=v1;.;destination_service=.=details.default.svc.cluster.local;.;destination_service_name=.=details;.;destination_service_namespace=.=default;.;destination_canonical_service=.=details;.;destination_canonical_revision=.=v1;.;request_protocol=.=http;.;response_code=.=200;.;grpc_response_status=.=;.;response_flags=.=-;.;connection_security_policy=.=unknown;.;_istio_request_bytes: P0(nan,1200.0) P25(nan,1321.9594594594594) P50(nan,1347.972972972973) P75(nan,1373.9864864864865) P90(nan,1389.5945945945946) P95(nan,1394.7972972972973) P99(nan,1398.9594594594594) P99.5(nan,1399.4797297297298) P99.9(nan,1399.8959459459459) P100(nan,1400.0)
reporter=.=source;.;source_workload=.=productpage-v1;.;source_workload_namespace=.=default;.;source_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-productpage;.;source_app=.=productpage;.;source_version=.=v1;.;source_canonical_service=.=productpage;.;source_canonical_revision=.=v1;.;destination_workload=.=details-v1;.;destination_workload_namespace=.=default;.;destination_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-details;.;destination_app=.=details;.;destination_version=.=v1;.;destination_service=.=details.default.svc.cluster.local;.;destination_service_name=.=details;.;destination_service_namespace=.=default;.;destination_canonical_service=.=details;.;destination_canonical_revision=.=v1;.;request_protocol=.=http;.;response_code=.=200;.;grpc_response_status=.=;.;response_flags=.=-;.;connection_security_policy=.=unknown;.;_istio_request_duration_milliseconds: P0(nan,1.0) P25(nan,1.030078125) P50(nan,1.06015625) P75(nan,1.090234375) P90(nan,2.0757142857142856) P95(nan,5.014999999999999) P99(nan,20.230000000000004) P99.5(nan,20.614999999999995) P99.9(nan,20.923000000000002) P100(nan,21.0)
reporter=.=source;.;source_workload=.=productpage-v1;.;source_workload_namespace=.=default;.;source_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-productpage;.;source_app=.=productpage;.;source_version=.=v1;.;source_canonical_service=.=productpage;.;source_canonical_revision=.=v1;.;destination_workload=.=details-v1;.;destination_workload_namespace=.=default;.;destination_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-details;.;destination_app=.=details;.;destination_version=.=v1;.;destination_service=.=details.default.svc.cluster.local;.;destination_service_name=.=details;.;destination_service_namespace=.=default;.;destination_canonical_service=.=details;.;destination_canonical_revision=.=v1;.;request_protocol=.=http;.;response_code=.=200;.;grpc_response_status=.=;.;response_flags=.=-;.;connection_security_policy=.=unknown;.;_istio_response_bytes: P0(nan,300.0) P25(nan,302.5) P50(nan,305.0) P75(nan,307.5) P90(nan,309.0) P95(nan,309.5) P99(nan,309.9) P99.5(nan,309.95) P99.9(nan,309.99) P100(nan,310.0)
reporter=.=source;.;source_workload=.=productpage-v1;.;source_workload_namespace=.=default;.;source_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-productpage;.;source_app=.=productpage;.;source_version=.=v1;.;source_canonical_service=.=productpage;.;source_canonical_revision=.=v1;.;destination_workload=.=reviews-v1;.;destination_workload_namespace=.=default;.;destination_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-reviews;.;destination_app=.=reviews;.;destination_version=.=v1;.;destination_service=.=reviews.default.svc.cluster.local;.;destination_service_name=.=reviews;.;destination_service_namespace=.=default;.;destination_canonical_service=.=reviews;.;destination_canonical_revision=.=v1;.;request_protocol=.=http;.;response_code=.=200;.;grpc_response_status=.=;.;response_flags=.=-;.;connection_security_policy=.=unknown;.;_istio_request_bytes: P0(nan,1200.0) P25(nan,1322.0) P50(nan,1348.0) P75(nan,1374.0) P90(nan,1389.6) P95(nan,1394.8) P99(nan,1398.96) P99.5(nan,1399.48) P99.9(nan,1399.896) P100(nan,1400.0)
reporter=.=source;.;source_workload=.=productpage-v1;.;source_workload_namespace=.=default;.;source_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-productpage;.;source_app=.=productpage;.;source_version=.=v1;.;source_canonical_service=.=productpage;.;source_canonical_revision=.=v1;.;destination_workload=.=reviews-v1;.;destination_workload_namespace=.=default;.;destination_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-reviews;.;destination_app=.=reviews;.;destination_version=.=v1;.;destination_service=.=reviews.default.svc.cluster.local;.;destination_service_name=.=reviews;.;destination_service_namespace=.=default;.;destination_canonical_service=.=reviews;.;destination_canonical_revision=.=v1;.;request_protocol=.=http;.;response_code=.=200;.;grpc_response_status=.=;.;response_flags=.=-;.;connection_security_policy=.=unknown;.;_istio_request_duration_milliseconds: P0(nan,3.0) P25(nan,4.013636363636364) P50(nan,4.072727272727272) P75(nan,5.0875) P90(nan,6.085) P95(nan,10.7) P99(nan,577.4) P99.5(nan,578.7) P99.9(nan,579.74) P100(nan,580.0)
reporter=.=source;.;source_workload=.=productpage-v1;.;source_workload_namespace=.=default;.;source_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-productpage;.;source_app=.=productpage;.;source_version=.=v1;.;source_canonical_service=.=productpage;.;source_canonical_revision=.=v1;.;destination_workload=.=reviews-v1;.;destination_workload_namespace=.=default;.;destination_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-reviews;.;destination_app=.=reviews;.;destination_version=.=v1;.;destination_service=.=reviews.default.svc.cluster.local;.;destination_service_name=.=reviews;.;destination_service_namespace=.=default;.;destination_canonical_service=.=reviews;.;destination_canonical_revision=.=v1;.;request_protocol=.=http;.;response_code=.=200;.;grpc_response_status=.=;.;response_flags=.=-;.;connection_security_policy=.=unknown;.;_istio_response_bytes: P0(nan,459.99999999999994) P25(nan,462.59999999999997) P50(nan,465.19999999999993) P75(nan,467.79999999999995) P90(nan,469.35999999999996) P95(nan,469.87999999999994) P99(nan,477.4) P99.5(nan,478.7) P99.9(nan,479.74) P100(nan,480.0)
reporter=.=source;.;source_workload=.=productpage-v1;.;source_workload_namespace=.=default;.;source_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-productpage;.;source_app=.=productpage;.;source_version=.=v1;.;source_canonical_service=.=productpage;.;source_canonical_revision=.=v1;.;destination_workload=.=reviews-v2;.;destination_workload_namespace=.=default;.;destination_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-reviews;.;destination_app=.=reviews;.;destination_version=.=v2;.;destination_service=.=reviews.default.svc.cluster.local;.;destination_service_name=.=reviews;.;destination_service_namespace=.=default;.;destination_canonical_service=.=reviews;.;destination_canonical_revision=.=v2;.;request_protocol=.=http;.;response_code=.=200;.;grpc_response_status=.=;.;response_flags=.=-;.;connection_security_policy=.=unknown;.;_istio_request_bytes: P0(nan,1200.0) P25(nan,1322.0) P50(nan,1348.0) P75(nan,1374.0) P90(nan,1389.6) P95(nan,1394.8) P99(nan,1398.96) P99.5(nan,1399.48) P99.9(nan,1399.896) P100(nan,1400.0)
reporter=.=source;.;source_workload=.=productpage-v1;.;source_workload_namespace=.=default;.;source_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-productpage;.;source_app=.=productpage;.;source_version=.=v1;.;source_canonical_service=.=productpage;.;source_canonical_revision=.=v1;.;destination_workload=.=reviews-v2;.;destination_workload_namespace=.=default;.;destination_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-reviews;.;destination_app=.=reviews;.;destination_version=.=v2;.;destination_service=.=reviews.default.svc.cluster.local;.;destination_service_name=.=reviews;.;destination_service_namespace=.=default;.;destination_canonical_service=.=reviews;.;destination_canonical_revision=.=v2;.;request_protocol=.=http;.;response_code=.=200;.;grpc_response_status=.=;.;response_flags=.=-;.;connection_security_policy=.=unknown;.;_istio_request_duration_milliseconds: P0(nan,15.0) P25(nan,17.75) P50(nan,20.0) P75(nan,27.166666666666668) P90(nan,43.400000000000006) P95(nan,47.7) P99(nan,777.4) P99.5(nan,778.7) P99.9(nan,779.74) P100(nan,780.0)
reporter=.=source;.;source_workload=.=productpage-v1;.;source_workload_namespace=.=default;.;source_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-productpage;.;source_app=.=productpage;.;source_version=.=v1;.;source_canonical_service=.=productpage;.;source_canonical_revision=.=v1;.;destination_workload=.=reviews-v2;.;destination_workload_namespace=.=default;.;destination_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-reviews;.;destination_app=.=reviews;.;destination_version=.=v2;.;destination_service=.=reviews.default.svc.cluster.local;.;destination_service_name=.=reviews;.;destination_service_namespace=.=default;.;destination_canonical_service=.=reviews;.;destination_canonical_revision=.=v2;.;request_protocol=.=http;.;response_code=.=200;.;grpc_response_status=.=;.;response_flags=.=-;.;connection_security_policy=.=unknown;.;_istio_response_bytes: P0(nan,550.0) P25(nan,552.5) P50(nan,555.0) P75(nan,557.5) P90(nan,559.0) P95(nan,559.5) P99(nan,559.9) P99.5(nan,559.95) P99.9(nan,559.99) P100(nan,560.0)
reporter=.=source;.;source_workload=.=productpage-v1;.;source_workload_namespace=.=default;.;source_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-productpage;.;source_app=.=productpage;.;source_version=.=v1;.;source_canonical_service=.=productpage;.;source_canonical_revision=.=v1;.;destination_workload=.=reviews-v3;.;destination_workload_namespace=.=default;.;destination_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-reviews;.;destination_app=.=reviews;.;destination_version=.=v3;.;destination_service=.=reviews.default.svc.cluster.local;.;destination_service_name=.=reviews;.;destination_service_namespace=.=default;.;destination_canonical_service=.=reviews;.;destination_canonical_revision=.=v3;.;request_protocol=.=http;.;response_code=.=200;.;grpc_response_status=.=;.;response_flags=.=-;.;connection_security_policy=.=unknown;.;_istio_request_bytes: P0(nan,1200.0) P25(nan,1321.875) P50(nan,1347.9166666666667) P75(nan,1373.9583333333333) P90(nan,1389.5833333333333) P95(nan,1394.7916666666667) P99(nan,1398.9583333333333) P99.5(nan,1399.4791666666667) P99.9(nan,1399.8958333333333) P100(nan,1400.0)
reporter=.=source;.;source_workload=.=productpage-v1;.;source_workload_namespace=.=default;.;source_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-productpage;.;source_app=.=productpage;.;source_version=.=v1;.;source_canonical_service=.=productpage;.;source_canonical_revision=.=v1;.;destination_workload=.=reviews-v3;.;destination_workload_namespace=.=default;.;destination_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-reviews;.;destination_app=.=reviews;.;destination_version=.=v3;.;destination_service=.=reviews.default.svc.cluster.local;.;destination_service_name=.=reviews;.;destination_service_namespace=.=default;.;destination_canonical_service=.=reviews;.;destination_canonical_revision=.=v3;.;request_protocol=.=http;.;response_code=.=200;.;grpc_response_status=.=;.;response_flags=.=-;.;connection_security_policy=.=unknown;.;_istio_request_duration_milliseconds: P0(nan,16.0) P25(nan,17.8125) P50(nan,19.833333333333332) P75(nan,22.75) P90(nan,25.833333333333332) P95(nan,43.75) P99(nan,847.5) P99.5(nan,848.75) P99.9(nan,849.75) P100(nan,850.0)
reporter=.=source;.;source_workload=.=productpage-v1;.;source_workload_namespace=.=default;.;source_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-productpage;.;source_app=.=productpage;.;source_version=.=v1;.;source_canonical_service=.=productpage;.;source_canonical_revision=.=v1;.;destination_workload=.=reviews-v3;.;destination_workload_namespace=.=default;.;destination_principal=.=spiffe://cluster.local/ns/default/sa/bookinfo-reviews;.;destination_app=.=reviews;.;destination_version=.=v3;.;destination_service=.=reviews.default.svc.cluster.local;.;destination_service_name=.=reviews;.;destination_service_namespace=.=default;.;destination_canonical_service=.=reviews;.;destination_canonical_revision=.=v3;.;request_protocol=.=http;.;response_code=.=200;.;grpc_response_status=.=;.;response_flags=.=-;.;connection_security_policy=.=unknown;.;_istio_response_bytes: P0(nan,540.0) P25(nan,542.6041666666666) P50(nan,545.2083333333334) P75(nan,547.8125) P90(nan,549.375) P95(nan,549.8958333333334) P99(nan,557.5) P99.5(nan,558.75) P99.9(nan,559.75) P100(nan,560.0)
server.initialization_time_ms: P0(nan,14000.0) P25(nan,14250.0) P50(nan,14500.0) P75(nan,14750.0) P90(nan,14900.0) P95(nan,14950.0) P99(nan,14990.0) P99.5(nan,14995.0) P99.9(nan,14999.0) P100(nan,15000.0)
```

## 一些常用的运维命令

```text

//查看里面的为服务
istio ps

//查看端口的一些fliter
istioctl  pc l  productpage-v1-65576bb7bf-qlqfh.default --port 80 -o json

//查看网关下面的virtualhost RDS
[devops_root@ali-tekton-CI-devops-dev-01 ~]$ istioctl pc   r istio-ingressgateway-58649bfdf4-p84z4.istio-system --name http.80  -o json
[
    {
        "name": "http.80",
        "virtualHosts": [
            {
                "name": "*:80",
                "domains": [
                    "*"
                ],
                "routes": [
                    {
                        "match": {
                            "path": "/productpage",
                            "caseSensitive": true
                        },
                        "route": {
                            "cluster": "outbound|9080||productpage.default.svc.cluster.local",
                            "timeout": "0s",
                            "retryPolicy": {
                                "retryOn": "connect-failure,refused-stream,unavailable,cancelled,retriable-status-codes",
                                "numRetries": 2,
                                "retryHostPredicate": [
                                    {
                                        "name": "envoy.retry_host_predicates.previous_hosts"
                                    }
                                ],
                                "hostSelectionRetryMaxAttempts": "5",
                                "retriableStatusCodes": [
                                    503
                                ]
                            },
                            "maxGrpcTimeout": "0s"
                        },
                        "metadata": {
                            "filterMetadata": {
                                "istio": {
                                    "config": "/apis/networking.istio.io/v1alpha3/namespaces/default/virtual-service/bookinfo"
                                }
                            }
                        },
                        "decorator": {
                            "operation": "productpage.default.svc.cluster.local:9080/productpage"
                        }
                    },
                    {
                        "match": {
                            "prefix": "/static",
                            "caseSensitive": true
                        },
                        "route": {
                            "cluster": "outbound|9080||productpage.default.svc.cluster.local",
                            "timeout": "0s",
                            "retryPolicy": {
                                "retryOn": "connect-failure,refused-stream,unavailable,cancelled,retriable-status-codes",
                                "numRetries": 2,
                                "retryHostPredicate": [
                                    {
                                        "name": "envoy.retry_host_predicates.previous_hosts"
                                    }
                                ],
                                "hostSelectionRetryMaxAttempts": "5",
                                "retriableStatusCodes": [
                                    503
                                ]
                            },
                            "maxGrpcTimeout": "0s"
                        },
                        "metadata": {
                            "filterMetadata": {
                                "istio": {
                                    "config": "/apis/networking.istio.io/v1alpha3/namespaces/default/virtual-service/bookinfo"
                                }
                            }
                        },
                        "decorator": {
                            "operation": "productpage.default.svc.cluster.local:9080/static*"
                        }
                    },
                    {
                        "match": {
                            "path": "/login",
                            "caseSensitive": true
                        },
                        "route": {
                            "cluster": "outbound|9080||productpage.default.svc.cluster.local",
                            "timeout": "0s",
                            "retryPolicy": {
                                "retryOn": "connect-failure,refused-stream,unavailable,cancelled,retriable-status-codes",
                                "numRetries": 2,
                                "retryHostPredicate": [
                                    {
                                        "name": "envoy.retry_host_predicates.previous_hosts"
                                    }
                                ],
                                "hostSelectionRetryMaxAttempts": "5",
                                "retriableStatusCodes": [
                                    503
                                ]
                            },
                            "maxGrpcTimeout": "0s"
                        },
                        "metadata": {
                            "filterMetadata": {
                                "istio": {
                                    "config": "/apis/networking.istio.io/v1alpha3/namespaces/default/virtual-service/bookinfo"
                                }
                            }
                        },
                        "decorator": {
                            "operation": "productpage.default.svc.cluster.local:9080/login"
                        }
                    },
                    {
                        "match": {
                            "path": "/logout",
                            "caseSensitive": true
                        },
                        "route": {
                            "cluster": "outbound|9080||productpage.default.svc.cluster.local",
                            "timeout": "0s",
                            "retryPolicy": {
                                "retryOn": "connect-failure,refused-stream,unavailable,cancelled,retriable-status-codes",
                                "numRetries": 2,
                                "retryHostPredicate": [
                                    {
                                        "name": "envoy.retry_host_predicates.previous_hosts"
                                    }
                                ],
                                "hostSelectionRetryMaxAttempts": "5",
                                "retriableStatusCodes": [
                                    503
                                ]
                            },
                            "maxGrpcTimeout": "0s"
                        },
                        "metadata": {
                            "filterMetadata": {
                                "istio": {
                                    "config": "/apis/networking.istio.io/v1alpha3/namespaces/default/virtual-service/bookinfo"
                                }
                            }
                        },
                        "decorator": {
                            "operation": "productpage.default.svc.cluster.local:9080/logout"
                        }
                    },
                    {
                        "match": {
                            "prefix": "/api/v1/products",
                            "caseSensitive": true
                        },
                        "route": {
                            "cluster": "outbound|9080||productpage.default.svc.cluster.local",
                            "timeout": "0s",
                            "retryPolicy": {
                                "retryOn": "connect-failure,refused-stream,unavailable,cancelled,retriable-status-codes",
                                "numRetries": 2,
                                "retryHostPredicate": [
                                    {
                                        "name": "envoy.retry_host_predicates.previous_hosts"
                                    }
                                ],
                                "hostSelectionRetryMaxAttempts": "5",
                                "retriableStatusCodes": [
                                    503
                                ]
                            },
                            "maxGrpcTimeout": "0s"
                        },
                        "metadata": {
                            "filterMetadata": {
                                "istio": {
                                    "config": "/apis/networking.istio.io/v1alpha3/namespaces/default/virtual-service/bookinfo"
                                }
                            }
                        },
                        "decorator": {
                            "operation": "productpage.default.svc.cluster.local:9080/api/v1/products*"
                        }
                    }
                ],
                "includeRequestAttemptCount": true
            }
        ],
        "validateClusters": false
    }
]


//然后再到CDS
[devops_root@ali-tekton-CI-devops-dev-01 ~]$  istioctl pc  c  istio-ingressgateway-58649bfdf4-p84z4.istio-system  | grep productpage.default.svc.cluster.local
outbound_.9080_._.productpage.default.svc.cluster.local                          -         -               -             EDS            productpage.default
outbound_.9080_.v1_.productpage.default.svc.cluster.local                        -         -               -             EDS            productpage.default
productpage.default.svc.cluster.local                                            9080      -               outbound      EDS            productpage.default
productpage.default.svc.cluster.local                                            9080      v1              outbound      EDS            productpage.default


[devops_root@ali-tekton-CI-devops-dev-01 ~]$  istioctl pc  c  istio-ingressgateway-58649bfdf4-p84z4.istio-system  --fqdn  productpage.default.svc.cluster.local -o json
[
    {
        "name": "outbound_.9080_._.productpage.default.svc.cluster.local",
        "type": "EDS",
        "edsClusterConfig": {
            "edsConfig": {
                "ads": {},
                "resourceApiVersion": "V3"
            },
            "serviceName": "outbound_.9080_._.productpage.default.svc.cluster.local"
        },
        "connectTimeout": "10s",
        "circuitBreakers": {
            "thresholds": [
                {
                    "maxConnections": 4294967295,
                    "maxPendingRequests": 4294967295,
                    "maxRequests": 4294967295,
                    "maxRetries": 4294967295
                }
            ]
        },
        "metadata": {
            "filterMetadata": {
                "istio": {
                    "config": "/apis/networking.istio.io/v1alpha3/namespaces/default/destination-rule/productpage"
                }
            }
        },
        "filters": [
            {
                "name": "istio.metadata_exchange",
                "typedConfig": {
                    "@type": "type.googleapis.com/udpa.type.v1.TypedStruct",
                    "typeUrl": "type.googleapis.com/envoy.tcp.metadataexchange.config.MetadataExchange",
                    "value": {
                        "protocol": "istio-peer-exchange"
                    }
                }
            }
        ]
    },
    {
        "name": "outbound_.9080_.v1_.productpage.default.svc.cluster.local",
        "type": "EDS",
        "edsClusterConfig": {
            "edsConfig": {
                "ads": {},
                "resourceApiVersion": "V3"
            },
            "serviceName": "outbound_.9080_.v1_.productpage.default.svc.cluster.local"
        },
        "connectTimeout": "10s",
        "circuitBreakers": {
            "thresholds": [
                {
                    "maxConnections": 4294967295,
                    "maxPendingRequests": 4294967295,
                    "maxRequests": 4294967295,
                    "maxRetries": 4294967295
                }
            ]
        },
        "metadata": {
            "filterMetadata": {
                "istio": {
                    "config": "/apis/networking.istio.io/v1alpha3/namespaces/default/destination-rule/productpage",
                    "subset": "v1"
                }
            }
        },
        "filters": [
            {
                "name": "istio.metadata_exchange",
                "typedConfig": {
                    "@type": "type.googleapis.com/udpa.type.v1.TypedStruct",
                    "typeUrl": "type.googleapis.com/envoy.tcp.metadataexchange.config.MetadataExchange",
                    "value": {
                        "protocol": "istio-peer-exchange"
                    }
                }
            }
        ]
    },
    {
        "transportSocketMatches": [
            {
                "name": "tlsMode-istio",
                "match": {
                    "tlsMode": "istio"
                },
                "transportSocket": {
                    "name": "envoy.transport_sockets.tls",
                    "typedConfig": {
                        "@type": "type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.UpstreamTlsContext",
                        "commonTlsContext": {
                            "tlsCertificateSdsSecretConfigs": [
                                {
                                    "name": "default",
                                    "sdsConfig": {
                                        "apiConfigSource": {
                                            "apiType": "GRPC",
                                            "transportApiVersion": "V3",
                                            "grpcServices": [
                                                {
                                                    "envoyGrpc": {
                                                        "clusterName": "sds-grpc"
                                                    }
                                                }
                                            ]
                                        },
                                        "initialFetchTimeout": "0s",
                                        "resourceApiVersion": "V3"
                                    }
                                }
                            ],
                            "combinedValidationContext": {
                                "defaultValidationContext": {
                                    "matchSubjectAltNames": [
                                        {
                                            "exact": "spiffe://cluster.local/ns/default/sa/bookinfo-productpage"
                                        }
                                    ]
                                },
                                "validationContextSdsSecretConfig": {
                                    "name": "ROOTCA",
                                    "sdsConfig": {
                                        "apiConfigSource": {
                                            "apiType": "GRPC",
                                            "transportApiVersion": "V3",
                                            "grpcServices": [
                                                {
                                                    "envoyGrpc": {
                                                        "clusterName": "sds-grpc"
                                                    }
                                                }
                                            ]
                                        },
                                        "initialFetchTimeout": "0s",
                                        "resourceApiVersion": "V3"
                                    }
                                }
                            },
                            "alpnProtocols": [
                                "istio-peer-exchange",
                                "istio"
                            ]
                        },
                        "sni": "outbound_.9080_._.productpage.default.svc.cluster.local"
                    }
                }
            },
            {
                "name": "tlsMode-disabled",
                "match": {},
                "transportSocket": {
                    "name": "envoy.transport_sockets.raw_buffer"
                }
            }
        ],
        "name": "outbound|9080||productpage.default.svc.cluster.local",
        "type": "EDS",
        "edsClusterConfig": {
            "edsConfig": {
                "ads": {},
                "resourceApiVersion": "V3"
            },
            "serviceName": "outbound|9080||productpage.default.svc.cluster.local"
        },
        "connectTimeout": "10s",
        "circuitBreakers": {
            "thresholds": [
                {
                    "maxConnections": 4294967295,
                    "maxPendingRequests": 4294967295,
                    "maxRequests": 4294967295,
                    "maxRetries": 4294967295
                }
            ]
        },
        "metadata": {
            "filterMetadata": {
                "istio": {
                    "config": "/apis/networking.istio.io/v1alpha3/namespaces/default/destination-rule/productpage"
                }
            }
        },
        "filters": [
            {
                "name": "istio.metadata_exchange",
                "typedConfig": {
                    "@type": "type.googleapis.com/udpa.type.v1.TypedStruct",
                    "typeUrl": "type.googleapis.com/envoy.tcp.metadataexchange.config.MetadataExchange",
                    "value": {
                        "protocol": "istio-peer-exchange"
                    }
                }
            }
        ]
    },
    {
        "transportSocketMatches": [
            {
                "name": "tlsMode-istio",
                "match": {
                    "tlsMode": "istio"
                },
                "transportSocket": {
                    "name": "envoy.transport_sockets.tls",
                    "typedConfig": {
                        "@type": "type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.UpstreamTlsContext",
                        "commonTlsContext": {
                            "tlsCertificateSdsSecretConfigs": [
                                {
                                    "name": "default",
                                    "sdsConfig": {
                                        "apiConfigSource": {
                                            "apiType": "GRPC",
                                            "transportApiVersion": "V3",
                                            "grpcServices": [
                                                {
                                                    "envoyGrpc": {
                                                        "clusterName": "sds-grpc"
                                                    }
                                                }
                                            ]
                                        },
                                        "initialFetchTimeout": "0s",
                                        "resourceApiVersion": "V3"
                                    }
                                }
                            ],
                            "combinedValidationContext": {
                                "defaultValidationContext": {
                                    "matchSubjectAltNames": [
                                        {
                                            "exact": "spiffe://cluster.local/ns/default/sa/bookinfo-productpage"
                                        }
                                    ]
                                },
                                "validationContextSdsSecretConfig": {
                                    "name": "ROOTCA",
                                    "sdsConfig": {
                                        "apiConfigSource": {
                                            "apiType": "GRPC",
                                            "transportApiVersion": "V3",
                                            "grpcServices": [
                                                {
                                                    "envoyGrpc": {
                                                        "clusterName": "sds-grpc"
                                                    }
                                                }
                                            ]
                                        },
                                        "initialFetchTimeout": "0s",
                                        "resourceApiVersion": "V3"
                                    }
                                }
                            },
                            "alpnProtocols": [
                                "istio-peer-exchange",
                                "istio"
                            ]
                        },
                        "sni": "outbound_.9080_.v1_.productpage.default.svc.cluster.local"
                    }
                }
            },
            {
                "name": "tlsMode-disabled",
                "match": {},
                "transportSocket": {
                    "name": "envoy.transport_sockets.raw_buffer"
                }
            }
        ],
        "name": "outbound|9080|v1|productpage.default.svc.cluster.local",
        "type": "EDS",
        "edsClusterConfig": {
            "edsConfig": {
                "ads": {},
                "resourceApiVersion": "V3"
            },
            "serviceName": "outbound|9080|v1|productpage.default.svc.cluster.local"
        },
        "connectTimeout": "10s",
        "circuitBreakers": {
            "thresholds": [
                {
                    "maxConnections": 4294967295,
                    "maxPendingRequests": 4294967295,
                    "maxRequests": 4294967295,
                    "maxRetries": 4294967295
                }
            ]
        },
        "metadata": {
            "filterMetadata": {
                "istio": {
                    "config": "/apis/networking.istio.io/v1alpha3/namespaces/default/destination-rule/productpage",
                    "subset": "v1"
                }
            }
        },
        "filters": [
            {
                "name": "istio.metadata_exchange",
                "typedConfig": {
                    "@type": "type.googleapis.com/udpa.type.v1.TypedStruct",
                    "typeUrl": "type.googleapis.com/envoy.tcp.metadataexchange.config.MetadataExchange",
                    "value": {
                        "protocol": "istio-peer-exchange"
                    }
                }
            }
        ]
    }
]


//最后到EDS
[devops_root@ali-tekton-CI-devops-dev-01 ~]$ istioctl  pc  endpoint istio-ingressgateway-58649bfdf4-p84z4.istio-system |grep productpage.default.svc.cluster.local
10.16.0.112:9080                 HEALTHY     OK                outbound_.9080_._.productpage.default.svc.cluster.local
10.16.0.112:9080                 HEALTHY     OK                outbound_.9080_.v1_.productpage.default.svc.cluster.local
10.16.0.112:9080                 HEALTHY     OK                outbound|9080|v1|productpage.default.svc.cluster.local
10.16.0.112:9080                 HEALTHY     OK                outbound|9080||productpage.default.svc.cluster.local


```
