//
// JsonError.swift
// AranetCli
//
// Copyright (c) 2025 Heiko Panjas
//
// SPDX-License-Identifier: MIT
//

/// An error in machine-readable form, written to standard output in JSON mode.
struct JsonError: Encodable {
    let error: String
    let device: String?
}
