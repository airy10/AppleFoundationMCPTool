import System
import Foundation

#if canImport(AnyLanguageModel)
@_exported import AnyLanguageModel
public struct AnyFoundationModels {
    public typealias Tool = AnyLanguageModel.Tool
    public typealias GeneratedContent = AnyLanguageModel.GeneratedContent
    public typealias ConvertibleFromGeneratedContent = AnyLanguageModel.ConvertibleFromGeneratedContent
    public typealias DynamicGenerationSchema = AnyLanguageModel.DynamicGenerationSchema
}
#else
@_exported import FoundationModels
public struct AnyFoundationModels {
    public typealias Tool = FoundationModels.Tool
    public typealias GeneratedContent = FoundationModels.GeneratedContent
    public typealias ConvertibleFromGeneratedContent = FoundationModels.ConvertibleFromGeneratedContent
    public typealias DynamicGenerationSchema = FoundationModels.DynamicGenerationSchema
}
#endif

import MCP
import os

private let logger = Logger(subsystem: "com.airy.applefoundationmcptool", category: "main")

/// Defines the connection method for the MCP server.
public enum MCPConnection {
    /// Connect to an MCP server via HTTP at the specified URL.
    case http(serverURL: URL)
    /// Launch and connect to an MCP server via standard input/output.
    case stdio(executablePath: String, arguments: [String] = [])
}
@available(macOS 26.0, *)
/// A dynamic bridge that connects to an MCP server and registers its tools with Apple's Foundation Models
@available(macOS 26.0, *)
public class MCPToolBridge {
    private let connection: MCPConnection
    private var client: Client?
    private var serverProcess: Process?

    /// Initializes a new MCPToolBridge instance using a specific connection type.
    /// - Parameter connection: The connection type, either `.http` with a server URL or `.stdio` with a server executable path.
    public init(connection: MCPConnection) {
        self.connection = connection
    }

    /// Convenience initializer for creating a bridge with an HTTP connection.
    /// - Parameter serverURL: The URL of the MCP server.
    public convenience init(serverURL: URL) {
        self.init(connection: .http(serverURL: serverURL))
    }

    /// Convenience initializer for creating a bridge that launches and connects to a server via stdin/stdout.
    /// - Parameters:
    ///   - executablePath: The path to the MCP server executable.
    ///   - arguments: The command-line arguments to pass to the executable.
    public convenience init(executablePath: String, arguments: [String] = []) {
        self.init(connection: .stdio(executablePath: executablePath, arguments: arguments))
    }
    
    /// Connects to the MCP server and discovers available tools. For stdio connections, it also launches the server process.
    public func connectAndDiscoverTools(_ filter : ((MCP.Tool) -> Bool) = { _ in true }) async throws -> [any AnyFoundationModels.Tool] {
        let transport: any Transport
        switch connection {
        case .http(let serverURL):
            transport = HTTPClientTransport(endpoint: serverURL)
        case .stdio(let executablePath, let arguments):
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments

            let toServerPipe = Pipe()
            let fromServerPipe = Pipe()

            process.standardInput = toServerPipe
            process.standardOutput = fromServerPipe

            try process.run()
            self.serverProcess = process

            transport = StdioTransport(
                input: FileDescriptor(rawValue: fromServerPipe.fileHandleForReading.fileDescriptor),
                output: FileDescriptor(rawValue: toServerPipe.fileHandleForWriting.fileDescriptor)
            )
        }
        
        let client = Client(name: "AppleFoundationMCPTool", version: "1.0.0")
        
        try await client.connect(transport: transport)
        self.client = client
        
        let listToolsResponse = try await client.listTools()

        var appleTools: [any AnyFoundationModels.Tool] = []
        for tool in listToolsResponse.tools.filter({ filter($0)}) {
            let appleTool = DynamicMCPTool(
                mcpClient: client,
                toolName: tool.name,
                toolDescription: tool.description ?? "",
                inputSchema: tool.inputSchema
            )
            appleTools.append(appleTool)
        }

        return appleTools
    }
    
    /// Disconnects from the MCP server and terminates the server process if it was launched by the bridge.
    public func disconnect() async {
        if let client = self.client {
            await client.disconnect()
        }
        self.client = nil

        if let serverProcess = self.serverProcess {
            if serverProcess.isRunning {
                serverProcess.terminate()
            }
            self.serverProcess = nil
        }
    }
}

/// A dynamic tool that bridges between Apple's Foundation Models and MCP tools
@available(macOS 26.0, *)
public struct DynamicMCPTool: AnyFoundationModels.Tool {

    public struct Arguments: AnyFoundationModels.ConvertibleFromGeneratedContent, Codable {
        public let jsonString: String

        public init(jsonString: String) {
            self.jsonString = jsonString
        }

        public init(_ content: AnyFoundationModels.GeneratedContent) throws {
            self.jsonString = content.jsonString
        }
    }

    /// The MCP client
    private let mcpClient: Client
    
    /// The name of the MCP tool
    private let toolName: String
    
    /// The name of the tool
    public let name: String
    
    /// The description of the tool
    public let description: String
    
    /// The parameters schema for the tool
    public let parameters: GenerationSchema
    
    /// Whether to include the schema in instructions
    public let includesSchemaInInstructions = true

    /// Initializes a new DynamicMCPTool instance
    /// - Parameters:
    ///   - mcpClient: The MCP client
    ///   - toolName: The name of the MCP tool
    ///   - toolDescription: The description of the MCP tool
    ///   - inputSchema: The input schema for the MCP tool
    init(mcpClient: Client, toolName: String, toolDescription: String, inputSchema: Value) {
        self.mcpClient = mcpClient
        self.toolName = toolName
        self.name = toolName
        self.description = toolDescription
        self.parameters =  Self.convertMCPSchemaToGenerationSchema(toolName: toolName, inputSchema: inputSchema)
    }

    /// Converts the MCP schema to Apple's GenerationSchema
    /// - Returns: The converted Apple GenerationSchema
    private static func convertMCPSchemaToGenerationSchema(toolName: String, inputSchema : Value) -> GenerationSchema {
        let converter = ValueSchemaConverter(root: inputSchema.objectValue ?? [:])
        if let dynamicSchema = converter.schema(), let schema = try? GenerationSchema(root: dynamicSchema, dependencies: []) {
            return schema
        } else {
            return GenerationSchema(
                type: String.self,
               description: "tool parameters",
               properties: [])
        }
    }

    /// Calls the MCP tool with the provided arguments
    /// - Parameter arguments: The arguments for the MCP tool
    /// - Returns: The response from the MCP tool
    public func call(arguments: Arguments) async throws -> String {
        guard let jsonData = arguments.jsonString.data(using: .utf8) else {
            let errorMessage = "Error: Could not convert JSON string to Data."
            logger.error("\(errorMessage)")
            return errorMessage
        }
        
        do {
            guard let mcpArguments = try? JSONDecoder().decode([String: Value].self, from:jsonData) else {
                let errorMessage = "Error: can't convert arguments to MCP JSON."
                logger.error("\(errorMessage): \(arguments.jsonString)")
                return errorMessage
            }

            logger.debug("Calling MCP tool '\(toolName)' with arguments: \(mcpArguments)")

            // Call the MCP tool
            let request = CallTool.request(.init(name: toolName, arguments: mcpArguments))
            let response = try await mcpClient.send(request)

            // Convert the result to a string
            var resultString = ""
            for content in response.content {
                switch content {
                case .text(let text):
                    resultString += text
                case .image(let data, let mimeType, _):
                    resultString += "[Image: \(mimeType), \(data.prefix(50))...]"
                case .audio(let data, let mimeType):
                    resultString += "[Audio: \(mimeType), \(data.prefix(50))...]"
                case .resource(let uri, let mimeType, let text):
                    resultString += "[Resource: \(uri), \(mimeType)]"
                    if let text = text {
                        resultString += " \(text.prefix(50))..."
                    }
                }
            }
            
            logger.debug("result: \(resultString)")
            return resultString
        } catch {
            // Handle JSON parsing or other errors
            let errorMessage = "Error calling MCP tool '\(toolName)': \(error.localizedDescription). Invalid JSON: \(arguments.jsonString)"
            logger.debug("\(errorMessage)")
            return errorMessage
        }
    }
}
