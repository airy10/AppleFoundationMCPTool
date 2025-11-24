import Foundation
import AppleFoundationMCPTool

// Example usage of the AppleFoundationMCPTool framework with MCP server

@available(macOS 26.0, *)
struct ExampleApp {
    static func main() async throws {
        let model = SystemLanguageModel.default

        print("=== Basic Usage ===")
        var session = LanguageModelSession(model: model)
        let response = try await session.respond(to: "Explain what a large language model is. 5 lines answer").content
        print(response)
        
        // Example 2: Using with instructions
        print("\n=== Using with Instructions ===")
        let instructedTool = LanguageModelSession(model: model, instructions: "You are a helpful assistant that explains technical concepts so they are understable to very young kids.")
        let simpleResponse = try await instructedTool.respond(to: "Explain what a large language model is. 5 lines answer").content
        print(simpleResponse)
        
        // Example 3: Using with tools
        print("\n=== Using with Tools ===")
        session = LanguageModelSession(model: model, instructions: "You are a helpful assistant that can use tools to manipulate GEDCOM data")

        // Example 4: Ask the model to load a GEDCOM file
        print("\n=== Loading GEDCOM File without any tool  ===")
        let gedcomResponse = try await session.respond(to: "Load the GEDCOM file 'ged.ged'").content
        print(gedcomResponse)
        
        // Example 5: Actually use the tools
        print("\n=== Actually Using the Tools ===")
        // Create and use the MCP tool bridge
        guard let serverURL = URL(string: "http://127.0.0.1:8080/mcp") else {
            print("Invalid server URL")
            return
        }
        
        let mcpToolBridge = MCPToolBridge(serverURL: serverURL)
        let tools = try await mcpToolBridge.connectAndDiscoverTools()
        print("Successfully connected to MCP server and registered \(tools.count) tools.")

        for tool in tools {
            // For demonstration purposes, we'll just show that the tool exists
            print("Name: \(tool.name)")
            let description = tool.description.components(separatedBy: .newlines).prefix(2).joined(separator: "\n")
            print("                 \(description)")
        }
        print("\n=== Loading GEDCOM File ===")
        if let load_gedcom = tools.first(where: { $0.name == "load_gedcom" }),
           let find_person = tools.first(where:  { $0.name == "find_person" }) {
            let session = LanguageModelSession(model: model, tools: [load_gedcom, find_person], instructions: "You are a helpful assistant that can use tools for genealogy data")

            var result = try await session.respond(to: "Load gedcom file \"/tmp/ged.ged\"").content
            print(result)
            result = try await session.respond(to: "Who is \"Jean Carpentier\"").content
            print(result)
        }

        print("\n=== All examples completed! ===")
    }
}

let _ = try await ExampleApp.main()
