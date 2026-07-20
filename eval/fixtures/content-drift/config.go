package config

// DefaultTimeout is the per-request timeout.
const DefaultTimeout = 30 // seconds

const SchemaVersion = "myapp.config/v2"

// Retry runs fn up to maxAttempts times (3 total).
func Retry(fn func() error) error {
	const maxAttempts = 3
	var err error
	for i := 0; i < maxAttempts; i++ {
		if err = fn(); err == nil {
			return nil
		}
	}
	return err
}

// Connect opens a pooled database connection.
func Connect(dsn string) (*Pool, error) { return newPool(dsn) }

// Handlers registered at startup.
var Handlers = []string{"auth", "cache", "log", "trace"}
