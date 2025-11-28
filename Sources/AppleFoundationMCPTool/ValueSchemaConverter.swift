//
//  ValueSchemaConverter.swift
//
// Inspired by :  https://github.com/0Itsuki0/Swift_FoundationModelsWithMCP/blob/main/FoundationModelWithMCP/ValueSchemaConvertor.swift
//
import MCP
import Foundation

// MARK: - JSON Schema Keys
private enum JSONSchemaKey: String, CustomStringConvertible {
    case type = "type"
    case properties = "properties"
    case items = "items"
    case required = "required"
    case description = "description"
    case title = "title"
    case enumType = "enum"
    case constType = "const"
    case anyOf = "anyOf"

    // Types
    case null = "null"
    case boolean = "boolean"
    case number = "number"
    case integer = "integer"
    case array = "array"
    case string = "string"
    case object = "object"

    // Array constraints
    case minItems = "minItems"
    case maxItems = "maxItems"

    var description: String {
        return self.rawValue
    }
}



// MARK: ValueSchemaConvertor
// converting JSON Schema (Value) to Dynamic Generation Schema
@available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0, *)
class ValueSchemaConverter {

    let root: Value
    var decodingStack: Set<String> = []

    init(root: [String: Value]) {
        self.root = Value.object(root)
    }

    func schema() -> DynamicGenerationSchema? {
        return schema(from: root.objectValue!)
    }

    // Replace $ref values by their actual values
    private func resolvedValue(_ value: Value) -> Value {
        switch value {

        case .null, .bool, .int, .double, .string, .data:
            return value

        case .array(let array):
            return .array(array.compactMap { resolvedValue($0) })

        case .object(let object):
            if let ref = object["$ref"]?.stringValue {
                if decodingStack.contains(ref) {
                    return value // Circular references
                }
                var resolvedRef = value
                decodingStack.insert(ref)
                var success = false
                // Supports only of #/path/to/value" references for now
                if ref.hasPrefix("#") {
                    let components = ref.split(separator: "/")
                    var result = root
                    for key in components {
                        if key == "#" {
                            continue
                        }
                        if let object = result.objectValue {
                            if let val = object[String(key)] {
                                success = true
                                result = val
                            } else {
                                success = false
                                result = value
                                break
                            }
                        }
                    }
                    resolvedRef = success ? resolvedValue(result) : result
                }
                decodingStack.remove(ref)
                return resolvedRef
            } else {
                return .object(object.compactMapValues { resolvedValue($0) })

            }
        }
    }

    private func propertyFrom(value: [String: Value], name: String, description: String?, typeString: String?, required: Bool) -> DynamicGenerationSchema.Property? {
        let propertyName = name
        let propertyDescription = description
        var propertyTypeString = typeString
        var isRequired = required

        if typeString == nil {
            // Check if it's a "anyOf <types>"
            if let typeValue = value[JSONSchemaKey.anyOf.rawValue]?.arrayValue {
                let typeArray = typeValue.compactMap {$0.objectValue?[JSONSchemaKey.type.rawValue]?.stringValue}
                // We don't actually support than for now - just return the first non-null one
                if typeArray.contains(JSONSchemaKey.null.rawValue) {
                    isRequired = false
                }
                propertyTypeString = typeArray.first { $0 != JSONSchemaKey.null.rawValue }
            }
        }
        switch propertyTypeString {
        case JSONSchemaKey.null.rawValue:
            return nil

        case JSONSchemaKey.boolean.rawValue:
            let schema = DynamicGenerationSchema(type: Bool.self)
            return property(name: propertyName, description: propertyDescription, schema: schema, required: isRequired)

        case JSONSchemaKey.object.rawValue:
            let schema = schema(from: value)
            return property(name: propertyName, description: propertyDescription, schema: schema, required: isRequired)

        case JSONSchemaKey.array.rawValue:
            let arrayItems = getArrayItems(object: value)
            let (min, max) = getArrayMinMax(object: value)

            let schema = schema(from: arrayItems)
            let arraySchema = DynamicGenerationSchema(
                arrayOf: schema,
                minimumElements: min,
                maximumElements: max
            )
            return property(name: propertyName, description: propertyDescription, schema: arraySchema, required: isRequired)

        case JSONSchemaKey.number.rawValue:
            let result = applyEnumAndConstConstraints(for: value, name: propertyName, description: propertyDescription, defaultSchema: DynamicGenerationSchema(type: Double.self), required: isRequired)
            return property(name: propertyName, description: propertyDescription, schema: result.schema, required: result.isRequired)

        case JSONSchemaKey.integer.rawValue:
            let result = applyEnumAndConstConstraints(for: value, name: propertyName, description: propertyDescription, defaultSchema: DynamicGenerationSchema(type: Int.self), required: isRequired)
            return property(name: propertyName, description: propertyDescription, schema: result.schema, required: result.isRequired)

        case JSONSchemaKey.string.rawValue:
            let result = applyEnumAndConstConstraints(for: value, name: propertyName, description: propertyDescription, defaultSchema: DynamicGenerationSchema(type: String.self), required: isRequired)
            return property(name: propertyName, description: propertyDescription, schema: result.schema, required: result.isRequired)

        case JSONSchemaKey.anyOf.rawValue:
            if let value = value[JSONSchemaKey.anyOf.rawValue]?.arrayValue {
                let typeArray = value.compactMap { $0.objectValue }
                let schemasArray: [DynamicGenerationSchema] = typeArray.compactMap { self.schema(from: $0) }
                let schema = DynamicGenerationSchema(name: propertyName, description: description, anyOf: schemasArray)
                return property(name: name, description: description, schema: schema, required: isRequired)
            }

        default:
            // const or enum without type
            if let enumValue = value[JSONSchemaKey.enumType.rawValue] {
                let result = enumSchema(name: propertyName, description: description, object: enumValue)
                return property(name: propertyName, description: propertyDescription, schema: result.schema, required: result.isRequired ?? isRequired)
            }

            if let constValue = value[JSONSchemaKey.constType.rawValue], let schema = constSchema(object: constValue) {
                return property(name: propertyName, description: propertyDescription, schema: schema, required: isRequired)
            }
        }

        return nil
    }

    func schema(from object: [String: Value]) -> DynamicGenerationSchema {
        let title = getTitle(object: object) ?? UUID().uuidString
        let description = getDescription(object: object)

        if let type = getPropertyTypeString(object: object) {
            switch type {
            case JSONSchemaKey.boolean.rawValue:
                return DynamicGenerationSchema(type: Bool.self)

            case JSONSchemaKey.array.rawValue:
                let arrayItems = getArrayItems(object: object)
                let (min, max) = getArrayMinMax(object: object)
                let itemSchema = schema(from: arrayItems)

                return DynamicGenerationSchema(
                    arrayOf: itemSchema,
                    minimumElements: min,
                    maximumElements: max
                )

            case JSONSchemaKey.number.rawValue:
                return applyEnumAndConstConstraints(for: object, name: title, description: description, defaultSchema: DynamicGenerationSchema(type: Double.self), required: true).schema

            case JSONSchemaKey.integer.rawValue:
                return applyEnumAndConstConstraints(for: object, name: title, description: description, defaultSchema: DynamicGenerationSchema(type: Int.self), required: true).schema

            case JSONSchemaKey.string.rawValue:
                return applyEnumAndConstConstraints(for: object, name: title, description: description, defaultSchema: DynamicGenerationSchema(type: String.self), required: true).schema

            case JSONSchemaKey.anyOf.rawValue:
                if let value = object[JSONSchemaKey.anyOf.rawValue]?.arrayValue as? [[String: Value]] {
                    let schemasArray: [DynamicGenerationSchema] = value.compactMap { schema(from: $0) }
                    return DynamicGenerationSchema(name: title, description: description, anyOf: schemasArray)
                }

            case JSONSchemaKey.object.rawValue:
                return objectSchema(from: object, title: title, description: description)

            default:
                // Unknown type, fall through to handle as object or typeless enum/const
                break
            }
        }

        // Handle schemas without a 'type' property, or with an unhandled type
        if let value = object[JSONSchemaKey.enumType.rawValue] {
            return enumSchema(name: title, description: description, object: value).schema
        }

        if let value = object[JSONSchemaKey.constType.rawValue], let result = constSchema(object: value) {
            return result
        }

        // Fallback for objects without an explicit "type": "object"
        return objectSchema(from: object, title: title, description: description)
    }

    private func objectSchema(from object: [String: Value], title: String, description: String?) -> DynamicGenerationSchema {
        let requiredFields = getRequiredFields(object: object)
        let properties = getProperties(object: object)

        let schemaProperties: [DynamicGenerationSchema.Property] = properties.compactMap { (key, value) in
            if let value = resolvedValue(Value.object(value)).objectValue {
                let propertyName: String = key
                let propertyDescription = getDescription(object: value)
                let propertyTypeString = getPropertyTypeString(object: value)
                let required = requiredFields.contains(key)

                return propertyFrom(value: value, name: propertyName, description: propertyDescription, typeString: propertyTypeString, required: required)
            } else {
                return nil
            }
        }

        return DynamicGenerationSchema(
            name: title,
            description: description,
            properties: schemaProperties
        )
    }

    private func applyEnumAndConstConstraints(for value: [String: Value], name: String, description: String?, defaultSchema: DynamicGenerationSchema, required: Bool) -> (schema: DynamicGenerationSchema, isRequired: Bool) {
        var schema = defaultSchema
        var isRequired = required

        if let enumValue = value[JSONSchemaKey.enumType.rawValue] {
            let result = enumSchema(name: name, description: description, object: enumValue)
            schema = result.schema
            if let r = result.isRequired {
                isRequired = r
            }
        } else if let constValue = value[JSONSchemaKey.constType.rawValue], let result = constSchema(object: constValue) {
            schema = result
        }

        return (schema, isRequired)
    }

    private func property(name: String, description: String?, schema: DynamicGenerationSchema, required: Bool)  -> DynamicGenerationSchema.Property {
        return DynamicGenerationSchema.Property(
            name: name,
            description: description,
            schema: schema,
            isOptional: required == false
        )
    }

    // "color": { "enum": ["red", "amber", "green", null, 42] }
    private func enumSchema(name: String, description: String?, object: Value) -> (schema: DynamicGenerationSchema, isRequired: Bool?) {
        guard let array = object.arrayValue else {
            let schema = DynamicGenerationSchema(name: name, description: description, anyOf: [] as [String])
            return (schema: schema, isRequired: nil)
        }

        let strings = array.compactMap { $0.stringValue }

        if strings.count == array.count {
            let stringSchema = DynamicGenerationSchema(name: name, description: description, anyOf: strings)
            return (schema: stringSchema, isRequired: nil)
        }

        let required = !array.contains { $0.isNull }

        let nonStringValues = array.filter { $0.stringValue == nil }

        var schemas: [DynamicGenerationSchema] = []
        if !strings.isEmpty {
            schemas.append(DynamicGenerationSchema(name: name, description: description, anyOf: strings))
        }

        for value in nonStringValues {
            if let intValue = value.intValue {
                schemas.append(constantIntSchema(value: intValue))
            } else if let doubleValue = value.doubleValue {
                schemas.append(constantDoubleSchema(value: doubleValue))
            } else if value.boolValue != nil {
                schemas.append(DynamicGenerationSchema(type: Bool.self))
            }
        }

        let schema = DynamicGenerationSchema(name: name, description: description, anyOf: schemas)
        return (schema: schema, isRequired: required)
    }


    // "country": { "const": "United States of America" }
    // not handling array, object, or bool here
    private func constSchema(object: Value) -> DynamicGenerationSchema? {
        if let intValue = object.intValue {
            return constantIntSchema(value: intValue)
        }
        if let doubleValue = object.doubleValue {
            return constantDoubleSchema(value: doubleValue)
        }
        if let stringValue = object.stringValue {
            return constantStringSchema(value: stringValue)
        }
        if let _ = object.arrayValue {
            // array constant not supported by dynamic schema
            return nil
        }

        if let _ = object.objectValue {
            // object constant not supported by dynamic schema
            return nil
        }
        return nil
    }

    private func constantIntSchema(value: Int) -> DynamicGenerationSchema {
        DynamicGenerationSchema(type: Int.self, guides: [.range(value...value)])
    }

    private func constantDoubleSchema(value: Double) -> DynamicGenerationSchema {
        DynamicGenerationSchema(type: Double.self, guides: [.range(value...value)])
    }

    private func constantStringSchema(value: String) -> DynamicGenerationSchema {
        DynamicGenerationSchema(type: String.self, guides: [.constant(value)])
    }

    private func getRequiredFields(object: [String: Value]) -> [String] {
        guard let array = object[JSONSchemaKey.required.rawValue]?.arrayValue else {
            return []
        }
        return array.compactMap { $0.stringValue }
    }

    // minItems and maxItems
    private func getArrayMinMax(object: [String: Value]) -> (Int?, Int?) {
        let minInt = object[JSONSchemaKey.minItems.rawValue]?.intValue
        let maxInt = object[JSONSchemaKey.maxItems.rawValue]?.intValue
        return (minInt, maxInt)
    }

    private func getArrayItems(object: [String: Value]) -> [String: Value] {
        guard let items = object[JSONSchemaKey.items.rawValue]?.objectValue else {
            return [:]
        }
        return items
    }

    private func getProperties(object: [String: Value]) -> [String: [String: Value]] {
        guard let propertyObject = object[JSONSchemaKey.properties.rawValue]?.objectValue else {
            return [:]
        }
        return propertyObject.compactMapValues { $0.objectValue }
    }

    private func getDescription(object: [String: Value]) -> String? {
        return object[JSONSchemaKey.description.rawValue]?.stringValue
    }

    private func getRequired(object: [String: Value]) -> [String]? {
        guard let required = object[JSONSchemaKey.required.rawValue]?.arrayValue as? [String] else {
            return nil
        }
        return required
    }

    private func getTitle(object: [String: Value]) -> String? {
        return object[JSONSchemaKey.title.rawValue]?.stringValue
    }

    private func getPropertyTypeString(object: [String: Value]) -> String? {
        return object[JSONSchemaKey.type.rawValue]?.stringValue
    }
}

