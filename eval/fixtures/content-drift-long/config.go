package config

import "time"

const DefaultTimeout = 30           // seconds
const MaxConns = 16
const SchemaVersion = "myapp.config/v3"
const RetryAttempts = 3
const CacheTTL = 5 * time.Minute

var SupportedFormats = []string{"json", "yaml", "toml"}
