## 通过OpenTelemetry上报iOS/Swift应用数据

###步骤一：创建应用并添加依赖
1. 选择要创建的应用，如 macOS Command Line Tool

2. 在XCode中选择File -> Add Packages...，在搜索框中输入https://github.com/open-telemetry/opentelemetry-swift，选择1.4.1版本，更多信息请参考[opentelemetry-swift releases信息](https://github.com/open-telemetry/opentelemetry-swift/releases) 

3. 勾选所需的Package Products，在本例中使用到的Package Products包括：

###步骤二： OpenTelemetry初始化
1. 创建用于导出观测数据的组件，有以下三种导出方式
- 方法一：通过grpc协议上报Trace数据
    - 请分别将 <gRPC-endpoint> 和 <gRPC-port> 替换为从前提条件中获取的接入点，例如host: "http://tracing-analysis-dc-hz.aliyuncs.com", port:8090
```swift
let grpcChannel = ClientConnection.usingPlatformAppropriateTLS(for: MultiThreadedEventLoopGroup(numberOfThreads:1))
.connect(host: "<gRPC-endpoint>", port:<gRPC-port>)

let otlpGrpcConfiguration = OtlpConfiguration(
    timeout: OtlpConfiguration.DefaultTimeoutInterval,
    headers: [
        ("Authentication","<your-token>")
    ]

)

let otlpGrpcTraceExporter = OtlpTraceExporter(channel: grpcChannel, config: otlpGrpcConfiguration)
```

- 方法二：通过http协议上报Trace数据
   - 请将<HTTP-endpoint>替换为从前提条件中获取的接入点，例如http://tracing-analysis-dc-hz.aliyuncs.com/adapt_aokcdqn3ly@xxxx_xxxx@xxxx/api/otlp/traces
   
```swift
let url = URL(string: "<HTTP-endpoint>")
let otlpHttpTraceExporter = OtlpHttpTraceExporter(endpoint: url!)
```

- 方法三：在命令行输出Trace数据
```swift
let consoleTraceExporter = StdoutExporter(isDebug: true)
```

2. 获取用于创建Span的Tracer
- 请将<your-service-name>替换为要上报的应用名，<your-host-name> 替换为主机名
- 请从以上三种导出方式中选择一种，并将<trace-exporter> 替换为变量otlpGrpcTraceExporter、otlpHttpTraceExporter或consoleTraceExporter
```swift
// 设置应用名与主机名
let resource = Resource(attributes: [
    ResourceAttributes.serviceName.rawValue: AttributeValue.string("<your-service-name>"),
    ResourceAttributes.hostName.rawValue: AttributeValue.string("<your-host-name>")
])

// 配置TracerProvider
OpenTelemetry.registerTracerProvider(tracerProvider: TracerProviderBuilder()
                                     .add(spanProcessor: BatchSpanProcessor(spanExporter: <trace-exporter>)) // 通过gRPC协议上报至链路追踪
                                     .with(resource: resource)
                                     .build())

// 获取tracer，用来创建Span
let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "instrumentation-library-name", instrumentationVersion: "1.0.0")
```

### 步骤三：创建Span，追踪链路数据
1. 创建Span，为Span添加属性（Attribute）和事件（Event），并输出当前Span的TraceId
```swift
let span = tracer.spanBuilder(spanName: "first span").startSpan()
// 设置属性
span.setAttribute(key: "http.method", value: "GET")
span.setAttribute(key: "http.url", value: "www.aliyun.com")
let attributes = [
    "key": AttributeValue.string("value"),
    "result": AttributeValue.int(100)
]

// your code...

// 设置Event
span.addEvent(name: "computation complete", attributes: attributes)

// 打印TraceId
print(span.context.traceId.hexString)

// your code...

// 结束当前span
span.end()
```

2. 创建嵌套的Span
```swift
let parentSpan = tracer.spanBuilder(spanName: "parent span").startSpan()

// your code...

let childSpan = tracer.spanBuilder(spanName: "child span").setParent(parentSpan).startSpan()

// your code...

childSpan.end()

// your code...

parentSpan.end()
```

3. 启动应用
