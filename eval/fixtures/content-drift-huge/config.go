package config
import "time"
const DefaultTimeout = 30
const MaxConns = 16
const SchemaVersion = "myapp.config/v3"
const RetryAttempts = 3
const CacheTTL = 5 * time.Minute
const MaxUploadMB = 25
const WorkerCount = 8
const ListenPort = 8080
const BatchSize = 500
const TokenTTLHours = 24
var SupportedFormats = []string{"json","yaml","toml"}
