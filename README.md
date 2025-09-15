# Apple Foundation Models MCP Tool Bridge

A Swift framework that bridges Apple's Foundation Models framework with MCP (Model Context Protocol) servers, enabling developers to use existing MCP tools with Apple's on-device LLMs.

## Overview

This framework provides a bridge between Apple's Foundation Models framework (introduced in macOS 26.0) and MCP servers. It allows developers to:

1. Use Apple's on-device LLMs with the privacy and performance benefits they provide
2. Integrate existing MCP tools with Apple's framework
3. Generate both text and structured responses from the model
4. Stream responses for real-time UI updates

## Features

- **Basic Prompt/Response**: Send prompts to the model and receive text responses
- **Structured Data Generation**: Generate Swift data structures directly from model responses
- **Tool Integration**: Integrate custom tools (including MCP-compatible tools) with the model
- **Session Management**: Manage language model sessions with multiple tools
- **Streaming Responses**: Stream partially generated responses for real-time UI updates

## Requirements

- macOS 26.0+
- Xcode 15.0+
- Swift 5.9+

## Installation

### Swift Package Manager

Add the following to your `Package.swift file:

```swift
dependencies: [
    .package(url: "https://github.com/your-username/AppleFoundationMCPTool.git", from: "1.0.0")
]
```

## Usage

### Basic Usage

```swift
import AppleFoundationMCPTool

@available(macOS 26.0, *)
func example() async throws {
    let tool = AppleFoundationMCPTool()
    let response = try await tool.sendPrompt("What are the benefits of using on-device AI?")
    print(response)
}
```

### Using with Instructions

```swift
@available(macOS 26.0, *)
func example() async throws {
    let instructedTool = AppleFoundationMCPTool(instructions: "You are a helpful assistant that explains technical concepts in simple terms.")
    let response = try await instructedTool.sendPrompt("Explain what a large language model is to a 10-year-old.")
    print(response)
}
```

### Structured Data Generation

```swift
// Define a generable type
@available(macOS 26.0, *)
@Generable
struct Recipe: Codable {
    var name: String
    var ingredients: [String]
    var instructions: [String]
}

@available(macOS 26.0, *)
func example() async throws {
    let tool = AppleFoundationMCPTool()
    let recipe = try await tool.sendPrompt("Generate a simple pasta recipe", responseType: Recipe.self)
    print("Recipe: \(recipe.name)")
}
```

### Using with Tools

```swift
@available(macOS 26.0, *)
func example() async throws {
    let sessionManager = SessionManager(instructions: "You are a helpful assistant that can perform file operations.")
    let fileTool = FileOperationTool()
    sessionManager.addTool(fileTool)

    let response = try await sessionManager.sendPrompt("Read the contents of 'example.txt'")
    print(response)
}
```

### MCP Tool Integration

```swift
@available(macOS 26.0, *)
func example() async throws {
    guard let serverURL = URL(string: "http://127.0.0.1:8000/mcp") else { return }
    let mcpTool = MCPTool(serverURL: serverURL)
    let sessionManager = SessionManager()
    sessionManager.addTool(mcpTool)

    let response = try await sessionManager.sendPrompt("Call the 'get_user_info' method with parameter 'user_id' set to '123'")
    print(response)
}
```

## Testing with MCP Server

To test with an MCP server, you can use the provided test server:

1. Start the MCP server at `http://127.0.0.1:8000/mcp`
2. Use the MCPTool to communicate with the server

## Best Practices

1. **Check Model Availability**: Always check if the model is available before using it
2. **Handle Errors Gracefully**: Implement proper error handling for network requests and model generation
3. **Respect Privacy**: Remember that Foundation Models run on-device for user privacy
4. **Optimize Performance**: Use appropriate generation options and context management

## License

This project is licensed under the MIT License - see the LICENSE file for details.