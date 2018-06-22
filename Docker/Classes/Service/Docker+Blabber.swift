//
//  Docker+Blabber.swift
//  Docker
//
//  Created by Paolo Ardia on 22/06/18.
//

import Foundation

let DockerServiceLogModuleName = "Docker.Service"

#if BLABBER
import Blabber
public func SDLogModuleError(_ message: @autoclosure () -> String, module: String, file: StaticString = #file , function: StaticString = #function, line: UInt = #line)
{
    SDLogger.shared().log(with: .error, module: module,  file: String(describing: file), function: String(describing: function), line: line, message: message())
}
public func SDLogModuleInfo(_ message: @autoclosure () -> String, module: String,file: StaticString = #file , function: StaticString = #function, line: UInt = #line)
{
    SDLogger.shared().log(with: .error, module: module,  file: String(describing: file), function: String(describing: function), line: line, message: message())
}
public func SDLogModuleWarning(_ message: @autoclosure () -> String, module: String,file: StaticString = #file , function: StaticString = #function, line: UInt = #line)
{
    SDLogger.shared().log(with: .error, module: module,  file: String(describing: file), function: String(describing: function), line: line, message: message())
}
public func SDLogModuleVerbose(_ message: @autoclosure () -> String, module: String,file: StaticString = #file , function: StaticString = #function, line: UInt = #line)
{
    SDLogger.shared().log(with: .error, module: module,  file: String(describing: file), function: String(describing: function), line: line, message: message())
}
#else
public func SDLogError(_ message: @autoclosure () -> String, file: StaticString = #file , function: StaticString = #function, line: UInt = #line)
{
    print(message)
}
public func SDLogInfo(_ message: @autoclosure () -> String, file: StaticString = #file , function: StaticString = #function, line: UInt = #line)
{
    print(message)
}
public func SDLogWarning(_ message: @autoclosure () -> String, file: StaticString = #file , function: StaticString = #function, line: UInt = #line)
{
    print(message)
}
public func SDLogVerbose(_ message: @autoclosure () -> String, file: StaticString = #file , function: StaticString = #function, line: UInt = #line)
{
    print(message)
}
#endif
