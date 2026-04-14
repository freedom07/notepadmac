import XCTest
@testable import SyntaxKit
import CommonKit

@available(macOS 13.0, *)
final class FunctionListParserTests: XCTestCase {

    // MARK: - Swift Tests

    func testSwiftFunctionParsing() {
        let code = """
        func hello() {
            print("Hello")
        }

        public func greet(name: String) -> String {
            return "Hi, \\(name)"
        }

        private func helper() {}
        """

        let symbols = FunctionListParser.parse(text: code, languageId: "swift")
        XCTAssertEqual(symbols.count, 3)
        XCTAssertEqual(symbols[0].name, "hello")
        XCTAssertEqual(symbols[0].kind, .function)
        XCTAssertEqual(symbols[0].lineNumber, 0)
        XCTAssertEqual(symbols[1].name, "greet")
        XCTAssertEqual(symbols[1].kind, .function)
        XCTAssertEqual(symbols[1].lineNumber, 4)
        XCTAssertEqual(symbols[2].name, "helper")
        XCTAssertEqual(symbols[2].kind, .function)
        XCTAssertEqual(symbols[2].lineNumber, 8)
    }

    func testSwiftClassWithMethods() {
        let code = """
        class MyClass {
            func method1() {}
            func method2() {}
        }
        """

        let symbols = FunctionListParser.parse(text: code, languageId: "swift")
        XCTAssertEqual(symbols.count, 1)
        XCTAssertEqual(symbols[0].name, "MyClass")
        XCTAssertEqual(symbols[0].kind, .class_)
        XCTAssertEqual(symbols[0].children.count, 2)
        XCTAssertEqual(symbols[0].children[0].name, "method1")
        XCTAssertEqual(symbols[0].children[0].kind, .method)
        XCTAssertEqual(symbols[0].children[1].name, "method2")
        XCTAssertEqual(symbols[0].children[1].kind, .method)
    }

    func testSwiftStructAndEnum() {
        let code = """
        struct Point {
            var x: Double
            var y: Double
        }

        enum Direction {
            case north, south, east, west
        }

        protocol Drawable {
            func draw()
        }
        """

        let symbols = FunctionListParser.parse(text: code, languageId: "swift")
        XCTAssertEqual(symbols.count, 3)
        XCTAssertEqual(symbols[0].name, "Point")
        XCTAssertEqual(symbols[0].kind, .struct_)
        XCTAssertEqual(symbols[1].name, "Direction")
        XCTAssertEqual(symbols[1].kind, .enum_)
        XCTAssertEqual(symbols[2].name, "Drawable")
        XCTAssertEqual(symbols[2].kind, .protocol_)
    }

    func testSwiftSkipsComments() {
        let code = """
        // func commentedOut() {}
        func realFunction() {}
        /*
        func inBlockComment() {}
        */
        func anotherReal() {}
        """

        let symbols = FunctionListParser.parse(text: code, languageId: "swift")
        XCTAssertEqual(symbols.count, 2)
        XCTAssertEqual(symbols[0].name, "realFunction")
        XCTAssertEqual(symbols[1].name, "anotherReal")
    }

    func testSwiftAccessModifiers() {
        let code = """
        public class PublicClass {
            private func privateMethod() {}
            internal func internalMethod() {}
            open func openMethod() {}
        }
        """

        let symbols = FunctionListParser.parse(text: code, languageId: "swift")
        XCTAssertEqual(symbols.count, 1)
        XCTAssertEqual(symbols[0].name, "PublicClass")
        XCTAssertEqual(symbols[0].children.count, 3)
    }

    // MARK: - Python Tests

    func testPythonFunctionParsing() {
        let code = """
        def hello():
            print("Hello")

        def greet(name):
            return f"Hi, {name}"

        async def async_func():
            await something()
        """

        let symbols = FunctionListParser.parse(text: code, languageId: "python")
        XCTAssertEqual(symbols.count, 3)
        XCTAssertEqual(symbols[0].name, "hello")
        XCTAssertEqual(symbols[0].kind, .function)
        XCTAssertEqual(symbols[0].lineNumber, 0)
        XCTAssertEqual(symbols[1].name, "greet")
        XCTAssertEqual(symbols[1].lineNumber, 3)
        XCTAssertEqual(symbols[2].name, "async_func")
    }

    func testPythonClassWithMethods() {
        let code = """
        class MyClass:
            def __init__(self):
                self.value = 0

            def method1(self):
                pass

            def method2(self):
                pass
        """

        let symbols = FunctionListParser.parse(text: code, languageId: "python")
        XCTAssertEqual(symbols.count, 1)
        XCTAssertEqual(symbols[0].name, "MyClass")
        XCTAssertEqual(symbols[0].kind, .class_)
        XCTAssertEqual(symbols[0].children.count, 3)
        XCTAssertEqual(symbols[0].children[0].name, "__init__")
        XCTAssertEqual(symbols[0].children[1].name, "method1")
        XCTAssertEqual(symbols[0].children[2].name, "method2")
    }

    func testPythonSkipsComments() {
        let code = """
        # def commented_out():
        def real_function():
            pass
        """

        let symbols = FunctionListParser.parse(text: code, languageId: "python")
        XCTAssertEqual(symbols.count, 1)
        XCTAssertEqual(symbols[0].name, "real_function")
    }

    // MARK: - JavaScript Tests

    func testJavaScriptFunctionParsing() {
        let code = """
        function hello() {
            console.log("Hello");
        }

        const greet = (name) => {
            return `Hi, ${name}`;
        }

        async function fetchData() {}
        """

        let symbols = FunctionListParser.parse(text: code, languageId: "javascript")
        XCTAssertEqual(symbols.count, 3)
        XCTAssertEqual(symbols[0].name, "hello")
        XCTAssertEqual(symbols[0].kind, .function)
        XCTAssertEqual(symbols[1].name, "greet")
        XCTAssertEqual(symbols[1].kind, .function)
        XCTAssertEqual(symbols[2].name, "fetchData")
        XCTAssertEqual(symbols[2].kind, .function)
    }

    func testJavaScriptClassWithMethods() {
        let code = """
        class Animal {
            constructor(name) {
                this.name = name;
            }

            speak() {
                console.log(this.name);
            }
        }
        """

        let symbols = FunctionListParser.parse(text: code, languageId: "javascript")
        XCTAssertEqual(symbols.count, 1)
        XCTAssertEqual(symbols[0].name, "Animal")
        XCTAssertEqual(symbols[0].kind, .class_)
        XCTAssertGreaterThanOrEqual(symbols[0].children.count, 1)
    }

    func testJavaScriptSkipsComments() {
        let code = """
        // function commented() {}
        function real() {}
        /*
        function inBlock() {}
        */
        function another() {}
        """

        let symbols = FunctionListParser.parse(text: code, languageId: "javascript")
        XCTAssertEqual(symbols.count, 2)
        XCTAssertEqual(symbols[0].name, "real")
        XCTAssertEqual(symbols[1].name, "another")
    }

    // MARK: - TypeScript Tests

    func testTypeScriptParsing() {
        let code = """
        interface Greeter {
            greet(name: string): string;
        }

        class MyGreeter {
            greet(name: string): string {
                return `Hello, ${name}`;
            }
        }

        enum Color {
            Red, Green, Blue
        }

        export function helper(): void {}
        """

        let symbols = FunctionListParser.parse(text: code, languageId: "typescript")
        XCTAssertEqual(symbols.count, 4)
        XCTAssertEqual(symbols[0].name, "Greeter")
        XCTAssertEqual(symbols[0].kind, .protocol_)
        XCTAssertEqual(symbols[1].name, "MyGreeter")
        XCTAssertEqual(symbols[1].kind, .class_)
        XCTAssertEqual(symbols[2].name, "Color")
        XCTAssertEqual(symbols[2].kind, .enum_)
        XCTAssertEqual(symbols[3].name, "helper")
        XCTAssertEqual(symbols[3].kind, .function)
    }

    // MARK: - Go Tests

    func testGoParsing() {
        let code = """
        func main() {
            fmt.Println("Hello")
        }

        type Server struct {
            port int
        }

        func (s *Server) Start() {
            // start server
        }

        func helper() int {
            return 42
        }
        """

        let symbols = FunctionListParser.parse(text: code, languageId: "go")
        XCTAssertEqual(symbols.count, 4)
        XCTAssertEqual(symbols[0].name, "main")
        XCTAssertEqual(symbols[0].kind, .function)
        XCTAssertEqual(symbols[1].name, "Server")
        XCTAssertEqual(symbols[1].kind, .struct_)
        XCTAssertEqual(symbols[2].name, "Start")
        XCTAssertEqual(symbols[2].kind, .method)
        XCTAssertEqual(symbols[3].name, "helper")
        XCTAssertEqual(symbols[3].kind, .function)
    }

    // MARK: - Rust Tests

    func testRustParsing() {
        let code = """
        struct Point {
            x: f64,
            y: f64,
        }

        impl Point {
            fn new(x: f64, y: f64) -> Self {
                Point { x, y }
            }
        }

        enum Direction {
            North,
            South,
        }

        pub fn main() {}
        """

        let symbols = FunctionListParser.parse(text: code, languageId: "rust")
        XCTAssertEqual(symbols.count, 4)
        XCTAssertEqual(symbols[0].name, "Point")
        XCTAssertEqual(symbols[0].kind, .struct_)
        XCTAssertEqual(symbols[1].name, "Point")
        XCTAssertEqual(symbols[1].kind, .class_)  // impl block
        XCTAssertEqual(symbols[1].children.count, 1)
        XCTAssertEqual(symbols[1].children[0].name, "new")
        XCTAssertEqual(symbols[2].name, "Direction")
        XCTAssertEqual(symbols[2].kind, .enum_)
        XCTAssertEqual(symbols[3].name, "main")
        XCTAssertEqual(symbols[3].kind, .function)
    }

    // MARK: - Ruby Tests

    func testRubyParsing() {
        let code = """
        class Animal
            def initialize(name)
                @name = name
            end

            def speak
                puts @name
            end
        end

        module Utilities
            def self.helper
                42
            end
        end
        """

        let symbols = FunctionListParser.parse(text: code, languageId: "ruby")
        XCTAssertEqual(symbols.count, 2)
        XCTAssertEqual(symbols[0].name, "Animal")
        XCTAssertEqual(symbols[0].kind, .class_)
        XCTAssertEqual(symbols[0].children.count, 2)
        XCTAssertEqual(symbols[0].children[0].name, "initialize")
        XCTAssertEqual(symbols[0].children[1].name, "speak")
        XCTAssertEqual(symbols[1].name, "Utilities")
        XCTAssertEqual(symbols[1].kind, .struct_)  // module
    }

    // MARK: - Java Tests

    func testJavaParsing() {
        let code = """
        public class Calculator {
            public int add(int a, int b) {
                return a + b;
            }

            private void reset() {
                // reset state
            }
        }
        """

        let symbols = FunctionListParser.parse(text: code, languageId: "java")
        XCTAssertEqual(symbols.count, 1)
        XCTAssertEqual(symbols[0].name, "Calculator")
        XCTAssertEqual(symbols[0].kind, .class_)
        XCTAssertEqual(symbols[0].children.count, 2)
    }

    // MARK: - Edge Cases

    func testEmptyText() {
        let symbols = FunctionListParser.parse(text: "", languageId: "swift")
        XCTAssertTrue(symbols.isEmpty)
    }

    func testUnknownLanguage() {
        let code = "function test() {}"
        let symbols = FunctionListParser.parse(text: code, languageId: "unknown")
        XCTAssertTrue(symbols.isEmpty)
    }

    func testLineNumbersAreZeroBased() {
        let code = """
        // line 0
        // line 1
        func onLineTwo() {}
        """

        let symbols = FunctionListParser.parse(text: code, languageId: "swift")
        XCTAssertEqual(symbols.count, 1)
        XCTAssertEqual(symbols[0].lineNumber, 2)
    }

    func testSymbolInfoEquality() {
        let s1 = SymbolInfo(name: "test", kind: .function, lineNumber: 0)
        let s2 = SymbolInfo(name: "test", kind: .function, lineNumber: 0)
        let s3 = SymbolInfo(name: "other", kind: .function, lineNumber: 0)

        XCTAssertEqual(s1, s2)
        XCTAssertNotEqual(s1, s3)
    }

    func testCppParsing() {
        let code = """
        class Widget {
        public:
            void draw() {
                // draw
            }
        };

        struct Config {
            int width;
        };
        """

        let symbols = FunctionListParser.parse(text: code, languageId: "cpp")
        XCTAssertGreaterThanOrEqual(symbols.count, 2)

        let classSymbol = symbols.first { $0.name == "Widget" }
        XCTAssertNotNil(classSymbol)
        XCTAssertEqual(classSymbol?.kind, .class_)

        let structSymbol = symbols.first { $0.name == "Config" }
        XCTAssertNotNil(structSymbol)
        XCTAssertEqual(structSymbol?.kind, .struct_)
    }
}
