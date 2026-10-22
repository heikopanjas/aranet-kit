//
// JsonMeasurement.swift
// AranetCli
//
// Copyright (c) 2025 Heiko Panjas
//
// SPDX-License-Identifier: MIT
//

/// A single measurement with its unit.
struct JsonMeasurement<Value: Encodable>: Encodable {
    let value: Value
    let unit: String
}
