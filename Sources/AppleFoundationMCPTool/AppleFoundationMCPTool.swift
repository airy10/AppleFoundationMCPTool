import Foundation
import FoundationModels
import MCP

/// A bridge between Apple's Foundation Models framework and MCP servers
@available(macOS 26.0, *)
public struct AppleFoundationMCPTool {
    /// The language model session used for communication with the Apple Foundation Models
    private var session: LanguageModelSession
    
    /// Initializes a new AppleFoundationMCPTool instance
    /// - Parameter instructions: Optional instructions to guide the model's behavior
    public init(instructions: String? = nil) {
        if let instructions = instructions {
            self.session = LanguageModelSession(tools: [], instructions: instructions)
        } else {
            self.session = LanguageModelSession(tools: [])
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
}