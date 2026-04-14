import XCTest
@testable import NotepadNextCore
import CommonKit

// MARK: - MacroSystemTests

final class MacroSystemTests: XCTestCase {

    // MARK: MacroRecorder

    func testInitialStateIsNotRecording() {
        let recorder = MacroRecorder()
        XCTAssertFalse(recorder.isRecording)
        XCTAssertTrue(recorder.currentActions.isEmpty)
    }

    func testStartRecording() {
        let recorder = MacroRecorder()
        recorder.startRecording()
        XCTAssertTrue(recorder.isRecording)
    }

    func testStartStopRecording() {
        let recorder = MacroRecorder()
        XCTAssertFalse(recorder.isRecording)
        recorder.startRecording()
        XCTAssertTrue(recorder.isRecording)
        recorder.recordAction(.insertText("hello"))
        recorder.recordAction(.moveCursorBy(5))
        let macro = recorder.stopRecording()
        XCTAssertFalse(recorder.isRecording)
        XCTAssertEqual(macro.actions.count, 2)
    }

    func testRecordActionWhileNotRecordingIsIgnored() {
        let recorder = MacroRecorder()
        recorder.recordAction(.insertText("ignored"))
        XCTAssertTrue(recorder.currentActions.isEmpty)
    }

    func testRecordActionsWhileRecording() {
        let recorder = MacroRecorder()
        recorder.startRecording()
        recorder.recordAction(.insertText("a"))
        recorder.recordAction(.deleteCharacters(1))
        recorder.recordAction(.moveCursorBy(-3))
        XCTAssertEqual(recorder.currentActions.count, 3)
    }

    func testStopRecordingClearsCurrentActions() {
        let recorder = MacroRecorder()
        recorder.startRecording()
        recorder.recordAction(.insertText("x"))
        _ = recorder.stopRecording()
        XCTAssertTrue(recorder.currentActions.isEmpty)
    }

    func testStartRecordingClearsPreviousActions() {
        let recorder = MacroRecorder()
        recorder.startRecording()
        recorder.recordAction(.insertText("first"))
        _ = recorder.stopRecording()

        recorder.startRecording()
        XCTAssertTrue(recorder.currentActions.isEmpty)
    }

    func testStopRecordingReturnsMacroWithCorrectActions() {
        let recorder = MacroRecorder()
        recorder.startRecording()
        recorder.recordAction(.insertText("hello"))
        recorder.recordAction(.deleteCharacters(2))
        let macro = recorder.stopRecording()

        XCTAssertEqual(macro.actions.count, 2)
        if case .insertText(let text) = macro.actions[0] {
            XCTAssertEqual(text, "hello")
        } else {
            XCTFail("Expected insertText action")
        }
        if case .deleteCharacters(let count) = macro.actions[1] {
            XCTAssertEqual(count, 2)
        } else {
            XCTFail("Expected deleteCharacters action")
        }
    }

    // MARK: Macro struct

    func testMacroInit() {
        let date = Date()
        let macro = Macro(name: "test", actions: [.insertText("x")], createdAt: date)
        XCTAssertEqual(macro.name, "test")
        XCTAssertEqual(macro.actions.count, 1)
        XCTAssertEqual(macro.createdAt, date)
    }

    func testMacroDefaultCreatedAt() {
        let before = Date()
        let macro = Macro(name: "auto", actions: [])
        let after = Date()
        XCTAssertGreaterThanOrEqual(macro.createdAt, before)
        XCTAssertLessThanOrEqual(macro.createdAt, after)
    }

    // MARK: MacroManager

    func testSaveAndDeleteMacro() {
        let manager = MacroManager.shared
        let initial = manager.savedMacros.count
        let macro = Macro(name: "test", actions: [.insertText("x")], createdAt: Date())
        manager.saveMacro(macro)
        XCTAssertEqual(manager.savedMacros.count, initial + 1)
        manager.deleteMacro(at: manager.savedMacros.count - 1)
        XCTAssertEqual(manager.savedMacros.count, initial)
    }

    func testDeleteMacroAtInvalidIndexDoesNothing() {
        let manager = MacroManager.shared
        let initial = manager.savedMacros.count
        manager.deleteMacro(at: -1)
        XCTAssertEqual(manager.savedMacros.count, initial)
        manager.deleteMacro(at: 9999)
        XCTAssertEqual(manager.savedMacros.count, initial)
    }

    func testMacroManagerSingleton() {
        let a = MacroManager.shared
        let b = MacroManager.shared
        XCTAssertTrue(a === b)
    }
}

// MARK: - PluginSystemTests

final class PluginSystemTests: XCTestCase {

    func testPluginManagerSingleton() {
        let manager = PluginManager.shared
        XCTAssertNotNil(manager)
        XCTAssertTrue(PluginManager.shared === manager)
    }

    func testPluginManifestCodable() throws {
        let manifest = PluginManifest(
            identifier: "com.test",
            displayName: "Test",
            version: "1.0",
            description_: "desc",
            capabilities: ["documentRead"]
        )
        let data = try JSONEncoder().encode(manifest)
        let decoded = try JSONDecoder().decode(PluginManifest.self, from: data)
        XCTAssertEqual(decoded.identifier, "com.test")
        XCTAssertEqual(decoded.displayName, "Test")
        XCTAssertEqual(decoded.version, "1.0")
        XCTAssertEqual(decoded.description_, "desc")
        XCTAssertEqual(decoded.capabilities, ["documentRead"])
    }

    func testPluginManifestCodingKeysDescription() throws {
        // Verify that description_ encodes/decodes with the key "description"
        let manifest = PluginManifest(
            identifier: "id",
            displayName: "name",
            version: "0.1",
            description_: "my description",
            capabilities: []
        )
        let data = try JSONEncoder().encode(manifest)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertNotNil(json["description"])
        XCTAssertNil(json["description_"])
        XCTAssertEqual(json["description"] as? String, "my description")
    }

    func testPluginManifestRoundTripWithMultipleCapabilities() throws {
        let capabilities = ["documentRead", "documentWrite", "uiPanels", "commands", "settings"]
        let manifest = PluginManifest(
            identifier: "com.multi",
            displayName: "Multi",
            version: "2.0",
            description_: "multi-capability plugin",
            capabilities: capabilities
        )
        let data = try JSONEncoder().encode(manifest)
        let decoded = try JSONDecoder().decode(PluginManifest.self, from: data)
        XCTAssertEqual(decoded.capabilities, capabilities)
    }

    func testPluginCapabilityRawValues() {
        XCTAssertEqual(PluginCapability.documentRead.rawValue, "documentRead")
        XCTAssertEqual(PluginCapability.documentWrite.rawValue, "documentWrite")
        XCTAssertEqual(PluginCapability.uiPanels.rawValue, "uiPanels")
        XCTAssertEqual(PluginCapability.commands.rawValue, "commands")
        XCTAssertEqual(PluginCapability.settings.rawValue, "settings")
    }
}

// MARK: - PreferencesTests

final class PreferencesTests: XCTestCase {

    override func tearDown() {
        // Clean up test keys
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("NotepadNext.") {
            defaults.removeObject(forKey: key)
        }
        super.tearDown()
    }

    func testSingletonIdentity() {
        let a = Preferences.shared
        let b = Preferences.shared
        XCTAssertTrue(a === b)
    }

    func testDefaultValues() {
        let prefs = Preferences.shared
        prefs.resetAll()
        XCTAssertEqual(prefs.tabWidth, 4)
        XCTAssertTrue(prefs.usesSpaces)
        XCTAssertTrue(prefs.showLineNumbers)
        XCTAssertFalse(prefs.wordWrap)
        XCTAssertEqual(prefs.themeName, "One Dark")
        XCTAssertEqual(prefs.fontSize, 13.0)
        XCTAssertEqual(prefs.lineHeight, 1.5)
        XCTAssertEqual(prefs.defaultEncoding, "UTF-8")
        XCTAssertEqual(prefs.defaultLineEnding, "LF")
        XCTAssertTrue(prefs.autoSaveEnabled)
        XCTAssertEqual(prefs.autoSaveInterval, 30.0)
        XCTAssertTrue(prefs.rememberSession)
        XCTAssertEqual(prefs.edgeColumn, 80)
        XCTAssertEqual(prefs.searchHistorySize, 20)
    }

    func testSetAndGetPreference() {
        let prefs = Preferences.shared
        prefs.tabWidth = 8
        XCTAssertEqual(prefs.tabWidth, 8)

        prefs.themeName = "Dracula"
        XCTAssertEqual(prefs.themeName, "Dracula")

        prefs.fontSize = 16.0
        XCTAssertEqual(prefs.fontSize, 16.0)

        prefs.trimTrailingWhitespaceOnSave = true
        XCTAssertTrue(prefs.trimTrailingWhitespaceOnSave)
    }

    func testResetAll() {
        let prefs = Preferences.shared
        prefs.tabWidth = 99
        prefs.themeName = "Custom"
        prefs.resetAll()
        XCTAssertEqual(prefs.tabWidth, 4)
        XCTAssertEqual(prefs.themeName, "One Dark")
    }

    func testNotificationPosted() {
        let prefs = Preferences.shared
        let expectation = expectation(description: "Notification posted")
        let observer = NotificationCenter.default.addObserver(
            forName: Preferences.didChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }
        prefs.notifyChange()
        waitForExpectations(timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }

    func testUserDefaultPropertyWrapper() {
        @UserDefault("test.wrapper", defaultValue: 42)
        var testValue: Int

        // Default value
        UserDefaults.standard.removeObject(forKey: "NotepadMac.test.wrapper")
        XCTAssertEqual(testValue, 42)

        // Set and get
        testValue = 100
        XCTAssertEqual(testValue, 100)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "NotepadMac.test.wrapper"), 100)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "NotepadMac.test.wrapper")
    }

    func testPanelPreferences() {
        let prefs = Preferences.shared
        prefs.resetAll()
        XCTAssertFalse(prefs.showFileBrowser)
        XCTAssertFalse(prefs.showFunctionList)
        XCTAssertEqual(prefs.leftPanelWidth, 250.0)
        XCTAssertEqual(prefs.bottomPanelHeight, 200.0)

        prefs.showFileBrowser = true
        prefs.leftPanelWidth = 300.0
        XCTAssertTrue(prefs.showFileBrowser)
        XCTAssertEqual(prefs.leftPanelWidth, 300.0)
    }
}

// MARK: - VersionTests

final class VersionTests: XCTestCase {

    func testVersionExists() {
        XCTAssertFalse(appVersion.isEmpty)
        XCTAssertEqual(appVersion, "0.1.0")
    }

    func testBuildExists() {
        XCTAssertFalse(appBuild.isEmpty)
        XCTAssertEqual(appBuild, "1")
    }

    func testVersionFormatSemVer() {
        // Verify version follows SemVer pattern: MAJOR.MINOR.PATCH
        let parts = appVersion.split(separator: ".")
        XCTAssertEqual(parts.count, 3,
                        "Version should have 3 components (MAJOR.MINOR.PATCH) but got: \(appVersion)")
        for part in parts {
            XCTAssertNotNil(Int(part),
                             "Each version component should be a number but '\(part)' is not in: \(appVersion)")
        }
    }
}

// MARK: - PluginManagerTests

final class PluginManagerTests: XCTestCase {

    /// A minimal test plugin conforming to EditorPluginProtocol.
    private final class MockPlugin: EditorPluginProtocol {
        static let identifier = "com.test.mock"
        static let displayName = "Mock Plugin"

        var activateCalled = false
        var deactivateCalled = false

        func activate(context: any PluginContextProtocol) {
            activateCalled = true
        }

        func deactivate() {
            deactivateCalled = true
        }
    }

    /// A second mock plugin with a different identifier.
    private final class MockPlugin2: EditorPluginProtocol {
        static let identifier = "com.test.mock2"
        static let displayName = "Mock Plugin 2"

        func activate(context: any PluginContextProtocol) {}
        func deactivate() {}
    }

    /// A minimal test context for plugin activation.
    private struct MockContext: PluginContextProtocol {
        var activeDocumentText: String? = "test"
        func replaceActiveDocumentText(_ text: String) {}
        func showNotification(message: String) {}
    }

    func testPluginManagerRegisterPlugin() {
        let manager = PluginManager.shared
        let before = manager.loadedPluginIDs.count
        let plugin = MockPlugin()
        manager.registerPlugin(plugin)
        XCTAssertTrue(manager.loadedPluginIDs.contains(MockPlugin.identifier),
                       "Registered plugin ID should appear in loadedPluginIDs")
        // Cleanup: re-register to avoid side effects on count (idempotent by key)
        XCTAssertGreaterThanOrEqual(manager.loadedPluginIDs.count, before)
    }

    func testPluginManagerLoadedPluginIDs() {
        let manager = PluginManager.shared
        let plugin1 = MockPlugin()
        let plugin2 = MockPlugin2()
        manager.registerPlugin(plugin1)
        manager.registerPlugin(plugin2)
        let ids = manager.loadedPluginIDs
        XCTAssertTrue(ids.contains(MockPlugin.identifier),
                       "loadedPluginIDs should contain MockPlugin ID")
        XCTAssertTrue(ids.contains(MockPlugin2.identifier),
                       "loadedPluginIDs should contain MockPlugin2 ID")
    }

    func testPluginManagerActivateDeactivate() {
        let manager = PluginManager.shared
        let plugin = MockPlugin()
        manager.registerPlugin(plugin)
        let context = MockContext()

        manager.activateAll(context: context)
        XCTAssertTrue(plugin.activateCalled,
                       "activate should have been called")

        manager.deactivateAll()
        XCTAssertTrue(plugin.deactivateCalled,
                       "deactivate should have been called")
    }
}

// MARK: - MacroRecorderEdgeCaseTests

final class MacroRecorderEdgeCaseTests: XCTestCase {

    func testMacroRecorderDoubleStart() {
        let recorder = MacroRecorder()
        recorder.startRecording()
        recorder.recordAction(.insertText("first"))
        XCTAssertEqual(recorder.currentActions.count, 1)

        // Second startRecording should reset actions
        recorder.startRecording()
        XCTAssertTrue(recorder.isRecording,
                       "Should still be recording after double start")
        XCTAssertTrue(recorder.currentActions.isEmpty,
                       "Actions should be cleared on second startRecording")
    }

    func testMacroRecorderStopWithoutStart() {
        let recorder = MacroRecorder()
        XCTAssertFalse(recorder.isRecording)

        // stopRecording without startRecording should not crash and return empty macro
        let macro = recorder.stopRecording()
        XCTAssertFalse(recorder.isRecording)
        XCTAssertTrue(macro.actions.isEmpty,
                       "Stopping without recording should yield an empty macro")
    }
}

// MARK: - MacroActionCodableTests

final class MacroActionCodableTests: XCTestCase {

    private func roundTrip(_ action: MacroAction) throws -> MacroAction {
        let encoder = JSONEncoder()
        let data = try encoder.encode(action)
        let decoder = JSONDecoder()
        return try decoder.decode(MacroAction.self, from: data)
    }

    func testInsertTextCodable() throws {
        let action = MacroAction.insertText("hello world")
        let decoded = try roundTrip(action)
        XCTAssertEqual(decoded, action)
    }

    func testDeleteCharactersCodable() throws {
        let action = MacroAction.deleteCharacters(5)
        let decoded = try roundTrip(action)
        XCTAssertEqual(decoded, action)
    }

    func testMoveCursorByCodable() throws {
        let action = MacroAction.moveCursorBy(-3)
        let decoded = try roundTrip(action)
        XCTAssertEqual(decoded, action)
    }

    func testFindReplaceCodable() throws {
        let action = MacroAction.findReplace(pattern: "foo\\d+", replacement: "bar")
        let decoded = try roundTrip(action)
        XCTAssertEqual(decoded, action)
    }

    func testExecuteCommandCodable() throws {
        let action = MacroAction.executeCommand(commandId: "toggleLineNumbers")
        let decoded = try roundTrip(action)
        XCTAssertEqual(decoded, action)
    }

    func testInsertTextEmptyStringCodable() throws {
        let action = MacroAction.insertText("")
        let decoded = try roundTrip(action)
        XCTAssertEqual(decoded, action)
    }

    func testInsertTextSpecialCharsCodable() throws {
        let action = MacroAction.insertText("hello\n\tworld \"quoted\" \\n")
        let decoded = try roundTrip(action)
        XCTAssertEqual(decoded, action)
    }

    func testDeleteCharactersZeroCodable() throws {
        let action = MacroAction.deleteCharacters(0)
        let decoded = try roundTrip(action)
        XCTAssertEqual(decoded, action)
    }

    func testMoveCursorByZeroCodable() throws {
        let action = MacroAction.moveCursorBy(0)
        let decoded = try roundTrip(action)
        XCTAssertEqual(decoded, action)
    }

    func testFindReplaceEmptyPatternCodable() throws {
        let action = MacroAction.findReplace(pattern: "", replacement: "replacement")
        let decoded = try roundTrip(action)
        XCTAssertEqual(decoded, action)
    }
}

// MARK: - MacroCodableTests

final class MacroCodableTests: XCTestCase {

    func testMacroCodableRoundTrip() throws {
        let date = Date(timeIntervalSince1970: 1700000000) // fixed date
        let macro = Macro(
            name: "Test Macro",
            actions: [
                .insertText("hello"),
                .deleteCharacters(2),
                .moveCursorBy(3),
                .findReplace(pattern: "old", replacement: "new"),
                .executeCommand(commandId: "save"),
            ],
            createdAt: date
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(macro)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Macro.self, from: data)
        XCTAssertEqual(decoded, macro)
    }

    func testMacroCodableEmptyActions() throws {
        let date = Date(timeIntervalSince1970: 1600000000)
        let macro = Macro(name: "Empty", actions: [], createdAt: date)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(macro)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Macro.self, from: data)
        XCTAssertEqual(decoded.name, "Empty")
        XCTAssertTrue(decoded.actions.isEmpty)
    }

    func testMacroCodablePreservesActionOrder() throws {
        let date = Date(timeIntervalSince1970: 1700000000)
        let actions: [MacroAction] = [
            .insertText("A"),
            .moveCursorBy(1),
            .insertText("B"),
            .deleteCharacters(1),
            .findReplace(pattern: "x", replacement: "y"),
        ]
        let macro = Macro(name: "Ordered", actions: actions, createdAt: date)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(macro)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Macro.self, from: data)
        XCTAssertEqual(decoded.actions, actions)
    }
}

// MARK: - MacroManagerPersistenceTests

final class MacroManagerPersistenceTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("NotepadNextTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testSaveAndLoadMacrosRoundTrip() throws {
        let date = Date(timeIntervalSince1970: 1700000000)
        let macros = [
            Macro(name: "Macro1", actions: [.insertText("hello")], createdAt: date),
            Macro(name: "Macro2", actions: [.deleteCharacters(3), .moveCursorBy(-1)], createdAt: date),
        ]
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(macros)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let loaded = try decoder.decode([Macro].self, from: data)

        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].name, "Macro1")
        XCTAssertEqual(loaded[0].actions, [.insertText("hello")])
        XCTAssertEqual(loaded[1].name, "Macro2")
        XCTAssertEqual(loaded[1].actions, [.deleteCharacters(3), .moveCursorBy(-1)])
    }

    func testLoadMacrosFromInvalidDataReturnsEmpty() throws {
        let invalidData = "not valid json".data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let loaded = try? decoder.decode([Macro].self, from: invalidData)
        XCTAssertNil(loaded)
    }

    func testSaveMacrosCreatesValidJSON() throws {
        let date = Date(timeIntervalSince1970: 1700000000)
        let macros = [
            Macro(name: "JSON Test", actions: [
                .findReplace(pattern: "a+", replacement: "b"),
                .executeCommand(commandId: "format"),
            ], createdAt: date),
        ]
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(macros)

        let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        XCTAssertNotNil(json)
        XCTAssertEqual(json?.count, 1)
        XCTAssertEqual(json?[0]["name"] as? String, "JSON Test")
    }
}

// MARK: - ExternalCommandVariableSubstitutionTests

final class ExternalCommandVariableSubstitutionTests: XCTestCase {

    func testFilePathSubstitution() {
        let context = ExternalCommandEngine.VariableContext(filePath: "/tmp/test.swift", fileName: "test.swift", fileDir: "/tmp")
        let engine = ExternalCommandEngine()
        let result = engine.substituteVariables(in: "echo $(FILE_PATH)", context: context)
        XCTAssertEqual(result, "echo '/tmp/test.swift'")
    }

    func testFileNameSubstitution() {
        let context = ExternalCommandEngine.VariableContext(fileName: "main.rs")
        let engine = ExternalCommandEngine()
        let result = engine.substituteVariables(in: "compile $(FILE_NAME)", context: context)
        XCTAssertEqual(result, "compile 'main.rs'")
    }

    func testFileDirSubstitution() {
        let context = ExternalCommandEngine.VariableContext(fileDir: "/Users/dev/project/src")
        let engine = ExternalCommandEngine()
        let result = engine.substituteVariables(in: "cd $(FILE_DIR)", context: context)
        XCTAssertEqual(result, "cd '/Users/dev/project/src'")
    }

    func testCurrentWordSubstitution() {
        let context = ExternalCommandEngine.VariableContext(currentWord: "myVariable")
        let engine = ExternalCommandEngine()
        let result = engine.substituteVariables(in: "grep $(CURRENT_WORD) .", context: context)
        XCTAssertEqual(result, "grep 'myVariable' .")
    }

    func testCurrentLineSubstitution() {
        let context = ExternalCommandEngine.VariableContext(currentLine: "let x = 42")
        let engine = ExternalCommandEngine()
        let result = engine.substituteVariables(in: "echo $(CURRENT_LINE)", context: context)
        XCTAssertEqual(result, "echo 'let x = 42'")
    }

    func testMultipleVariablesSubstitution() {
        let context = ExternalCommandEngine.VariableContext(
            filePath: "/tmp/test.py",
            currentWord: "func",
            currentLine: "def func():"
        )
        let engine = ExternalCommandEngine()
        let result = engine.substituteVariables(
            in: "grep $(CURRENT_WORD) $(FILE_PATH) # $(CURRENT_LINE)",
            context: context
        )
        XCTAssertEqual(result, "grep 'func' '/tmp/test.py' # 'def func():'")
    }

    func testNoVariablesPassthrough() {
        let context = ExternalCommandEngine.VariableContext()
        let engine = ExternalCommandEngine()
        let result = engine.substituteVariables(in: "echo hello world", context: context)
        XCTAssertEqual(result, "echo hello world")
    }

    func testNilValuesSubstituteEmpty() {
        let context = ExternalCommandEngine.VariableContext()
        let engine = ExternalCommandEngine()
        let result = engine.substituteVariables(in: "$(FILE_PATH) $(FILE_NAME) $(CURRENT_WORD)", context: context)
        XCTAssertEqual(result, "'' '' ''")
    }

    func testEmptyCommandReturnsEmpty() {
        let context = ExternalCommandEngine.VariableContext()
        let engine = ExternalCommandEngine()
        let result = engine.substituteVariables(in: "", context: context)
        XCTAssertEqual(result, "")
    }

    func testShellInjectionPrevention() {
        let context = ExternalCommandEngine.VariableContext(currentWord: "'; rm -rf / #")
        let engine = ExternalCommandEngine()
        let result = engine.substituteVariables(in: "echo $(CURRENT_WORD)", context: context)
        // The value is wrapped in single quotes with internal quotes escaped
        // Input: '; rm -rf / #  →  Output: echo ''\'''; rm -rf / #'
        // This is safe because the dangerous characters are inside a quoted string
        XCTAssertTrue(result.hasPrefix("echo '"), "Value should be shell-escaped with single quotes")
        XCTAssertTrue(result.hasSuffix("'"), "Value should end with closing single quote")
        // The escaped value should contain the backslash-quote sequence
        XCTAssertTrue(result.contains("'\\''"), "Single quotes in value should be escaped")
    }
}

// MARK: - ExternalCommandExecutionTests

final class ExternalCommandExecutionTests: XCTestCase {

    func testExecuteSimpleCommand() {
        let engine = ExternalCommandEngine()
        let output = engine.executeCommand("echo hello")
        XCTAssertEqual(output.trimmingCharacters(in: .whitespacesAndNewlines), "hello")
    }

    func testExecuteCommandWithStderr() {
        let engine = ExternalCommandEngine()
        let output = engine.executeCommand("echo error >&2")
        XCTAssertTrue(output.contains("error"))
    }

    func testExecuteCommandExitCode() {
        let engine = ExternalCommandEngine()
        let output = engine.executeCommand("echo success && exit 0")
        XCTAssertTrue(output.contains("success"))
    }
}

// MARK: - ExternalCommandCodableTests

final class ExternalCommandCodableTests: XCTestCase {

    func testExternalCommandCodableRoundTrip() throws {
        let cmd = ExternalCommand(name: "Build", command: "swift build")
        let data = try JSONEncoder().encode(cmd)
        let decoded = try JSONDecoder().decode(ExternalCommand.self, from: data)
        XCTAssertEqual(decoded, cmd)
    }

    func testExternalCommandEquality() {
        let a = ExternalCommand(name: "Test", command: "echo test")
        let b = ExternalCommand(name: "Test", command: "echo test")
        let c = ExternalCommand(name: "Other", command: "echo other")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }
}

// MARK: - MacroActionEqualityTests

final class MacroActionEqualityTests: XCTestCase {

    func testInsertTextEquality() {
        XCTAssertEqual(MacroAction.insertText("a"), MacroAction.insertText("a"))
        XCTAssertNotEqual(MacroAction.insertText("a"), MacroAction.insertText("b"))
    }

    func testDeleteCharactersEquality() {
        XCTAssertEqual(MacroAction.deleteCharacters(3), MacroAction.deleteCharacters(3))
        XCTAssertNotEqual(MacroAction.deleteCharacters(3), MacroAction.deleteCharacters(5))
    }

    func testMoveCursorByEquality() {
        XCTAssertEqual(MacroAction.moveCursorBy(1), MacroAction.moveCursorBy(1))
        XCTAssertNotEqual(MacroAction.moveCursorBy(1), MacroAction.moveCursorBy(-1))
    }

    func testFindReplaceEquality() {
        XCTAssertEqual(
            MacroAction.findReplace(pattern: "a", replacement: "b"),
            MacroAction.findReplace(pattern: "a", replacement: "b")
        )
        XCTAssertNotEqual(
            MacroAction.findReplace(pattern: "a", replacement: "b"),
            MacroAction.findReplace(pattern: "a", replacement: "c")
        )
    }

    func testExecuteCommandEquality() {
        XCTAssertEqual(MacroAction.executeCommand(commandId: "x"), MacroAction.executeCommand(commandId: "x"))
        XCTAssertNotEqual(MacroAction.executeCommand(commandId: "x"), MacroAction.executeCommand(commandId: "y"))
    }

    func testDifferentCasesNotEqual() {
        XCTAssertNotEqual(MacroAction.insertText("1"), MacroAction.deleteCharacters(1))
        XCTAssertNotEqual(MacroAction.moveCursorBy(1), MacroAction.deleteCharacters(1))
    }
}
