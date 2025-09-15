import Foundation
import FoundationModels
import MCP

/// A manager for language model sessions with tool support
@available(macOS 26.0, *)
public class SessionManager {
    private var session: LanguageModelSession
    private var tools: [any FoundationModels.Tool] = []
    
    /// Initializes a new SessionManager
    /// - Parameter instructions: Optional instructions to guide the model's behavior
    public init(instructions: String? = nil) {
        if let instructions = instructions {
            self.session = LanguageModelSession(instructions: instructions)
        } else {
            self.session = LanguageModelSession()
        }
    }
    
    /// Adds a tool to the session
    /// - Parameter tool: The tool to add
    public func addTool(_ tool: any FoundationModels.Tool) {
        tools.append(tool)
        // Recreate the session with the new tool
        recreateSession()
    }
    
    /// Removes all tools from the session
    public func removeAllTools() {
        tools.removeAll()
        recreateSession()
    }
    
    /// Recreates the session with the current tools
    private func recreateSession() {
        // Get the instructions from the session transcript
        let instructions = session.transcript.compactMap { entry -> String? in
            if case let .prompt(prompt) = entry {
                return String(describing: prompt)
            }
            return nil
        }.joined(separator: "\n")
        
        if instructions.isEmpty {
            self.session = LanguageModelSession(tools: tools)
        } else {
            self.session = LanguageModelSession(tools: tools, instructions: instructions)
        }
    }
    
    /// Sends a prompt to the language model and returns the response
    /// - Parameter prompt: The prompt to send to the model
    /// - Returns: The model's response as a string
    public func sendPrompt(_ prompt: String) async throws -> String {
        let response = try await session.respond(to: prompt)
        return response.content
    }
    
    /// Sends a prompt to the language model and returns a structured response
    /// - Parameters:
    ///   - prompt: The prompt to send to the model
    ///   - type: The type of structured response expected
    /// - Returns: The model's response as the specified type
    public func sendPrompt<T: Generable & Decodable>(_ prompt: String, responseType: T.Type) async throws -> T {
        let response = try await session.respond(to: prompt, generating: T.self)
        return response.content
    }
    
    /// Streams a response from the language model
    /// - Parameters:
    ///   - prompt: The prompt to send to the model
    ///   - type: The type of structured response expected
    /// - Returns: An async sequence of partially generated responses
    public func streamResponse<T: Generable & Decodable>(_ prompt: String, responseType: T.Type) -> LanguageModelSession.ResponseStream<T> {
        return session.streamResponse(to: prompt, generating: T.self)
    }
}