import Foundation
import FoundationModels
import AppleFoundationMCPTool

/// An interactive chat program that uses Apple's Foundation Models with automatic tool calling
@available(macOS 26.0, *)
@main
struct InteractiveChat {
    static func main() async throws {
        print("=== Apple Foundation Models Chat with Dynamic MCP Tools ===")
        print("Type your messages and press Enter to send.")
        print("Type 'quit' or 'exit' to end the conversation.")
        print("The model can automatically use tools discovered from the MCP server.")
        print("")
        
        // Create the session manager
        let sessionManager = SessionManager()
        
        // Connect to the MCP server and discover tools
        var mcpBridge: MCPToolBridge? = nil
        if let serverURL = URL(string: "http://127.0.0.1:8000/mcp") {
            do {
                mcpBridge = MCPToolBridge(serverURL: serverURL)
                let appleTools = try await mcpBridge!.connectAndDiscoverTools()
                
                // Register all discovered tools with the session
                for tool in appleTools {
                    sessionManager.addTool(tool)
                    print("Registered tool: \(tool.name)")
                }
                
                print("Successfully connected to MCP server and registered \(appleTools.count) tools.")
                print("")
            } catch {
                print("Warning: Failed to connect to MCP server: \(error.localizedDescription)")
                print("")
            }
        } else {
            print("Warning: Invalid MCP server URL. MCP functionality will not work.")
            print("")
        }
        
        // Main chat loop
        while true {
            print("You: ", terminator: "")
            
            // Read user input
            guard let input = readLine(), !input.isEmpty else {
                continue
            }
            
            // Check for quit commands
            if input.lowercased() == "quit" || input.lowercased() == "exit" {
                print("Goodbye!")
                break
            }
            
            // Process the user input
            do {
                let response = try await sessionManager.sendPrompt(input)
                print("Assistant: \(response)")
                print("")
            } catch {
                print("Error: \(error.localizedDescription)")
                print("")
            }
        }
        
        // Clean up
        if let mcpBridge = mcpBridge {
            await mcpBridge.disconnect()
        }
    }
}