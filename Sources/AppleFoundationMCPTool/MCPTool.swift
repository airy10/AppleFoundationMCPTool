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
        let paramsDict = try JSONDecoder().decode([String: AnyCodable].self, from: Data(arguments.jsonString.utf8))
        print("Calling MCP tool '\(toolName)' with arguments: \(paramsDict)")
        
        do {
            // Convert arguments to the format expected by MCP
            var mcpArguments: [String: Value] = [:]
            for (key, value) in paramsDict {
                // Convert AnyCodable to Value
                if let stringValue = value.value as? String {
                    mcpArguments[key] = .string(stringValue)
                } else if let intValue = value.value as? Int {
                    mcpArguments[key] = .int(intValue)
                } else if let doubleValue = value.value as? Double {
                    mcpArguments[key] = .double(doubleValue)
                } else if let boolValue = value.value as? Bool {
                    mcpArguments[key] = .bool(boolValue)
                } else if let arrayValue = value.value as? [Any] {
                    // Convert array elements
                    var mcpArray: [Value] = []
                    for element in arrayValue {
                        if let str = element as? String {
                            mcpArray.append(.string(str))
                        } else if let int = element as? Int {
                            mcpArray.append(.int(int))
                        } else if let double = element as? Double {
                            mcpArray.append(.double(double))
                        } else if let bool = element as? Bool {
                            mcpArray.append(.bool(bool))
                        } else {
                            mcpArray.append(.string(String(describing: element)))
                        }
                    }
                    mcpArguments[key] = .array(mcpArray)
                } else if let dictValue = value.value as? [String: Any] {
                    // Convert dictionary elements
                    var mcpDict: [String: Value] = [:]
                    for (dictKey, dictValue) in dictValue {
                        if let str = dictValue as? String {
                            mcpDict[dictKey] = .string(str)
                        } else if let int = dictValue as? Int {
                            mcpDict[dictKey] = .int(int)
                        } else if let double = dictValue as? Double {
                            mcpDict[dictKey] = .double(double)
                        } else if let bool = dictValue as? Bool {
                            mcpDict[dictKey] = .bool(bool)
                        } else {
                            mcpDict[dictKey] = .string(String(describing: dictValue))
                        }
                    }
                    mcpArguments[key] = .object(mcpDict)
                } else {
                    // For other types, convert to string
                    mcpArguments[key] = .string(String(describing: value.value))
                }
            }
            
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
            // Handle error case
            let errorMessage = "Error calling MCP tool '\(toolName)': \(error.localizedDescription)"
            print(errorMessage)
            return errorMessage
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