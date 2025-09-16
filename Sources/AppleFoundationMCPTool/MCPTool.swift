import Foundation
import FoundationModels
import MCP

/// A dynamic bridge that connects to an MCP server and registers its tools with Apple's Foundation Models
@available(macOS 26.0, *)
public class MCPToolBridge {
    private let serverURL: URL
    private var client: Client?
    
    /// Initializes a new MCPToolBridge instance
    /// - Parameter serverURL: The URL of the MCP server
    public init(serverURL: URL) {
        self.serverURL = serverURL
    }
    
    /// Connects to the MCP server and discovers available tools
    public func connectAndDiscoverTools() async throws -> [any FoundationModels.Tool] {
        // Create the HTTP client transport
        let transport = HTTPClientTransport(endpoint: serverURL)
        
        // Create the MCP client
        let client = Client(name: "AppleFoundationMCPTool", version: "1.0.0")
        
        // Connect to the server
        try await client.connect(transport: transport)
        self.client = client
        
        // List available tools from the server
        let listToolsRequest = ListTools.request(.init())
        let listToolsResponse = try await client.send(listToolsRequest)
        
        // Print debug info about discovered tools
        // print("Discovered \(listToolsResponse.tools.count) tools from MCP server:")
        // for tool in listToolsResponse.tools {
        //     print("  - \(tool.name): \(tool.description)")
        //     // Print the input schema if available
        //     print("    Schema: \(tool.inputSchema)")
        // }
        
        // Create Apple Foundation Models tools for each MCP tool
        var appleTools: [any FoundationModels.Tool] = []
        for tool in listToolsResponse.tools {
            let appleTool = DynamicMCPTool(
                mcpClient: client,
                toolName: tool.name,
                toolDescription: tool.description,
                inputSchema: tool.inputSchema
            )
            appleTools.append(appleTool)
        }
        
        return appleTools
    }
    
    /// Disconnects from the MCP server
    public func disconnect() async {
        if let client = self.client {
            await client.disconnect()
        }
        self.client = nil
    }
}

/// A dynamic tool that bridges between Apple's Foundation Models and MCP tools
@available(macOS 26.0, *)
public struct DynamicMCPTool: FoundationModels.Tool {
    public struct Arguments: FoundationModels.ConvertibleFromGeneratedContent, Codable {
        public let jsonString: String

        public init(jsonString: String) {
            self.jsonString = jsonString
        }

        public init(_ content: FoundationModels.GeneratedContent) throws {
            self.jsonString = String(describing: content)
        }
    }

    public typealias Output = String
    
    /// The MCP client
    private let mcpClient: Client
    
    /// The name of the MCP tool
    private let toolName: String
    
    /// The input schema for the tool
    private let inputSchema: Value
    
    /// The name of the tool
    public let name: String
    
    /// The description of the tool
    public let description: String
    
    /// The parameters schema for the tool
    public var parameters: GenerationSchema {
        // Convert the MCP schema to Apple's GenerationSchema
        return convertMCPSchemaToGenerationSchema()
    }
    
    /// Whether to include the schema in instructions
    public var includesSchemaInInstructions: Bool = true
    
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
        self.inputSchema = inputSchema
    }
    
    /// Converts the MCP schema to Apple's GenerationSchema
    /// - Returns: The converted Apple GenerationSchema
    private func convertMCPSchemaToGenerationSchema() -> GenerationSchema {
        return GenerationSchema(type: String.self, description: "JSON string containing parameters for the \(toolName) MCP tool", properties: [])
    }

    
    /// Calls the MCP tool with the provided arguments
    /// - Parameter arguments: The arguments for the MCP tool
    /// - Returns: The response from the MCP tool
    public func call(arguments: Arguments) async throws -> Output {
        guard let jsonData = arguments.jsonString.data(using: .utf8) else {
            let errorMessage = "Error: Could not convert JSON string to Data."
            print(errorMessage)
            return errorMessage
        }
        
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: [])
            
            guard let paramsDict = jsonObject as? [String: Any] else {
                let errorMessage = "Error: JSON root is not a dictionary, or is not valid JSON."
                print("Received content: \(arguments.jsonString)")
                return errorMessage
            }

            print("Calling MCP tool '\(toolName)' with arguments: \(paramsDict)")

            // Convert arguments to the format expected by MCP using the recursive helper
            let mcpArguments = paramsDict.mapValues { convertToMCPValue(from: $0) }
            
            print("Converted MCP arguments: \(mcpArguments)")
            
            // Call the MCP tool
            let request = CallTool.request(.init(name: toolName, arguments: mcpArguments))
            print("Sending request to MCP server: \(request)")
            
            let response = try await mcpClient.send(request)
            print("Received response from MCP server: \(response)")
            
            // Convert the result to a string
            var resultString = ""
            for content in response.content {
                switch content {
                case .text(let text):
                    resultString += text
                case .image(let data, let mimeType, let _):
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
            
            let result = "MCP tool '\(toolName)' returned: \(resultString)"
            print("Converted result: \(result)")
            return result
        } catch {
            // Handle JSON parsing or other errors
            let errorMessage = "Error calling MCP tool '\(toolName)': \(error.localizedDescription). Invalid JSON: \(arguments.jsonString)"
            print(errorMessage)
            return errorMessage
        }
    }

    /// Recursively converts a value of type `Any` from `JSONSerialization` into an `MCP.Value`.
    /// - Parameter any: The value to convert.
    /// - Returns: The converted `MCP.Value`.
    private func convertToMCPValue(from any: Any) -> Value {
        switch any {
        case let stringValue as String:
            return .string(stringValue)
        case let numValue as NSNumber:
            // The objCType for a Swift Bool bridged to NSNumber is "c" (for C char).
            if String(cString: numValue.objCType) == "c" {
                return .bool(numValue.boolValue)
            }
            // Check if the number has a fractional part.
            if numValue.doubleValue != floor(numValue.doubleValue) {
                return .double(numValue.doubleValue)
            }
            // Otherwise, it's an integer.
            return .int(numValue.intValue)
        case let arrayValue as [Any]:
            return .array(arrayValue.map { convertToMCPValue(from: $0) })
        case let dictValue as [String: Any]:
            return .object(dictValue.mapValues { convertToMCPValue(from: $0) })
        case is NSNull:
            // MCP.Value does not have a direct representation for null.
            // We'll represent it as an empty string, which is a safe default.
            return .string("")
        default:
            // For any other unexpected type, fall back to a string representation.
            return .string(String(describing: any))
        }
    }
}

// MARK: - MCP.Value extensions

extension MCP.Value {
    var objectValue: [String: MCP.Value]? {
        if case .object(let dict) = self {
            return dict
        } else {
            return nil
        }
    }

    var stringValue: String? {
        if case .string(let str) = self {
            return str
        } else {
            return nil
        }
    }
}