# AppleFoundationMCPTool

A Swift package that acts as a dynamic bridge between Apple's `FoundationModels` framework (or `AnyLanguageModel`)and any server implementing the [Model Context Protocol (MCP)](https://modelcontextprotocol.io).

> **A Note on This Project**
> 
> This project was largely developed by AI agents as a technical demonstration of integrating Apple's `FoundationModels` framework with the Model Context Protocol (MCP).
> 
> While functional, it should be considered a proof-of-concept rather than a production-ready solution. The practical utility is currently limited by the context size of the models available in the `FoundationModels` framework, which can make it challenging for the model to effectively use tools with complex input schemas or lengthy descriptions.
    Switching to `AnyLanguageModel` fixes this problem that allowing bigger models

## Overview

With the introduction of new on-device AI capabilities in macOS 26.0, Apple's `FoundationModels` framework provides a powerful way to interact with large language models. This project enables that new framework to communicate with a broader ecosystem of tools and servers by leveraging the open-standard Model Context Protocol.

`AppleFoundationMCPTool` discovers tools available on an MCP server at runtime and dynamically creates corresponding `FoundationModels.Tool` objects. This allows an LLM within a `FoundationModels` session to see and execute external tools without needing to know their specifics at compile time.

## Features

- **Dynamic Tool Bridging**: Automatically discovers and wraps MCP tools for use with `FoundationModels`.
- **Flexible Connections**: Supports connecting to MCP servers via two methods:
    - **HTTP/SSE**: Connects to a remote MCP server at a given URL.
    - **Stdio**: Launches a local MCP server executable and communicates with it over standard input/output.
- **Process Management**: Automatically manages the lifecycle of the server process when using a stdio connection.
- **Modern & Type-Safe**: Built with modern Swift concurrency (`async/await`) and leverages the latest `FoundationModels` APIs.

## Requirements

- macOS 26.0+
- Swift 6.0+
- An MCP-compliant server or server executable.

## Usage

The primary entry point for this library is the `MCPToolBridge` class.

### 1. Add the Package Dependency

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/your-username/AppleFoundationMCPTool.git", from: "1.0.0")
]
```

Then add the dependency to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        "AppleFoundationMCPTool"
    ]
)
```

### 2. Initialize the Bridge

You can initialize the `MCPToolBridge` in one of two ways, depending on your server setup.

#### Option A: Connect to an HTTP Server

Use this method if you have an MCP server running and listening on a specific URL.

```swift
import AppleFoundationMCPTool
import Foundation

let serverURL = URL(string: "http://127.0.0.1:8000/mcp")!
let bridge = MCPToolBridge(serverURL: serverURL)
```

#### Option B: Launch a Local Executable (Stdio)

Use this method to have the bridge launch and manage a local MCP server executable, communicating with it over stdin/stdout.

```swift
import AppleFoundationMCPTool

let serverPath = "/path/to/your/mcp_server_executable"
let bridge = MCPToolBridge(executablePath: serverPath)
```

### 3. Connect and Use Tools

Once the bridge is initialized, you can connect to the server, discover its tools, and use them in a `FoundationModels` session.

```swift
import AppleFoundationMCPTool // Will also import FoundationModels or AnyLanguageModel, depending on how the Package was built

// Assuming you have a SessionManager or similar class to manage the LLM session
do {
    // Connect to the server and get the dynamically created Apple Foundation tools
    let tools = try await bridge.connectAndDiscoverTools()
    print("Successfully discovered \(appleTools.count) tools.")

    let session = LanguageModelSession(model: model, tools: tools) 

    // You can now use the session, and the LLM will be able to see and call the tools.
    let response = try await session.prompt("Use the 'add' tool to calculate 5 + 7.")
    print(response)

} catch {
    print("An error occurred: \(error.localizedDescription)")
}

// Don't forget to disconnect when you're done.
// This will also terminate the server process if it was launched by the bridge.
await bridge.disconnect()
```

## Example Targets

This project includes two executable targets to demonstrate its functionality.

### `AppleFoundationMCPToolChat` (Recommended Example)

This is a fully interactive command-line chat application that demonstrates the end-to-end functionality of the bridge. It connects to an MCP server, registers the discovered tools, and allows you to chat with an LLM that can use those tools.

#### How to Run

1.  **Modify `main.swift`**: Open `Sources/AppleFoundationMCPToolChat/main.swift` and configure the `MCPToolBridge` initialization to point to your MCP server (either via URL or executable path).
2.  **Run from the command line**:
    ```sh
    swift run AppleFoundationMCPToolChat
    ```

### `AppleFoundationMCPToolExample`

This target contains various conceptual code snippets. It is less of a working example and more of a scratchpad that shows different ways the library components could be used. For a practical, working demonstration, please refer to the `AppleFoundationMCPToolChat` example.
