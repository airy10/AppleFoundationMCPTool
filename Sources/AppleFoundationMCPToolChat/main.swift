import Foundation
import AppleFoundationMCPTool
import Logging

/// An interactive chat program that uses Apple's Foundation Models with automatic tool calling
@available(macOS 26.0, *)
struct InteractiveChat {
    static func main() async throws {
        print("=== Apple Foundation Models Chat with Dynamic MCP Tools ===")
        print("Type your messages and press Enter to send.")
        print("Type 'quit' or 'exit' to end the conversation.")
        print("The model can automatically use tools discovered from the MCP server.")
        print("")

        // Create the session manager
        var session : LanguageModelSession? = nil

#if !canImport(AnyLanguageModel)
        let model = SystemLanguageModel.default
#elseif false
        let model = SystemLanguageModel.default
#elseif false
        let model = MLXLanguageModel(modelId: "mlx-community/Meta-Llama-3-8B-Instruct-4bit")
        //        let model = MLXLanguageModel(modelId: "mlx-community/Qwen3-0.6B-4bit")
#else
        var apiKey = "" // put your OpenCode.ai API key here
        if apiKey.count == 0 {
            print("Enter your OpenCode API key:")
            guard let input = readLine(), !input.isEmpty else {
                print("Can't run without any api key")
                exit(1)
            }
            apiKey = input

        }
        let key = apiKey
        let modelName = "grok-code"
        let model = OpenAILanguageModel(baseURL: URL(string: "https://opencode.ai/zen/v1")!,
                                        apiKey: key,
                                        model: modelName,
                                        apiVariant: .responses
        )
#endif
        // Connect to the MCP server and discover tools
        var mcpBridge: MCPToolBridge? = nil
        if let serverURL = URL(string: "http://127.0.0.1:8080/mcp") {
            do {
                mcpBridge = MCPToolBridge(serverURL: serverURL)
                var tools = try await mcpBridge!.connectAndDiscoverTools()

                if type(of:model) == SystemLanguageModel.self {
                    // Limit the tools - else the context is too big
                    tools = tools.filter { $0.name == "load_gedcom" || $0.name == "find_person" }

                }

                // Register all discovered tools with the session
                for tool in tools {
                    let description = tool.description.components(separatedBy: .newlines).first?.description ?? ""
                    print("\(tool.name) : \(description)")
                }
                session = LanguageModelSession(model: model, tools: tools)
                print("Successfully connected to MCP server and registered \(tools.count) tools.")
                print("")
            } catch {
                print("Warning: Failed to connect to MCP at \(serverURL.absoluteString): \(error.localizedDescription)")
                print("")
            }
        } else {
            print("Warning: Invalid MCP server URL. MCP functionality will not work.")
            print("")
        }

        if session == nil {
            session = LanguageModelSession(model: model);
        }
        if let session {
            // Main chat loop
            var prompt = ""
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

                prompt += "User: " + input
                // Process the user input
                do {
                    let response = try await session.respond(to: prompt)
                    let content = response.content.replacingOccurrences(of: #"<think>(.|\n)*?</think>[\n]*"#, with: "", options: .regularExpression, range: nil)

                    print("Assistant: \(response.content)")
                    prompt += "\n\nAssistant: \(content)\n\n"
                    print("")
                } catch {
                    print("Error: \(error.localizedDescription)")
                    print("")
                }
            }
        }
        // Clean up
        if let mcpBridge = mcpBridge {
            await mcpBridge.disconnect()
        }
    }
}

let _ = try await InteractiveChat.main()
