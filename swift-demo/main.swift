//
//  main.swift
//  swift-demo
//

import Foundation
import GRPC
import NIO
import OpenTelemetryApi
import OpenTelemetrySdk
import OpenTelemetryProtocolExporter
import StdoutExporter



/**
  1. OpenTelemetry初始化配置
 */

// 1.1 通过grpc协议上报

let grpcChannel = ClientConnection.usingPlatformAppropriateTLS(for: MultiThreadedEventLoopGroup(numberOfThreads:1))
    .connect(host: "<gRPC-endpoint>", port:8090)

let otlpGrpcConfiguration = OtlpConfiguration(
    timeout: OtlpConfiguration.DefaultTimeoutInterval,
    headers: [
        ("Authentication","<token>")
    ]

)
let otlpGrpcTraceExporter = OtlpTraceExporter(channel: grpcChannel, config: otlpGrpcConfiguration)


// 1.2 通过http协议上报
let url = URL(string: "<HTTP-endpoint>")
let otlpHttpTraceExporter = OtlpHttpTraceExporter(endpoint: url!)

// 1.3 设置应用名与主机名
let resource = Resource(attributes: [
    ResourceAttributes.serviceName.rawValue: AttributeValue.string("<your-service-name>"),
    ResourceAttributes.hostName.rawValue: AttributeValue.string("<your-host-name>")
])


// 1.4 在控制台输出
let consoleTraceExporter = StdoutExporter(isDebug: true)


// 配置TracerProvider
OpenTelemetry.registerTracerProvider(tracerProvider: TracerProviderBuilder()
                                                     .add(spanProcessor: BatchSpanProcessor(spanExporter: otlpGrpcTraceExporter)) // 通过gRPC协议上报至链路追踪
                                                    // .add(spanProcessor: BatchSpanProcessor(spanExporter: otlpHttpTraceExporter)) // 通过HTTP协议上报至链路追踪
                                                     .add(spanProcessor: BatchSpanProcessor(spanExporter: consoleTraceExporter))  // 控制台输出Trace数据
                                                    .with(resource: resource)
                                                    .build())


/**
  2. 获取Tracer
 */

let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "instrumentation-library-name", instrumentationVersion: "1.0.0")



/**
  3. 创建Span
 */

// 创建第一个Span
let span = tracer.spanBuilder(spanName: "first span").startSpan()
// 设置属性
span.setAttribute(key: "http.method", value: "GET")
span.setAttribute(key: "http.url", value: "www.aliyun.com")
let attributes = [
    "stringKey": AttributeValue.string("value"),
    "intKey": AttributeValue.int(100)
]
// 设置Event
span.addEvent(name: "event", attributes: attributes)

// 打印TraceId
print(span.context.traceId.hexString)

span.end()

// 创建嵌套的Span
let parentSpan = tracer.spanBuilder(spanName: "parent span").startSpan()

let childSpan = tracer.spanBuilder(spanName: "child span").setParent(parentSpan).startSpan()


childSpan.end()

parentSpan.end()


sleep(10)

print("end")


