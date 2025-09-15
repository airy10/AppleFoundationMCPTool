import Foundation
import FoundationModels
import AppleFoundationMCPTool

// Example usage of the AppleFoundationMCPTool framework with MCP server

@available(macOS 26.0, *)
@main
struct ExampleApp {
    static func main() async throws {
        // Example 1: Basic usage
        print("=== Basic Usage ===")
        let tool = AppleFoundationMCPTool()
        let response = try await tool.sendPrompt("What are the benefits of using on-device AI?")
        print(response)
        
        // Example 2: Using with instructions
        print("\n=== Using with Instructions ===")
        let instructedTool = AppleFoundationMCPTool(instructions: "You are a helpful assistant that explains technical concepts in simple terms.")
        let simpleResponse = try await instructedTool.sendPrompt("Explain what a large language model is to a 10-year-old.")
        print(simpleResponse)
        
        // Example 3: Using with tools
        print("\n=== Using with Tools ===")
        let sessionManager = SessionManager(instructions: "You are a helpful assistant that can communicate with an MCP server for genealogy data. When asked to load a GEDCOM file, explain that you would use the DynamicMCPTool with method 'load_gedcom' and params containing the file path.")
        
        // Example 4: Ask the model to load a GEDCOM file
        print("\n=== Loading GEDCOM File ===")
        let gedcomResponse = try await sessionManager.sendPrompt("Please load the GEDCOM file 'ged.ged'")
        print(gedcomResponse)
        
        // Example 5: Actually use the tools
        print("\n=== Actually Using the Tools ===")
        
        // Create and use the MCP tool bridge
        guard let serverURL = URL(string: "http://127.0.0.1:8000/mcp") else {
            print("Invalid server URL")
            return
        }
        
        let mcpToolBridge = MCPToolBridge(serverURL: serverURL)
        let appleTools = try await mcpToolBridge.connectAndDiscoverTools()
        print("Successfully connected to MCP server and registered \(appleTools.count) tools.")
        
        // Use the first available tool (if any)
        if let firstTool = appleTools.first as? DynamicMCPTool {
            // For demonstration purposes, we'll just show that the tool exists
            print("First tool name: \(firstTool.name)")
            print("First tool description: \(firstTool.description)")
        }
        
        print("\n=== All examples completed! ===")
    }
}